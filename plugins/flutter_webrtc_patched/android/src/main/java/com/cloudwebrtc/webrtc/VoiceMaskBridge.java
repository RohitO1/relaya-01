package com.cloudwebrtc.webrtc;

import org.webrtc.audio.JavaAudioDeviceModule;
import java.nio.ByteBuffer;

/**
 * Bridge that implements AudioBufferCallback and delegates to VoiceMaskCallbackRegistry.
 * Only THIS class touches WebRTC types. The registry and the app module never do.
 */
public class VoiceMaskBridge implements JavaAudioDeviceModule.AudioBufferCallback {

    @Override
    public long onBuffer(ByteBuffer buffer, int audioFormat, int channelCount, int sampleRate, int bytesRead, long captureTimeNs) {
        if (VoiceMaskCallbackRegistry.isActive() && VoiceMaskCallbackRegistry.hasCallback()) {
            try {
                VoiceMaskCallbackRegistry.dispatch(buffer, channelCount, sampleRate, bytesRead);
            } catch (Throwable t) {
                android.util.Log.e("VoiceMaskBridge", "DSP error: " + t.getMessage());
            }
        }
        return captureTimeNs;
    }
}
