# Keep VoiceMaskPlugin and all its methods/fields intact
-keep class com.example.meetra_app.VoiceMaskPlugin { *; }
-keep class com.example.meetra_app.MainActivity { *; }

# Keep flutter_webrtc classes (reflection-based hook)
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
