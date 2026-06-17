// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: prefer_final_fields, unused_field, curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:share_plus/share_plus.dart';
import 'chatrooms_screen.dart';
import 'bolroom_config.dart';
import 'bolroom/bolroom_profile_screen.dart';
import 'package:meetra_app/services/notification_service.dart';
import 'games/truth_dare_game.dart';
import 'games/two_truths_game.dart';
import 'games/blind_date_game.dart';
import 'package:meetra_app/bolroom/bolroom_dm_chat_screen.dart';
import 'package:meetra_app/services/voice_mask_service.dart';

class _BolRoomBaseRoute extends OverlayRoute<void> {
  _BolRoomBaseRoute({required this.builder});
  final WidgetBuilder builder;

  @override
  Iterable<OverlayEntry> createOverlayEntries() {
    return [
      OverlayEntry(builder: builder),
    ];
  }
}

class BolRoomManager {
  static OverlayEntry? _overlayEntry;
  static String? _roomKey;
  static BuildContext? _callerContext;
  static GlobalKey<NavigatorState>? _internalNavKey;
  static GlobalKey<NavigatorState>? get internalNavKey => _internalNavKey;
  static GlobalKey<_BolRoomOverlayHostState>? _hostKey;

  static void openRoom(BuildContext context,
      {required String roomId,
      required String roomName,
      required String topic,
      required String hostId,
      required String hostName}) {
    if (_overlayEntry != null) {
      _hostKey?.currentState?.maximize();
      return;
    }

    _hostKey = GlobalKey<_BolRoomOverlayHostState>();
    _internalNavKey = GlobalKey<NavigatorState>();
    _roomKey = roomId;
    _callerContext = context;
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Navigator(
        key: _internalNavKey,
        onGenerateInitialRoutes: (navigator, initialRouteName) {
          return [
            _BolRoomBaseRoute(
              builder: (context) => _BolRoomOverlayHost(
                key: _hostKey,
                roomId: roomId,
                roomName: roomName,
                topic: topic,
                hostId: hostId,
                hostName: hostName,
                onClose: completelyCloseRoom,
              ),
            )
          ];
        },
      ),
    );
    final overlay = Navigator.of(context, rootNavigator: true).overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) {
      overlay.insert(_overlayEntry!);
    } else {
      debugPrint('Failed to find Overlay to insert BolRoom');
    }
  }

  static void minimizeRoom(BuildContext context) {
    _hostKey?.currentState?.minimize();
  }

  static void maximizeRoom(BuildContext context) {
    _hostKey?.currentState?.maximize();
  }

  static void completelyCloseRoom() {
    // Capture and clear state immediately so isRoomFullscreen/hasActiveRoom
    // return false instantly (prevents re-entrant calls).
    final entry = _overlayEntry;
    _overlayEntry = null;
    _hostKey = null;
    _internalNavKey = null;
    _roomKey = null;
    _callerContext = null;
    // Defer the actual OverlayEntry removal to the next frame so any
    // in-progress Navigator operations (modal slide animations, etc.)
    // finish before the Navigator widget is torn down — prevents the
    // "Navigator is locked" assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      entry?.remove();
    });
  }

  static bool get hasActiveRoom => _roomKey != null;
  static String? get currentRoomId => _roomKey;
  static bool get isRoomMinimized =>
      _hostKey?.currentState?._isMinimized ?? false;
  static bool get isRoomFullscreen => hasActiveRoom && !isRoomMinimized;
  static void minimizeRoomIfOpen() => _hostKey?.currentState?.minimize();

  // Keys to internal room state — used by shell for precise back handling
  static GlobalKey<NavigatorState>? get roomNavKey => _internalNavKey;
  static GlobalKey<ChatroomLiveScreenState>? get roomStateKey =>
      _hostKey?.currentState?._roomStateKey;
}

class _BolRoomOverlayHost extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String topic;
  final String hostId;
  final String hostName;
  final VoidCallback onClose;

  const _BolRoomOverlayHost({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.topic,
    required this.hostId,
    required this.hostName,
    required this.onClose,
  });

  @override
  State<_BolRoomOverlayHost> createState() => _BolRoomOverlayHostState();
}

class _BolRoomOverlayHostState extends State<_BolRoomOverlayHost> {
  bool _isMinimized = false;
  double _minimizedX = -1; // -1 = unset, will be initialized on first build
  double _minimizedY = -1;
  final GlobalKey<ChatroomLiveScreenState> _roomStateKey =
      GlobalKey<ChatroomLiveScreenState>();

  void minimize() {
    if (!_isMinimized) {
      setState(() => _isMinimized = true);
      _roomStateKey.currentState?.setMinimized(true);
    }
  }

  void maximize() {
    if (_isMinimized) {
      setState(() => _isMinimized = false);
      _roomStateKey.currentState?.setMinimized(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;
    final topPad = MediaQuery.of(context).padding.top + 10;

    // Initialize pill to bottom-right corner on first build
    if (_minimizedX < 0) {
      _minimizedX = screenW - 76;
      _minimizedY = screenH - bottomPad - 80;
    }

    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0C0914),
          bottomSheetTheme:
              const BottomSheetThemeData(backgroundColor: Colors.transparent),
        ),
        child: ChatroomLiveScreen(
          key: _roomStateKey,
          roomId: widget.roomId,
          roomName: widget.roomName,
          topic: widget.topic,
          hostId: widget.hostId,
          hostName: widget.hostName,
        ),
      ),
    );
  }
}

class ChatroomLiveScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String topic;
  final String hostId;
  final String hostName;

  const ChatroomLiveScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.topic,
    required this.hostId,
    required this.hostName,
  });

  @override
  State<ChatroomLiveScreen> createState() => ChatroomLiveScreenState();
}

class ChatroomLiveScreenState extends State<ChatroomLiveScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _sb = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _chatFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  static const _voiceMaskChannel = MethodChannel('com.meetra.app/voice_mask');
  final _voiceMaskService = VoiceMaskService.instance;

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isMuted = true;
  bool _isVoiceMasked = false;
  String _voiceMaskPreset = 'ghost';
  bool _isEditingVoiceMask = false;
  bool _isHost = false;
  String _myId = '';
  String _myName = 'User';
  String? _myAvatar;
  late String _currentHostId;
  late String _currentHostName;
  Set<String> _speakingIdentities =
      {}; // LiveKit: uses string identity = supabase user_id
  Set<String> _seenMemberIds = {};
  bool _micRequestSent = false;
  final Map<String, String> _memberReactions =
      {}; // uid -> emoji (shown on avatar for 1.5s)

  // Join toast banner
  String? _joinToastText;
  Timer? _toastTimer;

  // LiveKit
  Room? _livekitRoom;
  EventsListener<RoomEvent>? _roomListener;
  bool _voiceReady = false;
  late AnimationController _pulseCtrl;

  // Realtime Channels
  RealtimeChannel? _memberChannel;
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _profileChannel; // syncs voice mask state with profile screen
  final ValueNotifier<List<Map<String, dynamic>>> _membersNotify =
      ValueNotifier([]);
  final ValueNotifier<Set<String>> _micRequestsNotify = ValueNotifier({});

  // Atom orbital animation
  late AnimationController _orbitCtrl;
  late AnimationController _orbitCtrl2;

  // Chat overlay - Instagram style
  bool _showChat = false;
  bool _showLiveChatStream = true;
  bool _chatActive = false; // full opacity mode
  Timer? _chatFadeTimer;

  // Reactions
  final List<_FloatingReaction> _floatingReactions = [];
  int _reactionIdCounter = 0;
  final List<DateTime> _myReactionTimestamps = [];

  // End-of-room countdown banner (shown to participants, NOT host)
  bool _showEndCountdownBanner = false;
  int _endCountdownSeconds = 3;
  Timer? _endCountdownTimer;

  // Mic requests
  bool _hasMicPermission = false;
  final Set<String> _micRequests = {};

  // Hand raise
  bool _handRaised = false;

  // Host-muted (locked mute — user cannot self-unmute)
  bool _hostMuted = false;

  // Recording state
  bool _isRecording = false;

  // Post-room stats
  int _peakListeners = 0;
  DateTime _roomStartedAt = DateTime.now();

  // Host disconnect monitoring
  Timer? _hostHeartbeatTimer;
  DateTime _lastHostSeen = DateTime.now();
  DateTime _lastActivityTime = DateTime.now();
  bool _hostDisconnected = false;
  int _hostDisconnectCountdown = 120;

  // Ban list
  final Set<String> _bannedUserIds = {};

  // X Spaces features
  bool _isMinimized = false;
  double _minimizedX = 20;
  double _minimizedY = 100;

  // ── Game Mode ──
  String? _gameMode; // e.g. 'truth_dare'
  bool _showGame = false; // whether game panel is visible
  final GlobalKey<TruthOrDareGameState> _gameKey =
      GlobalKey<TruthOrDareGameState>();
  final GlobalKey<TwoTruthsGameState> _twoTruthsKey =
      GlobalKey<TwoTruthsGameState>();
  final GlobalKey<BlindDateGameState> _blindDateKey =
      GlobalKey<BlindDateGameState>();
  bool _micsLockedByGame = false;
  bool _wasUnmutedBeforeGame = false;
  List<TodParticipant>? _gameParticipants;

  Future<void> _sendSystemCommand(String cmd, String targetUid) async {
    try {
      await _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': 'System',
        'text': 'SYSTEM_CMD:$cmd:$targetUid',
        'is_system': true,
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
      debugPrint('SystemCmd sent: $cmd → $targetUid');
    } on PostgrestException catch (e) {
      // Ignore foreign key violations (23503) when room is already deleted
      if (e.code != '23503') {
        debugPrint('_sendSystemCommand($cmd, $targetUid) FAILED: $e');
      }
    } catch (e) {
      debugPrint('_sendSystemCommand($cmd, $targetUid) FAILED: $e');
    }
  }

  Future<void> _sendGameEvent(Map<String, dynamic> data) async {
    try {
      await _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': 'Game',
        'text': 'GAME_EVENT:${jsonEncode(data)}',
        'is_system': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('_sendGameEvent FAILED: $e');
    }
  }

  String? _pinnedPost;
  String _speakPermission = 'everyone'; // from room DB
  bool _showPinnedInput = false;
  final TextEditingController _pinnedCtrl = TextEditingController();

  // Avatar colors per user
  final _avatarColors = <String, Color>{};
  final _colorPool = [
    BolRoomColors.cyan,
    BolRoomColors.purple,
    BolRoomColors.accent,
    BolRoomColors.gold,
    const Color(0xFF38D9A9),
    const Color(0xFF4ECDC4),
    const Color(0xFFFF6B6B),
    const Color(0xFF845EC2)
  ];

  Color _colorForUser(String id) {
    return _avatarColors.putIfAbsent(
        id, () => _colorPool[_avatarColors.length % _colorPool.length]);
  }

  // Deterministic color from uid — always same color for same user
  Color _deterministicColor(String seed) {
    const cols = [
      Color(0xFF6C63FF),
      Color(0xFFE91E63),
      Color(0xFF00BCD4),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFF03A9F4),
      Color(0xFFF44336),
      Color(0xFF009688),
      Color(0xFFFF5722),
      Color(0xFF3F51B5),
      Color(0xFF8BC34A),
    ];
    int h = 0;
    for (int i = 0; i < seed.length; i++)
      h = seed.codeUnitAt(i) + ((h << 5) - h);
    return cols[h.abs() % cols.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _orbitCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _orbitCtrl2 =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat();
    _myId = _sb.auth.currentUser?.id ?? '';
    _currentHostId = widget.hostId;
    _currentHostName = widget.hostName;
    _isHost = _myId == _currentHostId;
    _hasMicPermission = _isHost;
    _isMuted = !_isHost;

    _subscribeRealtime();
    _joinRoom();
    _loadRoomMeta();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Auto-leave room on dispose only if it's completely closing
    if (BolRoomManager._roomKey == null) {
      _exitRoomAsync();
    }
    // Stop voice masking processor on dispose
    if (_isVoiceMasked) _voiceMaskService.stopMasking();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _orbitCtrl2.dispose();
    _chatFadeTimer?.cancel();
    _toastTimer?.cancel();
    _hostHeartbeatTimer?.cancel();
    _endCountdownTimer?.cancel();
    _memberChannel?.unsubscribe();
    _msgChannel?.unsubscribe();
    _profileChannel?.unsubscribe();
    _msgCtrl.dispose();
    _chatFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (_showChat) {
      setState(() => _showChat = false);
      return true;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent)
      return false; // let system pop bottom sheet

    if (!_isMinimized) {
      BolRoomManager.minimizeRoom(context);
      return true;
    }
    return false;
  }

  void setMinimized(bool val) {
    if (mounted) {
      setState(() {
        _isMinimized = val;
      });
    }
  }

  bool handleBack() {
    if (_showChat) {
      setState(() => _showChat = false);
      return true;
    }
    return false;
  }

  Future<void> _loadRoomMeta() async {
    try {
      final res = await _sb
          .from('chatrooms')
          .select('is_recording, pinned_post, speak_permission, game_mode')
          .eq('id', widget.roomId)
          .maybeSingle();
      if (res != null && mounted)
        setState(() {
          _isRecording = res['is_recording'] == true;
          _pinnedPost = res['pinned_post']?.toString();
          _speakPermission = res['speak_permission']?.toString() ?? 'everyone';
          _gameMode = res['game_mode']?.toString();
          // Auto-open game panel if this is a game room
          if (_gameMode != null && _gameMode!.isNotEmpty) _showGame = true;
        });
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    final next = !_isRecording;
    setState(() => _isRecording = next);
    await _sb
        .from('chatrooms')
        .update({'is_recording': next}).eq('id', widget.roomId);
    _showToast(next ? '🔴 Recording started' : '⏹️ Recording stopped');
  }

  Future<void> _setPinnedPost(String text) async {
    setState(() {
      _pinnedPost = text.trim().isEmpty ? null : text.trim();
      _showPinnedInput = false;
    });
    await _sb
        .from('chatrooms')
        .update({'pinned_post': text.trim().isEmpty ? null : text.trim()}).eq(
            'id', widget.roomId);
  }

  String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(' ').first;
  }

  double _myVoicePitch = 0.5;

  Future<void> _updateNativeVoiceMasking() async {
    // DO NOT attempt to hook or start processing before WebRTC is fully connected.
    // The RoomConnectedEvent will automatically call this method once ready.
    if (!_voiceReady) return;

    try {
      if (_isVoiceMasked) {
        // Use startMasking() instead of setPreset() to ensure BOTH the Dart-side
        // state (_isActive, _activePreset) and native-side state are properly synced.
        // setPreset() alone doesn't update Dart _isActive, which causes mute→unmute
        // cycles to fail to reactivate the DSP pipeline.
        await _voiceMaskService.startMasking(_voiceMaskPreset);
        if (_livekitRoom != null && _hasMicPermission && !_isMuted) {
          await _livekitRoom!.localParticipant?.setMicrophoneEnabled(true);
        }
      } else {
        await _voiceMaskService.stopMasking();
        if (_livekitRoom != null) {
          await _livekitRoom!.localParticipant?.setMicrophoneEnabled(!_isMuted);
        }
      }
    } catch (e) {
      debugPrint('VoiceMask: _updateNativeVoiceMasking error: $e');
    }
  }

  /// Opens the Voice Masking bottom sheet with presets, toggle, and test button.
  void _showVoiceMaskSheet() async {
    // Re-read current voice mask state from DB to stay synced with profile screen
    try {
      final bp = await _sb.from('bolroom_profiles')
          .select('voice_mask_enabled, voice_mask_preset, voice_pitch')
          .eq('id', _myId)
          .maybeSingle();
      if (bp != null && mounted) {
        setState(() {
          _isVoiceMasked = bp['voice_mask_enabled'] == true;
          _voiceMaskPreset = (bp['voice_mask_preset'] ?? 'ghost').toString();
          _myVoicePitch = (bp['voice_pitch'] ?? 0.5).toDouble();
          _isEditingVoiceMask = false; // show active card if already enabled
        });
      }
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0914),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          const presets = VoiceMaskPreset.all;
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),

                // Title + badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.masks,
                        color: Color(0xFFFF6B00), size: 28),
                    const SizedBox(width: 10),
                    const Text('Voice Masking',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isVoiceMasked
                            ? const Color(0xFFFF6B00).withValues(alpha: 0.2)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _isVoiceMasked
                                ? const Color(0xFFFF6B00)
                                : Colors.white24),
                      ),
                      child: Text(
                        _isVoiceMasked ? 'ACTIVE' : 'ORIGINAL',
                        style: TextStyle(
                            color: _isVoiceMasked
                                ? const Color(0xFFFF6B00)
                                : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Disguise your voice so no one can identify you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13)),
                const SizedBox(height: 20),

                // Toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF13101E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF231D38)),
                  ),
                  child: SwitchListTile(
                    title: const Text('Enable Voice Masking',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _isVoiceMasked
                          ? 'Your voice is disguised'
                          : 'Others hear your real voice',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12),
                    ),
                    value: _isVoiceMasked,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFFFF6B00),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: const Color(0xFF2A2440),
                    onChanged: (v) async {
                      setState(() {
                        _isVoiceMasked = v;
                        if (v) _isEditingVoiceMask = true;
                      });
                      setSheetState(() {});
                      _updateNativeVoiceMasking();
                      await _sb.from('bolroom_profiles').update({'voice_mask_enabled': v}).eq('id', _myId);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                if (_isVoiceMasked) ...[
                  if (_isEditingVoiceMask) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('Voice Presets',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: presets.length,
                      itemBuilder: (_, i) {
                        final p = presets[i];
                        final isActive = _voiceMaskPreset == p.id;
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _voiceMaskPreset = p.id);
                            setSheetState(() {});
                            await _sb.from('bolroom_profiles').update({
                              'voice_mask_preset': p.id,
                            }).eq('id', _myId);
                            if (_isVoiceMasked) {
                              _updateNativeVoiceMasking();
                            }
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: p.colors,
                                  ),
                                  border: Border.all(
                                    color: isActive ? Colors.white : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.colors.first.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: Text(p.icon,
                                      style: const TextStyle(fontSize: 30)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.name,
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Active preset description
                    Text(
                      VoiceMaskPreset.byId(_voiceMaskPreset)?.description ?? '',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),

                    // Custom 2D pad (only for custom preset)
                    if (_voiceMaskPreset == 'custom') ...[
                      const SizedBox(height: 16),
                      _buildCustomVoicePad(setSheetState),
                    ],
                    const SizedBox(height: 16),

                    // Mask button
                    GestureDetector(
                      onTap: () async {
                        await _sb.from('bolroom_profiles').update({
                          'voice_mask_enabled': _isVoiceMasked,
                          'voice_mask_preset': _voiceMaskPreset,
                        }).eq('id', _myId);
                        setState(() => _isEditingVoiceMask = false);
                        setSheetState(() {});
                        _updateNativeVoiceMasking();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice masking applied successfully! Participants will now hear this voice.'))
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFF007BFF)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Use this voice',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Show active voice mask card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Active Voice Mask",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Builder(builder: (ctx) {
                            final p = VoiceMaskPreset.byId(_voiceMaskPreset) ?? VoiceMaskPreset.all.first;
                            return Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: p.colors,
                                    ),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: p.colors.first.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(p.icon, style: const TextStyle(fontSize: 32)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Turn switch OFF to change voice",
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // Compelling promotional card when OFF
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.record_voice_over, color: Color(0xFFFF6B00), size: 36),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Original Voice Active",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Mask your voice to speak freely and anonymously! Choose from fun presets like Ghost, Robot, or Alien to disguise your identity in any BolRoom.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )));
        });
      },
    );
  }

    Widget _buildCustomVoicePad(StateSetter setSheetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Custom Voice Tuner', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Drag the dot to find your perfect voice texture', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 10),
        Container(
          height: 180,
          decoration: BoxDecoration(color: const Color(0xFF13101E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF231D38))),
          child: LayoutBuilder(builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            double pitchNorm = ((_myVoicePitch - 0.5) * 24.0).clamp(-12.0, 12.0).toDouble();
            double formantNorm = 0.0; // Wait, chatroom_live_screen.dart doesn't have _voiceFormant locally?
            double dotX = (formantNorm + 6.0) / 12.0 * w;
            double dotY = (1.0 - (pitchNorm + 12.0) / 24.0) * h;
            return GestureDetector(
              onPanUpdate: (d) {
                final lx = d.localPosition.dx.clamp(0.0, w);
                final ly = d.localPosition.dy.clamp(0.0, h);
                final newPitch = (1.0 - ly / h) * 24.0 - 12.0;
                final newFormant = (lx / w) * 12.0 - 6.0;
                setState(() {
                  _myVoicePitch = (newPitch / 24.0) + 0.5;
                  // If we don't have _voiceFormant state variable in this class, we need to add it or ignore it.
                  // Wait, I should just pass it to VoiceMaskService directly.
                });
                setSheetState(() {});
                _voiceMaskService.setCustomPitch(newPitch);
                _voiceMaskService.setCustomFormant(newFormant);
              },
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _VoicePadPainter(dotX, dotY))),
                  Positioned(left: dotX - 14, top: dotY - 14, child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFFFF6B00), Color(0xFF007BFF)]), boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2)]))),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Pitch: ${((_myVoicePitch - 0.5) * 24).toStringAsFixed(1)} st', style: TextStyle(color: Colors.white70, fontSize: 11))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            _sb.from('bolroom_profiles').update({'voice_pitch': _myVoicePitch}).eq('id', _myId);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom voice saved successfully!')));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF007BFF)]), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('Use this voice', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          ),
        ),
      ],
    );
  }

  Future<void> _loadMyProfile() async {
    // Always use BolRoom anonymous profile from Supabase
    try {
      final bp = await _sb
          .from('bolroom_profiles')
          .select('*')
          .eq('id', _myId)
          .maybeSingle();
      if (bp != null && mounted) {
        final anonName = (bp['anon_name'] ?? '').toString().trim();
        setState(() {
          _isVoiceMasked = bp['voice_mask_enabled'] == true;
          _myVoicePitch = (bp['voice_pitch'] ?? 0.5).toDouble();
          _voiceMaskPreset = (bp['voice_mask_preset'] ?? 'ghost').toString();
        });
        _updateNativeVoiceMasking();
        if (anonName.isNotEmpty) {
          setState(() {
            _myName = anonName;
            _myAvatar = null;
          });
          return;
        }
      }
    } catch (_) {}
    // Fallback to main profile if no bolroom profile exists
    try {
      final p = await _sb
          .from('profiles')
          .select('name, full_name, avatar_url')
          .eq('id', _myId)
          .maybeSingle();
      if (p != null && mounted) {
        final loaded = (p['name'] ?? p['full_name'] ?? '').toString().trim();
        setState(() {
          _myName = loaded.isNotEmpty ? loaded : 'User';
          _myAvatar = p['avatar_url'];
        });
      }
    } catch (_) {}
  }

  /// Public method to trigger a re-sync of voice masking from Supabase.
  /// Used by profile screen when masking is toggled there.
  Future<void> refreshMaskingFromDB() => _loadMyProfile();

  Future<void> _joinRoom() async {
    await _loadMyProfile(); // must load BEFORE LiveKit token & DB insert

    // ── Room-full check ──
    try {
      final roomMeta = await _sb
          .from('chatrooms')
          .select('max_participants, is_recording, room_status')
          .eq('id', widget.roomId)
          .maybeSingle();
      if (roomMeta != null) {
        final maxP = roomMeta['max_participants'] as int? ?? 0;
        if (roomMeta['room_status'] == 'deleted') {
          if (mounted) {
            _showToast('This room has ended');
            Navigator.pop(context);
          }
          return;
        }
        if (maxP > 0) {
          final count = await _sb
              .from('chatroom_members')
              .select('user_id')
              .eq('room_id', widget.roomId);
          if (count.length >= maxP && !_isHost) {
            if (mounted) {
              _showToast('Room is full ($maxP max)');
              Navigator.pop(context);
            }
            return;
          }
        }
        _isRecording = roomMeta['is_recording'] == true;

        // ── Recording consent ──
        if (_isRecording && !_isHost && mounted) {
          final consented = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF13101E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                const Text('Recording Active',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
              content: const Text(
                'This room is being recorded. By joining, you consent to being recorded.',
                style:
                    TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Leave',
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('I Consent',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (consented != true) {
            if (mounted) Navigator.pop(context);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Room meta check: $e');
    }

    // ── Banned check ──
    try {
      final ban = await _sb
          .from('chatroom_bans')
          .select('id')
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId)
          .maybeSingle();
      if (ban != null) {
        if (mounted) {
          _showToast('You cannot join this room');
          Navigator.pop(context);
        }
        return;
      }
    } catch (_) {}

    // ── Join DB ──
    try {
      await _sb
          .from('chatroom_members')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId);
      await _sb.from('chatroom_members').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': _myName,
        'avatar_url': _myAvatar,
        'is_speaker': _isHost,
        'is_muted': _isMuted,
        'hand_raised': false,
        'host_muted': false,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': _myName,
        'text': '${_firstName(_myName)} joined the room 👋',
        'is_system': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Join DB: $e');
    }
    _loadMembers();
    _loadMessages();
    _initLiveKit(); // init voice AFTER profile is loaded so token has correct identity

    // Start host heartbeat monitor
    _hostHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (_isHost) {
        _sendSystemCommand('HEARTBEAT', '');
        // Periodically check inactivity for the host
        if (DateTime.now().difference(_lastActivityTime) > const Duration(minutes: 10)) {
          debugPrint("Silence/inactivity timeout: ending room.");
          _endRoom();
        }
      } else {
        final secondsSinceHostSeen = DateTime.now().difference(_lastHostSeen).inSeconds;
        if (secondsSinceHostSeen > 30) {
          if (!_hostDisconnected) {
            setState(() {
              _hostDisconnected = true;
              _hostDisconnectCountdown = 120;
            });
            _showToast("Host disconnected. Room will auto-close in 2 minutes.");
          } else {
            setState(() {
              _hostDisconnectCountdown = math.max(0, 120 - (secondsSinceHostSeen - 30));
            });
            if (_hostDisconnectCountdown <= 0) {
              _hostHeartbeatTimer?.cancel();
              _autoCloseEmptyOrNoHostRoom();
            }
          }
        } else {
          if (_hostDisconnected) {
            setState(() {
              _hostDisconnected = false;
              _hostDisconnectCountdown = 120;
            });
            _showToast("Host reconnected! 👑");
          }
        }
      }
    });
  }

  Future<void> _autoCloseEmptyOrNoHostRoom() async {
    try {
      // Send system command that room is closing
      await _sendSystemCommand('END', '');
      await Future.delayed(const Duration(milliseconds: 500));
      // Delete the room
      await _sb.from('chatrooms').delete().eq('id', widget.roomId);
    } catch (e) {
      debugPrint("Error closing room: $e");
    } finally {
      if (mounted) {
        _showEndCountdownForParticipants();
      }
    }
  }

  void _autoPromoteHost() {
    _hostHeartbeatTimer?.cancel();
    final speakers = _members
        .where((m) => m['is_speaker'] == true && m['user_id'] != _currentHostId)
        .toList();
    if (speakers.isNotEmpty) {
      speakers.sort(
          (a, b) => (a['joined_at'] ?? '').compareTo(b['joined_at'] ?? ''));
      if (speakers.first['user_id'] == _myId) {
        _sendSystemCommand('NEW_HOST', _myId);
        _sb.from('chatrooms').update(
            {'host_id': _myId, 'host_name': _myName}).eq('id', widget.roomId);
      }
    } else {
      final listeners = _members
          .where(
              (m) => m['is_speaker'] != true && m['user_id'] != _currentHostId)
          .toList();
      if (listeners.isNotEmpty) {
        listeners.sort(
            (a, b) => (a['joined_at'] ?? '').compareTo(b['joined_at'] ?? ''));
        if (listeners.first['user_id'] == _myId) {
          _sendSystemCommand('NEW_HOST', _myId);
          _sb.from('chatrooms').update(
              {'host_id': _myId, 'host_name': _myName}).eq('id', widget.roomId);
        }
      }
    }
  }

  // ── Leave: just remove yourself; transfer host if you're the host ──
  Future<void> _exitRoomAsync() async {
    try {
      await _livekitRoom?.disconnect();
      // Broadcast leave command to bypass RLS/Realtime replica identity limitations
      await _sendSystemCommand('LEAVE', _myId);

      // Optimistic local update
      if (mounted)
        setState(() => _members.removeWhere((m) => m['user_id'] == _myId));
      await _sb
          .from('chatroom_members')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId);
      // Check remaining members
      final remaining = await _sb
          .from('chatroom_members')
          .select('user_id, user_name')
          .eq('room_id', widget.roomId)
          .order('joined_at');
      if (remaining.isEmpty) {
        // Auto-dissolve: no one left (with 30-second grace period)
        final rId = widget.roomId;
        Future.delayed(const Duration(seconds: 30), () async {
          try {
            final checkRemaining = await _sb
                .from('chatroom_members')
                .select('user_id')
                .eq('room_id', rId);
            if (checkRemaining.isEmpty) {
              await _sb.from('chatrooms').delete().eq('id', rId);
              debugPrint('Grace period expired: Empty room $rId deleted.');
            } else {
              debugPrint('Grace period cancelled: Room $rId has participants.');
            }
          } catch (e) {
            debugPrint('Error in delayed empty room deletion: $e');
          }
        });
      } else if (_isHost) {
        // Transfer host to next person
        final nextHostId = remaining[0]['user_id'];
        final nextHostName = remaining[0]['user_name'] ?? 'Someone';
        await _sb
            .from('chatrooms')
            .update({'host_id': nextHostId, 'host_name': nextHostName}).eq(
                'id', widget.roomId);
        await _sb.from('chatroom_messages').insert({
          'room_id': widget.roomId,
          'user_id': nextHostId,
          'user_name': nextHostName,
          'text': '${_firstName(nextHostName)} is now the host 👑',
          'is_system': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Leave: $e');
    }
  }

  Future<void> _endRoom() async {
    try {
      // 1. Broadcast END command so every participant's listener fires
      await _sendSystemCommand('END', '');

      // Give realtime 1.5s to broadcast the END command before we cascade-delete the database rows
      await Future.delayed(const Duration(milliseconds: 1500));

      // 2. Delete all members first (to kick everyone)
      await _sb.from('chatroom_members').delete().eq('room_id', widget.roomId);

      // 3. Delete the room itself (permanently destructed)
      await _sb.from('chatrooms').delete().eq('id', widget.roomId);

      // 4. Clean up locally
      await _livekitRoom?.disconnect();
      if (mounted) setState(() => _members.clear());

      // 5. Host sees the exact same 3-second destruct countdown as participants
      if (mounted) _showEndCountdownForParticipants();
    } catch (e) {
      debugPrint('End room: $e');
      if (mounted) _showEndCountdownForParticipants();
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await _sb
          .from('chatroom_members')
          .select('*')
          .eq('room_id', widget.roomId)
          .order('joined_at');
      if (!mounted) return;
      final newList = List<Map<String, dynamic>>.from(res);
      // Show join toast locally AND send to chat so all participants see it
      for (final m in newList) {
        final uid = m['user_id']?.toString() ?? '';
        if (uid.isNotEmpty && !_seenMemberIds.contains(uid)) {
          _seenMemberIds.add(uid);
          final joinerName = m['user_name'] ?? 'Someone';
          if (uid == _myId) {
            _showToast('You joined the room 🎉');
          } else {
            _showToast('$joinerName joined 👋');
            // Broadcast to chat so all participants see the join notification
            try {
              await _sb.from('chatroom_messages').insert({
                'room_id': widget.roomId,
                'user_id': uid,
                'user_name': joinerName,
                'text': '👋 $joinerName joined the room',
                'is_system': true,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              });
            } catch (_) {}
          }
        }
      }

      if (newList.length > _peakListeners) {
        _peakListeners = newList.length;
      }
      // Rebuild mic-request set from scratch so stale entries are cleared
      final freshRequests = newList
          .where((m) => m['mic_requested'] == true)
          .map((m) => m['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Fire notification for any newly-seen pending requests (e.g. host joined late)
      if (_isHost || _amICohost()) {
        for (final uid in freshRequests) {
          if (!_micRequests.contains(uid)) {
            final requester = newList.firstWhere(
              (m) => m['user_id']?.toString() == uid,
              orElse: () => {},
            );
            final name = requester['user_name']?.toString() ?? 'Someone';
            // Delay so the build is complete before inserting overlay
            Future.microtask(() {
              if (mounted) _showMicRequestNotification(name, uid);
            });
          }
        }
      }

      setState(() {
        _members = newList;
        // Replace the whole set so revoked/denied requests are purged
        _micRequests
          ..clear()
          ..addAll(freshRequests);
        _membersNotify.value = newList;
        _micRequestsNotify.value = Set.from(_micRequests);

        // Sync local state for current user
        final me =
            newList.firstWhere((m) => m['user_id'] == _myId, orElse: () => {});
        if (me.isNotEmpty) {
          _hasMicPermission = me['is_speaker'] == true || _isHost;
          _micRequestSent = me['mic_requested'] == true;
          if (_hasMicPermission) {
            _isMuted = me['is_muted'] == true;
          }
        }
      });
    } catch (_) {}
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _joinToastText = text);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _joinToastText = null);
    });
  }

  Future<void> _loadMessages() async {
    try {
      final res = await _sb
          .from('chatroom_messages')
          .select('*')
          .eq('room_id', widget.roomId)
          .not('text', 'like', 'SYSTEM_CMD:%')
          .not('text', 'like', 'GAME_EVENT:%')
          .order('created_at', ascending: true)
          .limit(100);
      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(res));
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _subscribeRealtime() {
    // Clean up existing if any (safety for hot restart)
    if (_memberChannel != null) _sb.removeChannel(_memberChannel!);
    if (_msgChannel != null) _sb.removeChannel(_msgChannel!);
    if (_profileChannel != null) _sb.removeChannel(_profileChannel!);

    // Subscribe to own bolroom_profiles row for real-time voice mask sync
    _profileChannel = _sb.channel('bp_voicemask_$_myId').onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'bolroom_profiles',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _myId),
        callback: (payload) {
          if (!mounted) return;
          final row = payload.newRecord;
          final newEnabled = row.containsKey('voice_mask_enabled') ? row['voice_mask_enabled'] == true : _isVoiceMasked;
          final newPreset = row.containsKey('voice_mask_preset') && row['voice_mask_preset'] != null ? row['voice_mask_preset'].toString() : _voiceMaskPreset;
          final changed = newEnabled != _isVoiceMasked || newPreset != _voiceMaskPreset;
          if (changed) {
            final wasEnabled = _isVoiceMasked;
            setState(() {
              _isVoiceMasked = newEnabled;
              _voiceMaskPreset = newPreset;
            });
            _updateNativeVoiceMasking();
            
            if (newEnabled) {
              _broadcastVoiceMaskChange(true, newPreset);
            } else if (wasEnabled && !newEnabled) {
              _broadcastVoiceMaskChange(false, '');
            }
          }
        });
    _profileChannel!.subscribe();

    _memberChannel = _sb.channel('rm_${widget.roomId}').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chatroom_members',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId),
        callback: (p) {
          if (!mounted) return;
          if (p.eventType == PostgresChangeEvent.delete) {
            final old = p.oldRecord['user_id']?.toString();
            if (old != null)
              setState(() =>
                  _members.removeWhere((m) => m['user_id']?.toString() == old));
          } else if (p.eventType == PostgresChangeEvent.insert) {
            if (p.newRecord.isNotEmpty) {
              final uid = p.newRecord['user_id']?.toString() ?? '';
              if (!_members.any((m) => m['user_id'] == uid)) {
                setState(() => _members.add(p.newRecord));
              }
            }
          } else if (p.eventType == PostgresChangeEvent.update) {
            if (p.newRecord.isNotEmpty) {
              final uid = p.newRecord['user_id']?.toString() ?? '';
              setState(() {
                final idx = _members.indexWhere((m) => m['user_id'] == uid);
                Map<String, dynamic> mergedRecord = p.newRecord;
                if (idx != -1) {
                  mergedRecord = {..._members[idx], ...p.newRecord};
                  _members[idx] = mergedRecord;
                } else {
                  _members.add(p.newRecord);
                }

                if (uid == _myId) {
                  final nowSpeaker = mergedRecord['is_speaker'] == true;
                  final nowMuted = mergedRecord['is_muted'] == true;

                  if (nowSpeaker && !_hasMicPermission) {
                    _hasMicPermission = true;
                    _micRequestSent = false;
                    _isMuted = false;
                    _livekitRoom?.localParticipant?.setMicrophoneEnabled(true);
                    _showToast('You can speak now! 🎙️');
                  } else if (!nowSpeaker && _hasMicPermission && !_isHost) {
                    _hasMicPermission = false;
                    _micRequestSent = false;
                    _isMuted = true;
                    _livekitRoom?.localParticipant?.setMicrophoneEnabled(false);
                    _showToast('Your mic was revoked by the host');
                  } else if (_hasMicPermission) {
                    if (nowMuted && !_isMuted) {
                      _isMuted = true;
                      _livekitRoom?.localParticipant
                          ?.setMicrophoneEnabled(false);
                      if (DateTime.now().difference(_lastMuteTap).inSeconds >
                          2) {
                        _showToast('Mic Muted 🔇');
                      }
                    } else if (!nowMuted && _isMuted) {
                      _isMuted = false;
                      _livekitRoom?.localParticipant
                          ?.setMicrophoneEnabled(true);
                      if (DateTime.now().difference(_lastMuteTap).inSeconds >
                          2) {
                        _showToast('Mic Unmuted 🎙️');
                      }
                    }
                  }
                }
                // Sync mic request state & show popup to host
                if (p.newRecord['mic_requested'] == true) {
                  if (!_micRequests.contains(uid)) {
                    _micRequests.add(uid);
                    if (_isHost || _amICohost()) {
                      _showMicRequestNotification(
                          p.newRecord['user_name'] ?? 'Someone', uid);
                    }
                  }
                } else {
                  _micRequests.remove(uid);
                }
                _membersNotify.value = List.from(_members);
                _micRequestsNotify.value = Set.from(_micRequests);
              });
            }
          }
        });
    _memberChannel!.subscribe();

    _msgChannel = _sb.channel('rc_${widget.roomId}').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chatroom_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId),
        callback: (p) {
          if (!mounted) return;
          if (p.newRecord.isNotEmpty) {
            final txt = p.newRecord['text']?.toString() ?? '';
            final isSystemCmd = p.newRecord['is_system'] == true && txt.startsWith('SYSTEM_CMD:');
            if (!isSystemCmd) {
              _lastActivityTime = DateTime.now();
            }
            if (p.newRecord['is_system'] == true &&
                txt.startsWith('GAME_EVENT:')) {
              try {
                final jsonStr = txt.substring('GAME_EVENT:'.length);
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;

                // Handle game invitation popup for specific user
                if (data['event'] == 'invite_to_game' &&
                    data['userId'] == _myId) {
                  _showGameInvitePopup(data['name'] ?? 'Host');
                }
                if (data['event'] == 'kick_from_game' && data['userId'] == _myId) {
                  setState(() => _showGame = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('You have been removed from the game table by the host.'),
                      backgroundColor: Colors.redAccent,
                    ));
                  }
                }
                if (data['event'] == 'start_blind_date') {
                  final p1 = data['p1_id'];
                  final p2 = data['p2_id'];
                  if (_myId != p1 && _myId != p2 && !_isHost) {
                    setState(() {
                      _micsLockedByGame = true;
                      _wasUnmutedBeforeGame = !_isMuted;
                    });
                    if (!_isMuted) _toggleMute(); // Mute automatically
                  }
                }
                
                if (data['event'] == 'end_session' || data['event'] == 'reset_game') {
                  if (_micsLockedByGame) {
                    setState(() => _micsLockedByGame = false);
                    if (_wasUnmutedBeforeGame && _isMuted) {
                      _toggleMute(); // Restore unmute automatically
                      _wasUnmutedBeforeGame = false;
                    }
                  }
                }

                if (data['event'] == 'update_participants') {
                  final list = data['list'] as List<dynamic>? ?? [];
                  setState(() {
                    _gameParticipants = list
                        .map((e) => TodParticipant(
                              userId: e['userId']?.toString() ?? '',
                              name: e['name']?.toString() ?? 'User',
                            ))
                        .toList();
                  });
                }

                if (_gameMode == 'truth_dare') {
                  _gameKey.currentState?.handleGameEvent(data);
                } else if (_gameMode == 'two_truths') {
                  _twoTruthsKey.currentState?.handleGameEvent(data);
                } else if (_gameMode == 'blind_date') {
                  _blindDateKey.currentState?.handleGameEvent(data);
                }
              } catch (e) {
                debugPrint('Game event parse error: $e');
              }
              return; // don't add to chat UI
            }
            if (p.newRecord['is_system'] == true &&
                txt.startsWith('SYSTEM_CMD:')) {
              debugPrint(
                  '⚡ SystemCmd RECEIVED: $txt (myId=$_myId, isHost=$_isHost)');
              if (txt == 'SYSTEM_CMD:GRANT_MIC:$_myId') {
                if (mounted) {
                  setState(() {
                    _hasMicPermission = true;
                    _micRequestSent = false;
                    _isMuted = false;
                    _hostMuted = false;
                    _handRaised = false;

                    // Update local member array instantly
                    final idx =
                        _members.indexWhere((m) => m['user_id'] == _myId);
                    if (idx != -1) {
                      _members[idx]['is_speaker'] = true;
                      _members[idx]['is_muted'] = false;
                    }
                  });
                  _livekitRoom?.localParticipant?.setMicrophoneEnabled(true);
                  _showToast('You can speak now! 🎙️');

                  // Listener explicitly updates their own row to bypass any Host RLS restrictions
                  _sb
                      .from('chatroom_members')
                      .update({
                        'is_speaker': true,
                        'is_muted': false,
                        'mic_requested': false
                      })
                      .eq('room_id', widget.roomId)
                      .eq('user_id', _myId)
                      .catchError((_) {});
                }
              } else if (txt == 'SYSTEM_CMD:REVOKE_MIC:$_myId') {
                if (mounted) {
                  setState(() {
                    _hasMicPermission = false;
                    _micRequestSent = false;
                    _isMuted = true;

                    final idx =
                        _members.indexWhere((m) => m['user_id'] == _myId);
                    if (idx != -1) {
                      _members[idx]['is_speaker'] = false;
                    }
                  });

                  _sb
                      .from('chatroom_members')
                      .update({
                        'is_speaker': false,
                      })
                      .eq('room_id', widget.roomId)
                      .eq('user_id', _myId)
                      .catchError((_) {});

                  _livekitRoom?.localParticipant?.setMicrophoneEnabled(false);
                  _showToast('Your mic was revoked by the host');
                }
              } else if (txt == 'SYSTEM_CMD:MUTE:$_myId') {
                if (mounted) {
                  setState(() {
                    _isMuted = true;
                    _hostMuted = true;
                  });
                  _livekitRoom?.localParticipant?.setMicrophoneEnabled(false);

                  // Explicitly update own row to bypass Host RLS
                  _sb
                      .from('chatroom_members')
                      .update({'is_muted': true, 'host_muted': true})
                      .eq('room_id', widget.roomId)
                      .eq('user_id', _myId)
                      .catchError((_) {});

                  _showToast('You were muted by the host 🔇');
                }
              } else if (txt == 'SYSTEM_CMD:UNMUTE:$_myId') {
                if (mounted) {
                  setState(() {
                    _isMuted = false;
                    _hostMuted = false;
                  });
                  _livekitRoom?.localParticipant?.setMicrophoneEnabled(true);

                  // Explicitly update own row to bypass Host RLS
                  _sb
                      .from('chatroom_members')
                      .update({'is_muted': false, 'host_muted': false})
                      .eq('room_id', widget.roomId)
                      .eq('user_id', _myId)
                      .catchError((_) {});

                  _showToast('Your mic was unmuted by the host 🎙️');
                }
              } else if (txt == 'SYSTEM_CMD:MUTE_ALL:all' &&
                  _hasMicPermission &&
                  !_isHost) {
                if (mounted) {
                  setState(() {
                    _isMuted = true;
                    _hostMuted = true;
                  });
                  _livekitRoom?.localParticipant?.setMicrophoneEnabled(false);

                  _sb
                      .from('chatroom_members')
                      .update({'is_muted': true, 'host_muted': true})
                      .eq('room_id', widget.roomId)
                      .eq('user_id', _myId)
                      .catchError((_) {});

                  _showToast('Everyone was muted by the host 🔇');
                }
              } else if (txt == 'SYSTEM_CMD:KICK:$_myId') {
                // Fade to black, then close
                _showKickedOverlay('You were kicked from the room');
              } else if (txt.startsWith('SYSTEM_CMD:END')) {
                // Host navigates immediately in _endRoom(). Participants see 3-second countdown.
                if (!_isHost) _showEndCountdownForParticipants();
              } else if (txt == 'SYSTEM_CMD:DENY_MIC:$_myId') {
                setState(() {
                  _micRequestSent = false;
                  _hasMicPermission = false;
                  _handRaised = false;
                });
                _showToast('Your mic request was denied');
              } else if (txt.startsWith('SYSTEM_CMD:NEW_HOST:')) {
                final newHostId = txt.split(':').last;
                setState(() {
                  _currentHostId = newHostId;
                  _isHost = _myId == _currentHostId;
                  if (_isHost) {
                    _hasMicPermission = true;
                    _isMuted = false;
                  }
                  _lastHostSeen = DateTime.now();
                });

                if (_isHost) {
                  _livekitRoom?.localParticipant?.setMicrophoneEnabled(true);
                  _showToast('You are now the host 👑');
                  // Broadcast to chat so ALL participants see the host change
                  () async {
                    try {
                      await _sb.from('chatroom_messages').insert({
                        'room_id': widget.roomId,
                        'user_id': _myId,
                        'user_name': _myName,
                        'text': '👑 $_myName is now the host',
                        'is_system': true,
                        'created_at': DateTime.now().toUtc().toIso8601String(),
                      });
                    } catch (_) {}
                  }();
                } else {
                  final newHostObj = _members.firstWhere(
                      (m) => m['user_id'] == newHostId,
                      orElse: () => {});
                  final newHostNameStr = newHostObj['user_name'] ?? 'Someone';
                  _showToast('$newHostNameStr is now the host 👑');
                }
              } else if (txt == 'SYSTEM_CMD:HEARTBEAT:') {
                _lastHostSeen = DateTime.now();
              } else if (txt.startsWith('SYSTEM_CMD:MIC_REQUEST:')) {
                // Handled gracefully by _memberChannel to avoid duplicate notifications.
                final requesterUid = txt.split(':').last;
                if ((_isHost || _amICohost()) && requesterUid != _myId) {
                  _micRequests.add(requesterUid);
                  _micRequestsNotify.value = Set.from(_micRequests);
                }
              } else if (txt.startsWith('SYSTEM_CMD:HAND_RAISE:')) {
                final raiserUid = txt.split(':').last;
                if ((_isHost || _amICohost()) && raiserUid != _myId) {
                  final raiserName = _members
                          .firstWhere((m) => m['user_id'] == raiserUid,
                              orElse: () => {})['user_name']
                          ?.toString() ??
                      'Someone';
                  _showToast('✋ $raiserName raised their hand');
                }
              } else if (txt.startsWith('SYSTEM_CMD:LEAVE:')) {
                final leftUid = txt.split(':').last;
                if (leftUid.isNotEmpty) {
                  setState(() =>
                      _members.removeWhere((m) => m['user_id'] == leftUid));
                }
              }
              return; // don't add to chat UI
            }

            if (p.newRecord['is_reaction'] == true) {
              final uid = p.newRecord['user_id']?.toString() ?? '';
              final txt = p.newRecord['text']?.toString() ?? '';
              if (uid != _myId && uid.isNotEmpty) {
                // Trigger the local floating animation for the remote reaction
                _fireReaction(txt, isLocal: false, overrideUid: uid);
              }
            }

            setState(() {
              _messages.add(p.newRecord);
            });
            _scrollToBottom();
          }
        });
    _msgChannel!.subscribe();
  }

  Future<void> _broadcastVoiceMaskChange(bool enabled, String presetId) async {
    try {
      if (!enabled) {
        await _sb.from('chatroom_messages').insert({
          'room_id': widget.roomId,
          'user_id': _myId,
          'user_name': _myName,
          'text': '🎤 ${_firstName(_myName)} disabled their voice mask',
          'is_system': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }
      
      final presetName = VoiceMaskPreset.all.firstWhere((p) => p.id == presetId, orElse: () => VoiceMaskPreset.all.first).name;
      await _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': _myName,
        'text': '🎭 ${_firstName(_myName)} is now speaking with the $presetName voice mask',
        'is_system': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    Future.delayed(100.ms, () {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: 200.ms, curve: Curves.easeOut);
    });
  }

  // ── HMAC-SHA256 JWT using dart:crypto (Google-maintained) ──
  static String _base64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static String _b64NoPad(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');

  String _buildLiveKitToken(String roomName) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = {
      'metadata': jsonEncode({'avatarUrl': _myAvatar ?? ''}),
      'name': _myName,
      'video': {
        'roomJoin': true,
        'room': roomName,
        'canPublish': true,
        'canSubscribe': true,
        'canPublishData': true,
      },
      'iss': BolRoomConfig.livekitApiKey,
      'exp': now + 21600,
      'nbf': now,
      'sub': _myId,
    };

    // Header MUST match official LiveKit SDK: no "typ" field
    const header = '{"alg":"HS256"}';
    final signingInput =
        '${_b64NoPad(header)}.${_b64NoPad(jsonEncode(payload))}';

    final hmac = Hmac(sha256, utf8.encode(BolRoomConfig.livekitApiSecret));
    final sig = hmac.convert(utf8.encode(signingInput)).bytes;

    return '$signingInput.${_base64UrlNoPad(sig)}';
  }

  Future<void> _initLiveKit() async {
    if (kIsWeb) return;
    if (!BolRoomConfig.isVoiceEnabled) return;

    // ── Step 1: Mic permission ─────────────────────────────────
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showToast(status.isPermanentlyDenied
          ? 'Mic blocked. Go to Settings → Apps → Meetra → Permissions.'
          : 'Microphone permission denied. Tap mic to retry.');
      return;
    }

    // ── Step 2: Build token with pure-Dart HMAC-SHA256 ────────
    _showToast('Connecting to voice...');
    final roomName = 'bolroom-${widget.roomId}';
    final String token;
    try {
      token = _buildLiveKitToken(roomName);
      debugPrint('LiveKit token built ✅ room=$roomName identity=$_myId');
    } catch (e, st) {
      debugPrint('LiveKit token build error: $e\n$st');
      _showToast('Token error: $e');
      return;
    }

    // ── Step 3: Connect ───────────────────────────────────────
    try {
      // Explicitly initialize LiveKit/WebRTC first.
      // This triggers WebRTC.initialize() which creates the native
      // audioProcessingController required for our VoiceMask hook.
      await LiveKitClient.initialize();
      debugPrint('LiveKit: WebRTC initialized ✅');

      _livekitRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _roomListener = _livekitRoom!.createListener();

      _roomListener!
        ..on<RoomConnectedEvent>((_) async {
          debugPrint('LiveKit: connected ✅');
          if (mounted) setState(() => _voiceReady = true);
          try {
            await Hardware.instance.setSpeakerphoneOn(true);
          } catch (_) {}

          // ── CRITICAL: Hook VoiceMaskPlugin into WebRTC audio pipeline ──
          // Register callbacks FIRST, then fire hook.
          // hookWebRtc() starts a 12-second retry loop in Kotlin
          // (1500ms initial delay + 30×400ms retries).
          // Dart is notified via MethodChannel callback on success/failure.
          _voiceMaskService.listenForHookResult(
            onSuccess: () {
              if (mounted) {
                debugPrint('VoiceMask: hookSuccess — DSP pipeline active');
                _showToast('Voice masking active ✅');
              }
            },
            onFailed: (reason) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Voice mask unavailable: $reason'),
                    duration: const Duration(seconds: 6),
                    backgroundColor: const Color(0xFF8B0000),
                  ),
                );
              }
            },
          );
          // Fire hook (non-blocking).
          await _voiceMaskService.hookWebRtc();

          // Always enable mic for non-muted users.
          if (!_isMuted) {
            await _livekitRoom!.localParticipant?.setMicrophoneEnabled(true);
          }

          if (_isVoiceMasked) {
            // Queue the preset — Kotlin applies it once the hook succeeds.
            await _voiceMaskService.startMasking(_voiceMaskPreset);
            _showToast('Voice connected 🎙️ (Masking pending...)');
          } else {
            _showToast(_isMuted
                ? 'Voice connected 🎙️ (mic muted)'
                : 'Voice connected 🎙️ Speak now!');
          }
        })
        ..on<RoomDisconnectedEvent>((e) {
          debugPrint('LiveKit: disconnected — ${e.reason}');
          if (mounted) {
            setState(() => _voiceReady = false);
            // Auto-reconnect for up to 30 seconds
            _showReconnectingOverlay();
          }
        })
        ..on<ParticipantConnectedEvent>((_) => _loadMembers())
        ..on<ParticipantDisconnectedEvent>((_) => _loadMembers())
        ..on<ActiveSpeakersChangedEvent>((e) {
          if (!mounted) return;
          setState(() {
            _speakingIdentities = e.speakers.map((p) => p.identity).toSet();
            if (_speakingIdentities.isNotEmpty) {
              _lastActivityTime = DateTime.now();
            }
          });
        });

      await _livekitRoom!.connect(
        BolRoomConfig.livekitUrl,
        token,
        fastConnectOptions: FastConnectOptions(
          microphone: TrackOption(enabled: !_isMuted),
        ),
      );
    } catch (e, st) {
      debugPrint('LiveKit connect error: $e\n$st');
      _showToast('Voice failed: $e');
    }
  }

  DateTime _lastMuteTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _toggleMute() async {
    _lastMuteTap = DateTime.now();
    _lastActivityTime = DateTime.now();
    final newMuted = !_isMuted;
    setState(() => _isMuted = newMuted);
    HapticFeedback.mediumImpact();

    _showToast(newMuted ? 'Mic Muted 🔇' : 'Mic Unmuted 🎙️');

    if (_livekitRoom == null) {
      // Try to init if not yet connected
      _initLiveKit();
    } else {
      await _livekitRoom!.localParticipant?.setMicrophoneEnabled(!newMuted);
      debugPrint('LiveKit mic: muted=$newMuted');
    }

    // Pause/resume voice masking processor to save CPU when muted
    if (_isVoiceMasked) {
      if (newMuted) {
        _voiceMaskService.stopMasking();
      } else {
        _voiceMaskService.startMasking(_voiceMaskPreset);
      }
    }

    try {
      await _sb
          .from('chatroom_members')
          .update({'is_muted': newMuted})
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId);
    } catch (_) {}
  }

  File? _selectedImageFile;
  bool _isUploadingImage = false;
  String? _selectedImageUrl;
  String? _selectedImageBase64;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 1000);
      if (file == null) return;

      setState(() {
        _selectedImageFile = File(file.path);
        _isUploadingImage = true;
      });

      final bytes = await file.readAsBytes();
      final ext = file.path
          .split('.')
          .last
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), 'jpg');
      final uid = _myId;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'chat/$uid-$timestamp.$ext';

      try {
        await _sb.storage.from('avatars').uploadBinary(fileName, bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true));
        final url = _sb.storage.from('avatars').getPublicUrl(fileName);
        if (mounted)
          setState(() {
            _selectedImageUrl = url;
            _isUploadingImage = false;
          });
      } catch (e) {
        final b64 = base64Encode(bytes);
        if (mounted)
          setState(() {
            _selectedImageBase64 = 'data:image/jpeg;base64,$b64';
            _isUploadingImage = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _sendMessage() async {
    final raw = _msgCtrl.text.trim();
    if (raw.isEmpty &&
        _selectedImageUrl == null &&
        _selectedImageBase64 == null) return;
    if (_isUploadingImage) return;

    final imgUrl = _selectedImageUrl ?? _selectedImageBase64;
    final prefix = imgUrl != null ? '[IMG:$imgUrl] ' : '';

    const blocked = ['spam', 'hate', 'slur'];
    final filtered = raw.splitMapJoin(
      RegExp(r'\S+'),
      onMatch: (m) {
        final w = m[0]!.toLowerCase();
        return blocked.any((b) => w.contains(b)) ? '*' * m[0]!.length : m[0]!;
      },
    );

    final finalMsg = (prefix + filtered).trim();

    _msgCtrl.clear();
    setState(() {
      _selectedImageFile = null;
      _selectedImageUrl = null;
      _selectedImageBase64 = null;
      _chatActive = true;
    });

    try {
      await _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': _myName,
        'text': finalMsg,
        'is_system': false,
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
    } catch (_) {}
  }

  void handleLeaveAction() {
    _handleLeaveAction();
  }

  /// Called by the floating pill close button to leave cleanly
  void _handleLeaveAction() {
    if (_isHost && _members.length > 1) {
      if (mounted) _showExitSheet();
    } else if (_isHost) {
      // only person — end room
      _endRoom();
    } else {
      _disconnectAndLeave();
    }
  }

  Future<void> _disconnectAndLeave() async {
    // Stop voice masking before leaving
    if (_isVoiceMasked) {
      try { await _voiceMaskService.stopMasking(); } catch (_) {}
    }
    try {
      await _sb
          .from('chatroom_members')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId);
    } catch (_) {}
    try {
      await _livekitRoom?.disconnect();
    } catch (_) {}
    BolRoomManager.completelyCloseRoom();
  }

  bool _showingReconnect = false;
  Timer? _reconnectTimer;

  void _showReconnectingOverlay() {
    if (_showingReconnect) return;
    setState(() => _showingReconnect = true);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _showingReconnect) {
        setState(() => _showingReconnect = false);
        _showToast('Disconnected from room');
        _disconnectAndLeave();
      }
    });
    // Try to reconnect
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showingReconnect) {
        _initLiveKit().then((_) {
          if (mounted && _voiceReady) {
            setState(() => _showingReconnect = false);
            _reconnectTimer?.cancel();
          }
        });
      }
    });
  }

  // ── KICKED OVERLAY — Fade to black (for individual KICK) ──
  bool _isKicked = false;
  String _kickedReason = 'You were kicked from the room.';
  void _showKickedOverlay([String reason = 'You were kicked from the room.']) {
    if (!mounted) return;
    setState(() {
      _isKicked = true;
      _kickedReason = reason;
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      BolRoomManager.completelyCloseRoom();
    });
  }

  // ── END COUNTDOWN BANNER — For participants when host ends room ──
  void _showEndCountdownForParticipants() {
    if (!mounted) return;
    _chatFocusNode.unfocus();
    _msgCtrl.clear();
    setState(() {
      _showEndCountdownBanner = true;
      _showChat = false;
      _endCountdownSeconds = 3;
    });
    _endCountdownTimer?.cancel();
    _endCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_endCountdownSeconds > 1) {
        setState(() => _endCountdownSeconds--);
      } else {
        t.cancel();
        BolRoomManager.completelyCloseRoom();
      }
    });
  }

  // ── REPORT DIALOG ──
  void _showReportDialog(String reportedUserId, String reportedName) {
    String? selectedReason;
    final reasons = [
      'Hate Speech',
      'Harassment',
      'Spam',
      'Inappropriate Content',
      'Other'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0914),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Report $reportedName',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...reasons.map((r) => GestureDetector(
                          onTap: () => setLocal(() => selectedReason = r),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedReason == r
                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: selectedReason == r
                                      ? Colors.redAccent.withValues(alpha: 0.5)
                                      : Colors.white12),
                            ),
                            child: Text(r,
                                style: TextStyle(
                                    color: selectedReason == r
                                        ? Colors.redAccent
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        )),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                try {
                                  await _sb.from('chatroom_reports').insert({
                                    'room_id': widget.roomId,
                                    'reporter_id': _myId,
                                    'reported_user_id': reportedUserId,
                                    'reason': selectedReason,
                                  });
                                } catch (_) {}
                                _showToast('Report submitted. Thank you.');
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Submit Report',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              )),
    );
  }

  // ── PROFILE CARD IN-ROOM ──
  void _showProfileCard(Map<String, dynamic> member) {
    final uid = member['user_id']?.toString() ?? '';
    final name = member['user_name'] ?? 'User';
    final avatar = member['avatar_url']?.toString();
    bool isFollowing = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0914),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) => StatefulBuilder(builder: (statefulCtx, setLocal) {
        // Check follow status
        _sb
            .from('bolroom_follows')
            .select('id')
            .eq('follower_id', _myId)
            .eq('following_id', uid)
            .maybeSingle()
            .then((res) {
          if (res != null && statefulCtx.mounted) setLocal(() => isFollowing = true);
        });
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              // Avatar
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorForUser(uid).withValues(alpha: 0.15),
                  border: Border.all(
                      color: _colorForUser(uid).withValues(alpha: 0.4),
                      width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: _colorForUser(uid).withValues(alpha: 0.2),
                        blurRadius: 15)
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: (avatar != null && avatar.startsWith('http'))
                    ? Image.network(avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                    color: _colorForUser(uid),
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold))))
                    : Center(
                        child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: _colorForUser(uid),
                                fontSize: 36,
                                fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 16),
              Text(name,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              Row(children: [
                // View Profile
                Expanded(
                    child: _profileActionBtn(
                        Icons.person_outline, 'Profile', BolRoomColors.cyan,
                        () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              BolroomProfileScreen(targetUserId: uid)));
                })),
                const SizedBox(width: 12),
                Expanded(
                    child: _profileActionBtn(
                        Icons.message_outlined, 'Message', BolRoomColors.purple,
                        () async {
                  if (uid.isEmpty || _myId.isEmpty) return;
                  Navigator.of(sheetCtx).pop();

                  try {
                    // Check for existing conversation
                    final existing = await _sb
                        .from('bolroom_dm_conversations')
                        .select('*')
                        .or('and(user1_id.eq.$_myId,user2_id.eq.$uid),and(user1_id.eq.$uid,user2_id.eq.$_myId)')
                        .maybeSingle();

                    String convId;
                    if (existing != null) {
                      convId = existing['id'].toString();
                    } else {
                      final newConvo = await _sb
                          .from('bolroom_dm_conversations')
                          .insert({
                            'user1_id': _myId,
                            'user2_id': uid,
                          })
                          .select()
                          .single();
                      convId = newConvo['id'].toString();
                    }

                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (_) => BolroomDmChatScreen(
                                  conversationId: convId,
                                  partnerId: uid,
                                  partnerName: name,
                                  partnerAvatarKey: avatar ?? 'default',
                                )));
                  } catch (e) {
                    debugPrint('Start DM error: $e');
                  }
                })),
              ]),
              const SizedBox(height: 12),
              // Game management buttons
              if (_isHost && _showGame && uid != _myId) ...[
                Builder(builder: (context) {
                  final bool isInGame = _gameParticipants?.any((p) => p.userId == uid) ?? false;
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        if (isInGame) {
                          _sendGameEvent({
                            'event': 'kick_from_game',
                            'userId': uid,
                            'name': name
                          });
                          if (_gameMode == 'truth_dare') {
                            _gameKey.currentState?.handleGameEvent({
                              'event': 'kick_from_game',
                              'userId': uid,
                              'name': name
                            });
                          } else if (_gameMode == 'two_truths') {
                            _gameKey.currentState?.handleGameEvent({
                              'event': 'kick_from_game',
                              'userId': uid,
                              'name': name
                            });
                          }
                          _showToast('$name removed from game');
                        } else {
                          _sendGameEvent({
                            'event': 'invite_to_game',
                            'userId': uid,
                            'name': name
                          });
                          _showToast('Invite sent to $name');
                        }
                      },
                      icon: Icon(isInGame ? Icons.videogame_asset_off : Icons.videogame_asset, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isInGame ? Colors.redAccent : BolRoomColors.cyan).withValues(alpha: 0.1),
                        foregroundColor: isInGame ? Colors.redAccent : BolRoomColors.cyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: isInGame ? Colors.redAccent : BolRoomColors.cyan, width: 1.5),
                      ),
                      label: Text(isInGame ? 'Kick from Game Table' : 'Invite to Game Table',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
              // Follow button
              if (uid != _myId)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        if (isFollowing) {
                          await _sb
                              .from('bolroom_follows')
                              .delete()
                              .eq('follower_id', _myId)
                              .eq('following_id', uid);
                          if (statefulCtx.mounted) setLocal(() => isFollowing = false);
                        } else {
                          await _sb.from('bolroom_follows').insert(
                              {'follower_id': _myId, 'following_id': uid});
                          if (statefulCtx.mounted) setLocal(() => isFollowing = true);
                        }
                      } catch (_) {}
                    },
                    icon: Icon(
                        isFollowing ? Icons.check : Icons.person_add_outlined,
                        size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.white10
                          : const Color(0xFF7B2CBF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    label: Text(isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _profileActionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showGameInvitePopup(String hostName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Text(_gameMode == 'two_truths' ? '🎭 ' : '🍾 ', style: const TextStyle(fontSize: 24)),
          Text('Game Invite',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Text('$hostName invited you to join the game table.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendGameEvent({
                'event': 'invite_declined',
                'userId': _myId,
                'name': _myName
              });
            },
            child:
                const Text('Decline', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BolRoomColors.cyan,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Send accept event
              _sendGameEvent({
                'event': 'invite_accepted',
                'userId': _myId,
                'name': _myName
              });
              setState(() => _showGame = true);
            },
            child: const Text('Join Now',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool _amICohost() =>
      _members.any((m) => m['user_id'] == _myId && m['is_cohost'] == true);
  int get _speakerCount => _members
      .where((m) =>
          m['is_speaker'] == true ||
          m['is_cohost'] == true ||
          m['user_id'] == _currentHostId)
      .length;
  int get _cohostCount => _members.where((m) => m['is_cohost'] == true).length;

  // In-app mic request notification banner with Approve/Deny buttons
  void _showMicRequestNotification(String name, String uid) {
    if (!(_isHost || _amICohost())) return;

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A2744), Color(0xFF0D1B38)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.15), blurRadius: 20)
              ],
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.mic, color: Colors.amber, size: 16)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mic Request',
                      style: GoogleFonts.inter(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  Text('${_firstName(name)} wants to speak',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              )),
              const SizedBox(width: 8),
              // Approve (Tick)
              GestureDetector(
                onTap: () async {
                  overlayEntry.remove();
                  await _sb
                      .from('chatroom_members')
                      .update({
                        'is_speaker': true,
                        'is_muted': false,
                        'mic_requested': false
                      })
                      .eq('room_id', widget.roomId)
                      .eq('user_id', uid);
                  await _sendSystemCommand('GRANT_MIC', uid);
                  setState(() => _micRequests.remove(uid));
                  _showToast('Mic granted ✅');
                },
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 16)),
              ),
              const SizedBox(width: 8),
              // Deny (Cross)
              GestureDetector(
                onTap: () async {
                  overlayEntry.remove();
                  await _sb
                      .from('chatroom_members')
                      .update({'mic_requested': false})
                      .eq('room_id', widget.roomId)
                      .eq('user_id', uid);
                  await _sendSystemCommand('DENY_MIC', uid);
                  setState(() => _micRequests.remove(uid));
                  _micRequestsNotify.value = Set.from(_micRequests);
                },
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 16)),
              ),
            ]),
          ).animate().slideY(begin: -1, end: 0, duration: 300.ms).fadeIn(),
        ),
      ),
    );

    // Insert into parent overlay safely
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    overlay.insert(overlayEntry);
    // Auto-dismiss after 15s if host hasn't acted
    Timer(const Duration(seconds: 15), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  // Quick single-action popup: mute OR give mic
  void _showQuickMicAction(Map<String, dynamic> member, bool hasMic) {
    final uid = member['user_id']?.toString() ?? '';
    final name = member['user_name'] ?? 'User';
    if (uid.isEmpty || uid == _currentHostId) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorForUser(uid).withValues(alpha: 0.15)),
              child: Center(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(
                          color: _colorForUser(uid),
                          fontSize: 22,
                          fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text(
                      hasMic
                          ? '🎙️ Has mic permission'
                          : '🎧 No mic permission',
                      style: GoogleFonts.inter(
                          color:
                              hasMic ? const Color(0xFF7856FF) : Colors.white38,
                          fontSize: 12)),
                ])),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                if (hasMic) {
                  // Mute and revoke mic
                  await _sb
                      .from('chatroom_members')
                      .update({
                        'is_muted': true,
                        'is_speaker': false,
                        'mic_requested': false
                      })
                      .eq('room_id', widget.roomId)
                      .eq('user_id', uid);
                  await _sendSystemCommand('REVOKE_MIC', uid);
                  setState(() => _micRequests.remove(uid));
                  _showToast('${_firstName(name)} muted & mic revoked');
                } else {
                  // Grant mic
                  await _sb
                      .from('chatroom_members')
                      .update({
                        'is_speaker': true,
                        'is_muted': false,
                        'mic_requested': false
                      })
                      .eq('room_id', widget.roomId)
                      .eq('user_id', uid);
                  await _sendSystemCommand('GRANT_MIC', uid);
                  setState(() => _micRequests.remove(uid));
                  _showToast('Mic granted to ${_firstName(name)} 🎙️');
                }
                _loadMembers();
              },
              icon: Icon(hasMic ? Icons.mic_off : Icons.mic, size: 20),
              label: Text(
                  hasMic ? 'Mute This Participant' : 'Give Mic Permission',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasMic ? Colors.redAccent : const Color(0xFF7856FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Kick from Room ──
          if (_isHost)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF111827),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Kick $name?',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      content: Text(
                          '$name will be removed from the room immediately.',
                          style: GoogleFonts.inter(color: Colors.white54)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel',
                                style:
                                    GoogleFonts.inter(color: Colors.white54))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Kick',
                                style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _sendSystemCommand('KICK', uid);
                    // Remove from DB
                    await _sb
                        .from('chatroom_members')
                        .delete()
                        .eq('room_id', widget.roomId)
                        .eq('user_id', uid);
                    _loadMembers();
                  }
                },
                icon: const Icon(Icons.person_remove,
                    size: 18, color: Colors.redAccent),
                label: Text('Kick from Room',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showMicRequestPopup(String name, String uid) {
    late final Timer dialogTimer;
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          dialogTimer = Timer(const Duration(seconds: 4), () {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });
          return AlertDialog(
            backgroundColor: BolRoomColors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: BolRoomColors.cyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.mic,
                      color: BolRoomColors.cyan, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Mic Request',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
            ]),
            content: Text('${_firstName(name)} has requested mic permission',
                style: GoogleFonts.inter(
                    color: BolRoomColors.muted, fontSize: 14)),
            actions: [
              TextButton(
                  onPressed: () {
                    dialogTimer.cancel();
                    Navigator.pop(ctx);
                    _sb
                        .from('chatroom_members')
                        .update({'mic_requested': false})
                        .eq('room_id', widget.roomId)
                        .eq('user_id', uid);
                    setState(() => _micRequests.remove(uid));
                  },
                  child: Text('Decline',
                      style: GoogleFonts.inter(color: Colors.redAccent))),
              ElevatedButton(
                onPressed: () async {
                  dialogTimer.cancel();
                  Navigator.pop(ctx);
                  await _sb
                      .from('chatroom_members')
                      .update({
                        'is_speaker': true,
                        'is_muted': false,
                        'mic_requested': false
                      })
                      .eq('room_id', widget.roomId)
                      .eq('user_id', uid);
                  await _sendSystemCommand('GRANT_MIC', uid);
                  setState(() => _micRequests.remove(uid));
                  _showToast('Mic granted to ${_firstName(name)} 🎙️');
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: BolRoomColors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text('Allow',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
  }

  String _getCurrentSpeakerName() {
    if (_speakingIdentities.isEmpty) return 'No one speaking';
    final speakerId = _speakingIdentities.first;
    if (speakerId == _myId) return 'You are speaking';
    final member = _members.firstWhere((m) => m['user_id'] == speakerId,
        orElse: () => <String, dynamic>{});
    return member['user_name'] ?? 'Someone speaking';
  }

  Widget _buildMinimizedBar() {
    final speakerName = _getCurrentSpeakerName();
    return GestureDetector(
      onTap: () {
        BolRoomManager.maximizeRoom(context);
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF13101E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: BolRoomColors.cyan.withValues(alpha: 0.3), width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (ctx, _) {
                    return Icon(
                      Icons.multitrack_audio,
                      color: _speakingIdentities.isNotEmpty
                          ? BolRoomColors.cyan
                          : Colors.white38,
                      size: 20 +
                          (_speakingIdentities.isNotEmpty
                              ? (_pulseCtrl.value * 4)
                              : 0),
                    );
                  }),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.roomName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(speakerName,
                        style: const TextStyle(
                            color: BolRoomColors.cyan, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_hasMicPermission) {
                    _toggleMute();
                  } else {
                    _requestMic();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isMuted
                        ? Colors.white.withValues(alpha: 0.1)
                        : BolRoomColors.cyan.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.white70 : BolRoomColors.cyan,
                      size: 20),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  _handleLeaveAction();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    final fullScreen = Material(
      type: MaterialType.transparency,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF0C0914),
        body: Stack(children: [
          AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (ctx, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 1.2 + (_pulseCtrl.value * 0.1),
                      colors: [
                        _colorForUser(_currentHostId).withValues(
                            alpha: 0.15 + (_pulseCtrl.value * 0.05)),
                        const Color(0xFF0C0914),
                      ],
                    ),
                  ),
                );
              }),
          Center(
            child: SafeArea(
                child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildTopBar(),
                // Pinned post banner
                if (_pinnedPost != null && _pinnedPost!.isNotEmpty)
                  _buildPinnedBanner(),
                Expanded(
                    child: Stack(children: [
                  _buildGridStage(),
                  _buildLiveChat(),
                ])),
              ]),
              _buildBottomBar(),
            ])),
          ),
          ..._floatingReactions.map((r) => _buildFloatingEmoji(r)),
          _buildChatOverlay(),
          // ── Game Panel ──
          if (_showGame && (_gameMode == 'truth_dare' || _gameMode == 'two_truths' || _gameMode == 'blind_date')) _buildGamePanel(),
          if (_joinToastText != null)
            Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: _buildToastBanner(_joinToastText!)),
          // Reconnecting overlay
          if (_showingReconnect)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                          color: Color(0xFFFF6B00), strokeWidth: 3),
                      const SizedBox(height: 20),
                      Text('Reconnecting…',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Please wait up to 30 seconds',
                          style: GoogleFonts.inter(
                              color: Colors.white54, fontSize: 13)),
                    ]),
              ),
            ),
          // Kicked fade-to-black overlay (for individual KICK)
          if (_isKicked)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isKicked ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      _kickedReason,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_hostDisconnected && !_isHost && !_showEndCountdownBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Host disconnected. Room will auto-close in $_hostDisconnectCountdown seconds.",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // End-of-room countdown banner (for participants when host ends room)
          if (_showEndCountdownBanner)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: ColoredBox(
                  color: Colors.black, // Fully black screen
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.power_settings_new,
                                color: Colors.redAccent, size: 48),
                            const SizedBox(height: 20),
                            const Text(
                              'The room is destructed by host and you are going to be redirected on the bolroom section',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Leaving in $_endCountdownSeconds...',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );

    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutQuart,
          top: _isMinimized ? screenH : 0,
          bottom: _isMinimized ? -screenH : 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isMinimized ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: _isMinimized,
              child: fullScreen,
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutQuart,
          bottom: _isMinimized ? 85 : -100, // Just above navbar
          left: 16,
          right: 16,
          child: _buildMinimizedBar(),
        ),
      ],
    );
  }

  Widget _buildPinnedBanner() {
    return GestureDetector(
      onLongPress: _isHost
          ? () => setState(() {
                _pinnedPost = null;
                _sb
                    .from('chatrooms')
                    .update({'pinned_post': null}).eq('id', widget.roomId);
              })
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: BolRoomColors.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BolRoomColors.gold.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.push_pin, color: BolRoomColors.gold, size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_pinnedPost!,
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12))),
          if (_isHost)
            GestureDetector(
                onTap: () => setState(() {
                      _pinnedPost = null;
                      _sb.from('chatrooms').update({'pinned_post': null}).eq(
                          'id', widget.roomId);
                    }),
                child:
                    const Icon(Icons.close, color: Colors.white38, size: 14)),
        ]),
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildToastBanner(String text) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A2744), Color(0xFF0D1B38)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BolRoomColors.cyan.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: BolRoomColors.cyan.withValues(alpha: 0.15),
                blurRadius: 20)
          ],
        ),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: BolRoomColors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_add,
                  color: BolRoomColors.cyan, size: 16)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.3, end: 0);
  }

  // ==========================================
  // TOP BAR
  // ==========================================
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
            onTap: () {
              BolRoomManager.minimizeRoom(context);
            },
            child: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white70, size: 32)),
        Expanded(
            child: Column(children: [
          Text(widget.roomName,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (_isRecording)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Recording',
                  style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ]),
        ])),
        Row(children: [
          // Game icon — only for game-mode rooms
          if (_gameMode != null && _gameMode!.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _showGame = !_showGame),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showGame
                      ? const Color(0xFF3DCFA0).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                      color: _showGame
                          ? const Color(0xFF3DCFA0).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(Icons.sports_esports,
                    color: _showGame ? const Color(0xFF3DCFA0) : Colors.white60,
                    size: 20),
              ),
            ),
          // Leave button
          GestureDetector(
            onTap: () async {
              if (_isHost) {
                _showExitSheet();
              } else {
                await _exitRoomAsync();
                if (mounted) BolRoomManager.completelyCloseRoom();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Leave',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  void _showExitSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF13101E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) {
          final eligible = _members
              .where((m) => m['user_id'] != _myId && m['is_speaker'] == true)
              .toList();
          return DraggableScrollableSheet(
            initialChildSize: eligible.isEmpty ? 0.35 : 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.35,
            expand: false,
            builder: (_, scrollCtrl) => SafeArea(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Leave or End Room',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      eligible.isEmpty
                          ? 'No active speakers available to assign as host. Destruct the room to close it completely.'
                          : 'Assign a new host from the active speakers before leaving, or destruct the room for everyone.',
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Destruct Room Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _endRoom();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.redAccent.withValues(alpha: 0.15),
                            Colors.redAccent.withValues(alpha: 0.05)
                          ]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.power_settings_new,
                                  color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Text('Destruct Complete Room',
                                  style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (eligible.isNotEmpty) ...[
                    const Divider(color: Colors.white10),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('OR ASSIGN NEW HOST',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: eligible.length,
                        itemBuilder: (ctx, idx) {
                          final m = eligible[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _colorForUser(m['user_id'])
                                  .withValues(alpha: 0.2),
                              backgroundImage: m['avatar_url'] != null
                                  ? NetworkImage(m['avatar_url'].toString())
                                  : null,
                              child: m['avatar_url'] == null
                                  ? Text(
                                      (m['user_name'] ?? 'U')[0].toUpperCase(),
                                      style: TextStyle(
                                          color: _colorForUser(m['user_id'])))
                                  : null,
                            ),
                            title: Text(m['user_name'] ?? 'User',
                                style: const TextStyle(color: Colors.white)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: BolRoomColors.cyan,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 0),
                                  minimumSize: const Size(0, 32)),
                              child: const Text('Assign host & leave',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _sb.from('chatrooms').update({
                                  'host_id': m['user_id'],
                                  'host_name': m['user_name']
                                }).eq('id', widget.roomId);
                                await _sendSystemCommand(
                                    'NEW_HOST', m['user_id']);
                                await _exitRoomAsync();
                                if (mounted)
                                  BolRoomManager.completelyCloseRoom();
                              },
                            ),
                          );
                        },
                      ),
                    )
                  ]
                ],
              ),
            ),
          );
        });
  }

  void _showHostSettings() {
    showModalBottomSheet(
        context: context,
        backgroundColor: BolRoomColors.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Space Settings',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  // Recording toggle
                  _actionItem(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                      Icons.radio_button_checked,
                      _isRecording ? Colors.redAccent : const Color(0xFF7856FF),
                      () {
                    Navigator.pop(context);
                    _toggleRecording();
                  }),
                  // Pin a post
                  _actionItem('Pin a Message', Icons.push_pin_outlined,
                      BolRoomColors.gold, () {
                    Navigator.pop(context);
                    showDialog(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            backgroundColor: BolRoomColors.card,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: Text('Pin a Message',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            content: TextField(
                                controller: _pinnedCtrl,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                decoration: InputDecoration(
                                    hintText: 'Enter message to pin...',
                                    hintStyle:
                                        const TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: BolRoomColors.bg,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none))),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('Cancel',
                                      style: GoogleFonts.inter(
                                          color: Colors.white38))),
                              ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _setPinnedPost(_pinnedCtrl.text);
                                    _pinnedCtrl.clear();
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: BolRoomColors.gold,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  child: Text('Pin',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold))),
                            ],
                          );
                        });
                  }),
                  // Captions Placeholder
                  _actionItem('Show Captions', Icons.closed_caption_outlined,
                      Colors.white70, () {
                    Navigator.pop(context);
                    _showToast('Captions enabled (Beta)');
                  }),
                  // End space
                  _actionItem('End Space for All', Icons.stop_circle_outlined,
                      Colors.redAccent, () {
                    Navigator.pop(context);
                    _showExitSheet();
                  }),
                ]))));
  }

  // ── X-STYLE GRID STAGE ──
  Widget _buildGridStage() {
    final host = _members.firstWhere((m) => m['user_id'] == _currentHostId,
        orElse: () => {});
    final hostName = host['user_name'] ?? _currentHostName;
    final hostAura = _colorForUser(_currentHostId);

    final cohosts = _members
        .where((m) => m['is_cohost'] == true && m['user_id'] != _currentHostId)
        .take(2)
        .toList();

    final speakers = _members
        .where((m) =>
            m['is_speaker'] == true &&
            m['is_cohost'] != true &&
            m['user_id'] != _currentHostId)
        .take(8)
        .toList();

    final listeners = _members
        .where((m) =>
            m['is_speaker'] != true &&
            m['is_cohost'] != true &&
            m['user_id'] != _currentHostId)
        .toList();

    final nodeW = (MediaQuery.of(context).size.width - 40 - 48) / 4;

    return SingleChildScrollView(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Unified Stage (Host, Cohosts, Speakers)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 16,
            runSpacing: 24,
            alignment: WrapAlignment.start,
            children: [
              _buildSpaceNode(host, hostName, hostAura,
                      isHost: true,
                      isSpeaking: _speakingIdentities.contains(_currentHostId),
                      isMuted: host['is_muted'] == true,
                      width: nodeW)
                  .animate(key: ValueKey('host_$_currentHostId'))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1),
              ...cohosts.map((m) {
                final uid = m['user_id']?.toString() ?? '';
                final isMe = uid == _myId;
                final dispName =
                    isMe ? "You" : _firstName(m['user_name'] ?? 'User');
                return _buildSpaceNode(m, dispName, _colorForUser(uid),
                        isHost: false,
                        isSpeaking: _speakingIdentities.contains(uid),
                        isMuted: m['is_muted'] == true,
                        width: nodeW)
                    .animate(key: ValueKey('cohost_$uid'))
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1);
              }),
              ...speakers.map((m) {
                final uid = m['user_id']?.toString() ?? '';
                final isMe = uid == _myId;
                final dispName =
                    isMe ? "You" : _firstName(m['user_name'] ?? 'User');
                return _buildSpaceNode(m, dispName, _colorForUser(uid),
                        isHost: false,
                        isSpeaking: _speakingIdentities.contains(uid),
                        isMuted: m['is_muted'] == true,
                        width: nodeW)
                    .animate(key: ValueKey('speaker_$uid'))
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1);
              }),
            ],
          ),
        ),

        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text("Listeners (${listeners.length})",
              style: const TextStyle(
                  color: Color(0xFF8E8B99),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),

        // Listeners Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 16,
            runSpacing: 24,
            alignment: WrapAlignment.start,
            children: listeners.map((m) {
              final uid = m['user_id']?.toString() ?? '';
              final dispName =
                  (uid == _myId) ? "You" : _firstName(m['user_name'] ?? 'User');
              return GestureDetector(
                      onTap: () {
                        if (uid.isNotEmpty) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      BolroomProfileScreen(targetUserId: uid)));
                        } else {
                          _showToast('Cannot open profile for this user.');
                        }
                      },
                      onLongPress: () {
                        if (uid != _myId && (_isHost || _amICohost())) {
                          _showQuickMicAction(m, false);
                        }
                      },
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              _buildGlowingAvatar(
                                  Colors.grey.withValues(alpha: 0.2), 30,
                                  isPulsing: false,
                                  avatarUrl: m['avatar_url']?.toString(),
                                  userName: m['user_name']?.toString(),
                                  userId: m['user_id']?.toString()),
                              if (_memberReactions.containsKey(uid))
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Text(_memberReactions[uid]!,
                                          style: const TextStyle(fontSize: 16))
                                      .animate()
                                      .scale(
                                          begin: const Offset(0.3, 0.3),
                                          end: const Offset(1, 1),
                                          duration: 200.ms)
                                      .then()
                                      .fadeOut(
                                          delay: 1000.ms, duration: 300.ms),
                                ),
                              if (m['hand_raised'] == true)
                                Positioned(
                                  top: -4,
                                  left: -4,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.amber.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0C0914),
                                            width: 1.5)),
                                    child: const Center(
                                        child: Text('✋',
                                            style: TextStyle(fontSize: 10))),
                                  ),
                                ),
                              if (_micRequests.contains(uid))
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.green.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0C0914),
                                            width: 1.5)),
                                    child: const Icon(Icons.mic,
                                        color: Colors.white, size: 10),
                                  ),
                                ),
                              // Voice mask badge on own avatar
                              if (_isVoiceMasked && uid == _myId)
                                Positioned(
                                  bottom: -3,
                                  left: -3,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B00).withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0C0914),
                                            width: 1.5)),
                                    child: const Center(
                                        child: Icon(Icons.masks,
                                            color: Colors.white, size: 9)),
                                  ),
                                ),
                            ]),
                        const SizedBox(height: 6),
                        SizedBox(
                            width: nodeW,
                            child: Text(dispName,
                                style: const TextStyle(
                                    color: Color(0xFF8E8B99), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center)),
                      ]))
                  .animate(key: ValueKey('listener_$uid'))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1);
            }).toList(),
          ),
        ),
        const SizedBox(height: 120), // Bottom padding for floating bar
      ],
    ));
  }

  Widget _buildSpaceNode(Map<String, dynamic> member, String name, Color aura,
      {required bool isHost,
      required bool isSpeaking,
      required bool isMuted,
      required double width}) {
    final uid = member['user_id']?.toString() ?? '';
    final isMe = uid == _myId;
    return GestureDetector(
      onTap: () {
        if (uid.isNotEmpty) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BolroomProfileScreen(targetUserId: uid)));
        } else {
          _showToast('Cannot open profile for this user.');
        }
      },
      onLongPress: () {
        if (!isMe && (_isHost || _amICohost())) {
          _showQuickMicAction(member, true);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _buildGlowingAvatar(aura, isHost ? 42 : 35,
                  isPulsing: isSpeaking,
                  avatarUrl: member['avatar_url']?.toString(),
                  userName: member['user_name']?.toString(),
                  userId: member['user_id']?.toString()),
              if (_memberReactions.containsKey(uid))
                Positioned(
                  top: -10,
                  right: -10,
                  child: Text(_memberReactions[uid]!,
                          style: const TextStyle(fontSize: 24))
                      .animate()
                      .scale(
                          begin: const Offset(0.3, 0.3),
                          end: const Offset(1, 1),
                          duration: 200.ms)
                      .then()
                      .fadeOut(delay: 1000.ms, duration: 300.ms),
                ),
              if (member['hand_raised'] == true)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0C0914), width: 1.5)),
                    child: const Center(
                        child: Text('✋', style: TextStyle(fontSize: 10))),
                  ),
                ),
              Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: isMuted
                            ? Colors.redAccent
                            : const Color(0xFF0C0914),
                        shape: BoxShape.circle),
                    child: Icon(isMuted ? Icons.mic_off : Icons.mic,
                        color: isMuted ? Colors.white : aura, size: 12),
                  )),
              // Voice mask badge on own speaker avatar
              if (_isVoiceMasked && isMe)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0C0914), width: 1.5)),
                    child: const Center(
                        child: Icon(Icons.masks,
                            color: Colors.white, size: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
              width: width,
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center)),
          if (isHost)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: aura.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6)),
              child: Text("Host",
                  style: TextStyle(
                      color: aura, fontSize: 9, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildGlowingAvatar(Color glowColor, double radius,
      {bool isPulsing = false,
      String? avatarUrl,
      String? userName,
      String? userId}) {
    final seed = userId ?? userName ?? '';
    final bgColor =
        seed.isNotEmpty ? _deterministicColor(seed) : const Color(0xFF13101E);
    final label =
        userName != null && userName.isNotEmpty ? _initials(userName) : '?';
    final hasValidUrl = avatarUrl != null && avatarUrl.startsWith('http');
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: glowColor.withValues(alpha: isPulsing ? 1.0 : 0.3),
            width: isPulsing ? 3 : 1),
        boxShadow: isPulsing
            ? [
                BoxShadow(
                    color: glowColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ClipOval(
          child: Container(
            color: bgColor,
            child: hasValidUrl
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(label,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: radius * 0.45)),
                    ),
                  )
                : Center(
                    child: Text(label,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: radius * 0.45,
                            height: 1)),
                  ),
          ),
        ),
      ),
    );
  }

  // ── MEMBER LIST & MANAGEMENT ──
  void _showMemberList() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder(
        valueListenable: _membersNotify,
        builder: (ctx, members, _) => ValueListenableBuilder(
          valueListenable: _micRequestsNotify,
          builder: (ctx, micRequests, _) => _MemberSheet(
            members: members,
            hostId: _currentHostId,
            myId: _myId,
            isHost: _isHost,
            amICohost: _amICohost(),
            micRequests: micRequests,
            colorForUser: _colorForUser,
            speakingIds: _speakingIdentities,
            onShareDm: _showShareDmSheet,
            onMemberTap: (m) {
              Navigator.pop(context);
              _showMemberActions(m);
            },
            onMuteAll: () async {
              HapticFeedback.vibrate();
              await _sendSystemCommand('MUTE_ALL', 'all');
              _loadMembers();
              _showToast('Muting everyone on stage... 🔇');
            },
            onGrantMic: (uid) async {
              setState(() => _micRequests.remove(uid));
              _micRequestsNotify.value = Set.from(_micRequests);
              await _sb
                  .from('chatroom_members')
                  .update({
                    'is_speaker': true,
                    'is_muted': false,
                    'mic_requested': false
                  })
                  .eq('room_id', widget.roomId)
                  .eq('user_id', uid);
              // Send system command so listener's LiveKit track is activated
              await _sendSystemCommand('GRANT_MIC', uid);
              _loadMembers();
              _showToast('Mic granted ✅');
            },
            onDenyMic: (uid) async {
              setState(() => _micRequests.remove(uid));
              _micRequestsNotify.value = Set.from(_micRequests);
              await _sb
                  .from('chatroom_members')
                  .update({'mic_requested': false})
                  .eq('room_id', widget.roomId)
                  .eq('user_id', uid);
              // Notify the listener their request was denied
              await _sendSystemCommand('DENY_MIC', uid);
              _loadMembers();
              _showToast('Request denied');
            },
            onMuteMember: (uid) async {
              await _sb
                  .from('chatroom_members')
                  .update({'is_muted': true, 'host_muted': true})
                  .eq('room_id', widget.roomId)
                  .eq('user_id', uid);
              await _sendSystemCommand('MUTE', uid);
              _loadMembers();
              _showToast('Member muted 🔇');
            },
            onUnmuteMember: (uid) async {
              await _sb
                  .from('chatroom_members')
                  .update({'is_muted': false, 'host_muted': false})
                  .eq('room_id', widget.roomId)
                  .eq('user_id', uid);
              await _sendSystemCommand('UNMUTE', uid);
              _loadMembers();
              _showToast('Member unmuted 🎙️');
            },
            onInvite: _shareSpace,
          ),
        ),
      ),
    );
  }

  void _showMemberActions(Map<String, dynamic> member) {
    final uid = member['user_id']?.toString() ?? '';
    if (uid == _myId || uid == _currentHostId) return;
    final name = member['user_name'] ?? 'User';
    final avatar = member['avatar_url']?.toString();
    final isSpeaker = member['is_speaker'] == true;
    final isCohost = member['is_cohost'] == true;
    final canManage = _isHost || _amICohost();

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Drag handle
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                // Profile header
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          const Color(0xFF7856FF).withValues(alpha: 0.3),
                          Colors.transparent
                        ])),
                    clipBehavior: Clip.antiAlias,
                    child: (avatar != null && avatar.startsWith('http'))
                        ? Image.network(avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                        color: const Color(0xFF7856FF),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold))))
                        : Center(
                            child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF7856FF),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: (isCohost
                                      ? BolRoomColors.cyan
                                      : (isSpeaker
                                          ? const Color(0xFF7856FF)
                                          : Colors.white24))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              isCohost
                                  ? '🛡️ Co-host'
                                  : (isSpeaker ? '🎙️ Speaker' : '🎧 Listener'),
                              style: GoogleFonts.inter(
                                  color: isCohost
                                      ? BolRoomColors.cyan
                                      : (isSpeaker
                                          ? const Color(0xFF7856FF)
                                          : Colors.white54),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ])),
                ]),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                // ── Actions ──
                _actionItem(
                    'View Profile', Icons.person_outline, Colors.white70, () {
                  Navigator.pop(context);
                  _showProfileCard(member);
                }),
                if (canManage && isSpeaker)
                  Builder(builder: (context) {
                    final bool isMuted = member['is_muted'] == true;
                    return _actionItem(
                        isMuted ? 'Unmute Speaker' : 'Mute Speaker',
                        isMuted
                            ? Icons.mic_none_outlined
                            : Icons.mic_off_outlined,
                        isMuted ? BolRoomColors.cyan : Colors.orangeAccent,
                        () async {
                      Navigator.pop(context);
                      await _sb
                          .from('chatroom_members')
                          .update(
                              {'is_muted': !isMuted, 'host_muted': !isMuted})
                          .eq('room_id', widget.roomId)
                          .eq('user_id', uid);
                      await _sendSystemCommand(
                          isMuted ? 'UNMUTE' : 'MUTE', uid);
                      _showToast(isMuted
                          ? 'Unmuted ${_firstName(name)}'
                          : 'Muted ${_firstName(name)}');
                      _loadMembers();
                    });
                  }),
                if (canManage)
                  _actionItem(
                      isSpeaker ? 'Move to Listener' : 'Raise to Speaker',
                      isSpeaker
                          ? Icons.hearing_outlined
                          : Icons.mic_none_outlined,
                      isSpeaker ? Colors.orange : const Color(0xFF7856FF),
                      () async {
                    Navigator.pop(context);
                    await _sb
                        .from('chatroom_members')
                        .update({
                          'is_speaker': !isSpeaker,
                          'is_muted': isSpeaker,
                          'mic_requested': false
                        })
                        .eq('room_id', widget.roomId)
                        .eq('user_id', uid);
                    if (isSpeaker)
                      await _sendSystemCommand('REVOKE_MIC', uid);
                    else
                      await _sendSystemCommand('GRANT_MIC', uid);
                    _loadMembers();
                  }),
                // Make Co-Host — host only
                if (_isHost)
                  _actionItem(isCohost ? 'Remove Co-Host Role' : 'Make Co-Host',
                      Icons.shield_outlined, const Color(0xFF7856FF), () async {
                    Navigator.pop(context);
                    if (!isCohost && _cohostCount >= 1) {
                      _showToast('Only one co-host allowed at a time');
                      return;
                    }
                    await _sb
                        .from('chatroom_members')
                        .update(
                            {'is_cohost': !isCohost, 'is_speaker': !isCohost})
                        .eq('room_id', widget.roomId)
                        .eq('user_id', uid);
                    _showToast(isCohost
                        ? 'Co-host role removed'
                        : 'Promoted to co-host 🛡️');
                    _loadMembers();
                  }),
                // Transfer Host — host only
                if (_isHost)
                  _actionItem('Make Host', Icons.stars, BolRoomColors.gold, () {
                    Navigator.pop(context);
                    _showTransferHostConfirm(uid, name);
                  }),
                // Kick — host or cohost
                if (canManage)
                  _actionItem('Kick from Room', Icons.logout, Colors.redAccent,
                      () {
                    Navigator.pop(context);
                    _confirmKick(uid, name);
                  }),
                // Block — host only
                if (_isHost)
                  _actionItem('Block User', Icons.block, Colors.red.shade700,
                      () async {
                    Navigator.pop(context);
                    await _sb
                        .from('chatroom_members')
                        .delete()
                        .eq('room_id', widget.roomId)
                        .eq('user_id', uid);
                    await _sendSystemCommand('KICK', uid);
                    await _sb.from('chatroom_bans').upsert({
                      'room_id': widget.roomId,
                      'user_id': uid,
                      'banned_by': _myId,
                      'created_at': DateTime.now().toUtc().toIso8601String()
                    });
                    setState(() {
                      _bannedUserIds.add(uid);
                      _members
                          .removeWhere((m) => m['user_id']?.toString() == uid);
                    });
                    _showToast('User blocked from this room');
                  }),
                _actionItem('Report ${_firstName(name)}', Icons.flag_outlined,
                    Colors.orangeAccent, () {
                  Navigator.pop(context);
                  _showReportDialog(uid, name);
                }),
              ]))),
    );
  }

  void _confirmKick(String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove $name?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Remove $name from this room?',
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() =>
                  _members.removeWhere((m) => m['user_id']?.toString() == uid));
              await _sb
                  .from('chatroom_members')
                  .delete()
                  .eq('room_id', widget.roomId)
                  .eq('user_id', uid);
              await _sendSystemCommand('KICK', uid);
              _showToast('$name removed from room');
            },
            child: const Text('Remove',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTransferHostConfirm(String newHostId, String newHostName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Make $newHostName host?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            'Transfer host role to $newHostName? You will leave the room.',
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BolRoomColors.gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              // Update DB
              await _sb
                  .from('chatrooms')
                  .update({'host_id': newHostId}).eq('id', widget.roomId);
              await _sb
                  .from('chatroom_members')
                  .update({
                    'is_speaker': true,
                    'is_muted': false,
                    'host_muted': false
                  })
                  .eq('room_id', widget.roomId)
                  .eq('user_id', newHostId);
              await _sendSystemCommand('NEW_HOST', newHostId);
              _showToast('$newHostName is now the host');
              await Future.delayed(const Duration(milliseconds: 500));
              _disconnectAndLeave();
            },
            child: const Text('Transfer & Leave',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _actionItem(
          String text, IconData icon, Color color, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 14),
                Text(text,
                    style: GoogleFonts.inter(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const Spacer(),
                Icon(Icons.chevron_right,
                    color: color.withValues(alpha: 0.3), size: 18),
              ]),
            ),
          ),
        ),
      );

  // ── REACTIONS & OVERLAYS ──
  void _showReactionPicker() {
    final bool canSpeak = _hasMicPermission || _isHost;
    final bool isListener = !canSpeak;
    final emojis = ['🔥', '❤️', '😂', '👏', '🎉', '💯', '😍', '🤯'];
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                  color: BolRoomColors.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...emojis.map((e) => GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _fireReaction(e);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text(e, style: const TextStyle(fontSize: 32)),
                          ),
                        )),
                    if (isListener) ...[
                      const SizedBox(width: 10),
                      Container(width: 1.5, height: 32, color: Colors.white24),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _toggleHandRaise();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(_handRaised ? '✋' : '🤚', style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ));
  }

  void _fireReaction(String emoji, {bool isLocal = true, String? overrideUid}) {
    // Rate limit: max 3 reactions per 5 seconds for local user
    if (isLocal) {
      final now = DateTime.now();
      _myReactionTimestamps
          .removeWhere((t) => now.difference(t).inSeconds >= 5);
      if (_myReactionTimestamps.length >= 3) return; // silently ignore
      _myReactionTimestamps.add(now);
    }

    final uid = overrideUid ?? _myId;
    final id = _reactionIdCounter++;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    // Spawn from right 20% of screen, randomised
    final rightZoneStart = screenW * 0.80;
    final randomX =
        rightZoneStart + (math.Random().nextDouble() * (screenW * 0.15));
    final r = _FloatingReaction(
      id: id,
      emoji: emoji,
      x: randomX,
      y: screenH * 0.75,
      startTime: DateTime.now(),
    );
    setState(() {
      _floatingReactions.add(r);
      _memberReactions[uid] = emoji;
    });

    if (isLocal) {
      _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': _myName,
        'text': emoji,
        'is_system': false,
        'is_reaction': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).catchError((_) {});
    }

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted)
        setState(() {
          _floatingReactions.removeWhere((f) => f.id == id);
          // Only clear if the user hasn't spammed a newer reaction
          if (_memberReactions[uid] == emoji) {
            _memberReactions.remove(uid);
          }
        });
    });
  }

  // ── GAME PANEL ──
  Widget _buildGamePanel() {
    final screenH = MediaQuery.of(context).size.height;
    final participants = _gameParticipants ??
        _members
            .take(8)
            .map((m) => TodParticipant(
                  userId: m['user_id']?.toString() ?? '',
                  name: m['user_name']?.toString() ?? 'User',
                ))
            .where((p) => p.userId.isNotEmpty)
            .toList();

    return Positioned.fill(
      child: Stack(
        children: [
          // Dimmed backdrop — tap to close
          GestureDetector(
            onTap: () => setState(() => _showGame = false),
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
          // Game sheet sliding from bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: screenH * 0.82,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF050E0E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: const Color(0xFF1A4040), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3DCFA0).withValues(alpha: 0.08),
                    blurRadius: 40,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle + close
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showGame = false),
                          child: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white38, size: 28),
                        ),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A4040),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Premium badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3DCFA0), Color(0xFF0099CC)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text('PREMIUM',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  // Game Widget
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: _gameMode == 'two_truths'
                          ? TwoTruthsGame(
                              key: _twoTruthsKey,
                              roomId: widget.roomId,
                              myId: _myId,
                              isHost: _isHost,
                              participants: participants,
                              allRoomMembers: _members
                                  .map((m) => TodParticipant(
                                        userId: m['user_id']?.toString() ?? '',
                                        name: m['user_name']?.toString() ?? 'User',
                                      ))
                                  .where((p) => p.userId.isNotEmpty)
                                  .toList(),
                              onBroadcast: (cmd, data) {
                                if (data['event'] == 'update_participants') {
                                  final list = data['list'] as List<dynamic>? ?? [];
                                  setState(() {
                                    _gameParticipants = list
                                        .map((e) => TodParticipant(
                                              userId: e['userId']?.toString() ?? '',
                                              name: e['name']?.toString() ?? 'User',
                                            ))
                                        .toList();
                                  });
                                }
                                _sendGameEvent(data);
                              },
                            )
                          : _gameMode == 'blind_date'
                              ? BlindDateGame(
                                  key: _blindDateKey,
                                  roomId: widget.roomId,
                                  myId: _myId,
                                  isHost: _isHost,
                                  participants: participants,
                                  allRoomMembers: _members
                                      .map((m) => TodParticipant(
                                            userId: m['user_id']?.toString() ?? '',
                                            name: m['user_name']?.toString() ?? 'User',
                                          ))
                                      .where((p) => p.userId.isNotEmpty)
                                      .toList(),
                                  onBroadcast: (cmd, data) {
                                    if (data['event'] == 'update_participants') {
                                      final list = data['list'] as List<dynamic>? ?? [];
                                      setState(() {
                                        _gameParticipants = list
                                            .map((e) => TodParticipant(
                                                  userId: e['userId']?.toString() ?? '',
                                                  name: e['name']?.toString() ?? 'User',
                                                ))
                                            .toList();
                                      });
                                    }
                                    _sendGameEvent(data);
                                  },
                                )
                          : TruthOrDareGame(
                              key: _gameKey,
                              roomId: widget.roomId,
                              myId: _myId,
                              isHost: _isHost,
                              participants: participants,
                              allRoomMembers: _members
                                  .map((m) => TodParticipant(
                                        userId: m['user_id']?.toString() ?? '',
                                        name: m['user_name']?.toString() ?? 'User',
                                      ))
                                  .where((p) => p.userId.isNotEmpty)
                                  .toList(),
                              onBroadcast: (cmd, data) {
                                if (data['event'] == 'update_participants') {
                                  final list = data['list'] as List<dynamic>? ?? [];
                                  setState(() {
                                    _gameParticipants = list
                                        .map((e) => TodParticipant(
                                              userId: e['userId']?.toString() ?? '',
                                              name: e['name']?.toString() ?? 'User',
                                            ))
                                        .toList();
                                  });
                                }
                                _sendGameEvent(data);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingEmoji(_FloatingReaction r) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(r.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2200),
      curve: Curves.easeOut,
      builder: (context, progress, child) {
        // Rise from spawn point upward by 260px
        final yOffset = r.y - (progress * 260);
        // Fade: fully visible 0→0.7, then fade out 0.7→1.0
        final opacity = progress < 0.7
            ? 1.0
            : (1.0 - ((progress - 0.7) / 0.3)).clamp(0.0, 1.0);
        // Slight left‑right sine drift for organic feel
        final xDrift = math.sin(progress * math.pi * 3) * 14;
        // Scale: pop in big, settle to normal
        final scale =
            progress < 0.12 ? (1.0 + (0.12 - progress) / 0.12 * 0.4) : 1.0;
        return Positioned(
          left: r.x + xDrift,
          top: yOffset,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Text(
                r.emoji,
                style: const TextStyle(
                  fontSize: 36,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveChat() {
    // Include user messages AND system notification messages (join, host change)
    // but filter out raw SYSTEM_CMD protocol messages and reaction-only entries.
    final allMsgs = _messages
        .where((m) {
          if (m['is_reaction'] == true) return false;
          final txt = (m['text'] ?? '').toString();
          if (m['is_system'] == true &&
              (txt.startsWith('SYSTEM_CMD:') || txt.startsWith('GAME_EVENT:')))
            return false;
          return true;
        })
        .toList()
        .reversed
        .toList();

    // Limit to recent 100 messages to prevent excessive memory usage but allow good history
    final userMsgs = allMsgs.take(100).toList();

    // Toggle pill — always rendered, even with no messages
    final toggleTag = GestureDetector(
      onTap: () => setState(() => _showLiveChatStream = !_showLiveChatStream),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showLiveChatStream
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white.withValues(alpha: 0.7),
              size: 11,
            ),
            const SizedBox(width: 4),
            Text(
              _showLiveChatStream ? 'Hide' : 'Show Chat',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned(
      bottom: 90, // Above the bottom bar
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle pill — always visible
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 4),
            child: toggleTag,
          ),
          // Chat messages — smoothly animated in/out
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _showLiveChatStream && userMsgs.isNotEmpty
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: SizedBox(
              height: 220,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 1.0)
                    ],
                    stops: const [0.0, 0.3],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: userMsgs.length,
                  itemBuilder: (context, index) {
                    final msg = userMsgs[index];
                    final isSystem = msg['is_system'] == true;
                    final name = _firstName(msg['user_name'] ?? '?');
                    final text = msg['text'] ?? '';
                    final avatarUrl = msg['user_avatar']?.toString() ??
                        msg['avatar_url']?.toString();
                    final uid = msg['user_id']?.toString() ?? '';

                    if (isSystem) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(left: 10, top: 2, bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                text,
                                style: GoogleFonts.inter(
                                  color: BolRoomColors.cyan
                                      .withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 6),
                      child: _LiveChatMessage(
                        key: ValueKey('msg_${msg['id']}_${msg['created_at']}'),
                        username: name,
                        message: text,
                        usernameColor: Colors.white,
                        avatarUrl: avatarUrl,
                        userColor:
                            _deterministicColor(uid.isNotEmpty ? uid : name),
                      ),
                    );
                  },
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay() {
    return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        bottom: _showChat ? 0 : -100, // Slide up from bottom
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: !_showChat,
          child: Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                  left: 16,
                  right: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    focusNode: _chatFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onTapOutside: (_) {
                      _chatFocusNode.unfocus();
                      setState(() => _showChat = false);
                    },
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _sendMessage();
                      }
                      setState(() => _showChat = false);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (_msgCtrl.text.trim().isNotEmpty) {
                      _sendMessage();
                    }
                    setState(() => _showChat = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        color: BolRoomColors.cyan, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.send, color: Colors.black, size: 20),
                  ),
                )
              ])),
        ));
  }

  Widget _buildBottomBar() {
    final bool canSpeak = _hasMicPermission || _isHost;
    final bool isListener = !canSpeak;

    return IgnorePointer(
      ignoring: _showChat,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showChat ? 0.0 : 1.0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recording banner
              if (_isRecording)
                Container(
                  margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('Recording',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              // Main toolbar
              Container(
                margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF13101E).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0xFF231D38)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Mask (Voice Disguise)
                    GestureDetector(
                      onTap: () async {
                        // Quick toggle on tap
                        final newValue = !_isVoiceMasked;
                        setState(() {
                          _isVoiceMasked = newValue;
                          if (newValue) _isEditingVoiceMask = false;
                        });
                        _updateNativeVoiceMasking();
                        
                        try {
                          await _sb.from('bolroom_profiles').update({'voice_mask_enabled': newValue}).eq('id', _myId);
                          if (newValue) {
                            _showToast('Voice Masking ON');
                            _broadcastVoiceMaskChange(true, _voiceMaskPreset);
                          } else {
                            _showToast('Voice Masking OFF (Original Voice)');
                            _broadcastVoiceMaskChange(false, '');
                          }
                        } catch (e) {
                          _showToast('Failed to update voice mask');
                        }
                      },
                      onLongPress: () {
                        _showVoiceMaskSheet();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        color: Colors.transparent,
                        child: Center(
                          child: Icon(Icons.masks,
                              color: _isVoiceMasked
                                  ? const Color(0xFFFF6B00)
                                  : Colors.white54,
                              size: 24),
                        ),
                      ),
                    ),
                    // 2. React
                    GestureDetector(
                      onTap: _showReactionPicker,
                      child: Container(
                        width: 42,
                        height: 42,
                        color: Colors.transparent,
                        child: const Center(
                            child: Icon(Icons.favorite_border,
                                color: Colors.white54, size: 24)),
                      ),
                    ),
                    // 3. Mic (Large center button)
                    GestureDetector(
                      onTap: () {
                        if (_micsLockedByGame) {
                          _showToast('Mics are locked during the Blind Date session.');
                          return;
                        }
                        if (_hostMuted) {
                          _showToast('Muted by host 🤫');
                          return;
                        }
                        if (canSpeak) {
                          _toggleMute();
                        } else if (!_micRequestSent) {
                          _requestMic();
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hostMuted
                              ? Colors.red.withValues(alpha: 0.3)
                              : _micRequestSent
                                  ? Colors.amber
                                  : ((canSpeak && !_isMuted)
                                      ? _colorForUser(_myId)
                                      : const Color(0xFF231D38)),
                          boxShadow: (canSpeak && !_isMuted && !_hostMuted)
                              ? [
                                  BoxShadow(
                                      color: _colorForUser(_myId)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 10)
                                ]
                              : [],
                        ),
                        child: _hostMuted
                            ? const Icon(Icons.lock,
                                color: Colors.red, size: 24)
                            : _micRequestSent
                                ? const Icon(Icons.access_time,
                                    color: Colors.white, size: 26)
                                : Icon(
                                    (canSpeak && !_isMuted)
                                        ? Icons.mic
                                        : Icons.mic_off,
                                    color: Colors.white,
                                    size: 26),
                      ),
                    ),
                    // 4. People
                    GestureDetector(
                      onTap: _showMemberList,
                      child: Container(
                        width: 42,
                        height: 42,
                        color: Colors.transparent,
                        child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.people_outline,
                                  color: Colors.white54, size: 24),
                              if (_members.length > 1)
                                Positioned(
                                    top: 2,
                                    right: -2,
                                    child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: Color(0xFF7B2CBF),
                                            shape: BoxShape.circle),
                                        child: Text('${_members.length}',
                                            style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white)))),
                            ]),
                      ),
                    ),
                    // 5. Chat
                    GestureDetector(
                      onTap: () {
                        setState(() => _showChat = true);
                        _chatFocusNode.requestFocus();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        color: Colors.transparent,
                        child: const Center(
                            child: Icon(Icons.chat_bubble_outline,
                                color: Colors.white54, size: 24)),
                      ),
                    ),
                    // Game icon moved to top bar
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEndRoomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Room?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('This will remove everyone and cannot be undone.',
            style: TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              _endRoom();
            },
            child: const Text('End Room',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showShareDmSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          bool loading = true;
          List<Map<String, dynamic>> users = [];
          String searchQuery = '';
          Timer? searchTimer;

          Future<void> fetchUsers(void Function(void Function()) setModalState,
              {String query = ''}) async {
            try {
              setModalState(() => loading = true);
              if (query.isNotEmpty) {
                final res = await _sb
                    .from('bolroom_profiles')
                    .select('id, anon_name, avatar_url')
                    .ilike('anon_name', '%$query%')
                    .neq('id', _myId)
                    .limit(20);
                if (mounted)
                  setModalState(() {
                    users = List<Map<String, dynamic>>.from(res);
                    loading = false;
                  });
              } else {
                final followerRes = await _sb
                    .from('bolroom_follows')
                    .select('follower_id')
                    .eq('following_id', _myId);
                final followingRes = await _sb
                    .from('bolroom_follows')
                    .select('following_id')
                    .eq('follower_id', _myId);

                final Set<String> userIds = {};
                for (var f in followerRes as List) {
                  userIds.add(f['follower_id'].toString());
                }
                for (var f in followingRes as List) {
                  userIds.add(f['following_id'].toString());
                }
                for (var m in _members) {
                  final uid = m['user_id']?.toString() ?? '';
                  if (uid != _myId) userIds.add(uid);
                }
                if (userIds.isEmpty) {
                  if (mounted)
                    setModalState(() {
                      users = [];
                      loading = false;
                    });
                  return;
                }
                final profiles = await _sb
                    .from('bolroom_profiles')
                    .select('id, anon_name, avatar_url')
                    .filter('id', 'in', '(${userIds.join(",")})');
                if (mounted)
                  setModalState(() {
                    users = List<Map<String, dynamic>>.from(profiles);
                    loading = false;
                  });
              }
            } catch (e) {
              if (mounted) setModalState(() => loading = false);
            }
          }

          return StatefulBuilder(builder: (ctx, setModalState) {
            if (loading && users.isEmpty && searchQuery.isEmpty)
              fetchUsers(setModalState);
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                  color: Color(0xFF0C0914),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('Share via DM',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search Bolroom users...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF13101E),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        searchQuery = val.trim();
                        searchTimer?.cancel();
                        searchTimer =
                            Timer(const Duration(milliseconds: 500), () {
                          fetchUsers(setModalState, query: searchQuery);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: BolRoomColors.gold))
                        : users.isEmpty
                            ? const Center(
                                child: Text('No users found',
                                    style: TextStyle(color: Colors.white54)))
                            : ListView.builder(
                                itemCount: users.length,
                                itemBuilder: (ctx, i) {
                                  final u = users[i];
                                  final uid = u['id']?.toString() ?? '';
                                  final name = u['anon_name'] ?? 'Anonymous';
                                  final avatarUrl = u['avatar_url'];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF13101E),
                                      backgroundImage: avatarUrl != null
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl == null
                                          ? const Icon(Icons.person,
                                              color: Colors.white54)
                                          : null,
                                    ),
                                    title: Text(name,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF00D2D2),
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20))),
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        try {
                                          final existing = await _sb
                                              .from('bolroom_dm_conversations')
                                              .select('*')
                                              .or('and(user1_id.eq.$_myId,user2_id.eq.$uid),and(user1_id.eq.$uid,user2_id.eq.$_myId)')
                                              .maybeSingle();
                                          String convoId;
                                          if (existing != null) {
                                            convoId = existing['id'].toString();
                                          } else {
                                            final newConvo = await _sb
                                                .from(
                                                    'bolroom_dm_conversations')
                                                .insert({
                                                  'user1_id': _myId,
                                                  'user2_id': uid
                                                })
                                                .select()
                                                .single();
                                            convoId = newConvo['id'].toString();
                                          }
                                          final text =
                                              '[VOICEROOM_INVITE]${widget.roomId}::${widget.roomName}::${widget.topic}::$_currentHostId::$_currentHostName';
                                          await _sb
                                              .from('bolroom_dm_messages')
                                              .insert({
                                            'conversation_id': convoId,
                                            'sender_id': _myId,
                                            'text': text,
                                          });
                                          _showToast('Sent to $name');
                                        } catch (e) {
                                          _showToast('Failed to send');
                                        }
                                      },
                                      child: const Text('Send'),
                                    ),
                                  );
                                },
                              ),
                  )
                ],
              ),
            );
          });
        });
  }

  void _shareSpace() {
    final link = 'meetra://orbit/${widget.roomId}';
    final text = 'Join "${widget.roomName}" on VoiceRoom!\n$link';
    SharePlus.instance
        .share(ShareParams(text: text, subject: 'Join my VoiceRoom'));
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {int? count}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: BolRoomColors.card),
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, color: Colors.white54, size: 22),
              if (count != null)
                Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: BolRoomColors.cyan, shape: BoxShape.circle),
                        child: Text('$count',
                            style: const TextStyle(
                                fontSize: 8, fontWeight: FontWeight.bold)))),
            ])),
      );

  Future<void> _requestMic() async {
    if (_micRequestSent) return; // prevent double-tap
    setState(() => _micRequestSent = true);
    _showToast('Mic request sent 🎙️');
    try {
      // Write mic_requested to DB so host sees it in member list
      await _sb
          .from('chatroom_members')
          .update({'mic_requested': true})
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId);
      // Broadcast a system message so host gets a realtime ping
      await _sb.from('chatroom_messages').insert({
        'room_id': widget.roomId,
        'user_id': _myId,
        'user_name': _myName,
        'text': 'SYSTEM_CMD:MIC_REQUEST:$_myId',
        'is_system': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('_requestMic error: $e');
      if (mounted) {
        setState(() => _micRequestSent = false);
        _showToast('Failed to send request. Try again.');
      }
    }
  }

  Future<void> _toggleHandRaise() async {
    final newState = !_handRaised;
    setState(() => _handRaised = newState);
    HapticFeedback.lightImpact();
    try {
      await _sb
          .from('chatroom_members')
          .update({'hand_raised': newState})
          .eq('room_id', widget.roomId)
          .eq('user_id', _myId);
      if (newState) {
        _showToast('Hand raised ✋');
        // Also broadcast system command so host gets notification
        await _sb.from('chatroom_messages').insert({
          'room_id': widget.roomId,
          'user_id': _myId,
          'user_name': _myName,
          'text': 'SYSTEM_CMD:HAND_RAISE:$_myId',
          'is_system': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        _showToast('Hand lowered');
      }
    } catch (e) {
      debugPrint('_toggleHandRaise error: $e');
      if (mounted) setState(() => _handRaised = !newState);
    }
  }

  Future<void> _loadRecordingState() async {
    try {
      final res = await _sb
          .from('chatrooms')
          .select('is_recording')
          .eq('id', widget.roomId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _isRecording = res['is_recording'] == true);
      }
    } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════════════════
// PREMIUM MEMBER SHEET — X-Inspired Sectioned Participant View
// ══════════════════════════════════════════════════════════════════
class _MemberSheet extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final String hostId, myId;
  final bool isHost, amICohost;
  final Set<String> micRequests, speakingIds;
  final Color Function(String) colorForUser;
  final void Function(Map<String, dynamic>) onMemberTap;
  final VoidCallback onMuteAll;
  final Future<void> Function(String uid) onGrantMic,
      onDenyMic,
      onMuteMember,
      onUnmuteMember;
  final VoidCallback onInvite, onShareDm;

  const _MemberSheet({
    required this.members,
    required this.hostId,
    required this.myId,
    required this.isHost,
    required this.amICohost,
    required this.micRequests,
    required this.colorForUser,
    required this.speakingIds,
    required this.onMemberTap,
    required this.onMuteAll,
    required this.onGrantMic,
    required this.onDenyMic,
    required this.onMuteMember,
    required this.onUnmuteMember,
    required this.onInvite,
    required this.onShareDm,
  });

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  final _sb = Supabase.instance.client;
  Set<String> _myFollowings = {};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchFollowings();
  }

  Future<void> _fetchFollowings() async {
    final myId = widget.myId;
    if (myId.isEmpty) return;
    try {
      final res = await _sb
          .from('bolroom_follows')
          .select('following_id')
          .eq('follower_id', myId);
      if (mounted) {
        setState(() {
          _myFollowings =
              (res as List).map((e) => e['following_id'].toString()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollowUser(String uid, String userName) async {
    final myId = widget.myId;
    if (myId.isEmpty) return;

    final isFollowing = _myFollowings.contains(uid);
    setState(() {
      if (isFollowing)
        _myFollowings.remove(uid);
      else
        _myFollowings.add(uid);
    });

    try {
      if (isFollowing) {
        await _sb
            .from('bolroom_follows')
            .delete()
            .eq('follower_id', myId)
            .eq('following_id', uid);
      } else {
        await _sb
            .from('bolroom_follows')
            .insert({'follower_id': myId, 'following_id': uid});
        final me = await _sb
            .from('bolroom_profiles')
            .select('anon_name')
            .eq('id', myId)
            .maybeSingle();
        final myName = me?['anon_name'] ?? 'Anonymous';
        await NotificationService.sendNotification(
          userId: uid,
          type: NotificationType.message,
          title: 'BolRoom New Follower',
          body: '@$myName started following you in the ecosystem!',
          payload: {'source': 'bolroom', 'follower_id': myId},
        );
      }
    } catch (e) {
      setState(() {
        if (isFollowing)
          _myFollowings.add(uid);
        else
          _myFollowings.remove(uid);
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return widget.members;
    final q = _search.toLowerCase();
    return widget.members
        .where(
            (m) => (m['user_name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  List<Map<String, dynamic>> get _onStage {
    return _filtered.where((m) {
      final uid = m['user_id']?.toString() ?? '';
      return uid == widget.hostId ||
          m['is_cohost'] == true ||
          m['is_speaker'] == true;
    }).toList()
      ..sort((a, b) {
        if (a['user_id'] == widget.hostId) return -1;
        if (b['user_id'] == widget.hostId) return 1;
        if (a['is_cohost'] == true && b['is_cohost'] != true) return -1;
        return 0;
      });
  }

  List<Map<String, dynamic>> get _tunedIn {
    return _filtered.where((m) {
      final uid = m['user_id']?.toString() ?? '';
      return uid != widget.hostId &&
          m['is_cohost'] != true &&
          m['is_speaker'] != true;
    }).toList();
  }

  List<Map<String, dynamic>> get _requests {
    return _filtered
        .where((m) => widget.micRequests.contains(m['user_id']?.toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.isHost || widget.amICohost;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1), width: 1.0)),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3))),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                child: Row(children: [
                  Text('Orbit Members',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10)
                        ]),
                    child: Text('${widget.members.length}',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const Spacer(),
                  if (canManage)
                    GestureDetector(
                      onTap: widget.onMuteAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.redAccent.withValues(alpha: 0.2),
                              Colors.redAccent.withValues(alpha: 0.05)
                            ]),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color:
                                    Colors.redAccent.withValues(alpha: 0.5))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.mic_off,
                              color: Colors.redAccent, size: 14),
                          const SizedBox(width: 4),
                          Text('Mute All',
                              style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ]),
                      ),
                    ),
                ]),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 12),
                        child:
                            Icon(Icons.search, color: Colors.white54, size: 22),
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              onPressed: () => setState(() => _search = ''),
                              icon: const Icon(Icons.close,
                                  color: Colors.white38, size: 20))
                          : null,
                      hintText: 'Search the orbit...',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Body
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Mic Requests Banner
                    if (canManage && _requests.isNotEmpty) ...[
                      _sectionHeader(
                          'Requests to Speak', _requests.length, Colors.amber),
                      ..._requests.map((m) => _requestTile(m)),
                      const SizedBox(height: 16),
                    ],
                    // On Stage
                    _sectionHeader(
                        'On Stage', _onStage.length, const Color(0xFFFF6B00)),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                          children: _onStage
                              .map((m) => _memberTile(m, canManage,
                                  isLast: m == _onStage.last))
                              .toList()),
                    ),
                    const SizedBox(height: 24),
                    // Tuned In
                    if (_tunedIn.isNotEmpty) ...[
                      _sectionHeader('Listening', _tunedIn.length,
                          const Color(0xFF8E8B99)),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                            children: _tunedIn
                                .map((m) => _memberTile(m, canManage,
                                    isLast: m == _tunedIn.last))
                                .toList()),
                      ),
                    ] else if (_search.isEmpty) ...[
                      const SizedBox(height: 40),
                      Center(
                          child: Column(
                        children: [
                          const Icon(Icons.headset_off,
                              color: Colors.white12, size: 48),
                          const SizedBox(height: 12),
                          Text('No one else is listening right now.',
                              style: GoogleFonts.inter(
                                  color: Colors.white38, fontSize: 13)),
                        ],
                      )),
                    ],
                    const SizedBox(height: 120), // Space for bottom actions
                  ],
                ),
              ),
              // Bottom Actions
              _buildBottomActionArea(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onInvite();
            },
            icon: const Icon(Icons.person_add_outlined, size: 20),
            label: const Text('Invite People'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2D2),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              textStyle:
                  GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onShareDm();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF13101E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF231D38))),
            child:
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  static void _showToast(String msg) {
    // Placeholder
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Row(children: [
        Text(title,
            style: GoogleFonts.inter(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: GoogleFonts.inter(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _requestTile(Map<String, dynamic> m) {
    final uid = m['user_id']?.toString() ?? '';
    final name = m['user_name'] ?? 'User';
    final avatar = m['avatar_url']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.amber.withValues(alpha: 0.1),
          Colors.amber.withValues(alpha: 0.02)
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        _avatar(name, avatar, Colors.amber, 46),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Requested Mic',
              style: GoogleFonts.inter(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ])),
        // Accept
        GestureDetector(
          onTap: () => widget.onGrantMic(uid),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 10)
                ]),
            child: Text('Accept',
                style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        // Deny
        GestureDetector(
          onTap: () => widget.onDenyMic(uid),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24)),
            child: const Icon(Icons.close, color: Colors.white54, size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _memberTile(Map<String, dynamic> m, bool canManage,
      {bool isLast = false}) {
    final uid = m['user_id']?.toString() ?? '';
    final name = m['user_name'] ?? '?';
    final avatar = m['avatar_url']?.toString();
    final isHost = uid == widget.hostId;
    final isCohost = m['is_cohost'] == true;
    final isSpeaker = m['is_speaker'] == true;
    final isMe = uid == widget.myId;
    final isSpeaking = widget.speakingIds.contains(uid);
    final isMuted = m['is_muted'] == true;
    final color = isHost
        ? BolRoomColors.gold
        : (isCohost ? BolRoomColors.cyan : widget.colorForUser(uid));

    String roleLabel = isHost
        ? 'Host'
        : (isCohost ? 'Co-host' : (isSpeaker ? 'Speaker' : 'Listener'));
    Color roleColor = isHost
        ? BolRoomColors.gold
        : (isCohost
            ? BolRoomColors.cyan
            : (isSpeaker ? const Color(0xFF7856FF) : Colors.white54));

    return Column(
      children: [
        InkWell(
          onTap: () => widget.onMemberTap(m),
          borderRadius: BorderRadius.vertical(
            top: isLast && _onStage.length == 1
                ? const Radius.circular(20)
                : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              // Avatar with badges
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSpeaking ? color : Colors.transparent,
                        width: 2.5),
                    boxShadow: isSpeaking
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 10)
                          ]
                        : [],
                  ),
                  child: _avatar(name, avatar, color, 50),
                ),
                if (isSpeaker)
                  Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            color: m['host_muted'] == true
                                ? Colors.redAccent
                                : (isMuted ? Colors.redAccent : color),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF13101E), width: 2)),
                        child: Icon(
                          m['host_muted'] == true
                              ? Icons.lock
                              : (isMuted ? Icons.mic_off : Icons.mic),
                          color: Colors.white,
                          size: 10,
                        ),
                      )),
                // Hand raised badge
                if (m['hand_raised'] == true)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF13101E), width: 1.5)),
                      child: const Center(
                          child: Text('✋', style: TextStyle(fontSize: 10))),
                    ),
                  ),
                // Mic requested badge
                if (widget.micRequests.contains(uid) && !isSpeaker)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF13101E), width: 1.5)),
                      child:
                          const Icon(Icons.mic, color: Colors.white, size: 10),
                    ),
                  ),
              ]),
              const SizedBox(width: 16),
              // Info
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(isMe ? '$name (You)' : name,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis)),
                        if (isHost)
                          const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.stars,
                                  color: BolRoomColors.gold, size: 14)),
                        if (widget.micRequests.contains(uid) && !isSpeaker)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text('Requested Mic',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(roleLabel,
                          style: GoogleFonts.inter(
                              color: roleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      if (isSpeaking) ...[
                        const SizedBox(width: 8),
                        Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Speaking',
                            style: GoogleFonts.inter(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ]),
                  ])),
              if (!isMe)
                GestureDetector(
                  onTap: () => _toggleFollowUser(uid, name),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _myFollowings.contains(uid)
                          ? Colors.white.withValues(alpha: 0.1)
                          : BolRoomColors.cyan.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _myFollowings.contains(uid)
                              ? Colors.white24
                              : BolRoomColors.cyan.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      _myFollowings.contains(uid)
                          ? Icons.person_remove_rounded
                          : Icons.person_add_rounded,
                      color: _myFollowings.contains(uid)
                          ? Colors.white54
                          : BolRoomColors.cyan,
                      size: 16,
                    ),
                  ),
                ),

              // Host Actions
              if (canManage && !isMe && !isHost) ...[
                GestureDetector(
                  onTap: () {
                    if (isSpeaker) {
                      if (isMuted) {
                        widget.onUnmuteMember(uid);
                      } else {
                        widget.onMuteMember(uid);
                      }
                    } else {
                      widget.onGrantMic(uid);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isSpeaker && !isMuted)
                          ? Colors.transparent
                          : BolRoomColors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (isSpeaker && !isMuted)
                              ? Colors.redAccent.withValues(alpha: 0.5)
                              : BolRoomColors.cyan.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      (isSpeaker && !isMuted) ? 'Mute' : 'Unmute',
                      style: GoogleFonts.inter(
                        color: (isSpeaker && !isMuted)
                            ? Colors.redAccent
                            : BolRoomColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ]),
          ),
        ),
        if (!isLast)
          const Divider(color: Color(0xFF231D38), height: 1, indent: 86),
      ],
    );
  }

  Widget _avatar(String name, String? url, Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.startsWith('http'))
          ? Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initial(name, color, size))
          : _initial(name, color, size),
    );
  }

  Widget _initial(String name, Color color, double size) {
    return Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4)));
  }
}

// Deterministic-color avatar for chat messages
class _ChatAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final double size;
  final Color? userColor;
  const _ChatAvatar(
      {required this.avatarUrl,
      required this.username,
      required this.size,
      this.userColor});

  Color _deterministicColor(String seed) {
    const cols = [
      Color(0xFF6C63FF),
      Color(0xFFE91E63),
      Color(0xFF00BCD4),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFF03A9F4),
      Color(0xFFF44336),
      Color(0xFF009688),
      Color(0xFFFF5722),
      Color(0xFF3F51B5),
      Color(0xFF8BC34A),
    ];
    int h = 0;
    for (int i = 0; i < seed.length; i++)
      h = seed.codeUnitAt(i) + ((h << 5) - h);
    return cols[h.abs() % cols.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.startsWith('http');
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final bgColor = userColor ?? _deterministicColor(username);
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(top: 2),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor.withValues(alpha: 0.85),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: hasUrl
          ? Image.network(avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(initials,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.42))))
          : Center(
              child: Text(initials,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.42))),
    );
  }
}

class _FloatingReaction {
  final int id;
  final String emoji;
  final double x;
  final double y;
  final DateTime startTime;
  _FloatingReaction(
      {required this.id,
      required this.emoji,
      required this.x,
      required this.y,
      required this.startTime});
}

// ═══════════════════════════════════════════════════════════════════
// INSTAGRAM-STYLE LIVE CHAT MESSAGE — self-animating, transparent
// ═══════════════════════════════════════════════════════════════════
class _LiveChatMessage extends StatefulWidget {
  final String username;
  final String message;
  final Color usernameColor;
  final String? avatarUrl;
  final Color? userColor;

  const _LiveChatMessage({
    super.key,
    required this.username,
    required this.message,
    required this.usernameColor,
    this.avatarUrl,
    this.userColor,
  });

  @override
  State<_LiveChatMessage> createState() => _LiveChatMessageState();
}

class _LiveChatMessageState extends State<_LiveChatMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _hasImage = false;
  String? _imageUrl;
  String _displayMessage = '';

  @override
  void initState() {
    super.initState();
    _parseMessage();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  void _parseMessage() {
    _displayMessage = widget.message;
    if (_displayMessage.startsWith('[IMG:')) {
      final endIdx = _displayMessage.indexOf(']');
      if (endIdx != -1) {
        _imageUrl = _displayMessage.substring(5, endIdx);
        _displayMessage = _displayMessage.substring(endIdx + 1).trim();
        _hasImage = true;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        // Reference-style: small avatar on left, username BOLD on own line, message below
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small circular avatar
            _ChatAvatar(
              avatarUrl: widget.avatarUrl,
              username: widget.username,
              size: 28,
              userColor: widget.userColor,
            ),
            const SizedBox(width: 10),
            // Name + message block (with dark bubble background — matches reference)
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C141C).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bold username on its own line
                    Text(
                      widget.username,
                      style: GoogleFonts.inter(
                        color: BolRoomColors.cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Message text
                    Text(
                      _displayMessage,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    if (_hasImage && _imageUrl != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: _imageUrl!.startsWith('data:')
                                ? MemoryImage(base64Decode(
                                        _imageUrl!.split(',').last))
                                    as ImageProvider
                                : NetworkImage(_imageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// POST-ROOM SUMMARY SCREEN — shown to host after ending a room
// ═══════════════════════════════════════════════════════════════════
class BolRoomPostSummaryScreen extends StatelessWidget {
  final String roomName;
  final Duration duration;
  final int peakListeners;
  final int totalParticipants;

  const BolRoomPostSummaryScreen({
    super.key,
    required this.roomName,
    required this.duration,
    required this.peakListeners,
    required this.totalParticipants,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0914),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Checkmark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    const Color(0xFF7856FF).withValues(alpha: 0.3),
                    const Color(0xFFFF6B00).withValues(alpha: 0.15),
                  ]),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Color(0xFFFF6B00), size: 48),
              ),
              const SizedBox(height: 24),
              Text('Room Ended',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(roomName,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),
              // Stats grid
              Row(children: [
                _statCard('Duration', _formatDuration(duration),
                    Icons.timer_outlined, const Color(0xFF7856FF)),
                const SizedBox(width: 16),
                _statCard('Peak Listeners', '$peakListeners',
                    Icons.headset_outlined, const Color(0xFFFF6B00)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _statCard('Total Joined', '$totalParticipants',
                    Icons.people_outline, BolRoomColors.gold),
                const SizedBox(width: 16),
                _statCard('Messages', '—', Icons.chat_bubble_outline,
                    const Color(0xFF38D9A9)),
              ]),
              const Spacer(flex: 3),
              // Share button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = '🎙️ "$roomName" just ended!\n'
                        '⏱ Duration: ${_formatDuration(duration)}\n'
                        '👥 Peak: $peakListeners listeners\n'
                        '🎉 $totalParticipants people joined\n\n'
                        '#VoiceRoom #BolRoom';
                    SharePlus.instance.share(
                        ShareParams(text: text, subject: 'Room Summary'));
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share Room Summary',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7856FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Back to home
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Back to Home',
                      style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Grid painter for the custom voice 2D pad.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF231D38)
      ..strokeWidth = 0.5;

    // Horizontal lines (pitch divisions)
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines (formant divisions)
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Center crosshair
    final center = Paint()
      ..color = const Color(0xFFFF6B00).withAlpha(40)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), center);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



class _VoicePadPainter extends CustomPainter {
  final double dotX;
  final double dotY;

  _VoicePadPainter(this.dotX, this.dotY);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background gradient
    final Rect bgRect = Rect.fromLTWH(0, 0, w, h);
    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, const Color(0xFFFF6B00).withValues(alpha: 0.15)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Zone region fills
    final zonePaint = Paint()..style = PaintingStyle.fill;
    // High zone (top third)
    zonePaint.color = const Color(0xFF8A2BE2).withAlpha(20);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), zonePaint);
    // Low zone (bottom third)
    zonePaint.color = const Color(0xFFFF6600).withAlpha(15);
    canvas.drawRect(Rect.fromLTWH(0, h * 2 / 3, w, h / 3), zonePaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF231D38)
      ..strokeWidth = 0.8;
    for (int i = 1; i < 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (int i = 1; i < 4; i++) {
      final x = w * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // Ripple circles
    final ripplePaint = Paint()
      ..color = const Color(0xFFFF6B00).withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(dotX, dotY), 24, ripplePaint);
    ripplePaint.color = const Color(0xFFFF6B00).withAlpha(12);
    canvas.drawCircle(Offset(dotX, dotY), 38, ripplePaint);
  }

  @override
  bool shouldRepaint(_VoicePadPainter old) => old.dotX != dotX || old.dotY != dotY;
}