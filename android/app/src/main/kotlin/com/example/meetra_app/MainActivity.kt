package com.example.meetra_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register VoiceMaskPlugin.
        // IMPORTANT: This plugin has NO compile-time WebRTC imports, so it always
        // loads cleanly. The WebRTC hook is performed lazily via reflection at runtime.
        val plugin = VoiceMaskPlugin()
        flutterEngine.plugins.add(plugin)
        android.util.Log.d("MainActivity", "VoiceMaskPlugin registered ✅")

        // We do NOT start the retry loop here because the WebRTC engine does not
        // exist yet. The Dart RoomConnectedEvent listener calls hookWebRtc() over
        // the MethodChannel, which triggers startRetryLoop() at the right moment.
        // See: chatroom_live_screen.dart → _roomListener..on<RoomConnectedEvent>
    }
}
