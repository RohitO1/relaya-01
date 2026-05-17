package com.example.meetra_app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.nio.ByteBuffer

/**
 * VoiceMaskPlugin — Clean Architecture (No Reflection)
 *
 * ARCHITECTURE:
 *   1. VoiceMaskBridge.java (flutter_webrtc_patched) implements AudioBufferCallback.
 *   2. MethodCallHandlerImpl sets VoiceMaskBridge on the Builder before createAudioDeviceModule().
 *   3. VoiceMaskBridge delegates to VoiceMaskCallbackRegistry (zero WebRTC deps).
 *   4. This plugin registers its DSP callback with VoiceMaskCallbackRegistry at startup.
 *   5. When audio thread fires, the callback chain flows:
 *      WebRTC → VoiceMaskBridge.onBuffer() → Registry.dispatch() → our DSP.
 *
 * NO REFLECTION. NO UNSAFE. NO FINAL FIELD HACKS.
 */
class VoiceMaskPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    /** Whether DSP processing is currently active. */
    @Volatile var isActive = false
        private set

    /** The DSP engine. */
    private val dsp = VoiceMaskDsp()

    /** Frame counter for diagnostics. */
    @Volatile var processedFrameCount = 0L
        private set

    companion object {
        @JvmStatic var instance: VoiceMaskPlugin? = null
    }

    // ═══════════════════════════════════════════════════════════════
    //  DSP Callback — called from the WebRTC audio thread
    // ═══════════════════════════════════════════════════════════════

    private val dspCallback = com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.Callback { buffer, channelCount, sampleRate, bytesRead ->
        processedFrameCount++
        if (processedFrameCount <= 5L) {
            android.util.Log.w("VoiceMask", ">>> PROCESSING frame #$processedFrameCount | sr=$sampleRate ch=$channelCount bytes=$bytesRead cap=${buffer.capacity()}")
        }

        dsp.configure(sampleRate)
        val totalShorts = buffer.capacity() / 2
        val numFrames = if (channelCount > 0) totalShorts / channelCount else totalShorts
        dsp.processBuffer(1, numFrames, buffer)
    }

    // ═══════════════════════════════════════════════════════════════
    //  FlutterPlugin lifecycle
    // ═══════════════════════════════════════════════════════════════

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        methodChannel = MethodChannel(binding.binaryMessenger, "com.meetra.app/voice_mask")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "com.meetra.app/voice_mask_stream")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
            override fun onCancel(args: Any?) { eventSink = null }
        })

        // Register DSP callback with the registry (zero WebRTC deps).
        com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.setCallback(dspCallback)

        android.util.Log.i("VoiceMask", "Plugin attached ✅ — DSP callback registered")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        isActive = false
        com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.setActive(false)
        com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.setCallback(null)
        methodChannel.setMethodCallHandler(null)
        instance = null
    }

    // ═══════════════════════════════════════════════════════════════
    //  MethodChannel handler
    // ═══════════════════════════════════════════════════════════════

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "startCapture" -> {
                val presetId = call.argument<String>("preset") ?: "none"
                dsp.switchPreset(VoiceMaskPreset.byId(presetId))
                isActive = true
                com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.setActive(true)
                android.util.Log.i("VoiceMask", "Masking ON: preset=$presetId")
                result.success(true)
            }

            "stopCapture" -> {
                isActive = false
                com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.setActive(false)
                android.util.Log.i("VoiceMask", "Masking OFF")
                result.success(true)
            }

            "setPreset" -> {
                val presetId = call.argument<String>("preset") ?: "none"
                dsp.switchPreset(VoiceMaskPreset.byId(presetId))
                android.util.Log.i("VoiceMask", "Preset switched: $presetId")
                result.success(true)
            }

            "setCustomPitch" -> {
                val semitones = call.argument<Double>("semitones") ?: 0.0
                val factor = Math.pow(2.0, semitones / 12.0)
                dsp.setCustomPitchFactor(factor)
                result.success(true)
            }

            "processFrame" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes != null) {
                    val buf = java.nio.ByteBuffer.allocateDirect(bytes.size)
                    buf.put(bytes)
                    buf.rewind()
                    val numFrames = bytes.size / 2
                    dsp.processBuffer(1, numFrames, buf)
                    buf.rewind()
                    val out = ByteArray(bytes.size)
                    buf.get(out)
                    result.success(out)
                } else {
                    result.success(null)
                }
            }

            "hookWebRtc" -> {
                android.util.Log.i("VoiceMask", "hookWebRtc — bridge always active")
                notifyDart("hookSuccess")
                result.success(true)
            }

            "isHooked"     -> result.success(true)
            "isCapturing"  -> result.success(isActive)

            "getDiagnostic" -> result.success(mapOf(
                "hooked"       to true,
                "active"       to isActive,
                "processCount" to processedFrameCount,
                "diagnostic"   to "Bridge-based (no reflection)",
                "callbackRegistered" to com.cloudwebrtc.webrtc.VoiceMaskCallbackRegistry.hasCallback()
            ))

            else -> result.notImplemented()
        }
    }

    private fun notifyDart(event: String) {
        Handler(Looper.getMainLooper()).post {
            try {
                methodChannel.invokeMethod(event, "Bridge-based hook active")
            } catch (e: Throwable) {
                android.util.Log.w("VoiceMask", "notifyDart($event) failed: ${e.message}")
            }
        }
    }
}
