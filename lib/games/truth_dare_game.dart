// ignore_for_file: use_build_context_synchronously
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _GC {
  static const bg      = Color(0xFF04080F);
  static const surface = Color(0xFF0B1422);
  static const border  = Color(0xFF162030);
  static const neon    = Color(0xFF00FFD1);
  static const purple  = Color(0xFFB388FF);
  static const orange  = Color(0xFFFF6E40);
  static const txt     = Color(0xFF7A9CB8);
}

const _kPalette = [
  Color(0xFF6C63FF), Color(0xFFE91E63), Color(0xFF00BCD4),
  Color(0xFF4CAF50), Color(0xFFFF9800), Color(0xFF9C27B0),
  Color(0xFF2ECDA7), Color(0xFFD45DBF),
];

class TodParticipant {
  final String userId;
  final String name;
  const TodParticipant({required this.userId, required this.name});
}

class TruthOrDareGame extends StatefulWidget {
  final String roomId, myId;
  final bool isHost;
  final List<TodParticipant> participants;
  final List<TodParticipant> allRoomMembers; // everyone in the room
  final void Function(String cmd, Map<String, dynamic> data) onBroadcast;

  const TruthOrDareGame({
    super.key,
    required this.roomId, required this.myId, required this.isHost,
    required this.participants, required this.onBroadcast,
    this.allRoomMembers = const [],
  });

  @override
  State<TruthOrDareGame> createState() => TruthOrDareGameState();
}

class TruthOrDareGameState extends State<TruthOrDareGame>
    with TickerProviderStateMixin {
  int? _selectedIdx;
  bool _spinning = false;
  String _choiceType = '';
  String _chosenName = '';
  String _statusMsg = '';
  bool _showDone = false;

  late final AnimationController _spinCtrl;
  late final AnimationController _glowCtrl;
  late Animation<double> _spinAnim;
  double _curAngle = 0;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this);
    _spinAnim = const AlwaysStoppedAnimation(0);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() { _spinCtrl.dispose(); _glowCtrl.dispose(); super.dispose(); }

  // ── REMOTE EVENTS (called from chatroom_live_screen) ──
  void handleGameEvent(Map<String, dynamic> data) {
    final ev = data['event'] as String? ?? '';
    if (ev == 'spin_started') {
      // All clients animate the spin to the same target
      final targetIdx = data['targetIdx'] as int? ?? 0;
      final n = widget.participants.length;
      if (n < 2 || !mounted) return;
      _animateSpinTo(targetIdx);
    } else if (ev == 'bottle_landed') {
      final uid = data['targetUserId'] as String?;
      final idx = widget.participants.indexWhere((p) => p.userId == uid);
      if (!mounted) return;
      setState(() {
        _selectedIdx = idx >= 0 ? idx : null;
        _spinning = false;
        _choiceType = '';
        _chosenName = '';
        _showDone = false;
        if (idx >= 0) _statusMsg = '🍾 ${widget.participants[idx].name}, pick your fate!';
      });
    } else if (ev == 'choice_made') {
      if (!mounted) return;
      setState(() {
        _choiceType = data['type'] as String? ?? '';
        _chosenName = data['name'] as String? ?? '';
        _statusMsg = '$_chosenName chose ${_choiceType == 'dare' ? '🔥 DARE' : '💜 TRUTH'}';
        _showDone = widget.isHost;
      });
    } else if (ev == 'round_reset') {
      if (mounted) _reset();
    } else if (ev == 'invite_accepted' && widget.isHost) {
      // Host adds the user who accepted the invite
      final uid = data['userId'];
      final name = data['name'];
      if (uid != null && !widget.participants.any((p) => p.userId == uid)) {
        final newList = List<TodParticipant>.from(widget.participants);
        newList.add(TodParticipant(userId: uid, name: name ?? 'User'));
        widget.onBroadcast('update_participants', {
          'event': 'update_participants',
          'list': newList.map((p) => {'userId': p.userId, 'name': p.name}).toList()
        });
        widget.onBroadcast('sys_msg', {'event': 'sys_msg', 'msg': '@${name ?? 'A player'} joined the table.'});
      }
    } else if (ev == 'kick_from_game' && widget.isHost) {
      final uid = data['userId'];
      final name = data['name'];
      if (uid != null) {
        final newList = List<TodParticipant>.from(widget.participants);
        newList.removeWhere((p) => p.userId == uid);
        widget.onBroadcast('update_participants', {
          'event': 'update_participants',
          'list': newList.map((p) => {'userId': p.userId, 'name': p.name}).toList()
        });
        widget.onBroadcast('sys_msg', {'event': 'sys_msg', 'msg': '@$name was removed from the table.'});
      }
    } else if (ev == 'invite_declined' && widget.isHost) {
      final name = data['name'] ?? 'A player';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('@$name declined the invite', style: const TextStyle(color: Colors.white)),
          backgroundColor: _GC.surface,
          duration: const Duration(seconds: 2),
        ));
      }
    } else if (ev == 'sys_msg') {
      final msg = data['msg'];
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: _GC.purple,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  // ── SPIN ANIMATION (shared by host + remote) ──
  void _animateSpinTo(int idx) {
    final n = widget.participants.length;
    if (n < 2) return;
    setState(() { _spinning = true; _selectedIdx = null; _choiceType = ''; _chosenName = ''; _showDone = false; });

    // Pointer is on TOP of column → at angle=0 it points UP (-π/2 direction)
    // Avatar i sits at direction: (2π/n)*i - π/2
    // For pointer to aim at avatar i: -π/2 + θ = (2π/n)*i - π/2 → θ = (2π/n)*i
    final targetAng = (2 * pi / n) * idx;
    final curMod = _curAngle % (2 * pi);
    double delta = targetAng - curMod;
    if (delta < 0) delta += 2 * pi;

    _spinAnim = Tween<double>(begin: _curAngle, end: _curAngle + 7 * 2 * pi + delta)
        .animate(CurvedAnimation(parent: _spinCtrl, curve: const Cubic(0.08, 0.7, 0.18, 1.0)));
    _spinCtrl.duration = const Duration(milliseconds: 3200);
    _spinCtrl.forward(from: 0).then((_) {
      _curAngle = targetAng;
      final target = widget.participants[idx];
      setState(() {
        _selectedIdx = idx;
        _spinning = false;
        _statusMsg = '🍾 ${target.name}, pick your fate!';
      });
    });
  }

  // ── HOST SPIN (picks target + broadcasts to all) ──
  void _spinBottle() {
    if (_spinning || !widget.isHost) return;
    final n = widget.participants.length;
    if (n < 2) { setState(() => _statusMsg = 'Need 2+ players!'); return; }

    final idx = _rng.nextInt(n);
    final target = widget.participants[idx];

    // Broadcast spin_started so ALL clients animate
    widget.onBroadcast('spin_started', {
      'event': 'spin_started',
      'targetIdx': idx,
      'targetUserId': target.userId,
    });

    // Host also animates locally
    _animateSpinTo(idx);

    // After animation, broadcast bottle_landed
    Future.delayed(const Duration(milliseconds: 3300), () {
      widget.onBroadcast('bottle_landed', {
        'event': 'bottle_landed',
        'targetUserId': target.userId,
        'targetUsername': target.name,
      });
    });
  }

  void _pick(bool isTruth) {
    if (_selectedIdx == null) return;
    final p = widget.participants[_selectedIdx!];
    if (p.userId != widget.myId) return;
    final type = isTruth ? 'truth' : 'dare';
    setState(() {
      _choiceType = type; _chosenName = p.name;
      _statusMsg = '${p.name} chose ${isTruth ? '💜 TRUTH' : '🔥 DARE'}';
      _showDone = widget.isHost;
    });
    widget.onBroadcast('choice_made', {'event': 'choice_made', 'type': type, 'name': p.name});
  }

  void _reset() => setState(() { _selectedIdx = null; _choiceType = ''; _chosenName = ''; _statusMsg = ''; _showDone = false; });
  void _doneRound() { _reset(); widget.onBroadcast('round_reset', {'event': 'round_reset'}); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _GC.bg, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _GC.border),
        boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: 0.06), blurRadius: 40)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHeader(),
        SizedBox(height: MediaQuery.of(context).size.height * 0.44, child: _buildBoard()),
        if (_selectedIdx != null && _choiceType.isEmpty) _buildChoicePopup(),
        if (_choiceType.isNotEmpty) _buildResultCard(),
        _buildStatusBar(),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Row(children: [
      Flexible(child: _pill('🍾  TRUTH OR DARE', _GC.neon)),
      const SizedBox(width: 8),
      _pill('${widget.participants.length} players', _GC.txt),
      const Spacer(),
      if (widget.isHost) GestureDetector(
        onTap: _manageSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _GC.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.manage_accounts, color: _GC.neon, size: 14),
            const SizedBox(width: 4),
            Text('Manage', style: GoogleFonts.inter(color: _GC.txt, fontSize: 10)),
          ]),
        ),
      ),
    ]),
  );

  Widget _pill(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(20), color: c.withValues(alpha: 0.06)),
    child: Text(label, style: GoogleFonts.inter(color: c, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );

  Widget _buildBoard() {
    return LayoutBuilder(builder: (ctx, box) {
      final cx = box.maxWidth / 2, cy = box.maxHeight / 2;
      final ring = (min(box.maxWidth, box.maxHeight) * 0.37).clamp(72.0, 145.0);
      final n = widget.participants.length;
      return Stack(children: [
        // Glow ring
        Center(child: AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, __) => Container(
            width: ring * 2 + 22, height: ring * 2 + 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _GC.neon.withValues(alpha: 0.05 + _glowCtrl.value * 0.07), width: 1.5),
              boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: 0.03 + _glowCtrl.value * 0.04), blurRadius: 28)],
            ),
          ),
        )),
        // Track ring
        Center(child: Container(width: ring * 2, height: ring * 2, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _GC.border.withValues(alpha: 0.5))))),
        // Avatars
        if (n > 0) ...List.generate(n, (i) {
          final ang = (2 * pi / n) * i - pi / 2;
          return Positioned(left: cx + ring * cos(ang) - 22, top: cy + ring * sin(ang) - 30, child: GestureDetector(
            onTap: () {
              if (widget.isHost) {
                final p = widget.participants[i];
                if (p.userId != widget.myId) {
                  _showParticipantMenu(p);
                }
              }
            },
            child: _buildAvatar(widget.participants[i], i, _selectedIdx == i),
          ));
        }),
        // BOTTLE — pointer line on TOP so at angle=0 it points UP (toward avatar 0)
        Center(child: GestureDetector(
          onTap: widget.isHost ? _spinBottle : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_spinCtrl, _glowCtrl]),
            builder: (_, __) {
              final angle = _spinning ? _spinAnim.value : _curAngle;
              return Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_GC.neon.withValues(alpha: 0.14 + _glowCtrl.value * 0.10), _GC.surface]),
                  border: Border.all(color: _GC.neon.withValues(alpha: 0.28 + _glowCtrl.value * 0.12), width: 2.5),
                  boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: _spinning ? 0.35 : 0.12), blurRadius: _spinning ? 35 : 18)],
                ),
                child: Transform.rotate(angle: angle, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // POINTER on top → points UP at angle=0
                  Container(width: 3.0, height: 18, decoration: BoxDecoration(
                    color: _GC.neon, borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: 0.7), blurRadius: 6)],
                  )),
                  const SizedBox(height: 6),
                  Image.asset('assets/images/bottle.png', height: 65, fit: BoxFit.contain),
                ])),
              );
            },
          ),
        )),
        // Hint
        if (!_spinning && _selectedIdx == null)
          Positioned(bottom: 10, left: 0, right: 0, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: _GC.neon.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
            child: Text(widget.isHost ? '👆 TAP BOTTLE TO SPIN' : 'Waiting for host...', style: GoogleFonts.inter(color: _GC.neon, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ))),
      ]);
    });
  }

  Widget _buildAvatar(TodParticipant p, int i, bool sel) {
    final col = _kPalette[i % _kPalette.length];
    return GestureDetector(
      onLongPress: () {
        if (widget.isHost && p.userId != widget.myId) _confirmKick(p);
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack,
        width: sel ? 46 : 40, height: sel ? 46 : 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle, gradient: LinearGradient(colors: [col, col.withValues(alpha: 0.55)]),
          border: Border.all(color: sel ? _GC.neon : Colors.transparent, width: sel ? 3 : 0),
          boxShadow: sel ? [BoxShadow(color: _GC.neon.withValues(alpha: 0.55), blurRadius: 18, spreadRadius: 2)] : [BoxShadow(color: col.withValues(alpha: 0.25), blurRadius: 6)],
        ),
        child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?', style: GoogleFonts.inter(color: Colors.white, fontSize: sel ? 17 : 14, fontWeight: FontWeight.w800))),
      ),
      const SizedBox(height: 3),
      Text(p.name.length > 8 ? '${p.name.substring(0, 7)}..' : p.name, style: GoogleFonts.inter(color: sel ? _GC.neon : _GC.txt, fontSize: 9, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
    ]),
    );
  }

  Widget _buildChoicePopup() {
    final target = widget.participants[_selectedIdx!];
    final isMe = target.userId == widget.myId;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_GC.surface, _GC.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: _GC.neon.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text('🍾  ${target.name}\'s Turn!', style: GoogleFonts.inter(color: _GC.neon, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(isMe ? 'Choose your fate!' : '${target.name} is choosing...', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _choiceBtn('💜  TRUTH', _GC.purple, isMe, () => _pick(true))),
          const SizedBox(width: 10),
          Expanded(child: _choiceBtn('🔥  DARE', _GC.orange, isMe, () => _pick(false))),
        ]),
      ]),
    );
  }

  Widget _choiceBtn(String label, Color c, bool active, VoidCallback onTap) => Opacity(
    opacity: active ? 1.0 : 0.3,
    child: GestureDetector(onTap: active ? onTap : null, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: active ? LinearGradient(colors: [c.withValues(alpha: 0.18), c.withValues(alpha: 0.04)]) : null,
        color: active ? null : _GC.surface, borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withValues(alpha: active ? 0.65 : 0.15), width: 1.5),
      ),
      child: Center(child: Text(label, style: GoogleFonts.inter(color: c, fontSize: 13, fontWeight: FontWeight.w800))),
    )),
  );

  Widget _buildResultCard() {
    final isTruth = _choiceType == 'truth';
    final c = isTruth ? _GC.purple : _GC.orange;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8), padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withValues(alpha: 0.14), _GC.bg], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Text(isTruth ? '💜' : '🔥', style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('$_chosenName chose ${isTruth ? 'TRUTH' : 'DARE'}', style: GoogleFonts.inter(color: c, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Other players — give ${_chosenName.split(' ').first} a ${isTruth ? 'truth question' : 'dare challenge'}!', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildStatusBar() => Column(children: [
    if (_statusMsg.isNotEmpty) Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: _GC.border)),
      child: Row(children: [
        Expanded(child: Text(_statusMsg, style: GoogleFonts.inter(color: _GC.txt, fontSize: 10))),
        if (_spinning) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: _GC.neon)),
      ]),
    ),
    if (_showDone && widget.isHost) GestureDetector(
      onTap: _doneRound,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0), padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_GC.neon.withValues(alpha: 0.14), _GC.neon.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(26), border: Border.all(color: _GC.neon.withValues(alpha: 0.4)),
        ),
        child: Center(child: Text('🔄  SPIN AGAIN', style: GoogleFonts.inter(color: _GC.neon, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
      ),
    ),
  ]);

  void _confirmKick(TodParticipant p) {
    final bool isActive = _selectedIdx != null && widget.participants[_selectedIdx!].userId == p.userId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _GC.surface,
        title: Text('Remove ${p.name}?', style: const TextStyle(color: Colors.white)),
        content: Text(
          isActive 
            ? "This player's turn is active. Kicking them will cancel this round and re-spin the bottle."
            : "Remove ${p.name} from the table?",
          style: const TextStyle(color: _GC.txt),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final kickEvent = {
                'event': 'kick_from_game', 
                'userId': p.userId, 
                'name': p.name,
                'wasActive': isActive
              };
              widget.onBroadcast('kick_from_game', kickEvent);
              handleGameEvent(kickEvent);
              if (isActive) {
                // Host auto re-spins
                _spinBottle();
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── MANAGE SHEET with kick from game + invite ──
  void _manageSheet() {
    final nonPlayers = widget.allRoomMembers.where((m) => !widget.participants.any((p) => p.userId == m.userId)).toList();
    final bool isFull = widget.participants.length >= 8;
    
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _GC.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text('Manage Players', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            
            Align(alignment: Alignment.centerLeft, child: Text('AT THE TABLE (${widget.participants.length}/8)', style: GoogleFonts.inter(color: _GC.txt, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1))),
            const SizedBox(height: 8),
            ...widget.participants.map((p) {
              final i = widget.participants.indexOf(p);
              final col = _kPalette[i % _kPalette.length];
              final isMe = p.userId == widget.myId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: _GC.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _GC.border)),
                child: Row(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: col),
                    child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
                  if (isMe)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _GC.neon.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text('HOST', style: GoogleFonts.inter(color: _GC.neon, fontSize: 9, fontWeight: FontWeight.w800))),
                  if (!isMe) GestureDetector(
                    onTap: () { Navigator.pop(context); _confirmKick(p); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                      child: Text('Kick', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700))),
                  ),
                ]),
              );
            }),
            
            if (nonPlayers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: Text('IN THE ROOM', style: GoogleFonts.inter(color: _GC.txt, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1))),
              const SizedBox(height: 8),
              if (isFull)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('Table is full — kick a player to make space.', style: TextStyle(color: _GC.orange, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
              ...nonPlayers.take(15).map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _GC.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _GC.border)),
                child: Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: _GC.txt.withValues(alpha: 0.2)),
                    child: Center(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 11)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.name, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12))),
                  GestureDetector(
                    onTap: isFull ? null : () { Navigator.pop(context); widget.onBroadcast('invite_to_game', {'event': 'invite_to_game', 'userId': p.userId, 'name': p.name}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                      decoration: BoxDecoration(color: isFull ? Colors.white12 : Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: isFull ? Colors.transparent : Colors.green.withValues(alpha: 0.3))),
                      child: Text('Invite', style: GoogleFonts.inter(color: isFull ? Colors.white38 : Colors.green, fontSize: 11, fontWeight: FontWeight.w700))
                    ),
                  ),
                ]),
              )),
            ],
          ]),
        ),
      ),
    );
  }

  void _showParticipantMenu(TodParticipant p) {
    if (widget.isHost && p.userId != widget.myId) {
      _confirmKick(p);
    }
  }
}
