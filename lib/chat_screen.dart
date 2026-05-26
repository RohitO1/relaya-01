import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messages_screen.dart';
import 'communities_screen.dart';

class ChatScreen extends StatefulWidget {
  final bool isBolroomMode;
  const ChatScreen({super.key, this.isBolroomMode = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  bool _isLoading = true;
  List<MapEntry<String, Map<String, dynamic>>> _conversations = [];
  final Map<String, Map<String, String>> _profileCache = {};
  final Map<String, int> _unreadCounts = {};
  final Set<String> _locallyDeletedChats = {};
  Timer? _pollingTimer;

  // UI state matching reference image
  int _selectedTab = 0; // 0 = Direct, 1 = Communities

  // Source tags for conversations (simulated based on index)
  static const _sourceTags = ['Explore', 'Rush-in', 'General', 'Activity', 'Explore', 'General'];

  @override
  void initState() {
    super.initState();
    _loadDeletedChats();
    _fetchConversations();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchConversations());
  }

  Future<void> _loadDeletedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('deleted_chats') ?? [];
    if (mounted) setState(() {
      _locallyDeletedChats.addAll(list);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    // Do NOT fetch direct messages while viewing Communities tab
    if (_selectedTab == 1) return;
    if (_myUid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final allMsgs = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.$_myUid,receiver_id.eq.$_myUid')
          .order('created_at', ascending: false)
          .limit(200);

      final Map<String, Map<String, dynamic>> convos = {};
      final Map<String, int> unreads = {};
      for (final m in (allMsgs as List)) {
        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];
        if (partnerId == null || _locallyDeletedChats.contains(partnerId)) continue;

        if (m['sender_id'] != _myUid && m['is_read'] == false) {
          unreads[partnerId] = (unreads[partnerId] ?? 0) + 1;
        }

        if (!convos.containsKey(partnerId)) {
          convos[partnerId] = Map<String, dynamic>.from(m);
        }
      }

      for (final partnerId in convos.keys) {
        if (!_profileCache.containsKey(partnerId)) {
          try {
            final d = await Supabase.instance.client
                .from('profiles')
                .select('name, full_name, avatar_url')
                .eq('id', partnerId)
                .maybeSingle();
            final avatarRaw = d?['avatar_url']?.toString() ?? '';
            _profileCache[partnerId] = {
              'name': (d?['name'] ?? d?['full_name'] ?? 'User') as String,
              'avatar': (avatarRaw.isNotEmpty && avatarRaw != 'null')
                  ? avatarRaw
                  : 'https://picsum.photos/seed/$partnerId/100',
            };
          } catch (_) {
            _profileCache[partnerId] = {'name': 'User', 'avatar': 'https://picsum.photos/seed/$partnerId/100'};
          }
        }
      }

      if (mounted) {
        setState(() {
          _unreadCounts.clear();
          _unreadCounts.addAll(unreads);
          _conversations = convos.entries.toList();
          _conversations.sort((a, b) {
            final dateA = DateTime.tryParse(a.value['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = DateTime.tryParse(b.value['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${diff.inDays ~/ 7}w ago';
    } catch (_) {
      return '';
    }
  }

  void _showComposeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF000000),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Text('New Message', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search people...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(child: Text('Followers list will appear here', style: TextStyle(color: Colors.white38))),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Future<void> _handleDelete(String partnerId) async {
    setState(() {
      _conversations.removeWhere((c) => c.key == partnerId);
      _locallyDeletedChats.add(partnerId);
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList('deleted_chats', _locallyDeletedChats.toList());
      
      await Supabase.instance.client
          .from('messages')
          .delete()
          .or('and(sender_id.eq.$_myUid,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$_myUid)');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete chat: $e')));
    }
  }

  Future<void> _handleMute(String partnerId) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat muted')));
  }

  void _showChatOptions(String partnerId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Options for $name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Chat', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDelete(partnerId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined, color: Colors.white),
                title: const Text('Mute Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleMute(partnerId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD — Matching reference image exactly
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title: "CHAT" ──
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 16, bottom: 12),
              child: Text(
                _selectedTab == 0 ? 'CHAT' : 'TEXT CAMPS',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            // ── Direct / Communities toggle tabs ──
            _buildTabToggle(),

            const SizedBox(height: 16),

            // ── Content area ──
            Expanded(
              child: _selectedTab == 1 
                ? const CommunitiesListWidget()
                : _myUid.isEmpty
                  ? const Center(child: Text('Please sign in to see messages', style: TextStyle(color: Colors.white54)))
                  : _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                    : _conversations.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _conversations.length,
                            padding: const EdgeInsets.only(top: 4, bottom: 100),
                            itemBuilder: (context, index) {
                              final convo = _conversations[index];
                              return _buildConversationRow(convo.key, convo.value, index);
                            },
                          ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Direct / Communities toggle ──
  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            // Direct tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTab = 0);
                  _fetchConversations(); // Refresh DMs when switching back to Direct
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? const Color(0xFFFF6B00) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      'Direct',
                      style: GoogleFonts.inter(
                        color: _selectedTab == 0 ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Communities tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? const Color(0xFFFF6B00) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Communities',
                          style: GoogleFonts.inter(
                            color: _selectedTab == 1 ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B00),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 2),
            ),
            child: const Icon(Icons.near_me_outlined, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text('No messages yet', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text('Start a conversation with your connections.', style: GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _showComposeSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: Text('Start a chat', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Conversation row matching reference exactly ──
  Widget _buildConversationRow(String partnerId, Map<String, dynamic> lastMsg, int index) {
    final profile = _profileCache[partnerId] ?? {'name': 'User', 'avatar': ''};
    final name = profile['name']!;
    final avatar = profile['avatar']!;

    final isImage = lastMsg['is_image'] == true;
    final msgText = isImage ? 'Sent an image' : (lastMsg['text'] as String? ?? '');
    final unreadCount = _unreadCounts[partnerId] ?? 0;
    final timeStr = _formatTimestamp(lastMsg['created_at']);
    final isUnread = unreadCount > 0;

    // Source tag for this conversation
    final sourceTag = _sourceTags[index % _sourceTags.length];
    final tagColor = _getTagColor(sourceTag);

    return InkWell(
        onLongPress: () => _showChatOptions(partnerId, name),
        onTap: () async {
          if (isUnread) {
            setState(() {
              lastMsg['is_read'] = true;
              _unreadCounts[partnerId] = 0;
            });
            Supabase.instance.client
                .from('messages')
                .update({'is_read': true})
                .eq('sender_id', partnerId)
                .eq('receiver_id', _myUid)
                .eq('is_read', false)
                .then((_) {});
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                targetUserId: partnerId,
                name: name,
                avatarUrl: avatar,
              ),
            ),
          );
          _fetchConversations();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with unread badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                  ),
                  if (isUnread)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B00),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$unreadCount',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Name, message, source tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      msgText,
                      style: GoogleFonts.inter(
                        color: isUnread ? Colors.white70 : const Color(0xFF7A7A7A),
                        fontSize: 13,
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Source tag chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sourceTag,
                        style: GoogleFonts.inter(
                          color: tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Timestamp
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7A7A7A),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'Explore':
        return const Color(0xFFFF6B00);
      case 'Rush-in':
        return const Color(0xFFFF3D00);
      case 'Activity':
        return const Color(0xFF4ADE80);
      case 'General':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

}
