// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: constant_identifier_names
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Voice masking preset definitions.
class VoiceMaskPreset {
  final String id;
  final String name;
  final String icon;
  final List<Color> colors;
  final double pitchSemitones;
  final double formantSemitones;
  final String description;

  const VoiceMaskPreset({
    required this.id,
    required this.name,
    required this.icon,
    this.colors = const [Color(0xFF8A2BE2), Color(0xFF00E5FF)],
    required this.pitchSemitones,
    required this.formantSemitones,
    required this.description,
  });

  static const List<VoiceMaskPreset> all = [
    VoiceMaskPreset(
      id: 'ghost',
      name: 'Ghost',
      icon: '👻',
      colors: [Color(0xFFD4145A), Color(0xFFFBB03B)],
      pitchSemitones: 3.0,
      formantSemitones: 1.5,
      description: 'Ethereal & unrecognizable',
    ),
    VoiceMaskPreset(
      id: 'shadow',
      name: 'Shadow',
      icon: '🌑',
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      pitchSemitones: -5.0,
      formantSemitones: -3.0,
      description: 'Dark & gravelly',
    ),
    VoiceMaskPreset(
      id: 'robot',
      name: 'Robot',
      icon: '🤖',
      colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      pitchSemitones: 0.0,
      formantSemitones: 0.0,
      description: 'Metallic & synthetic',
    ),
    VoiceMaskPreset(
      id: 'chipmunk',
      name: 'Speed Up',
      icon: '⏩',
      colors: [Color(0xFFFF0844), Color(0xFFFFB199)],
      pitchSemitones: 8.0,
      formantSemitones: 6.0,
      description: 'High-pitched & fun',
    ),
    VoiceMaskPreset(
      id: 'oldman',
      name: 'Old Man',
      icon: '👴',
      colors: [Color(0xFF89F7FE), Color(0xFF66A6FF)],
      pitchSemitones: -3.0,
      formantSemitones: -2.0,
      description: 'Mature & wise voice',
    ),
    VoiceMaskPreset(
      id: 'titan',
      name: 'Giant',
      icon: '🧔',
      colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
      pitchSemitones: -7.0,
      formantSemitones: -5.0,
      description: 'Massive & commanding',
    ),
    VoiceMaskPreset(
      id: 'drunk',
      name: 'Drunk',
      icon: '🥴',
      colors: [Color(0xFFE2D1C3), Color(0xFFFDFCFB)],
      pitchSemitones: -1.0,
      formantSemitones: 0.0,
      description: 'Slurred & wavy effect',
    ),
    VoiceMaskPreset(
      id: 'alien',
      name: 'Alien',
      icon: '👽',
      colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
      pitchSemitones: 5.0,
      formantSemitones: 0.0,
      description: 'Warbling & otherworldly',
    ),
    VoiceMaskPreset(
      id: 'shinchan',
      name: 'Shinchan',
      icon: '🖍️',
      colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
      pitchSemitones: 7.0,
      formantSemitones: 4.0,
      description: 'Mischievous & nasal child',
    ),
    VoiceMaskPreset(
      id: 'doraemon',
      name: 'Doraemon',
      icon: '🔔',
      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
      pitchSemitones: 3.0,
      formantSemitones: -1.0,
      description: 'Warm robotic companion',
    ),
    VoiceMaskPreset(
      id: 'prettywoman',
      name: 'Shizuka',
      icon: '✨',
      colors: [Color(0xFFff9a9e), Color(0xFFfecfef)],
      pitchSemitones: 5.0,
      formantSemitones: 3.0,
      description: 'Sweet & elegant girl voice',
    ),
    VoiceMaskPreset(
      id: 'custom',
      name: 'Custom',
      icon: '🎛️',
      colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      pitchSemitones: 0.0,
      formantSemitones: 0.0,
      description: 'Your unique voice',
    ),
  ];

  static VoiceMaskPreset? byId(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Service that bridges Flutter ↔ Native voice masking processor.
///
/// ARCHITECTURE:
///   - All DSP runs natively in Kotlin (VoiceMaskDsp.kt) on the WebRTC audio thread.
///   - This service only sends commands over MethodChannel and surfaces errors to the UI.
///   - The hook failure path uses an EventChannel error event so Dart is notified
///     asynchronously (without polling).
class VoiceMaskService {
  VoiceMaskService._();
  static final VoiceMaskService instance = VoiceMaskService._();

  static const _channel = MethodChannel('com.meetra.app/voice_mask');
  static const _eventChannel = EventChannel('com.meetra.app/voice_mask_stream');

  bool _isActive = false;
  String _activePreset = 'none';
  bool _isHooked = false;

  // Callbacks from Kotlin when the hook result is known.
  Function()? onHookSuccess;
  Function(String reason)? onHookFailed;

  /// Register callbacks and set up the MethodChannel handler to receive
  /// hookSuccess/hookFailed notifications from the Kotlin retry loop.
  /// Call this once BEFORE calling hookWebRtc().
  void listenForHookResult({
    Function()? onSuccess,
    Function(String reason)? onFailed,
  }) {
    onHookSuccess = onSuccess;
    onHookFailed = onFailed;

    // Set up reverse MethodChannel handler for Kotlin→Dart callbacks.
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'hookSuccess':
          _isHooked = true;
          debugPrint('VoiceMask: hookSuccess callback from Kotlin');
          onHookSuccess?.call();
          break;
        case 'hookFailed':
          final reason = call.arguments?.toString() ?? 'Unknown';
          debugPrint('VoiceMask: hookFailed callback from Kotlin — $reason');
          onHookFailed?.call(reason);
          break;
      }
    });
  }

  void stopListening() {
    onHookSuccess = null;
    onHookFailed = null;
    // Don't null out the method call handler — it needs to persist.
  }

  /// Trigger the native WebRTC hook. Starts the retry loop in Kotlin.
  /// Returns true if already hooked. Does NOT block — retries run in the background.
  ///
  /// WHEN TO CALL: Inside RoomConnectedEvent, AFTER LiveKit.initialize().
  Future<bool> hookWebRtc() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod('hookWebRtc');
      _isHooked = result == true;
      debugPrint('VoiceMask: hookWebRtc initial result = $_isHooked');
      return _isHooked;
    } catch (e) {
      debugPrint('VoiceMask: hookWebRtc error: $e');
      return false;
    }
  }

  /// Start voice masking with a given preset.
  /// If the hook is not yet complete, the preset is QUEUED natively
  /// and will be applied automatically once the hook succeeds.
  Future<bool> startMasking(String presetId) async {
    if (kIsWeb) return false;
    try {
      await _channel.invokeMethod('startCapture', {'preset': presetId});
      _isActive = true;
      _activePreset = presetId;
      debugPrint('VoiceMask: startMasking preset=$presetId');
      return true;
    } catch (e) {
      debugPrint('VoiceMask: startMasking error: $e');
      return false;
    }
  }

  /// Stop voice masking.
  Future<void> stopMasking() async {
    try {
      await _channel.invokeMethod('stopCapture');
    } catch (e) {
      debugPrint('VoiceMask: stopMasking error: $e');
    }
    _isActive = false;
    _activePreset = 'none';
  }

  /// Switch preset mid-call. No restart needed — the native DSP handles it atomically.
  Future<void> setPreset(String presetId) async {
    try {
      await _channel.invokeMethod('setPreset', {'preset': presetId});
      _activePreset = presetId;
    } catch (e) {
      debugPrint('VoiceMask: setPreset error: $e');
    }
  }

  /// Set custom pitch (for the custom preset slider).
  Future<void> setCustomPitch(double semitones) async {
    try {
      await _channel.invokeMethod('setCustomPitch', {'semitones': semitones});
    } catch (e) {
      debugPrint('VoiceMask: setCustomPitch error: $e');
    }
  }

  /// Set custom formant shift — currently maps to pitch (native DSP handles it as one param).
  Future<void> setCustomFormant(double semitones) async {
    // Formant shift is not independently exposed on the new native DSP engine.
    // For the custom preset, pitch controls the primary character.
    // This is a no-op stub kept for API compatibility with existing UI callers.
    debugPrint('VoiceMask: setCustomFormant($semitones) — mapped to no-op (use setCustomPitch)');
  }

  /// Process a single raw PCM frame (used by bolroom_profile_screen for loopback test).
  /// Returns the DSP-processed bytes, or null on failure.
  Future<Uint8List?> processFrame(Uint8List frame) async {
    try {
      final result = await _channel.invokeMethod('processFrame', {'bytes': frame});
      if (result is Uint8List) return result;
      if (result is List) return Uint8List.fromList(result.cast<int>());
      return null;
    } catch (e) {
      debugPrint('VoiceMask: processFrame error: $e');
      return null;
    }
  }

  /// Get diagnostic info from native side.
  Future<Map<String, dynamic>> getDiagnostic() async {
    try {
      final result = await _channel.invokeMethod('getDiagnostic');
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return {};
    }
  }

  void dispose() {
    stopListening();
  }
}


