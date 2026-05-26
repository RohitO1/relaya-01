// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'companion_service.dart';

/// Video Room Screen — Section 5 of the spec.
/// Implements: LOCKED/OPEN/ACTIVE states, session timer, PiP layout,
/// in-session chat, extend/end, report, reconnect logic (EC-09 to EC-17).
class CompanionVideoRoomScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> videoRoom;
  final bool isCompanion; // true if current user is the companion

  const CompanionVideoRoomScreen({
    super.key,
    required this.booking,
    required this.videoRoom,
    required this.isCompanion,
  });

  @override
  State<CompanionVideoRoomScreen> createState() => _CompanionVideoRoomScreenState();
}

class _CompanionVideoRoomScreenState extends State<CompanionVideoRoomScreen> with WidgetsBindingObserver {
  // ── Timer state ──
  late DateTime _scheduledStart;
  late DateTime _scheduledEnd;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  Duration _remaining = Duration.zero;
  bool _sessionStarted = false;
  bool _sessionEnded = false;

  // ── Controls ──
  bool _micMuted = false;
  bool _cameraOff = false;
  bool _chatOpen = false;
  bool _frontCamera = true;

  // ── Connection / no-show ──
  bool _otherPartyJoined = false;
  bool _reconnecting = false;
  int _reconnectSecondsLeft = 60;
  Timer? _reconnectTimer;
  bool _showNoShowOption = false;

  // ── Extension ──
  bool _extensionRequested = false;

  // ── Chat ──
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  // ── Screen recording detection (EC-17) ──
  bool _screenRecordingDetected = false;

  String get _otherName => widget.isCompanion
      ? (widget.booking['booker_name'] ?? 'Booker')
      : (widget.booking['companion_name'] ?? 'Companion');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduledStart = DateTime.parse(widget.booking['scheduled_start_utc']).toLocal();
    _scheduledEnd = DateTime.parse(widget.booking['scheduled_end_utc']).toLocal();
    _startTicker();
    // Simulate T+5 no-show check
    Future.delayed(const Duration(minutes: 5), _checkNoShow);
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _remaining = _scheduledEnd.difference(now);
        if (now.isAfter(_scheduledStart)) {
          _sessionStarted = true;
          _elapsed = now.difference(_scheduledStart);
        }
        if (now.isAfter(_scheduledEnd)) {
          _sessionEnded = true;
        }
        // EC-17: Screen recording detection (platform-specific, stubbed)
        // In production, listen to platform channel for screen capture events
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // EC-14: Phone call / background → triggers disconnect flow
    if (state == AppLifecycleState.paused && _sessionStarted && !_sessionEnded) {
      _triggerDisconnect();
    } else if (state == AppLifecycleState.resumed) {
      _cancelReconnectIfNeeded();
    }
  }

  void _triggerDisconnect() {
    // EC-13, EC-16: App crash / battery → 60-second reconnect window
    if (!mounted) return;
    setState(() => _reconnecting = true);
    _reconnectSecondsLeft = 60;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _reconnectSecondsLeft--);
      if (_reconnectSecondsLeft <= 0) {
        t.cancel();
        _handleReconnectExpired();
      }
      // EC-32: Show "15 seconds left" warning
      if (_reconnectSecondsLeft == 15) {
        _showInAppBanner('Reconnect window closes in 15 seconds!');
      }
    });
  }

  void _cancelReconnectIfNeeded() {
    if (_reconnecting) {
      _reconnectTimer?.cancel();
      setState(() => _reconnecting = false);
    }
  }

  void _handleReconnectExpired() {
    // Session flagged as interrupted (EC-13)
    setState(() => _reconnecting = false);
    _showInAppBanner('Session interrupted. Reconnect attempts exhausted.');
    _updateRoomStatus('INTERRUPTED');
  }

  void _checkNoShow() {
    // N-11: T+15 no-show window (simplified — in production checks real join status)
    if (!_otherPartyJoined && _sessionStarted && !_sessionEnded) {
      if (mounted) setState(() => _showNoShowOption = true);
    }
  }

  Future<void> _markNoShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Mark as No-Show?', style: TextStyle(color: Colors.white)),
        content: Text('$_otherName has not joined. This will be recorded as a no-show.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Wait Longer')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Mark No-Show'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final status = widget.isCompanion ? 'NO_SHOW_BOOKER' : 'NO_SHOW_COMPANION';
      await _sb.from('companion_bookings').update({'status': status}).eq('id', widget.booking['id']);
      if (mounted) Navigator.pop(context);
    }
  }

  dynamic get _sb => throw UnimplementedError('Use CompanionService._sb in production');

  Future<void> _updateRoomStatus(String status) async {
    // Update video_room status in DB
    await CompanionService.getVideoRoom(widget.booking['id']); // read current
    // In production: _sb.from('companion_video_rooms').update({'status': status})
  }

  void _showInAppBanner(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF1A1A2E),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to end the session?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) Navigator.pop(context);
  }

  Future<void> _requestExtension() async {
    if (_extensionRequested) {
      _showInAppBanner('Extension already requested once');
      return;
    }
    if (!widget.isCompanion) {
      // Booker requests extension — companion must accept
      setState(() => _extensionRequested = true);
      _showInAppBanner('Extension request sent to companion');
      // In production: write to DB and listen via realtime
    } else {
      // Companion sees extension request — choose duration
      final minutes = await showDialog<int>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Extension Requested', style: TextStyle(color: Colors.white)),
          content: const Text('Booker wants to extend. Choose duration:', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 15), child: const Text('+15 min')),
            TextButton(onPressed: () => Navigator.pop(context, 30), child: const Text('+30 min')),
            TextButton(onPressed: () => Navigator.pop(context, 60), child: const Text('+60 min')),
            TextButton(onPressed: () => Navigator.pop(context, -1), child: const Text('Decline', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (minutes != null && minutes > 0) {
        setState(() { _scheduledEnd = _scheduledEnd.add(Duration(minutes: minutes)); });
        _showInAppBanner('Session extended by $minutes minutes');
      } else {
        _showInAppBanner('Extension declined');
      }
    }
  }

  Future<void> _reportSession() async {
    final reasons = ['Inappropriate behaviour', 'Not the person in profile', 'Harassment', 'Other'];
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Report Session', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: reasons.map((r) => ListTile(
          title: Text(r, style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(context, r),
        )).toList()),
      ),
    );
    if (selected != null) {
      // EC: report does NOT end session
      await CompanionService.fileSafetyReport(
        bookingId: widget.booking['id'],
        reportedUserId: widget.isCompanion ? widget.booking['booker_id'] : widget.booking['companion_user_id'] ?? '',
        reportType: 'IN_SESSION_REPORT',
        reason: selected,
      );
      _showInAppBanner('Report submitted. Session continues.');
    }
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatMessages.add({'sender': 'You', 'text': text, 'time': TimeOfDay.now().format(context)});
    });
    _chatCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
    });
    // In production: write to companion_video_room_chat table (encrypted)
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatDuration(_elapsed);
    final endTimeStr = '${_scheduledEnd.hour.toString().padLeft(2, '0')}:${_scheduledEnd.minute.toString().padLeft(2, '0')}';

    // Session color based on time remaining (Section 5.3 SESSION TIMER)
    Color timerColor = Colors.white;
    if (_sessionStarted && _remaining.inMinutes <= 2) {
      timerColor = Colors.red;
    } else if (_sessionStarted && _remaining.inMinutes <= 5) {
      timerColor = Colors.amber;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── EC-09: LOCKED state — countdown before session ──
          if (!_sessionStarted)
            _buildWaitingRoom()
          else
            _buildActiveRoom(timeStr, endTimeStr, timerColor),

          // ── Reconnecting overlay (EC-13) ──
          if (_reconnecting)
            _buildReconnectingOverlay(),

          // ── Time's Up overlay (Section 5.3) ──
          if (_sessionEnded)
            _buildTimesUpOverlay(),

          // ── Screen recording detected overlay (EC-17) ──
          if (_screenRecordingDetected)
            _buildScreenRecordOverlay(),

          // ── No-show option (N-11) ──
          if (_showNoShowOption && !_otherPartyJoined)
            Positioned(
              bottom: 120, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text('$_otherName has not joined yet.', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    ElevatedButton(onPressed: () => setState(() => _showNoShowOption = false), style: ElevatedButton.styleFrom(backgroundColor: Colors.white), child: const Text('Wait Longer', style: TextStyle(color: Colors.black))),
                    ElevatedButton(onPressed: _markNoShow, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Mark No-Show', style: TextStyle(color: Colors.white))),
                  ]),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── EC-09: Locked waiting room ──
  Widget _buildWaitingRoom() {
    final until = _scheduledStart.difference(DateTime.now());
    final mm = until.inMinutes.toString().padLeft(2, '0');
    final ss = (until.inSeconds % 60).toString().padLeft(2, '0');
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_clock, color: Colors.white54, size: 64),
        const SizedBox(height: 20),
        Text('Session starts in', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
        const SizedBox(height: 8),
        Text('$mm:$ss', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(height: 16),
        Text('Session with $_otherName', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        const Text('Camera and mic are off until session starts.', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }

  // ── Active room with PiP layout ──
  Widget _buildActiveRoom(String timeStr, String endTimeStr, Color timerColor) {
    return Column(
      children: [
        // ── Top bar ──
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black.withValues(alpha: 0.6),
            child: Row(children: [
              Text(_otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const Spacer(),
              Text(timeStr, style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Text('Ends $endTimeStr', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ),

        // ── Remote video (large) ──
        Expanded(
          child: Stack(
            children: [
              Container(
                color: const Color(0xFF15151A),
                child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white12)),
              ),

              // ── PiP local video (draggable) (Section 5.2) ──
              Positioned(
                right: 16, bottom: 16,
                child: GestureDetector(
                  onPanUpdate: (d) {/* Draggable PiP — handle position update */},
                  child: Container(
                    width: 100, height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _cameraOff
                        ? const Center(child: Icon(Icons.videocam_off, color: Colors.white38))
                        : const Center(child: Icon(Icons.person, color: Colors.white38)),
                  ),
                ),
              ),

              // ── T-5min warning overlay ──
              if (_sessionStarted && _remaining.inMinutes <= 5 && !_sessionEnded)
                Positioned(
                  top: 10, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_remaining.inMinutes <= 2 ? Colors.red : Colors.amber).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _remaining.inMinutes <= 2 ? '⚠ Session ends in ${_remaining.inSeconds}s' : '⚠ Session ends in ${_remaining.inMinutes} min',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── In-session chat panel ──
        if (_chatOpen) _buildChatPanel(),

        // ── Control bar (Section 5.2) ──
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlBtn(_micMuted ? Icons.mic_off : Icons.mic, _micMuted ? Colors.red : Colors.white, 'Mute', () => setState(() => _micMuted = !_micMuted)),
              _controlBtn(_cameraOff ? Icons.videocam_off : Icons.videocam, _cameraOff ? Colors.red : Colors.white, 'Camera', () => setState(() => _cameraOff = !_cameraOff)),
              _controlBtn(Icons.flip_camera_ios, Colors.white, 'Flip', () => setState(() => _frontCamera = !_frontCamera)),
              _controlBtn(Icons.chat_bubble_outline, _chatOpen ? const Color(0xFFFF7E40) : Colors.white, 'Chat', () => setState(() => _chatOpen = !_chatOpen)),
              _controlBtn(Icons.timer, Colors.amber, 'Extend', _requestExtension),
              _controlBtn(Icons.warning_amber_outlined, Colors.orange, 'Report', _reportSession),
              _controlBtn(Icons.call_end, Colors.red, 'End', _endSession),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controlBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ]),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      height: 220,
      color: const Color(0xFF0D0D18),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScroll,
              padding: const EdgeInsets.all(8),
              itemCount: _chatMessages.length,
              itemBuilder: (_, i) {
                final m = _chatMessages[i];
                final isMe = m['sender'] == 'You';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFFF7E40) : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(m['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(child: TextField(
                controller: _chatCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white30),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendChat(),
              )),
              IconButton(icon: const Icon(Icons.send, color: Color(0xFFFF7E40)), onPressed: _sendChat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReconnectingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: Color(0xFFFF7E40)),
          const SizedBox(height: 20),
          const Text('Reconnecting...', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$_reconnectSecondsLeft seconds remaining', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          TextButton(onPressed: () { _reconnectTimer?.cancel(); Navigator.pop(context); }, child: const Text('Leave Session', style: TextStyle(color: Colors.red))),
        ]),
      ),
    );
  }

  Widget _buildTimesUpOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.timer_off, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text("Time's Up!", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Session has ended.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(
              onPressed: _requestExtension,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7E40)),
              child: const Text('Extend Session'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('End Session'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildScreenRecordOverlay() {
    return Positioned(
      top: 60, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.screen_lock_portrait, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text('Screen recording detected. Video paused.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _reconnectTimer?.cancel();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
