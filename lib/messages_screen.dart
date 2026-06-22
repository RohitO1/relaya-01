// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'widgets/skeleton_loaders.dart';
import 'image_upload_service.dart';
import 'bot_chat_screen.dart';
import 'knock_review_screen.dart';
import 'services/notification_service.dart';
import 'main.dart'; // For CosmicBackgroundPainter
import 'communities_screen.dart';
import 'services/doodle_theme.dart';

// =============================================================================
// SHARED HELPERS
// =============================================================================

/// Returns the correct ImageProvider regardless of whether [url] is an HTTPS
/// URL or a base64 data URI (data:image/jpeg;base64,...). This ensures photos
/// uploaded via the web (data URI) also display correctly on native Android.
ImageProvider _safeImageProvider(String url) {
  if (url.startsWith('data:image')) {
    final b64 = url.split(',').last;
    return MemoryImage(base64Decode(b64));
  }
  return NetworkImage(url);
}

// =============================================================================
// ADVANCED MESSAGES SCREEN
// =============================================================================
class MessagesScreen extends StatefulWidget {
  final String? initialFilter;
  const MessagesScreen({super.key, this.initialFilter});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeChip = 'All';
  final List<String> _chips = ['All', 'Compliments', 'Knocks', 'Rush-In', 'Activity', 'Events', 'Companion', 'Groups'];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _activeChip = widget.initialFilter!;
    }
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : const Color(0xFF030305),
      body: Stack(
        children: [
          // Ambient Background
          Positioned.fill(
            child: isDoodleMode(context) ? Container(color: DoodleColors.cream) : CustomPaint(
              painter: CosmicBackgroundPainter(0.5), // Static value for background
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── WhatsApp Style Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Text('Meetra', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white, letterSpacing: -0.5)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.qr_code_scanner, color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white), onPressed: () {}),
                  IconButton(icon: Icon(Icons.camera_alt_outlined, color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white), onPressed: () {}),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDoodleMode(context) ? DoodleColors.paper : const Color(0xFF1B202D), // Dark slate search bg
                  borderRadius: BorderRadius.circular(24),
                  border: isDoodleMode(context) ? Border.all(color: DoodleColors.cardBorder) : null,
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ask Meetra AI or Search',
                    hintStyle: TextStyle(color: isDoodleMode(context) ? DoodleColors.textMuted : const Color(0xFF8B95A5), fontSize: 15),
                    prefixIcon: Icon(Icons.search, color: isDoodleMode(context) ? DoodleColors.textMuted : const Color(0xFF8B95A5), size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: Icon(Icons.close, color: isDoodleMode(context) ? DoodleColors.textMuted : const Color(0xFF8B95A5), size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Filter Chips ──
            SizedBox(
              height: 36,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _chips.length,
                itemBuilder: (context, index) {
                  final chip = _chips[index];
                  final isActive = _activeChip == chip;
                  final doodle = isDoodleMode(context);
                  return GestureDetector(
                    onTap: () => setState(() => _activeChip = chip),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? (doodle ? DoodleColors.amber : const Color(0xFF0D2B22)) : (doodle ? DoodleColors.paper : const Color(0xFF1B202D)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? (doodle ? DoodleColors.amber : const Color(0xFFFF6B00)) : (doodle ? DoodleColors.cardBorder : Colors.transparent)),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: isActive ? (doodle ? DoodleColors.textPrimary : const Color(0xFFFF6B00)) : (doodle ? DoodleColors.textMuted : const Color(0xFF8B95A5)),
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // ── Main Content ──
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ai_fab',
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BotChatScreen()));
        },
        backgroundColor: isDoodleMode(context) ? DoodleColors.amber : const Color(0xFF1B202D),
        elevation: 4,
        child: isDoodleMode(context) ? const Icon(Icons.smart_toy_rounded, color: DoodleColors.textPrimary, size: 24) : ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFFF0055)],
          ).createShader(bounds),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_activeChip) {
      case 'Compliments':
        return _ComplimentsView(searchQuery: _searchQuery);
      case 'Groups':
        return CommunitiesListWidget(searchQuery: _searchQuery);
      case 'Knocks':
        return _KnocksView(searchQuery: _searchQuery);
      case 'Rush-In':
        return _ActivityChatsView(searchQuery: _searchQuery, viewType: 'Rush-In');
      case 'Activity':
        return _ActivityChatsView(searchQuery: _searchQuery, viewType: 'Activity');
      case 'Events':
        return _ActivityChatsView(searchQuery: _searchQuery, viewType: 'Events');
      case 'Companion':
        return _CompanionView(searchQuery: _searchQuery);
      default:
        // 'All', 'Unread', 'Favourites' (Unread and Favourites handled by filter inside _ChatsView)
        return ChatsView(searchQuery: _searchQuery, filter: _activeChip);
    }
  }
}

// =============================================================================
// CHATS VIEW — Real Supabase Conversations
// =============================================================================
class ChatsView extends StatefulWidget {
  final String searchQuery;
  final String filter;
  const ChatsView({required this.searchQuery, this.filter = 'All'});

  @override
  State<ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<ChatsView> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final Map<String, Map<String, String>> _profileCache = {};
  List<MapEntry<String, Map<String, dynamic>>> _conversations = [];
  bool _loading = true;
  Timer? _pollingTimer;
  final Set<String> _archivedIds = {};
  final Map<String, DateTime?> _mutedUntilMap = {};
  final Set<String> _pinnedIds = {};
  final Set<String> _manuallyUnreadIds = {};
  final Map<String, int> _unreadCounts = {};
  RealtimeChannel? _presenceChannel;
  final Set<String> _onlineUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchConversations());
    _initPresence();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_presenceChannel != null) {
      Supabase.instance.client.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }

  Future<Map<String, String>> _getProfile(String uid) async {
    if (_profileCache.containsKey(uid)) return _profileCache[uid]!;
    try {
      final d = await Supabase.instance.client.from('profiles').select('name, full_name, avatar_url').eq('id', uid).maybeSingle();
      final avatarRaw = d?['avatar_url']?.toString() ?? '';
      final result = {
        'name': (d?['name'] ?? d?['full_name'] ?? 'User') as String,
        'avatar': (avatarRaw.isNotEmpty && avatarRaw != 'null') ? avatarRaw : 'https://picsum.photos/seed/$uid/100',
      };
      _profileCache[uid] = result;
      return result;
    } catch (_) {
      return {'name': 'User', 'avatar': 'https://picsum.photos/seed/$uid/100'};
    }
  }

  Future<void> _fetchConversations() async {
    if (_myUid.isEmpty) return;
    try {
      final allMsgs = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.$_myUid,receiver_id.eq.$_myUid')
          .order('created_at', ascending: false)
          .limit(200);

      final Map<String, Map<String, dynamic>> convos = {};
      final Map<String, int> unread = {};
      for (final m in (allMsgs as List)) {
        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];
        if (partnerId == null) continue;
        if (!convos.containsKey(partnerId)) {
          convos[partnerId] = Map<String, dynamic>.from(m);
        }
        if (m['sender_id'] != _myUid && m['is_read'] != true) {
          unread[partnerId] = (unread[partnerId] ?? 0) + 1;
        }
      }

      // Fetch pending hangout requests to show them in Chats inbox even if messages list is empty due to RLS
      try {
        final hangoutReqs = await Supabase.instance.client
            .from('requests')
            .select()
            .eq('target_type', 'hangout')
            .eq('status', 'pending')
            .or('sender_id.eq.$_myUid,target_id.eq.$_myUid');

        for (final req in (hangoutReqs as List)) {
          final partnerId = req['sender_id'] == _myUid ? req['target_id'] as String : req['sender_id'] as String;
          if (!convos.containsKey(partnerId)) {
            // Synthesize a premium Hangout invite message placeholder
            convos[partnerId] = {
              'id': 9999999999 + req.hashCode, // Unique ID
              'sender_id': req['sender_id'],
              'receiver_id': req['target_id'],
              'text': '⚡HANGOUT_INVITE|🍕|Invited you to hang out!|now',
              'is_image': false,
              'is_read': false,
              'created_at': req['created_at'] ?? DateTime.now().toIso8601String(),
            };
            if (req['sender_id'] != _myUid) {
              unread[partnerId] = (unread[partnerId] ?? 0) + 1;
            }
          }
        }
      } catch (e) {
        debugPrint('Fetch pending hangout requests error: $e');
      }

      // Pre-fetch all profiles
      for (final partnerId in convos.keys) {
        await _getProfile(partnerId);
      }

      if (mounted) {
        setState(() {
          _conversations = convos.entries.toList();
          _unreadCounts.clear();
          _unreadCounts.addAll(unread);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch conversations error: $e');
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  void _initPresence() {
    if (_myUid.isEmpty) return;
    try {
      _presenceChannel = Supabase.instance.client.channel('global_presence');
      _presenceChannel!.onPresenceSync((_) {
        if (!mounted) return;
        final List<SinglePresenceState> state = _presenceChannel!.presenceState();
        final Set<String> onlineUids = {};
        for (final singleState in state) {
          for (final presence in singleState.presences) {
            final uid = presence.payload['user_id']?.toString();
            if (uid != null) onlineUids.add(uid);
          }
        }
        setState(() {
          _onlineUsers.clear();
          _onlineUsers.addAll(onlineUids);
        });
      }).subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _presenceChannel!.track({'user_id': _myUid});
        }
      });
    } catch (e) {
      debugPrint('Presence init error: $e');
    }
  }

  void _showContextMenu(BuildContext context, String partnerId, String name) {
    HapticFeedback.mediumImpact();
    final isPinned = _pinnedIds.contains(partnerId);
    final isArchived = _archivedIds.contains(partnerId);
    final isMutedVal = _mutedUntilMap[partnerId];
    final isMuted = isMutedVal != null && isMutedVal.isAfter(DateTime.now());

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.white),
                title: Text(isPinned ? 'Unpin chat' : 'Pin chat', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isPinned) {
                      _pinnedIds.remove(partnerId);
                    } else {
                      if (_pinnedIds.length >= 3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You can only pin up to 3 chats'), backgroundColor: Color(0xFFFF0055)),
                        );
                      } else {
                        _pinnedIds.add(partnerId);
                      }
                    }
                  });
                },
              ),
              ListTile(
                leading: Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: Colors.white),
                title: Text(isArchived ? 'Unarchive chat' : 'Archive chat', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isArchived) {
                      _archivedIds.remove(partnerId);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat unarchived')));
                    } else {
                      _archivedIds.add(partnerId);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat archived')));
                    }
                  });
                },
              ),
              ListTile(
                leading: Icon(isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: Colors.white),
                title: Text(isMuted ? 'Unmute notifications' : 'Mute notifications', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isMuted) {
                    setState(() => _mutedUntilMap.remove(partnerId));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications unmuted')));
                  } else {
                    _showMuteOptions(context, partnerId);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined, color: Colors.white),
                title: const Text('Mark as unread', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _manuallyUnreadIds.add(partnerId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as unread')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Delete chat', style: TextStyle(color: Color(0xFFEF4444))),
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

  void _showMuteOptions(BuildContext context, String partnerId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Mute Notifications', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('For 1 Hour', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  setState(() => _mutedUntilMap[partnerId] = DateTime.now().add(const Duration(hours: 1)));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted for 1 Hour')));
                },
              ),
              ListTile(
                title: const Text('For 8 Hours', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  setState(() => _mutedUntilMap[partnerId] = DateTime.now().add(const Duration(hours: 8)));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted for 8 Hours')));
                },
              ),
              ListTile(
                title: const Text('Until I turn it back on', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  setState(() => _mutedUntilMap[partnerId] = DateTime.now().add(const Duration(days: 3650)));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted indefinitely')));
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _confirmDeleteChat(BuildContext context, String partnerId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B202D),
        title: Text('Delete chat with $name?', style: const TextStyle(color: Colors.white)),
        content: const Text('This will delete the chat for both users.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final backup = List<MapEntry<String, Map<String, dynamic>>>.from(_conversations);
              setState(() {
                _conversations.removeWhere((e) => e.key == partnerId);
              });
              try {
                await Supabase.instance.client
                    .from('messages')
                    .delete()
                    .or('and(sender_id.eq.$_myUid,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$_myUid)');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conversation deleted from database')));
                }
              } catch (e) {
                if (mounted) setState(() => _conversations = backup);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: const Color(0xFFFF0055)));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid.isEmpty) {
      return const Center(child: Text('Please sign in to see messages', style: TextStyle(color: Colors.white38)));
    }

    if (_loading) return _buildShimmer();

    // Apply Chip Filter & Archive Filtering & Pinned sorting
    var filtered = _conversations.where((entry) {
      // Filter out archived conversations from main list
      if (_archivedIds.contains(entry.key)) return false;

      if (widget.searchQuery.isNotEmpty) {
        final profile = _profileCache[entry.key];
        final name = profile?['name'] ?? '';
        return name.toLowerCase().contains(widget.searchQuery);
      }
      
      if (widget.filter == 'Unread') {
        final isMe = entry.value['sender_id'] == _myUid;
        final isRead = entry.value['is_read'] == true;
        final dbUnread = _unreadCounts[entry.key] ?? 0;
        final isManualUnread = _manuallyUnreadIds.contains(entry.key);
        final unreadCount = isManualUnread ? 1 : ((!isMe && !isRead) ? dbUnread : 0);
        return unreadCount > 0;
      }
      if (widget.filter == 'Favourites') {
        return entry.key.hashCode % 5 == 0; 
      }
      return true;
    }).toList();

    // Apply sorting: pinned chats first, then maintain recency
    filtered.sort((a, b) {
      final aPinned = _pinnedIds.contains(a.key);
      final bPinned = _pinnedIds.contains(b.key);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    if (filtered.isEmpty && widget.searchQuery.isNotEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded, color: Color(0xFF3B82F6), size: 48),
              ),
              const SizedBox(height: 24),
              const Text('No Conversations Found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Try searching for a different\\nname or username.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
    }

    // Include static items if 'All' is selected and no search query
    final bool showStaticRows = widget.filter == 'All' && widget.searchQuery.isEmpty;
    final int itemCount = filtered.length + (showStaticRows ? 2 : 0);

    return RefreshIndicator(
      onRefresh: _fetchConversations,
      color: const Color(0xFFFF6B00),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: itemCount,
        itemBuilder: (ctx, i) {
          if (showStaticRows) {
            if (i == 0) {
              return ListTile(
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8.0, right: 16.0),
                  child: Icon(Icons.lock_outline, color: Color(0xFF8B95A5), size: 24),
                ),
                title: const Text('Locked chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Locked vault coming soon! 🔒')));
                },
              );
            }
            if (i == 1) {
              return ListTile(
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8.0, right: 16.0),
                  child: Icon(Icons.archive_outlined, color: Color(0xFF8B95A5), size: 24),
                ),
                title: const Text('Archived', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                trailing: _archivedIds.isNotEmpty ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF8B95A5).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('${_archivedIds.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ) : null,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _ArchivedChatsScreen(
                      archivedIds: _archivedIds,
                      conversations: _conversations,
                      profileCache: _profileCache,
                      unreadCounts: _unreadCounts,
                      manuallyUnreadIds: _manuallyUnreadIds,
                      onUnarchive: (id) => setState(() => _archivedIds.remove(id)),
                    ),
                  ));
                  _fetchConversations();
                },
              );
            }
          }

          final dataIndex = showStaticRows ? i - 2 : i;
          final partnerId = filtered[dataIndex].key;
          final lastMsg = filtered[dataIndex].value;
          final profile = _profileCache[partnerId] ?? {'name': 'Loading...', 'avatar': ''};
          final name = profile['name']!;
          final avatar = profile['avatar']!;

          final isMe = lastMsg['sender_id'] == _myUid;
          final isImage = lastMsg['is_image'] == true;
          String preview = '';
          final isHang = lastMsg['text'] != null && (lastMsg['text'] as String).startsWith('⚡HANGOUT_INVITE|');
          if (isHang) {
            final parts = (lastMsg['text'] as String).split('|');
            final act = parts.length > 2 ? parts[2] : 'hangout';
            preview = isMe ? '⚡ Invited to hang for $act' : '⚡ Invited you to hang for $act';
          } else {
            preview = isImage ? '📸 Photo' : (lastMsg['text'] as String? ?? '');
          }
          final isRead = lastMsg['is_read'] == true;
          final isPinned = _pinnedIds.contains(partnerId);
          final isMutedVal = _mutedUntilMap[partnerId];
          final isMuted = isMutedVal != null && isMutedVal.isAfter(DateTime.now());
          final isManualUnread = _manuallyUnreadIds.contains(partnerId);
          final dbUnread = _unreadCounts[partnerId] ?? 0;
          final unreadCount = isManualUnread ? 1 : ((!isMe && !isRead) ? dbUnread : 0);

          // Time formatting
          String timeLabel = '';
          final createdAt = lastMsg['created_at'] as String?;
          if (createdAt != null) {
            try {
              final dt = DateTime.parse(createdAt).toLocal();
              final diff = DateTime.now().difference(dt);
              if (diff.inDays == 0) {
                // Formatting like 7:14 pm
                int hour = dt.hour;
                final String period = hour >= 12 ? 'pm' : 'am';
                if (hour > 12) hour -= 12;
                if (hour == 0) hour = 12;
                final minute = dt.minute.toString().padLeft(2, '0');
                timeLabel = '$hour:$minute $period';
              } else if (diff.inDays == 1) {
                timeLabel = 'Yesterday';
              } else {
                timeLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
              }
            } catch (_) {}
          }

          return GestureDetector(
            onTap: () async {
              setState(() {
                _manuallyUnreadIds.remove(partnerId);
                _unreadCounts[partnerId] = 0;
              });
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatDetailScreen(targetUserId: partnerId, name: name, avatarUrl: avatar),
              ));
              _fetchConversations();
            },
            onLongPress: () => _showContextMenu(context, partnerId, name),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: unreadCount > 0 ? const Color(0xFFFF6B00).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
                boxShadow: unreadCount > 0 ? [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.05), blurRadius: 10)] : null,
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: avatar.isNotEmpty ? _safeImageProvider(avatar) : null,
                        backgroundColor: const Color(0xFF1B202D),
                        child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null,
                      ),
                      if (_onlineUsers.contains(partnerId))
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF66),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0D0F14), width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Text(timeLabel, style: TextStyle(color: unreadCount > 0 ? const Color(0xFFFF6B00) : const Color(0xFF8B95A5), fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isMe) ...[
                              Icon(Icons.done_all, size: 16, color: isRead ? const Color(0xFF3B82F6) : const Color(0xFF8B95A5)), // Blue ticks
                              const SizedBox(width: 4),
                            ],
                            if (isImage) ...[
                              const Icon(Icons.image, size: 14, color: Color(0xFF8B95A5)),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                preview,
                                style: const TextStyle(color: Color(0xFF8B95A5), fontSize: 14),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMuted) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.volume_off, size: 16, color: Color(0xFF8B95A5)),
                            ],
                            if (isPinned) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.push_pin, size: 16, color: Color(0xFF8B95A5)),
                            ],
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                                child: Text('$unreadCount', style: const TextStyle(color: Color(0xFF0D0F14), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ACTIVITY CHATS — Rush-In / Event Participation Conversations
// =============================================================================
class _ActivityChatsView extends StatefulWidget {
  final String searchQuery;
  final String viewType;
  const _ActivityChatsView({required this.searchQuery, required this.viewType});

  @override
  State<_ActivityChatsView> createState() => _ActivityChatsViewState();
}

class _ActivityChatsViewState extends State<_ActivityChatsView> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      // Fetch activities I've joined (via requests table)
      final myRequests = await Supabase.instance.client
          .from('requests')
          .select('target_id')
          .eq('sender_id', _myUid)
          .eq('status', 'approved');

      final targetIds = (myRequests as List).map((r) => r['target_id']).whereType<String>().toList();

      // Also fetch activities I've created
      final myActivities = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('user_id', _myUid);

      final joinedActivities = targetIds.isNotEmpty
          ? await Supabase.instance.client
              .from('activities')
              .select()
              .inFilter('id', targetIds)
          : [];

      if (mounted) {
        setState(() {
          var combined = [...(myActivities as List).cast<Map<String, dynamic>>(), ...(joinedActivities.cast<Map<String, dynamic>>())];
          
          // Filter based on viewType using activity_type column
          if (widget.viewType == 'Rush-In') {
            combined = combined.where((a) => a['is_rush_in'] == true).toList();
          } else if (widget.viewType == 'Activity') {
            combined = combined.where((a) => a['is_rush_in'] == false && a['activity_type'] == 'activity').toList();
          } else if (widget.viewType == 'Events') {
            combined = combined.where((a) => a['is_rush_in'] == false && a['activity_type'] == 'event').toList();
          }

          _activities = combined;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Activity chat load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SkeletonLoaders.chatListSkeleton(doodle: isDoodleMode(context));
    }

    final filtered = _activities.where((a) {
      final title = (a['title'] as String? ?? '').toLowerCase();
      return widget.searchQuery.isEmpty || title.contains(widget.searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      String emptyText = 'No chats found';
      String emptySub = 'Join or create one to start chatting!';
      IconData emptyIcon = Icons.groups;
      
      if (widget.viewType == 'Rush-In') {
        emptyText = 'No active Rush-Ins';
        emptySub = 'Join a spontaneous Rush-In nearby!';
        emptyIcon = Icons.bolt;
      } else if (widget.viewType == 'Events') {
        emptyText = 'No Events booked';
        emptySub = 'RSVP to an event to chat with attendees.';
        emptyIcon = Icons.event;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            Text(emptyText, style: const TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(emptySub, style: const TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final act = filtered[i];
        final title = act['title'] as String? ?? 'Activity';
        final desc = act['description'] as String? ?? '';
        final isHost = act['user_id'] == _myUid;

        final bool isRushIn = act['is_rush_in'] == true;
        bool isCompleted = false;
        bool isClosed = false;

        try {
          if (isRushIn) {
            final expiresAtStr = act['expires_at'] as String?;
            if (expiresAtStr != null) {
              final expiresAt = DateTime.parse(expiresAtStr).toLocal();
              if (DateTime.now().isAfter(expiresAt)) {
                isCompleted = true;
                if (DateTime.now().isAfter(expiresAt.add(const Duration(hours: 24)))) {
                  isClosed = true;
                }
              }
            }
          } else {
            final actTimeStr = act['activity_time'] as String?;
            if (actTimeStr != null) {
              final actTime = DateTime.parse(actTimeStr).toLocal();
              // Assume Activity/Event completes 4 hours after start
              final completionTime = actTime.add(const Duration(hours: 4));
              if (DateTime.now().isAfter(completionTime)) {
                isCompleted = true;
                if (DateTime.now().isAfter(completionTime.add(const Duration(hours: 24)))) {
                  isClosed = true;
                }
              }
            }
          }
        } catch (_) {}

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHost
                    ? [const Color(0xFFFF7E40), const Color(0xFFFF3D00)]
                    : [const Color(0xFFFF6B00), const Color(0xFFFF8A00)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isHost ? Icons.campaign : Icons.groups,
              color: Colors.white, size: 24,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isCompleted)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: const Text('COMPLETED', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isHost ? const Color(0xFFFF7E40).withValues(alpha: 0.2) : const Color(0xFFFF6B00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isHost ? 'HOST' : 'JOINED',
                  style: TextStyle(color: isHost ? const Color(0xFFFF7E40) : const Color(0xFFFF6B00), fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  desc,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          onTap: () {
            // For group chats, if the user is NOT the host and member chat is disabled, make it read-only
            final memberChatEnabled = act['member_chat_enabled'] == true;
            final isReadOnly = (!isHost && !memberChatEnabled) || isClosed;

            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                targetUserId: act['id']?.toString() ?? '',
                name: '📢 $title',
                avatarUrl: 'https://picsum.photos/seed/${act['id']}/100',
                isUnlocked: true,
                isGroupChat: true,
                isReadOnly: isReadOnly,
                isClosed: isClosed,
                isHost: isHost,
                memberChatEnabled: memberChatEnabled,
              ),
            ));
          },
        );
      },
    );
  }
}

// =============================================================================
// KNOCKS VIEW
// =============================================================================
class _KnocksView extends StatefulWidget {
  final String searchQuery;
  const _KnocksView({required this.searchQuery});
  @override
  State<_KnocksView> createState() => _KnocksViewState();
}

class _KnocksViewState extends State<_KnocksView> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  bool _loading = true;
  List<Map<String, dynamic>> _profiles = [];
  Map<String, Map<String, dynamic>> _lastMessages = {};
  Map<String, Map<String, dynamic>> _requestsMap = {};

  @override
  void initState() {
    super.initState();
    _loadKnocks();
  }

  Future<void> _loadKnocks() async {
    try {
      final reqs = await Supabase.instance.client
          .from('requests')
          .select('id, sender_id, target_id, target_type, status, knock_answers, is_super, created_at, expires_at')
          .inFilter('target_type', ['profile', 'hangout'])
          .or('sender_id.eq.$_myUid,target_id.eq.$_myUid');

      final Set<String> partnerIds = {};
      final Map<String, Map<String, dynamic>> rMap = {};
      for (final r in (reqs as List)) {
        final partnerId = r['sender_id'] == _myUid ? r['target_id'] as String : r['sender_id'] as String;
        partnerIds.add(partnerId);
        rMap[partnerId] = Map<String, dynamic>.from(r);
      }

      if (partnerIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, name, full_name, avatar_url')
          .inFilter('id', partnerIds.toList());

      final msgs = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.$_myUid,receiver_id.eq.$_myUid')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> lastMsgs = {};
      for (final m in (msgs as List)) {
        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];
        if (partnerId != null && !lastMsgs.containsKey(partnerId)) {
          lastMsgs[partnerId] = Map<String, dynamic>.from(m);
        }
      }

      if (mounted) {
        setState(() {
          _profiles = (profiles as List).cast<Map<String, dynamic>>();
          _lastMessages = lastMsgs;
          _requestsMap = rMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openKnockReview(Map<String, dynamic> req, Map<String, dynamic> profile) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => KnockReviewScreen(
        knockRequest: req,
        senderProfile: profile,
      ),
    )).then((_) => _loadKnocks()); // Refresh list when returning
  }

  Future<void> _acceptKnock(String reqId, String senderId, String senderName, Map<String, dynamic> profile) async {
    try {
      await Supabase.instance.client.from('requests').update({'status': 'approved'}).eq('id', reqId);
      
      // Send message notification
      await NotificationService.sendNotification(
        userId: senderId,
        type: NotificationType.knock_accepted,
        title: 'Knock Accepted! 🎉',
        body: 'Someone accepted your knock. Start chatting!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Knock accepted!'), backgroundColor: Color(0xFF00E676)));
        _loadKnocks(); // refresh list
        
        // Open Chat Detail directly
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatDetailScreen(targetUserId: senderId, name: senderName, avatarUrl: profile['avatar_url']?.toString() ?? ''),
        ));
      }
    } catch (e) {
      debugPrint('Error accepting knock: $e');
    }
  }

  Future<void> _rejectKnock(String reqId) async {
    try {
      await Supabase.instance.client.from('requests').update({'status': 'rejected'}).eq('id', reqId);
      if (mounted) {
        _loadKnocks(); // refresh list
      }
    } catch (e) {
      debugPrint('Error rejecting knock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return SkeletonLoaders.chatListSkeleton(doodle: isDoodleMode(context));
    
    final filtered = _profiles.where((p) {
      final name = (p['name'] ?? p['full_name'] ?? '').toLowerCase();
      return widget.searchQuery.isEmpty || name.contains(widget.searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waving_hand, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            const Text('No Knocks yet', style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Swipe and connect in Explore to start chatting!', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final profile   = filtered[i];
        final partnerId = profile['id'] as String;
        final name      = profile['name'] ?? profile['full_name'] ?? 'User';
        final avatar    = profile['avatar_url']?.toString() ?? '';
        final lastMsg   = _lastMessages[partnerId];
        final req       = _requestsMap[partnerId];

        final status     = req?['status']?.toString() ?? 'approved';
        final isIncoming = req != null && req['sender_id'] != _myUid;
        final isPending  = status == 'pending';
        final isApproved = status == 'approved';
        final isRejected = status == 'rejected';
        final isSuper    = req?['is_super'] == true;

        // Compute expiry
        String? expiryLabel;
        bool isExpiringSoon = false;
        if (isPending && req?['expires_at'] != null) {
          try {
            final exp = DateTime.parse(req!['expires_at']).toLocal();
            final rem = exp.difference(DateTime.now());
            if (rem.isNegative) {
              expiryLabel = 'Expired';
            } else if (rem.inHours < 4) {
              expiryLabel = '${rem.inHours}h left';
              isExpiringSoon = true;
            } else if (rem.inHours < 24) {
              expiryLabel = '${rem.inHours}h left';
            }
          } catch (_) {}
        }

        // Preview text
        String preview = '';
        String timeLabel = '';
        int unreadCount = 0;

        if (lastMsg != null) {
          final isMe    = lastMsg['sender_id'] == _myUid;
          final isImage = lastMsg['is_image'] == true;
          preview    = isImage ? '📸 Photo' : (lastMsg['text'] as String? ?? '');
          final isRead = lastMsg['is_read'] == true;
          unreadCount = (!isMe && !isRead) ? 1 : 0;
          final createdAt = lastMsg['created_at'] as String?;
          if (createdAt != null) {
            try {
              final dt   = DateTime.parse(createdAt).toLocal();
              final diff = DateTime.now().difference(dt);
              if (diff.inDays == 0) {
                int hour = dt.hour;
                final String period = hour >= 12 ? 'pm' : 'am';
                if (hour > 12) hour -= 12;
                if (hour == 0) hour = 12;
                timeLabel = '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
              } else if (diff.inDays == 1) {
                timeLabel = 'Yesterday';
              } else {
                timeLabel = '${dt.day}/${dt.month}';
              }
            } catch (_) {}
          }
        } else if (req != null) {
          if (isPending && isIncoming) {
            preview = isSuper ? '⚡ Super Knocked you!' : '👋 Knocked to connect';
            unreadCount = 1;
          } else if (isPending && !isIncoming) {
            preview = 'Waiting for response…';
          } else if (isApproved) {
            preview = 'Knock accepted — start chatting!';
          } else if (isRejected) {
            preview = 'Knock passed';
          }
          final createdAt = req['created_at'] as String?;
          if (createdAt != null) {
            try {
              final dt   = DateTime.parse(createdAt).toLocal();
              final diff = DateTime.now().difference(dt);
              if (diff.inDays == 0) {
                int hour = dt.hour;
                final String period = hour >= 12 ? 'pm' : 'am';
                if (hour > 12) hour -= 12;
                if (hour == 0) hour = 12;
                timeLabel = '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
              } else if (diff.inDays == 1) {
                timeLabel = 'Yesterday';
              } else {
                timeLabel = '${dt.day}/${dt.month}';
              }
            } catch (_) {}
          }
        }

        // Colors per state
        Color borderColor = Colors.white.withValues(alpha: 0.07);
        Color? glowColor;
        if (isPending && isIncoming) {
          borderColor = isSuper
              ? const Color(0xFFFFB300).withValues(alpha: 0.7)
              : const Color(0xFFFF6B00).withValues(alpha: 0.6);
          glowColor = isSuper ? const Color(0xFFFFB300) : const Color(0xFFFF6B00);
        } else if (isApproved) {
          borderColor = const Color(0xFF22C55E).withValues(alpha: 0.3);
        } else if (isRejected) {
          borderColor = Colors.white.withValues(alpha: 0.04);
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (req != null && isPending && isIncoming) {
              _openKnockReview(req, profile);
              return;
            }
            if (req != null && isPending && !isIncoming) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Waiting for ${(name as String).split(' ').first} to review your knock…',
                    style: GoogleFonts.outfit(color: Colors.white)),
                backgroundColor: const Color(0xFF1B202D),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ));
              return;
            }
            if (isApproved) {
              Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  targetUserId: partnerId, name: name, avatarUrl: avatar, isUnlocked: true),
              ));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPending && isIncoming
                  ? (isSuper
                      ? const Color(0xFFFFB300).withValues(alpha: 0.06)
                      : const Color(0xFFFF6B00).withValues(alpha: 0.05))
                  : const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: isPending && isIncoming ? 1.5 : 1),
              boxShadow: glowColor != null
                  ? [BoxShadow(color: glowColor.withValues(alpha: 0.12), blurRadius: 14, spreadRadius: 1)]
                  : null,
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPending && isIncoming
                              ? (isSuper ? const Color(0xFFFFB300) : const Color(0xFFFF6B00))
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: avatar.isNotEmpty
                            ? Image(image: _safeImageProvider(avatar), fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFF1B202D),
                                child: const Icon(Icons.person, color: Colors.white38, size: 26),
                              ),
                      ),
                    ),
                    // Super badge
                    if (isSuper)
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0F0F16), width: 1.5),
                          ),
                          child: const Icon(Icons.bolt, color: Colors.black, size: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (timeLabel.isNotEmpty)
                                Text(timeLabel,
                                    style: GoogleFonts.outfit(
                                      color: unreadCount > 0
                                          ? const Color(0xFFFF6B00)
                                          : Colors.white38,
                                      fontSize: 11, fontWeight: FontWeight.w600)),
                              if (unreadCount > 0 && !isSuper) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B00),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$unreadCount',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF0D0F14),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(preview,
                          style: GoogleFonts.outfit(
                            color: isPending && isIncoming
                                ? (isSuper ? const Color(0xFFFFB300) : const Color(0xFFFF6B00))
                                : Colors.white38,
                            fontSize: 13,
                            fontStyle: lastMsg == null ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      // Status row
                      Row(children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                                : isPending && isIncoming
                                    ? (isSuper
                                        ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                                        : const Color(0xFFFF6B00).withValues(alpha: 0.12))
                                    : isPending
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isApproved
                                  ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                                  : isPending && isIncoming
                                      ? (isSuper
                                          ? const Color(0xFFFFB300).withValues(alpha: 0.5)
                                          : const Color(0xFFFF6B00).withValues(alpha: 0.4))
                                      : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            isApproved
                                ? '✓ CONNECTED'
                                : isSuper && isPending && isIncoming
                                    ? '⚡ SUPER KNOCK'
                                    : isPending && isIncoming
                                        ? '🚪 PENDING'
                                        : isPending
                                            ? '⏳ AWAITING'
                                            : isRejected
                                                ? 'PASSED'
                                                : 'CONNECTED',
                            style: GoogleFonts.outfit(
                              color: isApproved
                                  ? const Color(0xFF22C55E)
                                  : isPending && isIncoming
                                      ? (isSuper ? const Color(0xFFFFB300) : const Color(0xFFFF6B00))
                                      : isPending
                                          ? Colors.white38
                                          : Colors.white24,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (expiryLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(expiryLabel,
                              style: GoogleFonts.outfit(
                                color: isExpiringSoon ? Colors.red.shade300 : Colors.white24,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                        const Spacer(),
                        // Action arrow
                        if (isPending && isIncoming)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSuper
                                    ? [const Color(0xFFFFB300), const Color(0xFFFF6B00)]
                                    : [const Color(0xFFFF6B00), const Color(0xFFFF0055)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Review',
                                style: GoogleFonts.outfit(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          )
                        else if (isApproved)
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white24, size: 14),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



// =============================================================================
// COMPANION VIEW
// =============================================================================
class _CompanionView extends StatefulWidget {
  final String searchQuery;
  const _CompanionView({required this.searchQuery});
  @override
  State<_CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<_CompanionView> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  bool _loading = true;
  List<Map<String, dynamic>> _profiles = [];
  Map<String, Map<String, dynamic>> _lastMessages = {};

  @override
  void initState() {
    super.initState();
    _loadCompanions();
  }

  Future<void> _loadCompanions() async {
    try {
      final reqs = await Supabase.instance.client
          .from('requests')
          .select('sender_id, target_id')
          .eq('target_type', 'companion')
          .or('sender_id.eq.$_myUid,target_id.eq.$_myUid');

      final Set<String> partnerIds = {};
      for (final r in (reqs as List)) {
        if (r['sender_id'] != _myUid) partnerIds.add(r['sender_id'] as String);
        if (r['target_id'] != _myUid) partnerIds.add(r['target_id'] as String);
      }

      if (partnerIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, name, full_name, avatar_url')
          .inFilter('id', partnerIds.toList());

      final msgs = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.$_myUid,receiver_id.eq.$_myUid')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> lastMsgs = {};
      for (final m in (msgs as List)) {
        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];
        if (partnerId != null && !lastMsgs.containsKey(partnerId)) {
          lastMsgs[partnerId] = Map<String, dynamic>.from(m);
        }
      }

      if (mounted) {
        setState(() {
          _profiles = (profiles as List).cast<Map<String, dynamic>>();
          _lastMessages = lastMsgs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return SkeletonLoaders.chatListSkeleton(doodle: isDoodleMode(context));
    
    final filtered = _profiles.where((p) {
      final name = (p['name'] ?? p['full_name'] ?? '').toLowerCase();
      return widget.searchQuery.isEmpty || name.contains(widget.searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            const Text('No Companions yet', style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Book a session with a companion to chat!', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final profile = filtered[i];
        final partnerId = profile['id'] as String;
        final name = profile['name'] ?? profile['full_name'] ?? 'User';
        final avatar = profile['avatar_url']?.toString() ?? '';
        final lastMsg = _lastMessages[partnerId];

        String preview = 'Tap to start chatting';
        bool isRead = true;
        String timeLabel = '';
        int unreadCount = 0;

        if (lastMsg != null) {
          final isMe = lastMsg['sender_id'] == _myUid;
          final isImage = lastMsg['is_image'] == true;
          final isHang = lastMsg['text'] != null && (lastMsg['text'] as String).startsWith('⚡HANGOUT_INVITE|');
          if (isHang) {
            final parts = (lastMsg['text'] as String).split('|');
            final act = parts.length > 2 ? parts[2] : 'hangout';
            preview = isMe ? '⚡ Invited to hang for $act' : '⚡ Invited you to hang for $act';
          } else {
            preview = isImage ? '📸 Photo' : (lastMsg['text'] as String? ?? '');
          }
          isRead = lastMsg['is_read'] == true;
          unreadCount = (!isMe && !isRead) ? 1 : 0;
          
          final createdAt = lastMsg['created_at'] as String?;
          if (createdAt != null) {
            try {
              final dt = DateTime.parse(createdAt).toLocal();
              final diff = DateTime.now().difference(dt);
              if (diff.inDays == 0) {
                int hour = dt.hour;
                final String period = hour >= 12 ? 'pm' : 'am';
                if (hour > 12) hour -= 12;
                if (hour == 0) hour = 12;
                final minute = dt.minute.toString().padLeft(2, '0');
                timeLabel = '$hour:$minute $period';
              } else if (diff.inDays == 1) {
                timeLabel = 'Yesterday';
              } else {
                timeLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
              }
            } catch (_) {}
          }
        }

        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatDetailScreen(targetUserId: partnerId, name: name, avatarUrl: avatar),
            ));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: avatar.isNotEmpty ? _safeImageProvider(avatar) : null,
                  backgroundColor: const Color(0xFF1B202D),
                  child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(timeLabel, style: TextStyle(color: unreadCount > 0 ? const Color(0xFFFF6B00) : const Color(0xFF8B95A5), fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: TextStyle(color: lastMsg != null ? const Color(0xFF8B95A5) : const Color(0xFFFF6B00), fontSize: 14, fontStyle: lastMsg != null ? FontStyle.normal : FontStyle.italic),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                              child: Text('$unreadCount', style: const TextStyle(color: Color(0xFF0D0F14), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// CHAT DETAIL SCREEN — Premium Messaging Experience
// =============================================================================
class ChatDetailScreen extends StatefulWidget {
  final String targetUserId;
  final String name;
  final String avatarUrl;
  final bool isUnlocked;
  final bool isReadOnly;
  final bool isGroupChat;
  final bool isClosed;
  final bool isHost;
  final bool memberChatEnabled;

  const ChatDetailScreen({
    super.key,
    required this.targetUserId,
    required this.name,
    required this.avatarUrl,
    this.isUnlocked = false,
    this.isReadOnly = false,
    this.isGroupChat = false,
    this.isClosed = false,
    this.isHost = false,
    this.memberChatEnabled = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  // Static cache to simulate local storage for themes
  static final Map<String, Color> _chatThemes = {};

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late final String _myUid;
  
  Timer? _pollingTimer;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _presenceChannel;
  bool _isOnline = false;
  bool _isLoading = true;
  bool _isChatLocked = false;
  bool _isConnectionLoading = true;
  bool _memberChatEnabled = false;
  bool _isComposerEmpty = true;
  Map<String, dynamic>? _replyingTo;
  final Set<String> _locallyDeletedMsgIds = {};
  final Map<String, String> _messageReactions = {};
  String? _hangoutRequestStatus;
  String? _hangoutRequestSenderId;
  bool _showEmojiPicker = false;

  Future<void> _markAsRead() async {
    if (_myUid.isEmpty || widget.targetUserId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', widget.targetUserId)
          .eq('receiver_id', _myUid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _showMessageActions(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _myUid;
    final isImage = msg['is_image'] == true;
    final text = msg['text'] as String? ?? '';
    final msgId = msg['id'].toString();
    final createdAt = msg['created_at'] != null ? DateTime.parse(msg['created_at']) : DateTime.now();
    final canDeleteEveryone = isMe && DateTime.now().difference(createdAt).inHours < 24;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) => GestureDetector(
                    onTap: () {
                      setState(() => _messageReactions[msgId] = emoji);
                      Navigator.pop(ctx);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  )).toList(),
                ),
              ),
              if (!(msg['id'] is int && (msg['id'] as int) > 1000000000000))
                ListTile(
                  leading: const Icon(Icons.reply, color: Colors.white),
                  title: const Text('Reply', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _replyingTo = msg);
                  },
                ),
              if (!isImage)
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white),
                title: const Text('Delete for me', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _locallyDeletedMsgIds.add(msgId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message deleted locally')));
                },
              ),
              if (canDeleteEveryone)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
                  title: const Text('Delete for everyone', style: TextStyle(color: Color(0xFFEF4444))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await Supabase.instance.client
                          .from('messages')
                          .update({'deleted_for_everyone': true})
                          .eq('id', msg['id']);
                      
                      _fetchMessages();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                    }
                  },
                ),
            ],
          ),
        );
      }
    );
  }

  @override
  void initState() {
    super.initState();
    _memberChatEnabled = widget.memberChatEnabled;
    _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';

    _msgController.addListener(() {
      if (mounted) {
        setState(() {
          _isComposerEmpty = _msgController.text.trim().isEmpty;
        });
      }
    });
    
    if (widget.isUnlocked) {
      _isChatLocked = false;
      _isConnectionLoading = false;
    } else {
      _fetchConnectionStatus();
    }
    
    _fetchHangoutRequestStatus();
    _fetchMessages();
    _markAsRead();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages();
      _fetchHangoutRequestStatus();
      _fetchConnectionStatus();
    });
    _initPresence();
  }

  void _initPresence() {
    if (_myUid.isEmpty || widget.targetUserId.isEmpty) return;
    try {
      _presenceChannel = Supabase.instance.client.channel('global_presence');
      _presenceChannel!.onPresenceSync((_) {
        if (!mounted) return;
        final List<SinglePresenceState> state = _presenceChannel!.presenceState();
        bool online = false;
        for (final singleState in state) {
          for (final presence in singleState.presences) {
            final uid = presence.payload['user_id']?.toString();
            if (uid == widget.targetUserId) {
              online = true;
              break;
            }
          }
          if (online) break;
        }
        setState(() {
          _isOnline = online;
        });
      }).subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _presenceChannel!.track({'user_id': _myUid});
        }
      });
    } catch (e) {
      debugPrint('Presence detail error: $e');
    }
  }

  Future<void> _fetchConnectionStatus() async {
    try {
      // 1. Check direct profile/neighbor requests
      final directRes = await Supabase.instance.client
          .from('requests')
          .select('status, target_type')
          .or('and(sender_id.eq.$_myUid,target_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},target_id.eq.$_myUid)');
      
      bool hasDirectApproved = (directRes as List).any((row) => row['status'] == 'approved');
      bool isMutualMatch = (directRes).where((row) => row['target_type'] == 'profile').length >= 2;

      if (hasDirectApproved || isMutualMatch) {
        if (mounted) setState(() { _isChatLocked = false; _isConnectionLoading = false; });
        return;
      }

      // 2. Check Activity-based approvals (Me as participant)
      final participantRes = await Supabase.instance.client
          .from('requests')
          .select('status, target_id')
          .eq('sender_id', _myUid)
          .eq('target_type', 'activity')
          .eq('status', 'approved');

      if ((participantRes as List).isNotEmpty) {
        final activityIds = participantRes.map((r) => r['target_id'] as String).toList();
        final hostCheck = await Supabase.instance.client
            .from('activities')
            .select('user_id')
            .inFilter('id', activityIds)
            .eq('user_id', widget.targetUserId);
        
        if ((hostCheck as List).isNotEmpty) {
          if (mounted) setState(() { _isChatLocked = false; _isConnectionLoading = false; });
          return;
        }
      }

      // 3. Check Activity-based approvals (Target as participant)
      final hostRes = await Supabase.instance.client
          .from('requests')
          .select('status, target_id')
          .eq('sender_id', widget.targetUserId)
          .eq('target_type', 'activity')
          .eq('status', 'approved');

      if ((hostRes as List).isNotEmpty) {
        final activityIds = hostRes.map((r) => r['target_id'] as String).toList();
        final hostCheck = await Supabase.instance.client
            .from('activities')
            .select('user_id')
            .inFilter('id', activityIds)
            .eq('user_id', _myUid);
        
        if ((hostCheck as List).isNotEmpty) {
          if (mounted) setState(() { _isChatLocked = false; _isConnectionLoading = false; });
          return;
        }
      }

      if (mounted) setState(() { _isChatLocked = false; _isConnectionLoading = false; });
    } catch (e) {
      debugPrint('Chat lock check error: $e');
      if (mounted) setState(() { _isChatLocked = false; _isConnectionLoading = false; });
    }
  }

  Future<void> _fetchHangoutRequestStatus() async {
    if (_myUid.isEmpty || widget.targetUserId.isEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('requests')
          .select('sender_id, status')
          .eq('target_type', 'hangout')
          .or('and(sender_id.eq.$_myUid,target_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},target_id.eq.$_myUid)')
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (res != null) {
            _hangoutRequestStatus = res['status'] as String?;
            _hangoutRequestSenderId = res['sender_id'] as String?;
            if (_hangoutRequestStatus == 'approved') {
              _isChatLocked = false;
            }
          } else {
            _hangoutRequestStatus = null;
            _hangoutRequestSenderId = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching hangout request status: $e');
    }
  }

  bool _isHangoutInvite(String text) {
    return text.startsWith('⚡HANGOUT_INVITE|');
  }

  Widget _buildHangoutInviteCard(String text, bool isMe) {
    final parts = text.split('|');
    final emoji = parts.length > 1 ? parts[1] : '🍕';
    final activityName = parts.length > 2 ? parts[2] : 'hangout';
    final when = parts.length > 3 ? parts[3] : 'right now';

    return Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131313).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMe ? const Color(0xFFFF6B00).withValues(alpha: 0.3) : const Color(0xFF17C964).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMe ? const Color(0xFFFF6B00) : const Color(0xFF17C964)).withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isMe ? const Color(0xFFFF6B00) : const Color(0xFF17C964)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isMe ? const Color(0xFFFF6B00) : const Color(0xFF17C964)).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✦ ',
                  style: TextStyle(
                    color: isMe ? const Color(0xFFFF6B00) : const Color(0xFF17C964),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                Text(
                  isMe ? 'HANG INVITE SENT' : 'HANG INVITE RECEIVED',
                  style: GoogleFonts.inter(
                    color: isMe ? const Color(0xFFFF6B00) : const Color(0xFF17C964),
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Emoji inside a glowing circle
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 16),
          // Text
          Text(
            isMe ? 'asked ${widget.name} to hang for' : 'asked you to hang for',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            activityName,
            style: GoogleFonts.inter(
              color: isMe ? const Color(0xFFFF6B00) : const Color(0xFF17C964),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Pill-shaped when badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📍 ', style: TextStyle(fontSize: 12)),
                Text(
                  when,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveHangoutRequest() async {
    if (_myUid.isEmpty || widget.targetUserId.isEmpty) return;
    try {
      // Update hangout request status to approved
      await Supabase.instance.client
          .from('requests')
          .update({'status': 'approved'})
          .eq('target_type', 'hangout')
          .or('and(sender_id.eq.$_myUid,target_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},target_id.eq.$_myUid)');

      // Insert system message about hangout approval
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _myUid,
        'receiver_id': widget.targetUserId,
        'text': '⚡ HANGOUT REQUEST APPROVED! You can now chat freely.',
        'is_image': false,
      });

      // Instantly refresh
      await _fetchHangoutRequestStatus();
      await _fetchConnectionStatus();
      await _fetchMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request approved! Chat unlocked.'),
          backgroundColor: Color(0xFF17C964),
        ));
      }
    } catch (e) {
      debugPrint('Error approving request: $e');
    }
  }

  Future<void> _declineHangoutRequest() async {
    if (_myUid.isEmpty || widget.targetUserId.isEmpty) return;

    // Show high-fidelity custom confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Decline Request?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Declining this hangout request will delete your message history. Do you want to proceed?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Decline', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 1. Update hangout request status to declined
      await Supabase.instance.client
          .from('requests')
          .update({'status': 'declined'})
          .eq('target_type', 'hangout')
          .or('and(sender_id.eq.$_myUid,target_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},target_id.eq.$_myUid)');

      // 2. Delete ALL messages between the sender and receiver
      await Supabase.instance.client
          .from('messages')
          .delete()
          .or('and(sender_id.eq.$_myUid,receiver_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},receiver_id.eq.$_myUid)');

      // 3. Insert the automated permanent decline/lock message from sender to receiver
      // Wait, since we are receiver declining it, the sender will see:
      // "❌ The receiver has declined your request and you cannot chat further."
      // Since sender declined, receiver_id is the sender of the request (widget.targetUserId).
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _myUid,
        'receiver_id': widget.targetUserId,
        'text': '❌ The receiver has declined your request and you cannot chat further.',
        'is_image': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request declined and chat cleared.'),
          backgroundColor: Colors.orange,
        ));
        // Pop back to the DM inbox list
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error declining request: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    if (_presenceChannel != null) {
      Supabase.instance.client.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_myUid,receiver_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},receiver_id.eq.$_myUid)')
          .order('created_at', ascending: true); // Oldest first at index 0 (Top)

      final newMsgs = List<Map<String, dynamic>>.from(response);
      _markAsRead();

      if (mounted) {
        final wasAtBottom = _scrollController.hasClients && _scrollController.position.pixels == _scrollController.position.maxScrollExtent;
        setState(() {
          _messages = newMsgs;
          _isLoading = false;
        });
        if (wasAtBottom || _isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    } catch (_) {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    
    final text = _msgController.text.trim();
    _msgController.clear();
    HapticFeedback.lightImpact();
    
    // Optimistic update
    final tempMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_id': _myUid,
      'receiver_id': widget.targetUserId,
      'text': text,
      'is_image': false,
      'created_at': DateTime.now().toIso8601String(),
      if (_replyingTo != null) ...{
        'reply_to_id': _replyingTo!['id'].toString(),
        'reply_to_text': _replyingTo!['text'].toString(),
        'reply_to_sender': _replyingTo!['sender_id'].toString(),
      }
    };
    
    final payload = {
      'sender_id': _myUid,
      'receiver_id': widget.targetUserId,
      'text': text,
      'is_image': false,
      if (_replyingTo != null) ...{
        'reply_to_id': _replyingTo!['id'].toString(),
        'reply_to_text': _replyingTo!['text'].toString(),
        'reply_to_sender': _replyingTo!['sender_id'].toString(),
      }
    };

    setState(() {
      _messages.add(tempMsg);
      _replyingTo = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    try {
      await Supabase.instance.client.from('messages').insert(payload);

      // Send notification to receiver
      NotificationService.sendNotification(
        userId: widget.targetUserId,
        type: NotificationType.message,
        title: 'New Message from ${Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'Someone'}',
        body: text,
        payload: {'sender_id': _myUid},
      );

      _fetchMessages(); // Background sync
    } catch (_) {}
  }

  Future<void> _sendImage() async {
    final url = await ImageUploadService.pickAndUpload(context: context, folder: 'chat_images');
    if (url != null) {
      // Optimistic update
      final tempMsg = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender_id': _myUid,
        'receiver_id': widget.targetUserId,
        'text': url,
        'is_image': true,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      setState(() => _messages.add(tempMsg));
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      
      try {
        await Supabase.instance.client.from('messages').insert({
          'sender_id': _myUid,
          'receiver_id': widget.targetUserId,
          'text': url,
          'is_image': true,
        });

        // Send notification for image
        NotificationService.sendNotification(
          userId: widget.targetUserId,
          type: NotificationType.message,
          title: 'New Photo 📸',
          body: '${Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'Someone'} sent you a photo',
          payload: {'sender_id': _myUid},
        );

        _fetchMessages(); // Background sync
      } catch (_) {}
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) return 'Today';
    if (diff.inDays <= 1 && now.day != dt.day) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64str = url.split(',').last;
        return Image.memory(base64Decode(base64str), height: 200, width: 220, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Image.network(url, height: 200, width: 220, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 200, height: 120, color: const Color(0xFF1A1A2E),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 32)),
      )
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final colors = [
          const Color(0xFF0D0F14), // Default Dark
          const Color(0xFF1E293B), // Slate
          const Color(0xFF0F172A), // Deep Blue
          const Color(0xFF171717), // Neutral Black
          const Color(0xFF3B1D2A), // Deep Crimson
          const Color(0xFF112A22), // Deep Forest
        ];
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Chat Background', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: colors.map((c) => GestureDetector(
                  onTap: () {
                    setState(() => _chatThemes[widget.targetUserId] = c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget build(BuildContext context) {
    final bgColor = _chatThemes[widget.targetUserId] ?? const Color(0xFF000000);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF000000), // Pure black
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(radius: 20, backgroundImage: _safeImageProvider(widget.avatarUrl), backgroundColor: const Color(0xFF1A1A2E)),
                if (widget.isGroupChat || _isOnline)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF66),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D0F14), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(widget.isGroupChat ? 'Group Chat' : (_isOnline ? 'online' : 'offline'), style: TextStyle(color: widget.isGroupChat ? Colors.white54 : (_isOnline ? const Color(0xFF00FF66) : const Color(0xFF8B95A5)), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_outlined, color: Color(0xFFFF6B00), size: 20),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
            color: const Color(0xFF1B202D),
            onSelected: (value) async {
              if (value == 'wallpaper') {
                _showThemePicker();
              } else if (value == 'delete') {
                try {
                  await Supabase.instance.client
                      .from('messages')
                      .delete()
                      .or('and(sender_id.eq.$_myUid,receiver_id.eq.${widget.targetUserId}),and(sender_id.eq.${widget.targetUserId},receiver_id.eq.$_myUid)');
                  if (mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint('Failed to delete chat: $e');
                }
              } else if (value == 'toggle_chat') {
                final newVal = !_memberChatEnabled;
                setState(() => _memberChatEnabled = newVal);
                try {
                  await Supabase.instance.client
                      .from('activities')
                      .update({'member_chat_enabled': newVal})
                      .eq('id', widget.targetUserId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(newVal ? 'Members can now chat' : 'Members can only read'),
                      backgroundColor: const Color(0xFFFF6B00),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  setState(() => _memberChatEnabled = !newVal);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'delete', child: Text('Delete chat', style: TextStyle(color: Colors.redAccent))),
              if (widget.isHost && widget.isGroupChat)
                PopupMenuItem(
                  value: 'toggle_chat',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Members Can Chat', style: TextStyle(color: Colors.white)),
                      Icon(_memberChatEnabled ? Icons.check_circle : Icons.radio_button_unchecked, 
                           color: _memberChatEnabled ? const Color(0xFF10B981) : Colors.white38, size: 20),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
              : (_messages.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.waving_hand, color: Color(0xFFFF6B00), size: 40),
                          ),
                          const SizedBox(height: 16),
                          const Text('Say hi! 👋', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Start your conversation with ${widget.name}', style: const TextStyle(color: Colors.white30, fontSize: 13)),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: false, // Normal chat flow: oldest at top
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id'] == _myUid;
                        final msgId = msg['id'].toString();
                        if (_locallyDeletedMsgIds.contains(msgId)) {
                          return const SizedBox.shrink();
                        }
                        final isImage = msg['is_image'] == true;

                        // Date separator for reversed list (checking the NEXT message down, which is temporally older)
                        Widget? dateSeparator;
                        if (index == 0 || _shouldShowDateSeparator(_messages, index)) {
                          try {
                            final dt = DateTime.parse(msg['created_at']).toLocal();
                            dateSeparator = Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_formatDate(dt), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            );
                          } catch (_) {}
                        }

                        // Time label
                        String timeStr = '';
                        try {
                          final dt = DateTime.parse(msg['created_at']).toLocal();
                          timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        } catch (_) {}

                        return Column(
                          children: [
                            if (dateSeparator != null) dateSeparator,
                            GestureDetector(
                              onLongPress: () => _showMessageActions(msg),
                              child: Dismissible(
                                key: ValueKey(msgId),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (direction) async {
                                  final isTemp = msg['id'] is int && (msg['id'] as int) > 1000000000000;
                                  if (!isTemp) {
                                    setState(() => _replyingTo = msg);
                                  }
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  color: Colors.transparent,
                                  child: const Icon(Icons.reply, color: Colors.white54),
                                ),
                                child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (_isHangoutInvite(msg['text'] as String? ?? ''))
                                        _buildHangoutInviteCard(msg['text'] as String, isMe)
                                      else
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: isMe
                                                ? const LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [Color(0xFFD65200), Color(0xFFB53900)]
                                                  )
                                                : null,
                                            color: isMe ? null : const Color(0xFF1A1A1E),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: (isImage && msg['reply_to_text'] == null) ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: msg['deleted_for_everyone'] == true
                                              ? const Text(
                                                  'This message was deleted',
                                                  style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic, fontSize: 13),
                                                )
                                              : Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (msg['reply_to_text'] != null) ...[
                                                      Container(
                                                        margin: const EdgeInsets.only(bottom: 6),
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: isMe ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border(
                                                            left: BorderSide(color: isMe ? Colors.white70 : const Color(0xFFFF6B00), width: 3),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              msg['reply_to_sender'] == _myUid ? 'You' : widget.name,
                                                              style: TextStyle(color: isMe ? Colors.white : const Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              msg['reply_to_text'] as String,
                                                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                    isImage 
                                                        ? ClipRRect(
                                                            borderRadius: BorderRadius.circular(16),
                                                            child: _buildImage(msg['text'] as String),
                                                          )
                                                        : Text(msg['text'] as String, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(timeStr, style: TextStyle(color: isMe ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF7A7A7A), fontSize: 10)),
                                                        if (isMe) ...[
                                                          const SizedBox(width: 4),
                                                          Builder(
                                                              builder: (context) {
                                                                final isTemp = msg['id'] is int && (msg['id'] as int) > 1000000000000;
                                                                if (isTemp) {
                                                                  return const Icon(Icons.access_time, color: Colors.white70, size: 10);
                                                                }
                                                                final isRead = msg['is_read'] == true;
                                                                return Icon(
                                                                  isRead ? Icons.done_all : Icons.check,
                                                                  color: isRead ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.8),
                                                                  size: 14,
                                                                );
                                                              }
                                                            ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      if (_messageReactions[msgId] != null) ...[
                                        const SizedBox(height: 4),
                                        Transform.translate(
                                          offset: const Offset(0, -2),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1B202D),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.white12, width: 1),
                                            ),
                                            child: Text(_messageReactions[msgId]!, style: const TextStyle(fontSize: 10)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ],
                        );
                      },
                    )
                ),
          ),
          // ── Input Field or Locked State ──
          if (_hangoutRequestStatus == 'pending')
            if (_hangoutRequestSenderId == _myUid)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131313),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFFF7E40), size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for Approval',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your hangout invite is sent! Chat will unlock once approved.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131313),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.name} wants to hang out!',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: TextButton(
                              onPressed: _declineHangoutRequest,
                              child: Text(
                                'Decline',
                                style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF17C964),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF17C964).withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: _approveHangoutRequest,
                              child: Text(
                                'Approve',
                                style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
          else if (_hangoutRequestStatus == 'declined')
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131313),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Request Declined',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The hangout request has been declined. You cannot chat further.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (widget.isClosed)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: const Text(
                'This chatroom has been closed as the activity has ended.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            )
          else if (widget.isReadOnly && !widget.isHost && !_memberChatEnabled)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: const Text(
                'Only the host and collaborators can send messages.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            )
          else if (_isConnectionLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFF0055))),
            )
          else if (_isChatLocked)
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, color: Color(0xFFFF7E40), size: 32),
                        const SizedBox(height: 12),
                        const Text('Accept Knock to Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('You need to accept their knock request before you can start messaging.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(left: BorderSide(color: Color(0xFFFF6B00), width: 3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyingTo!['sender_id'] == _myUid ? 'Replying to yourself' : 'Replying to ${widget.name}',
                                  style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _replyingTo!['text'] as String,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                            onPressed: () => setState(() => _replyingTo = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _sendImage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                          child: const Icon(Icons.image_outlined, color: Colors.white54, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                setState(() => _showEmojiPicker = !_showEmojiPicker);
                              },
                              child: Icon(_showEmojiPicker ? Icons.keyboard : Icons.sentiment_satisfied_alt, color: Colors.white54, size: 22),
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onTap: () {
                            if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                          },
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedOpacity(
                        opacity: _isComposerEmpty ? 0.5 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: _isComposerEmpty ? null : _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B00),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: emoji.EmojiPicker(
                  textEditingController: _msgController,
                  config: emoji.Config(
                    height: 250,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: emoji.EmojiViewConfig(
                      backgroundColor: const Color(0xFF1B202D),
                      columns: 7,
                      emojiSizeMax: 28,
                    ),
                    categoryViewConfig: const emoji.CategoryViewConfig(
                      backgroundColor: Color(0xFF1B202D),
                      iconColorSelected: Color(0xFFFF6B00),
                      indicatorColor: Color(0xFFFF6B00),
                    ),
                    bottomActionBarConfig: const emoji.BottomActionBarConfig(
                      backgroundColor: Color(0xFF1B202D),
                      buttonColor: Color(0xFF1B202D),
                      buttonIconColor: Colors.white,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(List<Map<String, dynamic>> msgs, int index) {
    if (index == 0) return true; // oldest message gets a badge
    try {
      final current = DateTime.parse(msgs[index]['created_at']).toLocal();
      // In a normal list (oldest at index 0), the previous index is older chronologically.
      final temporallyOlder = DateTime.parse(msgs[index - 1]['created_at']).toLocal();
      return current.day != temporallyOlder.day || current.month != temporallyOlder.month || current.year != temporallyOlder.year;
    } catch (_) {
      return false;
    }
  }
}

// =============================================================================
// COMPLIMENTS VIEW
// =============================================================================
class _ComplimentsView extends StatefulWidget {
  final String searchQuery;
  const _ComplimentsView({required this.searchQuery});

  @override
  State<_ComplimentsView> createState() => _ComplimentsViewState();
}

class _ComplimentsViewState extends State<_ComplimentsView> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  List<Map<String, dynamic>> _compliments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompliments();
  }

  Future<void> _fetchCompliments() async {
    if (_myUid.isEmpty) return;
    try {
      final msgs = await Supabase.instance.client
          .from('messages')
          .select('*, sender:profiles!messages_sender_id_fkey(name, full_name, avatar_url)')
          .eq('receiver_id', _myUid)
          .like('text', '💌 Compliment:%')
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _compliments = List<Map<String, dynamic>>.from(msgs);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Compliments error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return SkeletonLoaders.chatListSkeleton(doodle: isDoodleMode(context));

    final filtered = _compliments.where((c) {
      final senderData = c['sender'] as Map<String, dynamic>? ?? {};
      final name = senderData['name'] ?? senderData['full_name'] ?? '';
      return widget.searchQuery.isEmpty || name.toString().toLowerCase().contains(widget.searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            const Text('No compliments yet', style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Update your profile to attract more!', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCompliments,
      color: const Color(0xFFFF3D00),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final msg = filtered[i];
          final senderData = msg['sender'] as Map<String, dynamic>? ?? {};
          final name = senderData['name'] ?? senderData['full_name'] ?? 'User';
          final avatarUrl = senderData['avatar_url']?.toString();
          final text = msg['text'].toString().replaceAll('💌 Compliment:', '').trim();
          final senderId = msg['sender_id'];

          return GestureDetector(
            onTap: () {
              if (senderId != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(targetUserId: senderId, name: name, avatarUrl: avatarUrl ?? ''),
                ));
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF3D00).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF3D00).withValues(alpha: 0.05), blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: avatarUrl != null ? _safeImageProvider(avatarUrl) : null,
                    backgroundColor: const Color(0xFF1B202D),
                    child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white38) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From $name', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(text, style: const TextStyle(color: Color(0xFFFF3D00), fontSize: 14, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const Icon(Icons.favorite, color: Color(0xFFFF3D00), size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}




// =============================================================================
// ARCHIVED CHATS SCREEN
// =============================================================================
class _ArchivedChatsScreen extends StatefulWidget {
  final Set<String> archivedIds;
  final List<MapEntry<String, Map<String, dynamic>>> conversations;
  final Map<String, Map<String, String>> profileCache;
  final Map<String, int> unreadCounts;
  final Set<String> manuallyUnreadIds;
  final Function(String) onUnarchive;

  const _ArchivedChatsScreen({
    required this.archivedIds,
    required this.conversations,
    required this.profileCache,
    required this.unreadCounts,
    required this.manuallyUnreadIds,
    required this.onUnarchive,
  });

  @override
  State<_ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<_ArchivedChatsScreen> {
  @override
  Widget build(BuildContext context) {
    final list = widget.conversations.where((entry) => widget.archivedIds.contains(entry.key)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        title: const Text('Archived Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: list.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  Text('No archived chats', style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final partnerId = list[i].key;
                final lastMsg = list[i].value;
                final profile = widget.profileCache[partnerId] ?? {'name': 'User', 'avatar': ''};
                final name = profile['name']!;
                final avatar = profile['avatar']!;

                return Dismissible(
                  key: Key(partnerId),
                  background: Container(
                     color: const Color(0xFF3B82F6),
                     alignment: Alignment.centerLeft,
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: const Icon(Icons.unarchive, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (dir) async {
                    widget.onUnarchive(partnerId);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat unarchived')));
                    setState(() {});
                    return true;
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      backgroundColor: const Color(0xFF1B202D),
                      child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null,
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      lastMsg['is_image'] == true ? '📸 Photo' : (lastMsg['text'] as String? ?? ''),
                      style: const TextStyle(color: Colors.white38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.unarchive, color: Colors.white54),
                      onPressed: () {
                        widget.onUnarchive(partnerId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat unarchived')));
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
