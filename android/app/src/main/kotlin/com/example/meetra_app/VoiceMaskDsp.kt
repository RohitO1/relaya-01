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
    // 0.004f ≈ -68dBFS — below typical breath noise but above absolute silence.
    private val GATE_THRESHOLD = 0.004f

    // ── Ring buffer (pitch shifter) ───────────────────────────────────────
    // Size must be large enough for max delay at lowest sample rate.
    // At 16kHz, 96000 samples = 6 seconds. At 48kHz = 2 seconds. More than enough.
    private var ring = FloatArray(96000) { 0f }
    private var rSize = ring.size

    // Write pointer — monotonically increasing; modulo rSize when accessing ring[].
    @Volatile private var writePos = 0L

    // Dual read-pointer phases for Hann cross-fade OLA (Overlap-Add) pitch shift.
    // Both are in the range [0.0, 1.0) representing where in the window cycle we are.
    private var phase1 = 0.0
    private var phase2 = 0.5   // Offset by half-cycle so the two windows complement.

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

    // ── Stats ─────────────────────────────────────────────────────────────
    @Volatile var processCallCount = 0L
        private set

    // ─────────────────────────────────────────────────────────────────────
    //  Public API
    // ─────────────────────────────────────────────────────────────────────

    /** Called from VoiceMaskPlugin.onInit() / onReset() — MethodChannel thread safe. */
    fun configure(sr: Int) {
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

        // ── 1. Read entire buffer into a Kotlin ShortArray ─────────────
        buffer.rewind()
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        val shorts = ShortArray(totalShorts)
        buffer.asShortBuffer().get(shorts)

        // ── 2. Extract channels and run DSP ────────────────────────────
        for (c in 0 until numChannels) {
            val channelData = FloatArray(numFrames)
            // Read interleaved data for this channel
            for (i in 0 until numFrames) {
                channelData[i] = shorts[i * numChannels + c] / 32768f
            }

            // Run DSP chain
            val processed = runDspChain(channelData, preset)

            // Write back interleaved data
            for (i in 0 until numFrames) {
                shorts[i * numChannels + c] = (processed[i].coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            }
        }

        // ── 5. Write back into the SAME DirectByteBuffer ───────────────
        buffer.rewind()
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        buffer.asShortBuffer().put(shorts)

        // ── 6. Restore Buffer State ────────────────────────────────────
        // CRITICAL: WebRTC C++ might use position/limit to read the data.
        buffer.limit(savedLimit)
        buffer.position(savedPosition)
    }

    // ─────────────────────────────────────────────────────────────────────
    //  DSP Chain
    // ─────────────────────────────────────────────────────────────────────

    private fun runDspChain(input: FloatArray, preset: VoiceMaskPreset): FloatArray {

        // STAGE 1: Noise Gate
        // Compute peak amplitude of the frame. If below threshold, it's silence/hiss.
        var peak = 0f
        for (s in input) { val a = abs(s); if (a > peak) peak = a }
        if (peak < GATE_THRESHOLD) {
            // Frame is below the noise floor. Return zeroed output.
            // This eliminates hiss, breath, and background noise between words.
            return FloatArray(input.size)
        }

        // STAGE 2: Pitch Shift (Granular OLA)
        val pitchFactor = if (preset.id == "custom") customPitchFactor else preset.pitchFactor
        var out = if (abs(pitchFactor - 1.0) > 0.001) {
            pitchShiftOla(input, pitchFactor)
        } else {
            input.copyOf() // No pitch shift needed — avoid unnecessary work.
        }

        // STAGE 3: Band/Tone Shaping
        // Band-pass (Shinchan: nasal / squeaky)
        if (preset.bandLowHz > 0f && preset.bandHighHz > 0f) {
            out = bandPass(out, preset.bandLowHz, preset.bandHighHz)
        } else {
            // Low-pass only (warmth / muffling)
            if (preset.lowPassHz > 0f) out = lowPass(out, preset.lowPassHz)
            // High-pass only
            if (preset.highPassHz > 0f) out = highPass(out, preset.highPassHz)
        }

        // STAGE 4: Robot (Ring Modulation)
        if (preset.robotHz > 0f) {
            out = ringModulate(out, preset.robotHz)
        }

        // STAGE 5: Flanger
        if (preset.flangerRate > 0f) {
            out = flanger(out, preset.flangerRate, preset.flangerDepth)
        }

        // STAGE 6: Chorus (subtle for old man / ghost warmth)
        if (preset.chorusDepth > 0f) {
            out = chorus(out, preset.chorusDepth)
        }

        // STAGE 7: Reverb
        if (preset.reverbMix > 0f) {
            out = reverb(out, preset.reverbMix)
        }

        // STAGE 8: Peak Limiter
        // Prevents mathematical overflow from stacked effects clipping the DAC.
        var maxPeak = 0f
        for (s in out) { val a = abs(s); if (a > maxPeak) maxPeak = a }
        if (maxPeak > 0.95f) {
            val gain = 0.95f / maxPeak
            for (i in out.indices) out[i] *= gain
        }

        return out
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
    private fun pitchShiftOla(input: FloatArray, pitchFactor: Double): FloatArray {
        ensureHannWindow()

        val output = FloatArray(input.size)
        val halfWindow = windowSize / 2

        for (i in input.indices) {
            // Write current sample into ring buffer.
            val wp = (writePos % rSize).toInt()
            ring[wp] = input[i]

            // --- Read Head 1 ---
            // Phase increments by (1 - pitchFactor) / windowSize per sample.
            // This slowly walks the read head backward or forward relative to the write head.
            phase1 += (1.0 - pitchFactor) / windowSize
            // Wrap phase into [0.0, 1.0)
            phase1 -= floor(phase1)

            // --- Read Head 2 (offset by half cycle) ---
            phase2 = phase1 + 0.5
            if (phase2 >= 1.0) phase2 -= 1.0

            // Convert phases to sample delays (distance behind write pointer).
            // Minimum delay of 5 samples prevents reading ahead of the write pointer.
            val delay1 = (phase1 * windowSize) + halfWindow + 5.0
            val delay2 = (phase2 * windowSize) + halfWindow + 5.0

            // Read interpolated samples from ring buffer.
            val s1 = readInterpolated(writePos - delay1)
            val s2 = readInterpolated(writePos - delay2)

            // Look up precomputed Hann window values.
            // window index is the phase scaled to [0, windowSize).
            val w1 = hannWindow[(phase1 * windowSize).toInt().coerceIn(0, windowSize - 1)]
            val w2 = hannWindow[(phase2 * windowSize).toInt().coerceIn(0, windowSize - 1)]

            // Cross-faded output.
            output[i] = s1 * w1 + s2 * w2

            writePos++
        }
        return output
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
        val targetSize = (sampleRate * 0.035).toInt().coerceAtLeast(64)
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
    private fun lowPass(input: FloatArray, cutoffHz: Float): FloatArray {
        val alpha = cutoffHz / (cutoffHz + sampleRate / (2f * PI.toFloat()))
        val out = FloatArray(input.size)
        for (i in input.indices) {
            lpfState = lpfState + alpha * (input[i] - lpfState)
            out[i] = lpfState
        }
        return out
    }

    /**
     * Single-pole IIR High-Pass Filter.
     * HP is derived from LP: HP[n] = Input[n] - LP[n]
     */
    private fun highPass(input: FloatArray, cutoffHz: Float): FloatArray {
        val alpha = cutoffHz / (cutoffHz + sampleRate / (2f * PI.toFloat()))
        val out = FloatArray(input.size)
        for (i in input.indices) {
            hpfState = hpfState + alpha * (input[i] - hpfState)
            out[i] = input[i] - hpfState   // HP = Input - LP
        }
        return out
    }

    /**
     * Band-Pass filter: apply LP followed by HP.
     * Frequencies between [lowHz, highHz] pass through; all others are attenuated.
     */
    private fun bandPass(input: FloatArray, lowHz: Float, highHz: Float): FloatArray {
        // Low-pass to remove everything above highHz.
        val lpAlpha = highHz / (highHz + sampleRate / (2f * PI.toFloat()))
        // High-pass to remove everything below lowHz.
        val hpAlpha = lowHz / (lowHz + sampleRate / (2f * PI.toFloat()))

        val out = FloatArray(input.size)
        for (i in input.indices) {
            // LP stage
            bpfLowState = bpfLowState + lpAlpha * (input[i] - bpfLowState)
            // HP stage applied to LP output
            bpfHighState = bpfHighState + hpAlpha * (bpfLowState - bpfHighState)
            out[i] = bpfLowState - bpfHighState
        }
        return out
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Effects
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Ring Modulation: multiplies input by a carrier sine wave at [carrierHz].
     * Creates the classic metallic "robot" buzz by folding sidebands into the spectrum.
     */
    private fun ringModulate(input: FloatArray, carrierHz: Float): FloatArray {
        val out = FloatArray(input.size)
        val angularFreq = 2.0 * PI * carrierHz / sampleRate
        for (i in input.indices) {
            out[i] = (input[i] * sin(robotPhase)).toFloat()
            robotPhase += angularFreq
            // Keep robotPhase in [0, 2π) to prevent accumulation of floating point error.
            if (robotPhase >= 2.0 * PI) robotPhase -= 2.0 * PI
        }
        return out
    }

    /**
     * Flanger effect: mixes dry signal with a delayed copy.
     * The delay time is modulated by a slow LFO to create the "sweeping jet" sound.
     *
     * @param rate  LFO rate in Hz (how fast the delay sweeps).
     * @param depth Max delay in seconds.
     */
    private fun flanger(input: FloatArray, rate: Float, depth: Float): FloatArray {
        val maxDelaySamples = (depth * sampleRate).toInt().coerceAtLeast(1)
        val lfoAngFreq = 2.0 * PI * rate / sampleRate
        val out = FloatArray(input.size)

        for (i in input.indices) {
            // Write current sample into flanger buffer.
            val wp = flangerWritePos % flangerBuf.size
            flangerBuf[wp] = input[i]

            // Compute current delay in samples from LFO.
            val lfoValue = (1.0 + sin(flangerLfoPhase)) / 2.0  // LFO range [0, 1]
            val delaySamples = (lfoValue * maxDelaySamples).toInt().coerceAtLeast(1)

            // Read delayed sample.
            var rp = flangerWritePos - delaySamples
            if (rp < 0) rp += flangerBuf.size
            val delayedSample = flangerBuf[rp % flangerBuf.size]

            out[i] = input[i] * 0.7f + delayedSample * 0.3f

            flangerWritePos++
            flangerLfoPhase += lfoAngFreq
            if (flangerLfoPhase >= 2.0 * PI) flangerLfoPhase -= 2.0 * PI
        }
        return out
    }

    /**
     * Subtle Chorus effect: mixes input with a fixed-delay copy.
     * Adds a "quivering" quality useful for old-man and ghost presets.
     *
     * @param depth Delay depth in seconds (e.g., 0.003 = 3ms).
     */
    private fun chorus(input: FloatArray, depth: Float): FloatArray {
        val delaySamples = (depth * sampleRate).toInt().coerceAtLeast(1)
        val out = FloatArray(input.size)

        for (i in input.indices) {
            val wp = chorusWritePos % chorusBuf.size
            chorusBuf[wp] = input[i]

            var rp = chorusWritePos - delaySamples
            if (rp < 0) rp += chorusBuf.size
            val delayed = chorusBuf[rp % chorusBuf.size]

            out[i] = input[i] * 0.75f + delayed * 0.25f
            chorusWritePos++
        }
        return out
    }

    /**
     * Simple comb-filter reverb for ambient "space" effects (ghost, drunk, pretty woman).
     *
     * @param mix Wet/dry ratio (0.0 = dry, 1.0 = fully wet).
     */
    private fun reverb(input: FloatArray, mix: Float): FloatArray {
        val out = FloatArray(input.size)
        for (i in input.indices) {
            val delayed = reverbBuf[reverbReadPos % reverbBuf.size]
            reverbBuf[reverbWritePos % reverbBuf.size] = input[i] + delayed * 0.3f
            out[i] = input[i] * (1f - mix) + delayed * mix
            reverbReadPos++
            reverbWritePos++
        }
        return out
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
        phase1 = 0.0; phase2 = 0.5
        lpfState = 0f; hpfState = 0f
        bpfLowState = 0f; bpfHighState = 0f
        robotPhase = 0.0
        flangerBuf.fill(0f); flangerWritePos = 0; flangerLfoPhase = 0.0
        chorusBuf.fill(0f); chorusWritePos = 0
        reverbBuf.fill(0f); reverbReadPos = 0; reverbWritePos = 0
    }
}
