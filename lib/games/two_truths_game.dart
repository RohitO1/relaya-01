// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'truth_dare_game.dart'; // For TodParticipant

class _GC {
  static const bg      = Color(0xFF04080F);
  static const surface = Color(0xFF0B1422);
  static const border  = Color(0xFF162030);
  static const neon    = Color(0xFF00FFD1);
  static const purple  = Color(0xFFB388FF);
  static const orange  = Color(0xFFFF6E40);
  static const txt     = Color(0xFF7A9CB8);
  static const green   = Color(0xFF4CAF50);
  static const red     = Color(0xFFF44336);
}

const _kPalette = [
  Color(0xFF6C63FF), Color(0xFFE91E63), Color(0xFF00BCD4),
  Color(0xFF4CAF50), Color(0xFFFF9800), Color(0xFF9C27B0),
  Color(0xFF2ECDA7), Color(0xFFD45DBF),
];

class TwoTruthsGame extends StatefulWidget {
  final String roomId, myId;
  final bool isHost;
  final List<TodParticipant> participants;
  final List<TodParticipant> allRoomMembers;
  final void Function(String cmd, Map<String, dynamic> data) onBroadcast;

  const TwoTruthsGame({
    super.key,
    required this.roomId, required this.myId, required this.isHost,
    required this.participants, required this.onBroadcast,
    this.allRoomMembers = const [],
  });

  @override
  State<TwoTruthsGame> createState() => TwoTruthsGameState();
}

class TwoTruthsGameState extends State<TwoTruthsGame> with TickerProviderStateMixin {
  String _gameState = 'idle'; // idle, spinning, input, voting, reveal, result
  String? _selectedUserId;
  
  // Input state
  final _st1Ctrl = TextEditingController();
  final _st2Ctrl = TextEditingController();
  final _st3Ctrl = TextEditingController();
  List<String> _statements = []; // [st1, st2, st3]
  
  // Voting state
  final Map<String, int> _votes = {}; // voterId -> statement index (0, 1, 2)
  int _timeRemaining = 90;
  Timer? _pollTimer;
  int? _myVote; // Index of the statement I voted for
  
  // Reveal state
  int? _selectedLieIdx;
  final _noteCtrl = TextEditingController();
  String _revealNote = '';
  int _actualLieIdx = -1;
  
  // Leaderboard (userId -> score)
  final Map<String, int> _leaderboard = {};
  final List<String> _playedUserIds = [];

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
  void dispose() { 
    _spinCtrl.dispose(); 
    _glowCtrl.dispose(); 
    _pollTimer?.cancel();
    _st1Ctrl.dispose(); _st2Ctrl.dispose(); _st3Ctrl.dispose(); _noteCtrl.dispose();
    super.dispose(); 
  }

  void handleGameEvent(Map<String, dynamic> data) {
    final ev = data['event'] as String? ?? '';
    if (ev == 'spin_started') {
      final targetIdx = data['targetIdx'] as int? ?? 0;
      final n = widget.participants.length;
      if (n < 2 || !mounted) return;
      _animateSpinTo(targetIdx);
    } else if (ev == 'bottle_landed') {
      final uid = data['targetUserId'] as String?;
      if (!mounted) return;
      setState(() {
        _gameState = 'input';
        _selectedUserId = uid;
        _statements = [];
        _myVote = null;
        _votes.clear();
        _st1Ctrl.clear(); _st2Ctrl.clear(); _st3Ctrl.clear();
      });
      if (widget.isHost) {
        if (uid != null && !_playedUserIds.contains(uid)) {
          _playedUserIds.add(uid);
          if (_playedUserIds.length >= widget.participants.length) {
            _playedUserIds.clear(); // Reset exclusion when everyone played
          }
        }
      }
    } else if (ev == 'statements_submitted') {
      if (!mounted) return;
      final stmts = List<String>.from(data['statements'] ?? []);
      setState(() {
        _gameState = 'voting';
        _statements = stmts;
        _timeRemaining = 90;
        _myVote = null;
        _votes.clear();
      });
      _startPollTimer();
    } else if (ev == 'vote_cast') {
      if (!mounted) return;
      final voter = data['voterId'] as String?;
      final stmtIdx = data['stmtIdx'] as int?;
      if (voter != null && stmtIdx != null) {
        setState(() => _votes[voter] = stmtIdx);
      }
    } else if (ev == 'poll_closed') {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _gameState = 'reveal';
        _selectedLieIdx = null;
        _noteCtrl.clear();
      });
    } else if (ev == 'lie_revealed') {
      if (!mounted) return;
      setState(() {
        _actualLieIdx = data['lieIdx'] as int? ?? 0;
        _revealNote = data['note'] as String? ?? '';
        _gameState = 'result';
      });
      
      // Update leaderboard locally
      _votes.forEach((voterId, voteIdx) {
        if (voteIdx == _actualLieIdx && voterId != _selectedUserId) {
          _leaderboard[voterId] = (_leaderboard[voterId] ?? 0) + 1;
        }
      });
      
      // Auto-back to idle after 12s
      Future.delayed(const Duration(seconds: 12), () {
        if (mounted && _gameState == 'result') {
          setState(() => _gameState = 'idle');
        }
      });
    } else if (ev == 'round_reset') {
      if (mounted) {
        setState(() => _gameState = 'idle');
      }
    } else if (ev == 'skip_turn') {
      if (mounted) {
        setState(() => _gameState = 'idle');
      }
    } else if (ev == 'invite_accepted' && widget.isHost) {
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

  void _animateSpinTo(int idx) {
    final n = widget.participants.length;
    if (n < 2) return;
    setState(() { _gameState = 'spinning'; });

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
      // Do not transition to input yet, wait for bottle_landed broadcast
    });
  }

  void _spinBottle() {
    if (_gameState == 'spinning' || !widget.isHost) return;
    final n = widget.participants.length;
    if (n < 2) return;

    // Filter unplayed users
    List<int> validIndices = [];
    for (int i=0; i<n; i++) {
      if (!_playedUserIds.contains(widget.participants[i].userId)) {
        validIndices.add(i);
      }
    }
    if (validIndices.isEmpty) {
      _playedUserIds.clear(); // Safety reset
      validIndices = List.generate(n, (i) => i);
    }

    final idx = validIndices[_rng.nextInt(validIndices.length)];
    final target = widget.participants[idx];

    widget.onBroadcast('spin_started', {
      'event': 'spin_started',
      'targetIdx': idx,
    });

    _animateSpinTo(idx);

    Future.delayed(const Duration(milliseconds: 3300), () {
      widget.onBroadcast('bottle_landed', {
        'event': 'bottle_landed',
        'targetUserId': target.userId,
      });
    });
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _gameState != 'voting') {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          timer.cancel();
          if (widget.myId == _selectedUserId || widget.isHost) {
            _closePoll();
          }
        }
      });
    });
  }

  void _submitStatements() {
    final s1 = _st1Ctrl.text.trim();
    final s2 = _st2Ctrl.text.trim();
    final s3 = _st3Ctrl.text.trim();
    if (s1.isEmpty || s2.isEmpty || s3.isEmpty) return;
    widget.onBroadcast('statements_submitted', {
      'event': 'statements_submitted',
      'statements': [s1, s2, s3],
    });
  }

  void _castVote(int idx) {
    if (_myVote != null || widget.myId == _selectedUserId) return;
    setState(() { _myVote = idx; _votes[widget.myId] = idx; });
    widget.onBroadcast('vote_cast', {
      'event': 'vote_cast',
      'voterId': widget.myId,
      'stmtIdx': idx,
    });
  }

  void _closePoll() {
    widget.onBroadcast('poll_closed', {'event': 'poll_closed'});
  }

  void _revealLie() {
    if (_selectedLieIdx == null) return;
    widget.onBroadcast('lie_revealed', {
      'event': 'lie_revealed',
      'lieIdx': _selectedLieIdx,
      'note': _noteCtrl.text.trim(),
    });
  }

  void _skipTurn() {
    widget.onBroadcast('skip_turn', {'event': 'skip_turn'});
  }

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
        if (_gameState == 'idle' || _gameState == 'spinning' || _gameState == 'input')
          SizedBox(height: MediaQuery.of(context).size.height * 0.44, child: _buildBoard()),
        
        if (_gameState == 'input') _buildInputPanel(),
        if (_gameState == 'voting') _buildVotingPanel(),
        if (_gameState == 'reveal') _buildRevealPanel(),
        if (_gameState == 'result') _buildResultPanel(),
        
        if (_gameState == 'idle' || _gameState == 'spinning') _buildStatusBar(),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Row(children: [
      Flexible(child: _pill('🎭 TWO TRUTHS, ONE LIE', _GC.neon)),
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
      if (widget.isHost) const SizedBox(width: 6),
      GestureDetector(
        onTap: _showLeaderboard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _GC.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.leaderboard, color: _GC.orange, size: 14),
            const SizedBox(width: 4),
            Text('Scores', style: GoogleFonts.inter(color: _GC.txt, fontSize: 10)),
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
      final isSpinning = _gameState == 'spinning';
      
      int? selIdx;
      if (_selectedUserId != null) {
        selIdx = widget.participants.indexWhere((p) => p.userId == _selectedUserId);
      }

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
          return Positioned(left: cx + ring * cos(ang) - 22, top: cy + ring * sin(ang) - 30, child: _buildAvatar(widget.participants[i], i, selIdx == i));
        }),
        // BOTTLE
        Center(child: GestureDetector(
          onTap: widget.isHost ? _spinBottle : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_spinCtrl, _glowCtrl]),
            builder: (_, __) {
              final angle = isSpinning ? _spinAnim.value : _curAngle;
              return Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_GC.neon.withValues(alpha: 0.14 + _glowCtrl.value * 0.10), _GC.surface]),
                  border: Border.all(color: _GC.neon.withValues(alpha: 0.28 + _glowCtrl.value * 0.12), width: 2.5),
                  boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: isSpinning ? 0.35 : 0.12), blurRadius: isSpinning ? 35 : 18)],
                ),
                child: Transform.rotate(angle: angle, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 3.0, height: 18, decoration: BoxDecoration(
                    color: _GC.neon, borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: 0.7), blurRadius: 6)],
                  )),
                  const SizedBox(height: 6),
                  Image.asset('assets/images/bottle.png', height: 65, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.arrow_upward, color: _GC.neon, size: 60)),
                ])),
              );
            },
          ),
        )),
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

  Widget _buildInputPanel() {
    final isMe = widget.myId == _selectedUserId;
    final targetName = widget.participants.firstWhere((p) => p.userId == _selectedUserId, orElse: () => const TodParticipant(userId: '', name: 'Someone')).name;

    if (!isMe) {
      return Container(
        margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _GC.border)),
        child: Column(children: [
          const CircularProgressIndicator(color: _GC.neon),
          const SizedBox(height: 16),
          Text('$targetName is preparing their statements...', style: GoogleFonts.inter(color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Get ready to vote on the lie!', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12)),
          if (widget.isHost) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: _skipTurn, child: const Text('Skip Turn', style: TextStyle(color: Colors.redAccent))),
          ]
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _GC.neon.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Write Two Truths and One Lie', style: GoogleFonts.inter(color: _GC.neon, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Mix them up! Others won\'t know which is which.', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12)),
        const SizedBox(height: 16),
        _buildTextField(_st1Ctrl, 'Statement 1'),
        const SizedBox(height: 10),
        _buildTextField(_st2Ctrl, 'Statement 2'),
        const SizedBox(height: 10),
        _buildTextField(_st3Ctrl, 'Statement 3'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitStatements,
          style: ElevatedButton.styleFrom(backgroundColor: _GC.neon, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Submit & Launch Poll', style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: _GC.txt.withValues(alpha: 0.5)),
        filled: true, fillColor: _GC.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildVotingPanel() {
    final isMe = widget.myId == _selectedUserId;
    final totalVoters = widget.participants.length - 1; // Exclude selected user
    final votesCast = _votes.length;

    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _GC.purple.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Live Poll', style: GoogleFonts.inter(color: _GC.purple, fontSize: 16, fontWeight: FontWeight.bold)),
          _pill('⏱ $_timeRemaining s', _GC.orange),
        ]),
        const SizedBox(height: 16),
        if (isMe) ...[
          Text('Players are voting...', style: GoogleFonts.inter(color: Colors.white)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: totalVoters > 0 ? votesCast / totalVoters : 0, backgroundColor: _GC.bg, valueColor: const AlwaysStoppedAnimation(_GC.purple)),
          const SizedBox(height: 8),
          Text('$votesCast of $totalVoters have voted', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: _closePoll, child: const Text('End Poll Early', style: TextStyle(color: Colors.redAccent))),
        ] else ...[
          Text('Which statement is the LIE?', style: GoogleFonts.inter(color: Colors.white)),
          const SizedBox(height: 12),
          ...List.generate(3, (i) {
            final isSelected = _myVote == i;
            return GestureDetector(
              onTap: () => _castVote(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? _GC.purple.withValues(alpha: 0.2) : _GC.bg,
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? _GC.purple : _GC.border),
                ),
                child: Row(children: [
                  Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? _GC.purple : _GC.txt, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_statements[i], style: const TextStyle(color: Colors.white, fontSize: 14))),
                ]),
              ),
            );
          }),
          if (widget.isHost)
            TextButton(onPressed: _closePoll, child: const Text('End Poll (Host)', style: TextStyle(color: Colors.redAccent))),
        ]
      ]),
    );
  }

  Widget _buildRevealPanel() {
    final isMe = widget.myId == _selectedUserId;

    if (!isMe) {
      return Container(
        margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _GC.border)),
        child: Column(children: [
          const CircularProgressIndicator(color: _GC.neon),
          const SizedBox(height: 16),
          Text('Voting closed! Waiting for the big reveal...', style: GoogleFonts.inter(color: Colors.white), textAlign: TextAlign.center),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _GC.neon.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Reveal the Lie!', style: GoogleFonts.inter(color: _GC.neon, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Select which statement was the fake one.', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12)),
        const SizedBox(height: 16),
        ...List.generate(3, (i) {
          final isSelected = _selectedLieIdx == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedLieIdx = i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? _GC.red.withValues(alpha: 0.2) : _GC.bg,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? _GC.red : _GC.border),
              ),
              child: Text(_statements[i], style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl, style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(hintText: 'Add a fun note (optional)...', hintStyle: TextStyle(color: _GC.txt.withValues(alpha: 0.5)), filled: true, fillColor: _GC.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _selectedLieIdx == null ? null : _revealLie,
          style: ElevatedButton.styleFrom(backgroundColor: _GC.neon, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Reveal to Everyone', style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }

  Widget _buildResultPanel() {
    int correctVotes = 0;
    int totalVotes = _votes.length;
    List<String> sharpMinds = [];
    List<String> fooled = [];

    _votes.forEach((voterId, voteIdx) {
      final p = widget.participants.firstWhere((p) => p.userId == voterId, orElse: () => const TodParticipant(userId: '', name: ''));
      if (p.name.isNotEmpty) {
        if (voteIdx == _actualLieIdx) {
          correctVotes++;
          sharpMinds.add(p.name);
        } else {
          fooled.add(p.name);
        }
      }
    });

    bool majorityCorrect = totalVotes > 0 && (correctVotes / totalVotes) >= 0.5;

    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _GC.surface, borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: majorityCorrect ? _GC.green : _GC.orange, width: 2),
        boxShadow: [BoxShadow(color: majorityCorrect ? _GC.green.withValues(alpha: 0.2) : _GC.orange.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(majorityCorrect ? '🎉 Sharp Minds Win!' : '😈 Master of Deception!', style: GoogleFonts.inter(color: majorityCorrect ? _GC.green : _GC.orange, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('The Lie was:', style: GoogleFonts.inter(color: _GC.txt, fontSize: 12)),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _GC.bg, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: _GC.red, width: 4))),
          child: Text(_actualLieIdx >= 0 && _actualLieIdx < _statements.length ? _statements[_actualLieIdx] : 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
        if (_revealNote.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('"$_revealNote"', style: GoogleFonts.inter(color: _GC.neon, fontStyle: FontStyle.italic, fontSize: 13))),
        
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statCol('Voted', '$totalVotes', _GC.purple),
          _statCol('Correct', '$correctVotes', _GC.green),
          _statCol('Accuracy', totalVotes > 0 ? '${((correctVotes/totalVotes)*100).round()}%' : '0%', majorityCorrect ? _GC.green : _GC.orange),
        ]),
        const SizedBox(height: 16),
        
        if (sharpMinds.isNotEmpty) ...[
          Text('Sharp Minds: ${sharpMinds.join(', ')}', style: GoogleFonts.inter(color: _GC.green, fontSize: 11)),
          const SizedBox(height: 4),
        ],
        if (fooled.isNotEmpty)
          Text('Fooled: ${fooled.join(', ')}', style: GoogleFonts.inter(color: _GC.orange, fontSize: 11)),
          
        if (widget.isHost) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => widget.onBroadcast('round_reset', {'event': 'round_reset'}),
            style: ElevatedButton.styleFrom(backgroundColor: _GC.surface, side: const BorderSide(color: _GC.neon)),
            child: const Text('Next Round', style: TextStyle(color: _GC.neon)),
          )
        ]
      ]),
    );
  }

  Widget _statCol(String label, String val, Color c) => Column(children: [
    Text(val, style: GoogleFonts.inter(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
    Text(label, style: GoogleFonts.inter(color: _GC.txt, fontSize: 10)),
  ]);

  Widget _buildStatusBar() {
    String msg = '';
    if (_gameState == 'idle') {
      msg = widget.isHost ? '👆 Tap bottle to select a player' : 'Waiting for host to spin...';
    } else if (_gameState == 'spinning') {
      msg = 'Spinning...';
    }
    
    if (msg.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _GC.border)),
      child: Center(child: Text(msg, style: GoogleFonts.inter(color: _GC.txt, fontSize: 11))),
    );
  }
  void _confirmKick(TodParticipant p) {
    final bool isActive = _selectedUserId == p.userId;
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
                _spinBottle();
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

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


  void _showLeaderboard() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(color: _GC.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _GC.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          Text('🏆 Leaderboard', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (_leaderboard.isEmpty)
            Text('No points scored yet!', style: GoogleFonts.inter(color: _GC.txt))
          else
            ...(() {
              final entries = _leaderboard.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
              return entries.map((e) {
                final p = widget.participants.firstWhere((p) => p.userId == e.key, orElse: () => const TodParticipant(userId: '', name: 'User'));
                return ListTile(
                  leading: const Icon(Icons.star, color: _GC.orange),
                  title: Text(p.name, style: const TextStyle(color: Colors.white)),
                  trailing: Text('${e.value} pts', style: const TextStyle(color: _GC.neon, fontWeight: FontWeight.bold, fontSize: 16)),
                );
              }).toList();
            })(),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}


