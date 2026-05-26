// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'truth_dare_game.dart' show TodParticipant;

class _GC {
  static const neon = Color(0xFFF97316); // Orange/Fire for Blind Date
  static const bg = Color(0xFF1E293B);
  static const surface = Color(0xFF0F172A);
  static const border = Color(0xFF334155);
  static const txt = Color(0xFFF8FAFC);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6); // Freeze color
}

class BlindDateGame extends StatefulWidget {
  final String roomId, myId;
  final bool isHost;
  final List<TodParticipant> participants;
  final List<TodParticipant> allRoomMembers;
  final void Function(String cmd, Map<String, dynamic> data) onBroadcast;

  const BlindDateGame({
    super.key,
    required this.roomId,
    required this.myId,
    required this.isHost,
    required this.participants,
    required this.allRoomMembers,
    required this.onBroadcast,
  });

  @override
  State<BlindDateGame> createState() => BlindDateGameState();
}

class BlindDateGameState extends State<BlindDateGame> with TickerProviderStateMixin {
  String _gameState = 'idle'; // idle, selecting_confirmed, session_active, session_ended, poll_open, poll_closed, analysis_shown
  String? _player1Id;
  String? _player2Id;
  String? _player1Name;
  String? _player2Name;
  
  // Timers
  Timer? _sessionTimer;
  int _sessionTimeRemaining = 180;
  
  Timer? _pollTimer;
  int _pollTimeRemaining = 30;

  // Poll state
  String? _myVote; // 'fire' or 'freeze'
  int _fireCount = 0;
  int _freezeCount = 0;
  int _totalVotes = 0;
  
  // DB
  final _sb = Supabase.instance.client;
  String? _sessionId;
  
  // Selection state
  Map<String, String> _memberGenders = {}; // userId -> 'Male', 'Female', etc.

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void handleGameEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final ev = data['event'];
    
    if (ev == 'start_blind_date') {
      setState(() {
        _gameState = 'session_active';
        _player1Id = data['p1_id'];
        _player2Id = data['p2_id'];
        _player1Name = data['p1_name'];
        _player2Name = data['p2_name'];
        _sessionId = data['session_id'];
        _sessionTimeRemaining = 180;
      });
      _startSessionTimer();
    } else if (ev == 'end_session') {
      _sessionTimer?.cancel();
      setState(() {
        _gameState = 'poll_open';
        _pollTimeRemaining = 30;
        _myVote = null;
        _fireCount = 0;
        _freezeCount = 0;
        _totalVotes = 0;
      });
      _startPollTimer();
    } else if (ev == 'close_poll') {
      _pollTimer?.cancel();
      setState(() {
        _gameState = 'analysis_shown';
        _fireCount = data['fire'] ?? 0;
        _freezeCount = data['freeze'] ?? 0;
        _totalVotes = data['total'] ?? 0;
      });
    } else if (ev == 'vote_cast' && widget.isHost) {
      // Host tallies votes
      final choice = data['choice'];
      if (choice == 'fire') _fireCount++;
      if (choice == 'freeze') _freezeCount++;
      _totalVotes++;
    } else if (ev == 'reset_game') {
      setState(() {
        _gameState = 'idle';
        _player1Id = null;
        _player2Id = null;
        _sessionId = null;
      });
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_sessionTimeRemaining > 0) {
          _sessionTimeRemaining--;
        } else {
          timer.cancel();
          if (widget.isHost && _gameState == 'session_active') {
            _triggerEndSession('timer');
          }
        }
      });
    });
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_pollTimeRemaining > 0) {
          _pollTimeRemaining--;
        } else {
          timer.cancel();
          if (widget.isHost && _gameState == 'poll_open') {
            _triggerClosePoll();
          }
        }
      });
    });
  }

  Future<void> _triggerEndSession(String reason) async {
    if (!widget.isHost) return;
    _sessionTimer?.cancel();
    
    if (_sessionId != null) {
      try {
        await _sb.from('bolroom_blind_date_sessions').update({
          'state': 'POLL_OPEN',
          'session_ended_at': DateTime.now().toUtc().toIso8601String(),
          'session_end_reason': reason,
          'poll_opened_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _sessionId!);
      } catch (e) {
        debugPrint('Error updating session: $e');
      }
    }
    if (!mounted) return;
    final ev = {'event': 'end_session', 'reason': reason};
    widget.onBroadcast('end_session', ev);
    handleGameEvent(ev);
  }

  Future<void> _triggerClosePoll() async {
    if (!widget.isHost) return;
    _pollTimer?.cancel();
    
    final aiJson = {
      'sentiment_score': _fireCount > _freezeCount ? 80 : 30,
      'engagement_level': _totalVotes > 5 ? 'high_energy' : 'steady_flow',
      'key_topics': ['Vibes', 'Interests', 'Connection'],
      'vibe_summary': _fireCount > _freezeCount 
          ? "The room felt the chemistry instantly!" 
          : "It was more of a friendly chat, not much romance.",
    };
    
    if (_sessionId != null) {
      try {
        await _sb.from('bolroom_blind_date_sessions').update({
          'state': 'ANALYSIS_SHOWN',
          'poll_closed_at': DateTime.now().toUtc().toIso8601String(),
          'analysis_json': aiJson,
        }).eq('id', _sessionId!);
      } catch (e) {
        debugPrint('Error closing poll DB: $e');
      }
    }
    if (!mounted) return;
    final ev = {
      'event': 'close_poll',
      'fire': _fireCount,
      'freeze': _freezeCount,
      'total': _totalVotes,
      'analysis': aiJson,
    };
    widget.onBroadcast('close_poll', ev);
    handleGameEvent(ev);
  }

  // UI BUILDERS
  @override
  Widget build(BuildContext context) {
    if (_gameState == 'analysis_shown') return _buildAnalysisCard();
    if (_gameState == 'poll_open') return _buildPollOverlay();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _GC.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gameState == 'session_active' ? _GC.neon : _GC.border, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('🔥 Blind Date', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_gameState == 'session_active')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sessionTimeRemaining < 30 ? _GC.red.withValues(alpha: 0.2) : _GC.neon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_sessionTimeRemaining ~/ 60)}:${(_sessionTimeRemaining % 60).toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(
                      color: _sessionTimeRemaining < 30 ? _GC.red : _GC.neon,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_gameState == 'idle') ...[
            Text('Hot Seat interaction game!', style: GoogleFonts.inter(color: _GC.txt, fontSize: 13)),
            const SizedBox(height: 20),
            if (widget.isHost)
              ElevatedButton.icon(
                icon: _isLoadingGenders ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.local_fire_department, color: Colors.white),
                label: Text(_isLoadingGenders ? 'Loading...' : 'Start Blind Date 🔥', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _GC.neon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: _isLoadingGenders ? null : _openPlayerSelection,
              )
            else
              Text('Waiting for host to start...', style: TextStyle(color: _GC.txt.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
          ],

          if (_gameState == 'session_active') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerAvatar(_player1Name ?? 'P1', true),
                const Icon(Icons.favorite, color: _GC.red, size: 32),
                _buildPlayerAvatar(_player2Name ?? 'P2', false),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.isHost)
              TextButton(
                onPressed: () => _triggerEndSession('host'),
                child: const Text('End Session Now', style: TextStyle(color: _GC.red)),
              ),
            if (widget.myId == _player1Id || widget.myId == _player2Id)
              TextButton(
                onPressed: () => _triggerEndSession('player'),
                child: const Text('Leave Hot Seat', style: TextStyle(color: _GC.red)),
              ),
          ]
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar(String name, bool isP1) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isP1 ? _GC.blue : _GC.red,
            border: Border.all(color: _GC.neon, width: 2),
            boxShadow: [BoxShadow(color: _GC.neon.withValues(alpha: 0.5), blurRadius: 10)],
          ),
          child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  bool _isLoadingGenders = false;

  void _openPlayerSelection() async {
    setState(() => _isLoadingGenders = true);
    
    try {
      final userIds = widget.allRoomMembers.map((m) => m.userId).toList();
      if (userIds.isNotEmpty) {
        final res = await _sb.from('bolroom_profiles').select('id, gender').filter('id', 'in', '(${userIds.join(',')})');
        final Map<String, String> genders = {};
        for (var row in res) {
          genders[row['id'].toString()] = row['gender']?.toString() ?? 'Not Set';
        }
        _memberGenders = genders;
      }
    } catch (e) {
      debugPrint('Error fetching genders: $e');
    }
    
    if (!mounted) return;
    setState(() => _isLoadingGenders = false);
    
    _showPlayerSelectionModal();
  }

  void _showPlayerSelectionModal() {
    String? s1;
    String? s2;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _GC.surface,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          bool isValid = false;
          String? error;
          
          if (s1 != null && s2 != null) {
            isValid = true;
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Select Players for Hot Seat', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.allRoomMembers.length,
                    itemBuilder: (ctx, i) {
                      final m = widget.allRoomMembers[i];
                      if (m.userId == widget.myId) return const SizedBox(); // Exclude host
                      final isSelected = s1 == m.userId || s2 == m.userId;
                      final gender = _memberGenders[m.userId] ?? 'Not Set';
                      
                      return ListTile(
                        leading: CircleAvatar(child: Text(m.name[0])),
                        title: Text(m.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(gender, style: TextStyle(color: _GC.txt.withValues(alpha: 0.5))),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: _GC.neon) : null,
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              if (s1 == m.userId) s1 = null;
                              if (s2 == m.userId) s2 = null;
                            } else {
                              if (s1 == null) {
                                s1 = m.userId;
                              } else {
                                s2 ??= m.userId;
                              }
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: isValid ? () async {
                    Navigator.pop(ctx);
                    
                    final n1 = widget.allRoomMembers.firstWhere((p)=>p.userId==s1, orElse: ()=> const TodParticipant(userId:'', name:'P1')).name;
                    final n2 = widget.allRoomMembers.firstWhere((p)=>p.userId==s2, orElse: ()=> const TodParticipant(userId:'', name:'P2')).name;
                    
                    String sId = 'bd_${DateTime.now().millisecondsSinceEpoch}';
                    try {
                      final res = await _sb.from('bolroom_blind_date_sessions').insert({
                        'room_id': widget.roomId,
                        'host_user_id': widget.myId,
                        'player_1_user_id': s1,
                        'player_2_user_id': s2,
                        'player_1_gender': _memberGenders[s1],
                        'player_2_gender': _memberGenders[s2],
                        'state': 'SESSION_ACTIVE',
                      }).select('id').single();
                      sId = res['id'] ?? sId;
                    } catch (e) {
                      debugPrint('Blind date DB insert (non-fatal): $e');
                    }
                    if (!mounted) return;
                    
                    final ev = {
                      'event': 'start_blind_date',
                      'session_id': sId,
                      'p1_id': s1,
                      'p2_id': s2,
                      'p1_name': n1,
                      'p2_name': n2,
                    };
                    widget.onBroadcast('start_blind_date', ev);
                    handleGameEvent(ev);
                    widget.onBroadcast('sys_msg', {'event': 'sys_msg', 'msg': '🔥 Blind Date is starting! $n1 & $n2 are on the Hot Seat!'});
                    
                  } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _GC.neon),
                  child: const Text('Confirm & Start', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        });
      }
    );
  }

  Widget _buildPollOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _GC.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _GC.neon, width: 2),
      ),
      child: Column(
        children: [
          const Text('AUDIENCE POLL', style: TextStyle(color: _GC.neon, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('$_pollTimeRemaining seconds left', style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _voteButton('fire', '🔥 Fire', 'I felt chemistry!'),
              _voteButton('freeze', '🥶 Freeze', 'Total friendzone'),
            ],
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _triggerClosePoll(),
              child: const Text('Close Poll Now', style: TextStyle(color: Colors.red)),
            ),
          ]
        ],
      ),
    );
  }
  
  Widget _voteButton(String type, String title, String sub) {
    final isSelected = _myVote == type;
    final color = type == 'fire' ? _GC.neon : _GC.blue;
    return GestureDetector(
      onTap: () {
        if (_myVote != null) return;
        setState(() => _myVote = type);
        widget.onBroadcast('vote_cast', {'event': 'vote_cast', 'choice': type, 'userId': widget.myId});
        if (widget.isHost) handleGameEvent({'event': 'vote_cast', 'choice': type});
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : _GC.bg,
          border: Border.all(color: isSelected ? color : _GC.border, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: _GC.txt.withValues(alpha: 0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final firePct = _totalVotes > 0 ? (_fireCount / _totalVotes) * 100 : 50.0;
    final freezePct = _totalVotes > 0 ? (_freezeCount / _totalVotes) * 100 : 50.0;
    final fireF = firePct.toInt().clamp(1, 99);
    final freezeF = freezePct.toInt().clamp(1, 99);
    
    String verdict;
    if (_totalVotes == 0) {
      verdict = '👻 No votes were cast!';
    } else if (firePct > 70) {
      verdict = '🔥 The room felt the spark! Chemistry confirmed.';
    } else if (firePct > 50) {
      verdict = '👀 Something was there… the room is intrigued.';
    } else if (firePct > 45) {
      verdict = '🤷 It\'s complicated. The room can\'t decide.';
    } else if (firePct > 30) {
      verdict = '😬 The room sensed a friendzone forming.';
    } else {
      verdict = '🥶 Friendzoned by the crowd. Hard pass.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _GC.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _GC.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('VOTE VERDICT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(verdict, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (_totalVotes > 0) ...[
            Row(
              children: [
                Expanded(
                  flex: fireF,
                  child: Container(height: 12, decoration: const BoxDecoration(color: _GC.neon, borderRadius: BorderRadius.horizontal(left: Radius.circular(6)))),
                ),
                Expanded(
                  flex: freezeF,
                  child: Container(height: 12, decoration: const BoxDecoration(color: _GC.blue, borderRadius: BorderRadius.horizontal(right: Radius.circular(6)))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🔥 $_fireCount (${firePct.toStringAsFixed(0)}%)', style: const TextStyle(color: _GC.neon)),
                Text('🥶 $_freezeCount (${freezePct.toStringAsFixed(0)}%)', style: const TextStyle(color: _GC.blue)),
              ],
            ),
            const SizedBox(height: 20),
            Text('✨ Compatibility: ${(firePct * 0.6 + 40).clamp(0, 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            Text('This score is for fun only. Real compatibility takes more than 3 minutes 😄', style: TextStyle(color: _GC.txt.withValues(alpha: 0.5), fontSize: 10, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _GC.neon),
            onPressed: () {
              final ev = {'event': 'reset_game'};
              widget.onBroadcast('reset_game', ev);
              handleGameEvent(ev);
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


