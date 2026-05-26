package com.example.meetra_app

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.*

/**
 * VoiceMaskDsp
 *
 * Owns ALL audio signal processing: pitch shifting, filters, effects, noise gate,
 * limiter, and buffer I/O from/to a JNI DirectByteBuffer.
 *
 * THREAD SAFETY:
 *   - onProcess() runs on WebRTC's dedicated audio thread (~every 10ms).
 *   - switchPreset() is called from the MethodChannel UI thread.
 *   - We use AtomicReference<VoiceMaskPreset> for lock-free preset reads and
 *     synchronize only on the ring/filter state reset during a preset switch
 *     (which completes in under 1ms — well within one 10ms frame window).
 */
class VoiceMaskDsp {

    // ── Preset (atomic for lock-free read on audio thread) ───────────────
    private val activePreset = AtomicReference(VoiceMaskPreset.NONE)

    // Custom pitch override (for the "custom" preset slider)
    @Volatile private var customPitchFactor: Double = 1.0

    // ── Sample rate (set once on onInit/onReset) ──────────────────────────
    @Volatile private var sampleRate: Int = 48000

    // ── Noise gate ────────────────────────────────────────────────────────
    // Threshold below which an entire 10ms frame is considered silence.
    // 0.001f ≈ -60dBFS (lowered to prevent attenuation of quiet speech)
    private val GATE_THRESHOLD = 0.001f
    private var gateGain = 0f
    private var smoothedPitchFactor = 1.0

    // ── Ring buffer (pitch shifter) ───────────────────────────────────────
    // Size must be large enough for max delay at lowest sample rate.
    // At 16kHz, 96000 samples = 6 seconds. At 48kHz = 2 seconds. More than enough.
    private var ring = FloatArray(96000) { 0f }
    private var rSize = ring.size

    // Write pointer — monotonically increasing; modulo rSize when accessing ring[].
    @Volatile private var writePos = 0L

    // 4-Phase Overlap-Add (OLA) state for smooth pitch shifting
    private var phase1 = 0.0
    private var phase2 = 0.25
    private var phase3 = 0.5
    private var phase4 = 0.75

    // ── Hann window cache ─────────────────────────────────────────────────
    // Precomputed for the current windowSize so we don't call cos() every sample.
    private var hannWindow = FloatArray(0)
    private var windowSize = 0   // samples, ~35ms at current sample rate

    // ── IIR filter state ──────────────────────────────────────────────────
    // Single-pole biquad state variables reset on every preset switch.
    private var lpfState = 0f      // Low-pass filter
    private var hpfState = 0f      // High-pass filter
    private var bpfLowState = 0f   // Band-pass (low-pass stage)
    private var bpfHighState = 0f  // Band-pass (high-pass stage)

    // ── Robot (ring modulation) ───────────────────────────────────────────
    private var robotPhase = 0.0

    // ── Flanger ───────────────────────────────────────────────────────────
    private var flangerBuf = FloatArray(4800) { 0f }
    private var flangerWritePos = 0
    private var flangerLfoPhase = 0.0

    // ── Chorus ────────────────────────────────────────────────────────────
    private var chorusBuf = FloatArray(4800) { 0f }
    private var chorusWritePos = 0

    // ── Reverb ────────────────────────────────────────────────────────────
    // Simple comb-filter reverb: one delay line + feedback.
    private var reverbBuf = FloatArray(24000) { 0f }
    private var reverbReadPos = 0
    private var reverbWritePos = 0

    // ── Working Buffers (Zero Allocation) ─────────────────────────────────
    private val workShorts = ShortArray(96000)
    private val workFloats = FloatArray(96000)
    private val pitchOut = FloatArray(96000)

    // ── Stats ─────────────────────────────────────────────────────────────
    @Volatile var processCallCount = 0L
        private set

    // ─────────────────────────────────────────────────────────────────────
    //  Public API
    // ─────────────────────────────────────────────────────────────────────

    /** Called from VoiceMaskPlugin.onInit() / onReset() — MethodChannel thread safe.
     *
     *  IMPORTANT: This may be called on every audio frame from the DSP callback.
     *  We MUST guard with a sample-rate check to avoid flushing state on every frame.
     *  Flushing state destroys the ring buffer, phase pointers, and filter state,
     *  which breaks ALL pitch shifting and effects.
     */
    fun configure(sr: Int) {
        if (sr == sampleRate && ring.isNotEmpty()) return  // Already configured — skip
        sampleRate = sr
        rebuildBuffers(sr)
    }

    /**
     * Atomically switches to a new preset.
     *
     * The preset reference is updated atomically first so the audio thread
     * reads the new preset immediately. Then we flush all filter/buffer state
     * in a synchronized block. The flush takes <0.1ms — well under one 10ms frame.
     */
    fun switchPreset(preset: VoiceMaskPreset) {
        activePreset.set(preset)
        synchronized(this) { flushState() }
    }

    /** Override for the custom-pitch slider (UI thread). */
    fun setCustomPitchFactor(factor: Double) {
        customPitchFactor = factor
        // If "custom" is active, no flush needed — factor is read sample-by-sample.
    }

    /**
     * Main entry point. Called from VoiceMaskPlugin.onProcess() on the WebRTC audio thread.
     *
     * Reads 16-bit PCM shorts from [buffer], processes them according to the active preset,
     * and writes the result BACK into the exact same buffer positions.
     *
     * @param numBands  Number of frequency bands WebRTC passes (typically 1 at 48kHz full-band).
     * @param numFrames Number of samples per band per channel (typically 480 at 48kHz/10ms).
     * @param buffer    DirectByteBuffer shared between WebRTC C++ and Kotlin JNI.
     */
    fun processBuffer(numBands: Int, numFrames: Int, buffer: ByteBuffer) {
        processCallCount++
        val preset = activePreset.get()

        // Hard bypass — write nothing back, return raw mic audio as-is.
        if (preset.bypass) return



        // Defensive: skip corrupted/unexpected frames.
        val cap = buffer.capacity()
        if (cap <= 0 || numFrames <= 0) return

        // Calculate layout: [bands × channels × frames] shorts.
        // At 48kHz full-band: numBands=1, numFrames=480.
        val totalShorts = cap / 2
        val numChannels = totalShorts / (numBands * numFrames)
        if (numChannels < 1) return

        // ── 0. Save Buffer State ───────────────────────────────────────
        // WebRTC C++ relies on the exact state of this buffer.
        val savedPosition = buffer.position()
        val savedLimit = buffer.limit()

        // ── 1. Read entire buffer into reused ShortArray ─────────────
        buffer.rewind()
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        buffer.asShortBuffer().get(workShorts, 0, totalShorts)

        // ── 2. Extract channels and run DSP in-place ───────────────────
        for (c in 0 until numChannels) {
            // Read interleaved data for this channel
            for (i in 0 until numFrames) {
                workFloats[i] = workShorts[i * numChannels + c] / 32768f
            }

            // Run DSP chain
            runDspChain(workFloats, numFrames, preset)

            // Write back interleaved data
            for (i in 0 until numFrames) {
                workShorts[i * numChannels + c] = (workFloats[i].coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            }
        }

        // ── 5. Write back into the SAME DirectByteBuffer ───────────────
        buffer.rewind()
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        buffer.asShortBuffer().put(workShorts, 0, totalShorts)

        // ── 6. Restore Buffer State ────────────────────────────────────
        // CRITICAL: WebRTC C++ might use position/limit to read the data.
        buffer.limit(savedLimit)
        buffer.position(savedPosition)
    }

    // ─────────────────────────────────────────────────────────────────────
    //  DSP Chain
    // ─────────────────────────────────────────────────────────────────────

    private fun runDspChain(buffer: FloatArray, size: Int, preset: VoiceMaskPreset) {

        // STAGE 1: Noise Gate (with Hysteresis Smoothing)
        var peak = 0f
        for (i in 0 until size) { val a = abs(buffer[i]); if (a > peak) peak = a }
        
        val targetGate = if (peak > GATE_THRESHOLD) 1f else 0f
        val pitchFactor = if (preset.id == "custom") customPitchFactor else preset.pitchFactor
        
        smoothedPitchFactor += (pitchFactor - smoothedPitchFactor) * 0.1
        
        if (abs(smoothedPitchFactor - 1.0) > 0.001) {
            pitchShiftOla(buffer, size, smoothedPitchFactor)
        }
        
        // Apply smoothed noise gate gain across the frame.
        val gateCoef = if (targetGate > gateGain) 0.1f else 0.001f
        for (i in 0 until size) {
            gateGain += (targetGate - gateGain) * gateCoef
            buffer[i] *= gateGain
        }

        // STAGE 3: Distortion (Add presence/grit)
        if (preset.distortion > 0f) {
            saturate(buffer, size, preset.distortion)
        }

        // STAGE 4: Tone Shaping (Filters)
        if (preset.bassBoost > 0f) {
            bassBoost(buffer, size, preset.bassBoost)
        }
        
        if (preset.bandLowHz > 0f && preset.bandHighHz > 0f) {
            bandPass(buffer, size, preset.bandLowHz, preset.bandHighHz)
        } else {
            if (preset.lowPassHz > 0f) lowPass(buffer, size, preset.lowPassHz)
            if (preset.highPassHz > 0f) highPass(buffer, size, preset.highPassHz)
        }

        // STAGE 5: Vibrato/Warble
        if (preset.vibratoRate > 0f) {
            vibrato(buffer, size, preset.vibratoRate, preset.vibratoDepth)
        }

        // STAGE 6: Robot (Ring Modulation)
        if (preset.robotHz > 0f) {
            ringModulate(buffer, size, preset.robotHz)
        }

        // STAGE 7: Modulation Effects
        if (preset.flangerRate > 0f) {
            flanger(buffer, size, preset.flangerRate, preset.flangerDepth)
        }
        if (preset.chorusDepth > 0f) {
            chorus(buffer, size, preset.chorusDepth)
        }

        // STAGE 8: Reverb
        if (preset.reverbMix > 0f) {
            reverb(buffer, size, preset.reverbMix)
        }

        // STAGE 9: Final Gain & Soft Limiter
        for (i in 0 until size) {
            var s = buffer[i] * preset.masterGain
            // Wider Soft-knee clipping above 0.7 to prevent harsh distortion
            if (s > 0.7f) s = 0.7f + (s - 0.7f) * 0.5f
            else if (s < -0.7f) s = -0.7f + (s + 0.7f) * 0.5f
            buffer[i] = s.coerceIn(-0.98f, 0.98f)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Pitch Shifter: Hann-windowed OLA (Overlap-Add)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Granular pitch shifting using dual-pointer Overlap-Add with a Hann window.
     *
     * HOW IT WORKS:
     *   1. Incoming samples are written into a circular ring buffer.
     *   2. Two "read heads" (phase1, phase2, offset by 0.5 cycles) read from the buffer
     *      at different delays. The delay shifts over time proportional to (1 - pitchFactor).
     *   3. Each read head's output is multiplied by a Hann window so their contributions
     *      smoothly cross-fade, eliminating the clicking/stuttering that would occur with a
     *      hard switch.
     *   4. When the read head crosses the write head, it jumps by +windowSize to stay behind.
     *
     * THREAD SAFETY: Entirely single-threaded (called only from processBuffer on WebRTC thread).
     */
    private fun pitchShiftOla(buffer: FloatArray, size: Int, pitchFactor: Double) {
        ensureHannWindow()
        val halfWindow = windowSize / 2

        for (i in 0 until size) {
            val wp = (writePos % rSize).toInt()
            ring[wp] = buffer[i]

            // Increment common phase
            val pInc = (1.0 - pitchFactor) / windowSize
            phase1 = (phase1 + pInc) % 1.0; if (phase1 < 0) phase1 += 1.0
            
            // Calculate other phases offset by 1/4 cycle
            phase2 = (phase1 + 0.25) % 1.0
            phase3 = (phase1 + 0.50) % 1.0
            phase4 = (phase1 + 0.75) % 1.0

            // Convert to delays
            val d1 = (phase1 * windowSize) + halfWindow + 5.0
            val d2 = (phase2 * windowSize) + halfWindow + 5.0
            val d3 = (phase3 * windowSize) + halfWindow + 5.0
            val d4 = (phase4 * windowSize) + halfWindow + 5.0

            // Read 4 grains
            val s1 = readInterpolated(writePos - d1)
            val s2 = readInterpolated(writePos - d2)
            val s3 = readInterpolated(writePos - d3)
            val s4 = readInterpolated(writePos - d4)

            // Window indices
            val wi1 = (phase1 * windowSize).toInt().coerceIn(0, windowSize - 1)
            val wi2 = (phase2 * windowSize).toInt().coerceIn(0, windowSize - 1)
            val wi3 = (phase3 * windowSize).toInt().coerceIn(0, windowSize - 1)
            val wi4 = (phase4 * windowSize).toInt().coerceIn(0, windowSize - 1)

            // Mix (normalized by 2.0 because 4 Hann windows sum to 2.0)
            pitchOut[i] = (s1 * hannWindow[wi1] + s2 * hannWindow[wi2] + 
                           s3 * hannWindow[wi3] + s4 * hannWindow[wi4]) * 0.5f

            writePos++
        }
        
        System.arraycopy(pitchOut, 0, buffer, 0, size)
    }

    /**
     * Linear interpolation read from the ring buffer.
     * [readPos] is an absolute (non-modulo) sample position.
     */
    private fun readInterpolated(readPos: Double): Float {
        // Compute the modulo position in the ring buffer.
        var rp = readPos % rSize
        if (rp < 0) rp += rSize

        val i0 = rp.toInt()
        val fraction = (rp - i0).toFloat()
        val i1 = (i0 + 1) % rSize

        return ring[i0] * (1f - fraction) + ring[i1] * fraction
    }

    /**
     * Ensures the Hann window is computed for the current sample rate.
     * Only rebuilds if the window size has changed (e.g. after configure()).
     */
    private fun ensureHannWindow() {
        // Increased window size (45ms) for smoother low-end fidelity (Dark Lord/Giant).
        val targetSize = (sampleRate * 0.045).toInt().coerceAtLeast(64)
        if (hannWindow.size == targetSize) return  // Already correct, skip.
        windowSize = targetSize
        hannWindow = FloatArray(windowSize) { i ->
            // Standard Hann formula: w(n) = 0.5 * (1 - cos(2π * n / N))
            (0.5 * (1.0 - cos(2.0 * PI * i / (windowSize - 1)))).toFloat()
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  IIR Filters  (single-pole, O(1) per sample)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Single-pole IIR Low-Pass Filter.
     *
     * The coefficient alpha is derived from the RC time constant:
     *   alpha = 1 / (1 + 2π * fc / sampleRate)
     * Equivalent to: alpha = exp(-2π * fc / sampleRate) for small fc/sr ratios.
     *
     * Output[n] = alpha * Output[n-1] + (1 - alpha) * Input[n]
     */
    private fun lowPass(buffer: FloatArray, size: Int, cutoffHz: Float) {
        val alpha = cutoffHz / (cutoffHz + sampleRate / (2f * PI.toFloat()))
        for (i in 0 until size) {
            lpfState = lpfState + alpha * (buffer[i] - lpfState)
            buffer[i] = lpfState
        }
    }

    /**
     * Single-pole IIR High-Pass Filter.
     * HP is derived from LP: HP[n] = Input[n] - LP[n]
     */
    private fun highPass(buffer: FloatArray, size: Int, cutoffHz: Float) {
        val alpha = cutoffHz / (cutoffHz + sampleRate / (2f * PI.toFloat()))
        for (i in 0 until size) {
            hpfState = hpfState + alpha * (buffer[i] - hpfState)
            buffer[i] = buffer[i] - hpfState   // HP = Input - LP
        }
    }

    /**
     * Band-Pass filter: apply LP followed by HP.
     * Frequencies between [lowHz, highHz] pass through; all others are attenuated.
     */
    private fun bandPass(buffer: FloatArray, size: Int, lowHz: Float, highHz: Float) {
        // Low-pass to remove everything above highHz.
        val lpAlpha = highHz / (highHz + sampleRate / (2f * PI.toFloat()))
        // High-pass to remove everything below lowHz.
        val hpAlpha = lowHz / (lowHz + sampleRate / (2f * PI.toFloat()))

        for (i in 0 until size) {
            // LP stage
            bpfLowState = bpfLowState + lpAlpha * (buffer[i] - bpfLowState)
            // HP stage applied to LP output
            bpfHighState = bpfHighState + hpAlpha * (bpfLowState - bpfHighState)
            buffer[i] = bpfLowState - bpfHighState
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Effects
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Saturation / Distortion: waveshaper to add harmonics.
     * x' = tanh(x * (1 + amount * 3))
     */
    private fun saturate(buffer: FloatArray, size: Int, amount: Float) {
        val drive = 1f + amount * 3f
        for (i in 0 until size) {
            val x = buffer[i] * drive
            // tanh approximation: x * (27 + x^2) / (27 + 9 * x^2)
            buffer[i] = (x * (27f + x * x) / (27f + 9f * x * x)).coerceIn(-1f, 1f)
        }
    }

    /**
     * Simple low-shelf bass boost.
     */
    private fun bassBoost(buffer: FloatArray, size: Int, amount: Float) {
        // Apply a gentle low-pass mixed back with original to boost bass.
        System.arraycopy(buffer, 0, pitchOut, 0, size) // Reuse pitchOut as temp buffer
        lowPass(pitchOut, size, 300f)
        for (i in 0 until size) {
            buffer[i] = buffer[i] + pitchOut[i] * amount
        }
    }

    /**
     * Vibrato: LFO-modulated pitch shifting or delay.
     * Here we just modulate the smoothedPitchFactor's TARGET.
     */
    private var vibratoPhase = 0.0
    private fun vibrato(buffer: FloatArray, size: Int, rate: Float, depth: Float) {
        val angularFreq = 2.0 * PI * rate / sampleRate
        val dFactor = Math.pow(2.0, depth.toDouble() / 12.0) - 1.0
        
        for (i in 0 until size) {
            val lfo = sin(vibratoPhase)
            val mod = 1.0 + lfo * dFactor
            // Stub for now. Delay-based vibrato requires modulating read delays.
            // buffer[i] remains unmodified.
            vibratoPhase += angularFreq
            if (vibratoPhase >= 2.0 * PI) vibratoPhase -= 2.0 * PI
        }
    }

    /**
     * Ring Modulation: multiplies input by a carrier sine wave at [carrierHz].
     * Creates the classic metallic "robot" buzz by folding sidebands into the spectrum.
     */
    private fun ringModulate(buffer: FloatArray, size: Int, carrierHz: Float) {
        val angularFreq = 2.0 * PI * carrierHz / sampleRate
        for (i in 0 until size) {
            buffer[i] = (buffer[i] * sin(robotPhase)).toFloat()
            robotPhase += angularFreq
            // Keep robotPhase in [0, 2π) to prevent accumulation of floating point error.
            if (robotPhase >= 2.0 * PI) robotPhase -= 2.0 * PI
        }
    }

    /**
     * Flanger effect: mixes dry signal with a delayed copy.
     * The delay time is modulated by a slow LFO to create the "sweeping jet" sound.
     */
    private fun flanger(buffer: FloatArray, size: Int, rate: Float, depth: Float) {
        val maxDelaySamples = (depth * sampleRate).toInt().coerceAtLeast(1)
        val lfoAngFreq = 2.0 * PI * rate / sampleRate

        for (i in 0 until size) {
            val wp = flangerWritePos % flangerBuf.size
            flangerBuf[wp] = buffer[i]

            val lfoValue = (1.0 + sin(flangerLfoPhase)) / 2.0  // LFO range [0, 1]
            val delaySamples = (lfoValue * maxDelaySamples).toInt().coerceAtLeast(1)

            var rp = flangerWritePos - delaySamples
            if (rp < 0) rp += flangerBuf.size
            val delayedSample = flangerBuf[rp % flangerBuf.size]

            buffer[i] = buffer[i] * 0.7f + delayedSample * 0.3f

            flangerWritePos++
            flangerLfoPhase += lfoAngFreq
            if (flangerLfoPhase >= 2.0 * PI) flangerLfoPhase -= 2.0 * PI
        }
    }

    /**
     * Subtle Chorus effect: mixes input with a fixed-delay copy.
     */
    private fun chorus(buffer: FloatArray, size: Int, depth: Float) {
        val delaySamples = (depth * sampleRate).toInt().coerceAtLeast(1)

        for (i in 0 until size) {
            val wp = chorusWritePos % chorusBuf.size
            chorusBuf[wp] = buffer[i]

            var rp = chorusWritePos - delaySamples
            if (rp < 0) rp += chorusBuf.size
            val delayed = chorusBuf[rp % chorusBuf.size]

            buffer[i] = buffer[i] * 0.75f + delayed * 0.25f
            chorusWritePos++
        }
    }

    /**
     * Simple comb-filter reverb for ambient "space" effects.
     */
    private fun reverb(buffer: FloatArray, size: Int, mix: Float) {
        for (i in 0 until size) {
            val delayed = reverbBuf[reverbReadPos % reverbBuf.size]
            reverbBuf[reverbWritePos % reverbBuf.size] = buffer[i] + delayed * 0.3f
            buffer[i] = buffer[i] * (1f - mix) + delayed * mix
            reverbReadPos++
            reverbWritePos++
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Buffer Management
    // ─────────────────────────────────────────────────────────────────────

    private fun rebuildBuffers(sr: Int) {
        synchronized(this) {
            val ringSz = maxOf(sr * 2, 96000)
            ring = FloatArray(ringSz)
            rSize = ringSz

            flangerBuf = FloatArray(maxOf(sr / 5, 4800))
            chorusBuf  = FloatArray(maxOf(sr / 5, 4800))
            reverbBuf  = FloatArray(maxOf(sr / 2, 24000))

            hannWindow = FloatArray(0)  // Force Hann window rebuild on next call.
            flushState()
        }
    }

    /**
     * Flushes all DSP state. Called synchronously during preset switch and on rebuild.
     * Must complete in < 1ms (it's just array fills and counter resets).
     */
    private fun flushState() {
        ring.fill(0f)
        writePos = 0L
        robotPhase = 0.0
        gateGain = 0f
        smoothedPitchFactor = 1.0
        phase1 = 0.0; phase2 = 0.25; phase3 = 0.5; phase4 = 0.75
        flangerBuf.fill(0f); flangerWritePos = 0; flangerLfoPhase = 0.0
        chorusBuf.fill(0f); chorusWritePos = 0
        reverbBuf.fill(0f); reverbReadPos = 0; reverbWritePos = 0
    }
}
