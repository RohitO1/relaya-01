/// ============================================
/// BolRoom Configuration — LiveKit Voice
/// ============================================
/// ALL THREE values below MUST come from the SAME LiveKit project page.
/// Go to: https://cloud.livekit.io → Your Project → Settings → Keys
///
/// Step 1: Copy the WSS URL   → paste as livekitUrl
/// Step 2: Copy the API Key   → paste as livekitApiKey
/// Step 3: Copy the Secret    → paste as livekitApiSecret
///
/// If they are from different projects, you will get "invalid API key" error.
/// ============================================
library;

class BolRoomConfig {
  /// LiveKit WebSocket URL  (example: wss://my-project-abc123.livekit.cloud)
  static const String livekitUrl = 'wss://meetra-qpnmu7vr.livekit.cloud';

  /// LiveKit API Key  (from same project's Settings → Keys page)
  static const String livekitApiKey = 'APIC2MoanQqDdoE';

  /// LiveKit API Secret  (from same project's Settings → Keys page)
  static const String livekitApiSecret = 'aa2N3fCi65FqflofwW5tc3VhOtHdKUBHqz27x1QPM3BB';

  /// Whether voice is enabled
  static bool get isVoiceEnabled =>
      livekitUrl.isNotEmpty && !livekitUrl.startsWith('YOUR');
}
