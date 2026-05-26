// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'bolroom_theme.dart';
import '../services/notification_service.dart';

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
  bool _loading = true;
  bool _isMember = false;
  String _myAnonName = 'Anonymous';
  String _myAvatarKey = 'default';

  String get _myId => _sb.auth.currentUser?.id ?? '';
  String get _communityId => widget.community['id'].toString();

  RealtimeChannel? _msgChannel;

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
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
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
      final res = await _sb.from('bolroom_community_members').select('id').eq('community_id', _communityId).eq('user_id', _myId).maybeSingle();
      if (mounted) setState(() => _isMember = res != null);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final res = await _sb.from('bolroom_community_messages').select('*').eq('community_id', _communityId).order('created_at', ascending: true).limit(200);
      if (mounted) { setState(() { _messages = List<Map<String, dynamic>>.from(res); _loading = false; }); _scrollToBottom(); }
    } catch (e) {
      debugPrint('Load messages: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await _sb.from('bolroom_community_members').select('*').eq('community_id', _communityId).order('joined_at');
      if (mounted) setState(() => _members = List<Map<String, dynamic>>.from(res));
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
        }
      },
    );
    _msgChannel!.subscribe();
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
        if (memberId != null && memberId != _myId) {
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
      setState(() => _isMember = true);
      _loadMembers();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.community['icon'] ?? '💬';
    final name = widget.community['name'] ?? 'Community';

    return Scaffold(
      backgroundColor: BolroomTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(icon, name),
            // Messages
            Expanded(
              child: _loading
                ? Center(child: CircularProgressIndicator(color: BolroomTheme.purple, strokeWidth: 2))
                : _messages.isEmpty
                  ? _buildEmptyChat()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                    ),
            ),
            // Input
            if (_isMember)
              _buildInputBar()
            else
              _buildJoinBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String icon, String name) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: BolroomTheme.bg,
        border: Border(bottom: BorderSide(color: BolroomTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new, color: BolroomTheme.textSecondary, size: 20),
          ),
          SizedBox(width: 12),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: BolroomTheme.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: TextStyle(fontSize: 20))),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${_members.length} members', style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 12)),
            ],
          )),
          GestureDetector(
            onTap: () => _showCommunityInfo(),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BolroomTheme.glassDecoration(radius: 10),
              child: Icon(Icons.info_outline, color: BolroomTheme.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
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
              decoration: BoxDecoration(
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
                  if (!isMe) Text(anonName, style: GoogleFonts.inter(color: BolroomTheme.purple, fontSize: 11, fontWeight: FontWeight.w700)),
                  if (!isMe) SizedBox(height: 3),
                  Text(text, style: GoogleFonts.inter(color: BolroomTheme.textPrimary, fontSize: 14, height: 1.4)),
                  SizedBox(height: 4),
                  Text(time, style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ),
          if (isMe) SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: BolroomTheme.bg,
        border: Border(top: BorderSide(color: BolroomTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BolroomTheme.glassDecoration(radius: 12),
            child: Icon(Icons.add, color: BolroomTheme.textSecondary, size: 20),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: BolroomTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BolroomTheme.border),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Message as $_myAnonName...',
                  hintStyle: GoogleFonts.inter(color: BolroomTheme.textHint, fontSize: 14),
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
              decoration: BoxDecoration(
                gradient: BolroomTheme.purpleGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BolroomTheme.surface,
        border: Border(top: BorderSide(color: BolroomTheme.borderSubtle)),
      ),
      child: GestureDetector(
        onTap: _joinCommunity,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: BolroomTheme.purpleGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: Text('Join Community to Chat', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.community['icon'] ?? '💬', style: TextStyle(fontSize: 48)),
        SizedBox(height: 16),
        Text('No messages yet', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Be the first to say something!', style: GoogleFonts.inter(color: BolroomTheme.textSecondary, fontSize: 14)),
      ]),
    );
  }

  void _showCommunityInfo() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: BolroomTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: BolroomTheme.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BolroomTheme.border, borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 20),
          Text(widget.community['icon'] ?? '💬', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(widget.community['name'] ?? '', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text(widget.community['description'] ?? 'No description', style: GoogleFonts.inter(color: BolroomTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _infoStat('${_members.length}', 'Members'),
            SizedBox(width: 32),
            _infoStat(widget.community['category'] ?? 'General', 'Category'),
          ]),
          SizedBox(height: 24),
          if (widget.community['rules']?.toString().isNotEmpty == true) ...[
            Align(alignment: Alignment.centerLeft, child: Text('RULES', style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
            SizedBox(height: 8),
            Text(widget.community['rules'] ?? '', style: GoogleFonts.inter(color: BolroomTheme.textSecondary, fontSize: 13)),
          ],
        ]),
      ),
    );
  }

  Widget _infoStat(String value, String label) {
    return Column(children: [
      Text(value, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 12)),
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
