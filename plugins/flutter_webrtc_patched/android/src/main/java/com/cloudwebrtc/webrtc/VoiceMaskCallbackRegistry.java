package com.cloudwebrtc.webrtc;

import java.nio.ByteBuffer;

/**
 * Standalone callback registry for voice mask DSP processing.
 * 
 * This class has ZERO WebRTC dependencies, so it can be safely
 * referenced from ANY module (app, plugins, etc.) without classpath issues.
 *
 * VoiceMaskBridge (which implements AudioBufferCallback) delegates to this.
 * VoiceMaskPlugin registers its DSP callback here at startup.
 */
public final class VoiceMaskCallbackRegistry {

    /**
     * Simple functional callback. No WebRTC types.
     */
    public interface Callback {
        void onAudioData(ByteBuffer buffer, int channelCount, int sampleRate, int bytesRead);
    }

    private static volatile Callback sCallback = null;
    private static volatile boolean sActive = false;

    public static void setCallback(Callback callback) {
        sCallback = callback;
        android.util.Log.i("VoiceMaskRegistry", "Callback set: " + (callback != null));
    }

    public static void setActive(boolean active) {
        sActive = active;
    }

    public static boolean isActive() {
        return sActive;
    }

    public static boolean hasCallback() {
        return sCallback != null;
    }

    /** Called by VoiceMaskBridge from the audio thread. */
    static void dispatch(ByteBuffer buffer, int channelCount, int sampleRate, int bytesRead) {
        Callback cb = sCallback;
        if (cb != null) {
            cb.onAudioData(buffer, channelCount, sampleRate, bytesRead);
        }
    }
}
