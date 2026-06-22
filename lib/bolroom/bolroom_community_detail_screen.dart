// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bolroom_theme.dart';
import '../services/notification_service.dart';
import '../services/doodle_theme.dart';

/// ============================================================
/// Community Detail Screen — Chat inside a community
/// ============================================================
class BolroomCommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> community;
  const BolroomCommunityDetailScreen({super.key, required this.community});
  @override
  State<BolroomCommunityDetailScreen> createState() => _BolroomCommunityDetailScreenState();
}

class _BolroomCommunityDetailScreenState extends State<BolroomCommunityDetailScreen> {
  final _sb = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _loading = true;
  bool _isMember = false;
  String _myAnonName = 'Anonymous';
  String _myAvatarKey = 'default';
  
  String? _myRole;
  bool _hasPendingRequest = false;
  bool _isRequesting = false;

  final ValueNotifier<List<Map<String, dynamic>>> _membersNotifier = ValueNotifier([]);
  final ValueNotifier<String?> _myRoleNotifier = ValueNotifier(null);

  String get _myId => _sb.auth.currentUser?.id ?? '';
  String get _communityId => widget.community['id'].toString();

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _membersChannel;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMessages();
    _loadMembers();
    _checkMembership();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (_msgChannel != null) _sb.removeChannel(_msgChannel!);
    if (_membersChannel != null) _sb.removeChannel(_membersChannel!);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _membersNotifier.dispose();
    _myRoleNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final bp = await _sb.from('bolroom_profiles').select('anon_name, avatar_key').eq('id', _myId).maybeSingle();
      if (bp != null && mounted) {
        setState(() {
          _myAnonName = bp['anon_name'] ?? 'Anonymous';
          _myAvatarKey = bp['avatar_key'] ?? 'default';
        });
      }
    } catch (_) {}
  }

  Future<void> _checkMembership() async {
    try {
      final res = await _sb.from('bolroom_community_members').select('role').eq('community_id', _communityId).eq('user_id', _myId).maybeSingle();
      if (mounted) {
        setState(() {
          if (res == null) {
            _isMember = false;
            _myRole = null;
            _hasPendingRequest = false;
          } else {
            final role = res['role']?.toString();
            _myRole = role;
            if (role == 'pending') {
              _isMember = false;
              _hasPendingRequest = true;
            } else {
              _isMember = true;
              _hasPendingRequest = false;
            }
          }
        });
        _myRoleNotifier.value = _myRole;
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final res = await _sb.from('bolroom_community_messages').select('*').eq('community_id', _communityId).order('created_at', ascending: true).limit(200);
      if (res.isNotEmpty) {
        final latestMsgId = res.last['id'].toString();
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('seen_msg_$_communityId', latestMsgId);
        });
      }
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Load messages: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await _sb.from('bolroom_community_members').select('*').eq('community_id', _communityId).order('joined_at');
      final list = List<Map<String, dynamic>>.from(res);
      final userIds = list.map((m) => m['user_id'].toString()).toList();
      if (userIds.isNotEmpty) {
        final profs = await _sb.from('bolroom_profiles').select('id, anon_name, avatar_key').inFilter('id', userIds);
        final profMap = { for (var p in profs) p['id'].toString() : p as Map<String, dynamic> };
        if (mounted) {
          setState(() {
            _members = list;
            _memberProfiles = profMap;
          });
          _membersNotifier.value = list;
        }
      } else {
        if (mounted) {
          setState(() {
            _members = list;
            _memberProfiles = {};
          });
          _membersNotifier.value = list;
        }
      }
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _msgChannel = _sb.channel('community_msg_$_communityId').onPostgresChanges(
      event: PostgresChangeEvent.insert, schema: 'public', table: 'bolroom_community_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'community_id', value: _communityId),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty && mounted) {
          setState(() => _messages.add(payload.newRecord));
          _scrollToBottom();
          final latestMsgId = payload.newRecord['id'].toString();
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('seen_msg_$_communityId', latestMsgId);
          });
        }
      },
    );
    _msgChannel!.subscribe();

    _membersChannel = _sb.channel('community_mem_$_communityId').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'bolroom_community_members',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'community_id', value: _communityId),
      callback: (payload) {
        _loadMembers();
        _checkMembership();
      },
    );
    _membersChannel!.subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(100.ms, () {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: 200.ms, curve: Curves.easeOut);
    });
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty || !_isMember) return;
    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    try {
      await _sb.from('bolroom_community_messages').insert({
        'community_id': _communityId,
        'user_id': _myId,
        'anon_name': _myAnonName,
        'avatar_key': _myAvatarKey,
        'text': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      // Notify other members
      for (var m in _members) {
        final memberId = m['user_id']?.toString();
        if (memberId != null && memberId != _myId && m['role'] != 'pending') {
          try {
            NotificationService.sendNotification(
              userId: memberId,
              type: NotificationType.message,
              title: 'New Message in ${widget.community['name'] ?? 'Community'}',
              body: '$_myAnonName: $text',
              payload: {
                'community_id': _communityId,
                'sender_id': _myId,
                'bolroom_community': true,
              },
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Send: $e');
    }
  }

  Future<void> _joinCommunity() async {
    try {
      await _sb.from('bolroom_community_members').insert({
        'community_id': _communityId,
        'user_id': _myId,
        'role': 'member',
      });
      
      await _sb.from('bolroom_communities').update({
        'member_count': (widget.community['member_count'] ?? 0) + 1
      }).eq('id', _communityId);

      _checkMembership();
      _loadMembers();
    } catch (_) {}
  }

  Future<void> _toggleJoinRequest() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    try {
      if (_hasPendingRequest) {
        await _sb.from('bolroom_community_members').delete().eq('community_id', _communityId).eq('user_id', _myId);
        setState(() {
          _hasPendingRequest = false;
        });
      } else {
        await _sb.from('bolroom_community_members').insert({
          'community_id': _communityId,
          'user_id': _myId,
          'role': 'pending',
        });
        setState(() {
          _hasPendingRequest = true;
        });
      }
      await _checkMembership();
      await _loadMembers();
    } catch (e) {
      debugPrint('Toggle join request: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _approveRequest(String userId) async {
    try {
      await _sb.from('bolroom_community_members').update({'role': 'member'}).eq('community_id', _communityId).eq('user_id', userId);
      await _sb.from('bolroom_communities').update({
        'member_count': (widget.community['member_count'] ?? 0) + 1
      }).eq('id', _communityId);
      _loadMembers();
    } catch (e) {
      debugPrint('Approve request: $e');
    }
  }

  Future<void> _declineRequest(String userId) async {
    try {
      await _sb.from('bolroom_community_members').delete().eq('community_id', _communityId).eq('user_id', userId);
      _loadMembers();
    } catch (e) {
      debugPrint('Decline request: $e');
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await _sb.from('bolroom_community_members').delete().eq('community_id', _communityId).eq('user_id', userId);
      final currentCount = widget.community['member_count'] ?? 1;
      await _sb.from('bolroom_communities').update({
        'member_count': currentCount > 0 ? currentCount - 1 : 0
      }).eq('id', _communityId);
      _loadMembers();
    } catch (e) {
      debugPrint('Remove member: $e');
    }
  }

  Future<void> _leaveCommunity() async {
    try {
      await _sb.from('bolroom_community_members').delete().eq('community_id', _communityId).eq('user_id', _myId);
      final currentCount = widget.community['member_count'] ?? 1;
      await _sb.from('bolroom_communities').update({
        'member_count': currentCount > 0 ? currentCount - 1 : 0
      }).eq('id', _communityId);
      
      if (mounted) {
        Navigator.pop(context); // Close info sheet
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      debugPrint('Leave community: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    final icon = widget.community['icon'] ?? '💬';
    final name = widget.community['name'] ?? 'Community';
    final isPrivate = widget.community['is_private'] == true;

    return Scaffold(
      backgroundColor: doodle ? DoodleColors.paper : BolroomTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(icon, name, doodle),
            // Messages / Locked Overlay
            Expanded(
              child: _loading
                ? Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : BolroomTheme.purple, strokeWidth: 2))
                : (isPrivate && !_isMember)
                  ? _buildLockedOverlay(doodle)
                  : _messages.isEmpty
                    ? _buildEmptyChat(doodle)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i], doodle),
                      ),
            ),
            // Input
            if (_isMember)
              _buildInputBar(doodle)
            else
              _buildJoinBar(doodle),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedOverlay(bool doodle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: doodle
                ? DoodleDecorations.card(color: DoodleColors.orange).copyWith(shape: BoxShape.circle, borderRadius: null)
                : BoxDecoration(
                    color: BolroomTheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: BolroomTheme.purple.withValues(alpha: 0.2), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: BolroomTheme.purple.withValues(alpha: 0.1),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
              child: Icon(
                _hasPendingRequest ? Icons.hourglass_empty_rounded : Icons.lock_outline_rounded,
                color: doodle ? DoodleColors.cream : BolroomTheme.purple,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Private Community',
              style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 26) : GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This group is private. You must request approval from the host to join and view messages.',
              textAlign: TextAlign.center,
              style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : GoogleFonts.inter(
                color: BolroomTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _toggleJoinRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: doodle ? (_hasPendingRequest ? DoodleColors.paper : DoodleColors.blue) : (_hasPendingRequest ? const Color(0xFF1D1B26) : BolroomTheme.purple),
                  foregroundColor: doodle ? (_hasPendingRequest ? DoodleColors.brown : DoodleColors.cream) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: doodle ? BorderSide(color: DoodleColors.brown, width: 2) : (_hasPendingRequest ? const BorderSide(color: Colors.white10) : BorderSide.none),
                  ),
                  elevation: 0,
                ),
                child: _isRequesting
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: doodle ? DoodleColors.cream : Colors.white, strokeWidth: 2))
                    : Text(
                        _hasPendingRequest ? 'Cancel Join Request' : 'Request to Join',
                        style: doodle ? DoodleFonts.body(color: doodle ? (_hasPendingRequest ? DoodleColors.brown : DoodleColors.cream) : Colors.white, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _hasPendingRequest ? Colors.white70 : Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String icon, String name, bool doodle) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: doodle
        ? BoxDecoration(
            color: DoodleColors.paper,
            border: Border(bottom: BorderSide(color: DoodleColors.brown.withValues(alpha: 0.2))),
          )
        : BoxDecoration(
            color: BolroomTheme.bg,
            border: Border(bottom: BorderSide(color: BolroomTheme.borderSubtle)),
          ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new, color: doodle ? DoodleColors.brown : BolroomTheme.textSecondary, size: 20),
          ),
          SizedBox(width: 12),
          Container(
            width: 40, height: 40,
            decoration: doodle
              ? BoxDecoration(
                  color: DoodleColors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: DoodleColors.orange),
                )
              : BoxDecoration(
                  color: BolroomTheme.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
            child: Center(child: Text(icon, style: TextStyle(fontSize: 20))),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _membersNotifier,
                builder: (context, membersList, _) {
                  final activeCount = membersList.where((m) => m['role'] != 'pending').length;
                  return Text('$activeCount members', style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 12));
                },
              ),
            ],
          )),
          GestureDetector(
            onTap: () => _showCommunityInfo(),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: doodle ? DoodleDecorations.card() : BolroomTheme.glassDecoration(radius: 10),
              child: Icon(Icons.info_outline, color: doodle ? DoodleColors.blue : BolroomTheme.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool doodle) {
    final isMe = msg['user_id'] == _myId;
    final anonName = msg['anon_name'] ?? 'Anonymous';
    final avatarKey = msg['avatar_key'] ?? 'default';
    final preset = BolroomTheme.avatarPresets[avatarKey] ?? BolroomTheme.avatarPresets['default']!;
    final text = msg['text'] ?? '';
    final time = _formatTime(msg['created_at']);

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (preset['color'] as Color).withValues(alpha: 0.2),
                border: Border.all(color: (preset['color'] as Color).withValues(alpha: 0.3)),
              ),
              child: Center(child: Text(preset['icon'] as String, style: TextStyle(fontSize: 16))),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: doodle
                ? BoxDecoration(
                    color: isMe ? DoodleColors.cream : DoodleColors.paper,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 16 : 4),
                      topRight: Radius.circular(isMe ? 4 : 16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: DoodleColors.brown, width: 2),
                    boxShadow: [BoxShadow(color: DoodleColors.brown, offset: const Offset(2, 2))],
                  )
                : BoxDecoration(
                    color: isMe ? BolroomTheme.purple.withValues(alpha: 0.15) : BolroomTheme.card,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 16 : 4),
                      topRight: Radius.circular(isMe ? 4 : 16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: isMe ? BolroomTheme.purple.withValues(alpha: 0.15) : BolroomTheme.borderSubtle),
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) Text(anonName, style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: BolroomTheme.purple, fontSize: 11, fontWeight: FontWeight.w700)),
                  if (!isMe) SizedBox(height: 3),
                  Text(text, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16) : GoogleFonts.inter(color: BolroomTheme.textPrimary, fontSize: 14, height: 1.4)),
                  SizedBox(height: 4),
                  Text(time, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 10) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ),
          if (isMe) SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool doodle) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: doodle
        ? BoxDecoration(
            color: DoodleColors.paper,
            border: Border(top: BorderSide(color: DoodleColors.brown.withValues(alpha: 0.2))),
          )
        : BoxDecoration(
            color: BolroomTheme.bg,
            border: Border(top: BorderSide(color: BolroomTheme.borderSubtle)),
          ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: doodle ? DoodleDecorations.card(color: DoodleColors.cream).copyWith(shape: BoxShape.circle, borderRadius: null) : BolroomTheme.glassDecoration(radius: 12),
            child: Icon(Icons.add, color: doodle ? DoodleColors.brown : BolroomTheme.textSecondary, size: 20),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: doodle
                ? DoodleDecorations.input()
                : BoxDecoration(
                    color: BolroomTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: BolroomTheme.border),
                  ),
              child: TextField(
                controller: _msgCtrl,
                style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16) : GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Message as $_myAnonName...',
                  hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 16) : GoogleFonts.inter(color: BolroomTheme.textHint, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: doodle
                ? DoodleDecorations.card(color: DoodleColors.orange).copyWith(shape: BoxShape.circle, borderRadius: null)
                : BoxDecoration(
                    gradient: BolroomTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
              child: Icon(Icons.send_rounded, color: doodle ? DoodleColors.cream : Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinBar(bool doodle) {
    if (widget.community['is_private'] == true) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.all(16),
      decoration: doodle
        ? BoxDecoration(
            color: DoodleColors.paper,
            border: Border(top: BorderSide(color: DoodleColors.brown.withValues(alpha: 0.2))),
          )
        : BoxDecoration(
            color: BolroomTheme.surface,
            border: Border(top: BorderSide(color: BolroomTheme.borderSubtle)),
          ),
      child: GestureDetector(
        onTap: _joinCommunity,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: doodle
            ? DoodleDecorations.card(color: DoodleColors.blue).copyWith(borderRadius: BorderRadius.circular(16))
            : BoxDecoration(
                gradient: BolroomTheme.purpleGradient,
                borderRadius: BorderRadius.circular(16),
              ),
          child: Center(child: Text('Join Community to Chat', style: doodle ? DoodleFonts.body(color: DoodleColors.cream, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        ),
      ),
    );
  }

  Widget _buildEmptyChat(bool doodle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.community['icon'] ?? '💬', style: TextStyle(fontSize: 48)),
        SizedBox(height: 16),
        Text('No messages yet', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 22) : GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Be the first to say something!', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : GoogleFonts.inter(color: BolroomTheme.textSecondary, fontSize: 14)),
      ]),
    );
  }

  Widget _buildAvatarWidget(String avatarKey, double size) {
    final preset = BolroomTheme.avatarPresets[avatarKey] ?? BolroomTheme.avatarPresets['default']!;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (preset['color'] as Color).withValues(alpha: 0.2),
        border: Border.all(color: (preset['color'] as Color).withValues(alpha: 0.3)),
      ),
      child: Center(child: Text(preset['icon'] as String, style: TextStyle(fontSize: size * 0.5))),
    );
  }

  void _showCommunityInfo() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _membersNotifier,
              builder: (context, membersList, _) {
                final isHost = widget.community['creator_id'] == _myId;
                
                final activeMembers = membersList.where((m) => m['role'] != 'pending').toList();
                final pendingRequests = membersList.where((m) => m['role'] == 'pending').toList();

                return Container(
                  decoration: doodle
                    ? BoxDecoration(
                        color: DoodleColors.paper,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: Border.all(color: DoodleColors.brown, width: 2),
                      )
                    : BoxDecoration(
                        color: BolroomTheme.bg,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: Border.all(color: BolroomTheme.border),
                      ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : BolroomTheme.border, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 20),
                      Center(child: Text(widget.community['icon'] ?? '💬', style: const TextStyle(fontSize: 48))),
                      const SizedBox(height: 12),
                      Center(child: Text(widget.community['name'] ?? '', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 26) : GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 8),
                      Center(child: Text(widget.community['description'] ?? 'No description', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : GoogleFonts.inter(color: BolroomTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _infoStat('${activeMembers.length}', 'Members', doodle),
                          const SizedBox(width: 32),
                          _infoStat(widget.community['category'] ?? 'General', 'Category', doodle),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (widget.community['rules']?.toString().isNotEmpty == true) ...[
                        Text('RULES', style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 12).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text(widget.community['rules'] ?? '', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : GoogleFonts.inter(color: BolroomTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 24),
                      ],
                      
                      // Pending Requests Section
                      if (isHost && pendingRequests.isNotEmpty) ...[
                        Text('PENDING JOIN REQUESTS (${pendingRequests.length})', style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 12).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5) : GoogleFonts.inter(color: BolroomTheme.purple, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pendingRequests.length,
                          itemBuilder: (ctx, idx) {
                            final req = pendingRequests[idx];
                            final reqId = req['user_id'].toString();
                            final prof = _memberProfiles[reqId] ?? {
                              'anon_name': 'Anonymous',
                              'avatar_key': 'default'
                            };
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  _buildAvatarWidget(prof['avatar_key'] ?? 'default', 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      prof['anon_name'] ?? 'Anonymous',
                                      style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _approveRequest(reqId),
                                    child: Text('Accept', style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () => _declineRequest(reqId),
                                    child: Text('Decline', style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Active Members Section
                      Text('MEMBERS (${activeMembers.length})', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeMembers.length,
                        itemBuilder: (ctx, idx) {
                          final mem = activeMembers[idx];
                          final memId = mem['user_id'].toString();
                          final isMemHost = mem['role'] == 'host' || memId == widget.community['creator_id'];
                          final prof = _memberProfiles[memId] ?? {
                            'anon_name': 'Anonymous',
                            'avatar_key': 'default'
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                _buildAvatarWidget(prof['avatar_key'] ?? 'default', 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        prof['anon_name'] ?? 'Anonymous',
                                        style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      if (isMemHost) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: doodle
                                            ? BoxDecoration(
                                                color: DoodleColors.orange.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: DoodleColors.orange),
                                              )
                                            : BoxDecoration(
                                                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.star, color: doodle ? DoodleColors.orange : const Color(0xFFFFD700), size: 10),
                                              const SizedBox(width: 2),
                                              Text('Host', style: TextStyle(color: doodle ? DoodleColors.orange : const Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isHost && !isMemHost)
                                  GestureDetector(
                                    onTap: () => _removeMember(memId),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: doodle
                                        ? BoxDecoration(
                                            color: DoodleColors.orange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: DoodleColors.orange.withValues(alpha: 0.4)),
                                          )
                                        : BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                                          ),
                                      child: Text('Remove', style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Leave Button
                      if (!isHost) ...[
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _leaveCommunity,
                            icon: Icon(Icons.logout, color: doodle ? DoodleColors.orange : Colors.redAccent, size: 18),
                            label: Text('Leave Community', style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 14)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: doodle ? DoodleColors.orange : Colors.redAccent, width: doodle ? 2 : 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _infoStat(String value, String label, bool doodle) {
    return Column(children: [
      Text(value, style: doodle ? DoodleFonts.heading(color: DoodleColors.blue, fontSize: 24) : GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      SizedBox(height: 4),
      Text(label, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 12) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 12)),
    ]);
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) { return ''; }
  }
}
