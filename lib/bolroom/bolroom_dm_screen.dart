// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bolroom_theme.dart';
import 'bolroom_dm_chat_screen.dart';
import '../services/doodle_theme.dart';

class BolroomDmScreen extends StatefulWidget {
  const BolroomDmScreen({super.key});
  @override
  State<BolroomDmScreen> createState() => _BolroomDmScreenState();
}

class _BolroomDmScreenState extends State<BolroomDmScreen> {
  final _sb = Supabase.instance.client;
  String get _myId => _sb.auth.currentUser?.id ?? '';
  List<Map<String, dynamic>> _convos = [];
  bool _loading = true;
  String searchQuery = "";

  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color purpleDark = Color(0xFF7B2CBF);
  static const Color textMuted = Color(0xFF8E8B99);

  static LinearGradient neonGradient = const LinearGradient(
    colors: [Color(0xFFD433FF), Color(0xFF7B2CBF), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadConvos();
    _sb.channel('bolroom_dm_list').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'bolroom_dm_conversations',
      callback: (_) => _loadConvos(),
    ).subscribe();
  }

  @override
  void dispose() {
    try { _sb.removeChannel(_sb.channel('bolroom_dm_list')); } catch (_) {}
    super.dispose();
  }

  Map<String, int> _unreadCounts = {};

  Future<void> _loadConvos() async {
    try {
      final res = await _sb.from('bolroom_dm_conversations').select('*')
        .or('user1_id.eq.$_myId,user2_id.eq.$_myId')
        .order('last_message_at', ascending: false);
        
      final unreadRes = await _sb.from('bolroom_dm_messages')
        .select('conversation_id')
        .neq('sender_id', _myId)
        .eq('is_read', false);
        
      final counts = <String, int>{};
      for (var u in unreadRes) {
        final cid = u['conversation_id'].toString();
        counts[cid] = (counts[cid] ?? 0) + 1;
      }

      if (mounted) setState(() { 
        _convos = List<Map<String, dynamic>>.from(res); 
        _unreadCounts = counts;
        _loading = false; 
      });
    } catch (e) {
      debugPrint('Load convos: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _otherUserId(Map<String, dynamic> c) => c['user1_id'] == _myId ? c['user2_id'] : c['user1_id'];

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final d = DateTime.tryParse(ts);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _openChat(Map<String, dynamic> convo, String otherName) async {
    HapticFeedback.lightImpact();
    await Navigator.push(context, BolroomTheme.slideRoute(BolroomDmChatScreen(
      conversationId: convo['id'].toString(), partnerId: _otherUserId(convo), partnerName: otherName, partnerAvatarKey: 'default',
    )));
    _loadConvos();
  }

  void _showContextMenu(BuildContext context, String partnerId, String name) {
    final doodle = isDoodleMode(context);
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Icon(Icons.push_pin_outlined, color: doodle ? DoodleColors.brown : Colors.white),
                title: Text('Pin chat', style: doodle ? DoodleFonts.body(color: DoodleColors.brown) : const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); },
              ),
              ListTile(
                leading: Icon(Icons.archive_outlined, color: doodle ? DoodleColors.brown : Colors.white),
                title: Text('Archive chat', style: doodle ? DoodleFonts.body(color: DoodleColors.brown) : const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); },
              ),
              ListTile(
                leading: Icon(Icons.notifications_off_outlined, color: doodle ? DoodleColors.brown : Colors.white),
                title: Text('Mute notifications', style: doodle ? DoodleFonts.body(color: DoodleColors.brown) : const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); },
              ),
              ListTile(
                leading: Icon(Icons.mark_chat_unread_outlined, color: doodle ? DoodleColors.brown : Colors.white),
                title: Text('Mark as unread', style: doodle ? DoodleFonts.body(color: DoodleColors.brown) : const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: Text('Delete chat', style: doodle ? DoodleFonts.body(color: const Color(0xFFEF4444)) : const TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteChat(context, partnerId, name);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _confirmDeleteChat(BuildContext context, String partnerId, String name) {
    final doodle = isDoodleMode(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: doodle ? DoodleColors.paper : cardColor,
        title: Text('Delete chat with $name?', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : const TextStyle(color: Colors.white)),
        content: Text('This will delete the chat only for you.', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 16) : const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14) : const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _convos.removeWhere((e) => _otherUserId(e) == partnerId);
              });
            },
            child: Text('Delete', style: doodle ? DoodleFonts.body(color: const Color(0xFFEF4444), fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    return Scaffold(
      backgroundColor: doodle ? DoodleColors.paper : bgColor,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : purplePrimary, strokeWidth: 2))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader("Messages", Icons.edit_square, doodle),
                  _buildSearchBar("Search messages...", doodle, (val) {
                    setState(() => searchQuery = val);
                  }),
                  
                  // Message Requests Banner
                  if (searchQuery.isEmpty && _convos.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message Requests coming soon!')));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: doodle
                          ? DoodleDecorations.card(color: DoodleColors.cream)
                          : BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: Row(
                          children: [
                            Icon(Icons.person_add_alt_1_outlined, color: doodle ? DoodleColors.blue : purplePrimary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Message Requests', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: doodle ? DoodleColors.orange : purplePrimary, borderRadius: BorderRadius.circular(10)), child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : textMuted, size: 14),
                          ],
                        ),
                      ),
                    ),

                  // Online / Active Users Scroll
                  if (searchQuery.isEmpty && _convos.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
                      child: Text("Active Now", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    _buildActiveUsersRow(doodle),
                  ],

                  const SizedBox(height: 10),
                  
                  // Chat List
                  Expanded(
                    child: _convos.isEmpty 
                      ? _empty(doodle) 
                      : ListView.builder(
                          itemCount: _convos.length,
                          itemBuilder: (context, index) {
                            return _buildDynamicChatTile(_convos[index], index, doodle);
                          },
                        ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(String title, IconData actionIcon, bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: doodle
                    ? DoodleDecorations.card()
                    : BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                  child: Icon(Icons.arrow_back_ios_new, color: doodle ? DoodleColors.brown : Colors.white, size: 18),
                ),
              ),
              Text(
                title,
                style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 32) : const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showNewDm,
            child: Container(
              width: 44,
              height: 44,
              decoration: doodle
                ? DoodleDecorations.card()
                : BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)
                    ]
                  ),
              child: Icon(actionIcon, color: doodle ? DoodleColors.blue : purplePrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint, bool doodle, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: doodle
          ? DoodleDecorations.input().copyWith(color: DoodleColors.cream)
          : BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
        child: TextField(
          onChanged: onChanged,
          style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: Colors.white),
          decoration: doodle
            ? InputDecoration(
                hintText: hint,
                hintStyle: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14),
                prefixIcon: Icon(Icons.search, color: DoodleColors.brown.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              )
            : InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
        ),
      ),
    );
  }

  Widget _buildActiveUsersRow(bool doodle) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: _convos.take(5).toList().asMap().entries.map((entry) {
          int idx = entry.key;
          Map<String, dynamic> c = entry.value;
          final otherId = _otherUserId(c);
          return FutureBuilder<Map<String, dynamic>?>(
            future: _sb.from('bolroom_profiles').select('anon_name, aura_color').eq('id', otherId).maybeSingle(),
            builder: (_, snap) {
              final p = snap.data;
              final name = p?['anon_name'] ?? 'Anon';
              final auraHex = p?['aura_color'] ?? '#7856FF';
              Color aura = purpleDark;
              try { aura = Color(int.parse('FF${auraHex.replaceFirst('#', '')}', radix: 16)); } catch (_) {}
              
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => _openChat(c, name),
                  child: Column(
                    children: [
                      doodle ? CircleAvatar(backgroundColor: DoodleColors.orange, radius: 30, child: Icon(Icons.person, color: DoodleColors.cream, size: 30)) : _buildGlowingAvatar(aura, 60),
                      const SizedBox(height: 6),
                      Text(
                        name.length > 5 ? "${name.substring(0, 5)}.." : name,
                        style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: textMuted, fontSize: 12),
                      )
                    ],
                  ),
                ),
              );
            }
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDynamicChatTile(Map<String, dynamic> chat, int idx, bool doodle) {
    final otherId = _otherUserId(chat);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb.from('bolroom_profiles').select('anon_name, aura_color').eq('id', otherId).maybeSingle(),
      builder: (_, snap) {
        final p = snap.data;
        final name = p?['anon_name'] ?? 'Anonymous';
        if (searchQuery.isNotEmpty && !name.toLowerCase().contains(searchQuery.toLowerCase())) return SizedBox.shrink();
        
        final auraHex = p?['aura_color'] ?? '#7856FF';
        Color aura = purpleDark;
        try { aura = Color(int.parse('FF${auraHex.replaceFirst('#', '')}', radix: 16)); } catch (_) {}
        
        final lastMsg = chat['last_message'] ?? 'Started a chat';
        final timeStr = _timeAgo(chat['last_message_at']?.toString());
        
        int unreadCount = _unreadCounts[chat['id'].toString()] ?? 0;
        bool hasUnread = unreadCount > 0;
        bool isOnline = idx < 2;
        return Dismissible(
          key: Key(chat['id'].toString()),
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerLeft,
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: const Color(0xFF8B95A5), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.notifications_off_outlined, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat muted')));
              return false;
            }
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: cardColor,
                title: Text('Delete chat with $name?', style: const TextStyle(color: Colors.white)),
                content: const Text('This will delete the chat only for you.', style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
                ],
              ),
            );
            return confirm == true;
          },
          onDismissed: (direction) {
            setState(() {
              _convos.removeWhere((e) => e['id'] == chat['id']);
            });
          },
          child: InkWell(
            onTap: () => _openChat(chat, name),
            onLongPress: () => _showContextMenu(context, otherId, name),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: doodle
                ? BoxDecoration(
                    color: hasUnread ? DoodleColors.paper : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hasUnread ? DoodleColors.brown : Colors.transparent, width: hasUnread ? 2 : 0),
                    boxShadow: hasUnread ? [BoxShadow(color: DoodleColors.brown, offset: const Offset(2, 2))] : [],
                  )
                : BoxDecoration(
                    color: hasUnread ? cardColor.withValues(alpha: 0.8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: hasUnread ? Border.all(color: borderColor) : null,
                  ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      doodle ? CircleAvatar(backgroundColor: DoodleColors.orange, radius: 25, child: Icon(Icons.person, color: DoodleColors.cream, size: 25)) : _buildGlowingAvatar(aura, 50),
                      if (isOnline)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF00), // Online Green
                              shape: BoxShape.circle,
                              border: Border.all(color: doodle ? DoodleColors.paper : bgColor, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: doodle
                            ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18).copyWith(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600)
                            : TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: doodle
                            ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 14)
                            : TextStyle(
                                color: hasUnread ? Colors.white70 : textMuted,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeStr.isEmpty ? 'now' : timeStr,
                        style: doodle
                          ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 12).copyWith(fontWeight: FontWeight.bold)
                          : TextStyle(
                              color: hasUnread ? purplePrimary : textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: doodle
                            ? BoxDecoration(
                                color: DoodleColors.orange,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: DoodleColors.brown),
                              )
                            : BoxDecoration(
                                gradient: neonGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: purpleDark.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                          child: Text(
                            unreadCount > 99 ? "99+" : unreadCount.toString(),
                            style: doodle ? DoodleFonts.body(color: DoodleColors.cream, fontSize: 10).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGlowingAvatar(Color glowColor, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [glowColor, purpleDark, glowColor],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: bgColor),
          child: CircleAvatar(
            backgroundColor: cardColor,
            child: Icon(Icons.person, color: Colors.white30, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _empty(bool doodle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90, height: 90,
            decoration: doodle
              ? DoodleDecorations.card(color: DoodleColors.cream).copyWith(shape: BoxShape.circle)
              : BoxDecoration(shape: BoxShape.circle, color: cardColor, border: Border.all(color: Color(0xFFFF6B00).withValues(alpha: 0.15))),
            child: Icon(Icons.send_rounded, size: 40, color: doodle ? DoodleColors.blue : Color(0xFFFF6B00)),
          ),
          SizedBox(height: 18),
          Text('No messages yet', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 24) : TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Start a conversation anonymously', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 14) : TextStyle(color: textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  void _showNewDm() {
    final ctrl = TextEditingController();
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: doodle
            ? BoxDecoration(color: DoodleColors.paper, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: DoodleColors.brown, width: 2))
            : BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: borderColor)),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 22),
            Text('New Message', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 24) : const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('Search by anonymous name', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : const TextStyle(color: textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            Container(
              decoration: doodle
                ? DoodleDecorations.input().copyWith(color: DoodleColors.cream)
                : BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
              child: TextField(
                controller: ctrl, onChanged: (_) => setSheet(() {}),
                style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : textMuted, size: 20),
                  hintText: 'Search @username...', hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14) : TextStyle(color: textMuted.withValues(alpha: 0.5), fontSize: 14),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: ctrl.text.trim().length < 2
              ? Center(child: Text('Type at least 2 characters', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14) : const TextStyle(color: textMuted, fontSize: 13)))
              : FutureBuilder<List<dynamic>>(
                  future: _sb.from('bolroom_profiles').select('id, anon_name, avatar_key, aura_color').ilike('anon_name', '%${ctrl.text.trim()}%').neq('id', _myId).limit(20),
                  builder: (_, snap) {
                    if (!snap.hasData) return Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : purplePrimary, strokeWidth: 2));
                    final results = snap.data ?? [];
                    if (results.isEmpty) return Center(child: Text('No users found', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14) : const TextStyle(color: textMuted)));
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final u = results[i] as Map<String, dynamic>;
                        final name = u['anon_name'] ?? 'Anonymous';
                        final auraHex = u['aura_color'] ?? '#7856FF';
                        Color aura = purpleDark;
                        try { aura = Color(int.parse('FF${auraHex.replaceFirst('#', '')}', radix: 16)); } catch (_) {}
                        
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _startConversation(u['id'], name);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: doodle
                              ? DoodleDecorations.card(color: DoodleColors.cream)
                              : BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                            child: Row(children: [
                              doodle ? CircleAvatar(backgroundColor: DoodleColors.orange, radius: 20, child: Icon(Icons.person, color: DoodleColors.cream, size: 20)) : _buildGlowingAvatar(aura, 40),
                              const SizedBox(width: 12),
                              Text('@$name', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Icon(Icons.arrow_forward_ios, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : textMuted, size: 14),
                            ]),
                          ),
                        );
                      },
                    );
                  },
                )),
          ]),
        );
      }),
    );
  }

  Future<void> _startConversation(String otherId, String otherName) async {
    try {
      final existing = await _sb.from('bolroom_dm_conversations').select('*')
        .or('and(user1_id.eq.$_myId,user2_id.eq.$otherId),and(user1_id.eq.$otherId,user2_id.eq.$_myId)')
        .maybeSingle();
      if (existing != null) {
        Navigator.push(context, BolroomTheme.slideRoute(BolroomDmChatScreen(
          conversationId: existing['id'].toString(), partnerId: otherId, partnerName: otherName, partnerAvatarKey: 'default',
        )));
        _loadConvos();
        return;
      }
      final newConvo = await _sb.from('bolroom_dm_conversations').insert({
        'user1_id': _myId, 'user2_id': otherId,
      }).select().single();
      Navigator.push(context, BolroomTheme.slideRoute(BolroomDmChatScreen(
        conversationId: newConvo['id'].toString(), partnerId: otherId, partnerName: otherName, partnerAvatarKey: 'default',
      )));
      _loadConvos();
    } catch (e) { debugPrint('Start convo: $e'); }
  }
}


