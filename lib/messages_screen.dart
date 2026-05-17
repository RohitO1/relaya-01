// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'image_upload_service.dart';
import 'bot_chat_screen.dart';
import 'services/notification_service.dart';
import 'main.dart'; // For CosmicBackgroundPainter

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
  const MessagesScreen({super.key});

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
      backgroundColor: const Color(0xFF030305), // Cosmic dark base
      body: Stack(
        children: [
          // Ambient Background
          Positioned.fill(
            child: CustomPaint(
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
                  const Text('Meetra', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: Colors.white, letterSpacing: -0.5)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.white), onPressed: () {}),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B202D), // Dark slate search bg
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ask Meetra AI or Search',
                    hintStyle: const TextStyle(color: Color(0xFF8B95A5), fontSize: 15),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF8B95A5), size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.close, color: Color(0xFF8B95A5), size: 18),
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
                  return GestureDetector(
                    onTap: () => setState(() => _activeChip = chip),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF0D2B22) : const Color(0xFF1B202D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? const Color(0xFF00E5CC) : Colors.transparent),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF00E5CC) : const Color(0xFF8B95A5),
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
        backgroundColor: const Color(0xFF1B202D),
        elevation: 4,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFFFF0055)],
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
        return _CommunitiesView(searchQuery: _searchQuery);
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
        return _ChatsView(searchQuery: _searchQuery, filter: _activeChip);
    }
  }
}

// =============================================================================
// CHATS VIEW — Real Supabase Conversations
// =============================================================================
class _ChatsView extends StatefulWidget {
  final String searchQuery;
  final String filter;
  const _ChatsView({required this.searchQuery, this.filter = 'All'});

  @override
  State<_ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<_ChatsView> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final Map<String, Map<String, String>> _profileCache = {};
  List<MapEntry<String, Map<String, dynamic>>> _conversations = [];
  bool _loading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchConversations());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
      for (final m in (allMsgs as List)) {
        final partnerId = m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];
        if (partnerId == null) continue;
        if (!convos.containsKey(partnerId)) {
          convos[partnerId] = Map<String, dynamic>.from(m);
        }
      }

      // Pre-fetch all profiles
      for (final partnerId in convos.keys) {
        await _getProfile(partnerId);
      }

      if (mounted) {
        setState(() {
          _conversations = convos.entries.toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch conversations error: $e');
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid.isEmpty) {
      return const Center(child: Text('Please sign in to see messages', style: TextStyle(color: Colors.white38)));
    }

    if (_loading) return _buildShimmer();

    // Apply Chip Filter
    var filtered = _conversations.where((entry) {
      if (widget.searchQuery.isNotEmpty) {
        final profile = _profileCache[entry.key];
        final name = profile?['name'] ?? '';
        return name.toLowerCase().contains(widget.searchQuery);
      }
      
      if (widget.filter == 'Unread') {
        // Simple mock for unread: if sender is not me and is_read == false
        final m = entry.value;
        return m['sender_id'] != _myUid && m['is_read'] == false;
      }
      // Favourites mock
      if (widget.filter == 'Favourites') {
        return entry.key.hashCode % 5 == 0; 
      }
      return true;
    }).toList();

    if (filtered.isEmpty && widget.searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            const Text('No conversations found', style: TextStyle(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // Include static items if 'All' is selected and no search query
    final bool showStaticRows = widget.filter == 'All' && widget.searchQuery.isEmpty;
    final int itemCount = filtered.length + (showStaticRows ? 2 : 0);

    return RefreshIndicator(
      onRefresh: _fetchConversations,
      color: const Color(0xFF00E5CC),
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive coming soon! 📦')));
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
          final msgText = isImage ? '📸 Photo' : (lastMsg['text'] as String? ?? '');
          final preview = msgText;
          final isRead = lastMsg['is_read'] == true;
          final isPinned = partnerId.hashCode % 4 == 0; // Mock pinned
          final isMuted = partnerId.hashCode % 7 == 0; // Mock muted
          final unreadCount = (!isMe && !isRead) ? 1 : 0; // Mock count

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
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatDetailScreen(targetUserId: partnerId, name: name, avatarUrl: avatar),
              ));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: unreadCount > 0 ? const Color(0xFF00E5CC).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
                boxShadow: unreadCount > 0 ? [BoxShadow(color: const Color(0xFF00E5CC).withValues(alpha: 0.05), blurRadius: 10)] : null,
              ),
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
                            Text(timeLabel, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF00E5CC) : const Color(0xFF8B95A5), fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
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
                                decoration: const BoxDecoration(color: Color(0xFF00E5CC), shape: BoxShape.circle),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
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
                    ? [const Color(0xFF8B5CF6), const Color(0xFFEC4899)]
                    : [const Color(0xFF00E5FF), const Color(0xFF3B4CCA)],
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
                  color: isHost ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isHost ? 'HOST' : 'JOINED',
                  style: TextStyle(color: isHost ? const Color(0xFF8B5CF6) : const Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.w800),
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

  @override
  void initState() {
    super.initState();
    _loadKnocks();
  }

  Future<void> _loadKnocks() async {
    try {
      final reqs = await Supabase.instance.client
          .from('requests')
          .select('sender_id, target_id')
          .eq('target_type', 'profile')
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    
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
          preview = isImage ? '📸 Photo' : (lastMsg['text'] as String? ?? '');
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
                          Text(timeLabel, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF00E5CC) : const Color(0xFF8B95A5), fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: TextStyle(color: lastMsg != null ? const Color(0xFF8B95A5) : const Color(0xFF00E5CC), fontSize: 14, fontStyle: lastMsg != null ? FontStyle.normal : FontStyle.italic),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF00E5CC), shape: BoxShape.circle),
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    
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
          preview = isImage ? '📸 Photo' : (lastMsg['text'] as String? ?? '');
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
                          Text(timeLabel, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF00E5CC) : const Color(0xFF8B95A5), fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: TextStyle(color: lastMsg != null ? const Color(0xFF8B95A5) : const Color(0xFF00E5CC), fontSize: 14, fontStyle: lastMsg != null ? FontStyle.normal : FontStyle.italic),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF00E5CC), shape: BoxShape.circle),
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
// COMMUNITIES VIEW — Clean, No Alex Gating
// =============================================================================
class _CommunitiesView extends StatefulWidget {
  final String searchQuery;
  const _CommunitiesView({required this.searchQuery});

  @override
  State<_CommunitiesView> createState() => _CommunitiesViewState();
}

class _CommunitiesViewState extends State<_CommunitiesView> {
  final List<Map<String, dynamic>> _communities = [
    {'name': 'Delhi Startup Hustlers', 'members': 142, 'img': 'https://picsum.photos/seed/startupdelhi/400', 'joined': false, 'desc': 'Connect with founders & builders'},
    {'name': 'Lodi Gardens Fitness', 'members': 89, 'img': 'https://picsum.photos/seed/lodifit/400', 'joined': false, 'desc': 'Morning runs & workout sessions'},
    {'name': 'CP Coffee Addicts', 'members': 345, 'img': 'https://picsum.photos/seed/cpcoffee/400', 'joined': false, 'desc': 'Best cafes & coffee conversations'},
    {'name': 'Weekend Hikers', 'members': 56, 'img': 'https://picsum.photos/seed/hikers/400', 'joined': true, 'desc': 'Weekend treks near Delhi NCR'},
    {'name': 'Music Jammers', 'members': 201, 'img': 'https://picsum.photos/seed/musicjam2/400', 'joined': false, 'desc': 'Open mic nights & jam sessions'},
    {'name': 'Tech Meetup Circle', 'members': 178, 'img': 'https://picsum.photos/seed/techcircle/400', 'joined': false, 'desc': 'Hackathons, talks & learning'},
  ];

  void _joinCommunity(int idx) {
    HapticFeedback.mediumImpact();
    setState(() { _communities[idx]['joined'] = true; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Welcome to ${_communities[idx]['name']}! 🎉'),
      backgroundColor: const Color(0xFF00E5FF),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _createCommunity() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D0D12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_add, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text('New Community', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Community Name',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      setState(() {
                        _communities.insert(0, {
                          'name': ctrl.text.trim(),
                          'members': 1,
                          'img': 'https://picsum.photos/seed/${ctrl.text.trim()}/400',
                          'joined': true,
                          'desc': 'Your new community',
                        });
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                  ),
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
    final filtered = _communities.where((c) {
      final name = (c['name'] as String).toLowerCase();
      return widget.searchQuery.isEmpty || name.contains(widget.searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, color: Colors.white.withValues(alpha: 0.1), size: 64),
                  const SizedBox(height: 16),
                  const Text('No communities found', style: TextStyle(color: Colors.white24, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final comm = filtered[index];
                final isJoined = comm['joined'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101015),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isJoined ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(comm['img'] as String, width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: const Color(0xFF1A1A2E), child: const Icon(Icons.group, color: Colors.white24))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comm['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(comm['desc'] as String, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.people, color: Colors.white24, size: 12),
                                const SizedBox(width: 4),
                                Text('${comm['members']} members', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isJoined)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 14),
                              SizedBox(width: 4),
                              Text('Joined', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          // find original index for joining
                          onTap: () {
                            final origIdx = _communities.indexOf(comm);
                            if (origIdx >= 0) _joinCommunity(origIdx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF3B4CCA)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        onPressed: _createCommunity,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
  bool _isLoading = true;
  bool _isChatLocked = true;
  bool _isConnectionLoading = true;
  bool _memberChatEnabled = false;

  @override
  void initState() {
    super.initState();
    _memberChatEnabled = widget.memberChatEnabled;
    _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    
    if (widget.isUnlocked) {
      _isChatLocked = false;
      _isConnectionLoading = false;
    } else {
      _fetchConnectionStatus();
    }
    
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
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

      if (mounted) setState(() { _isChatLocked = true; _isConnectionLoading = false; });
    } catch (e) {
      debugPrint('Chat lock check error: $e');
      if (mounted) setState(() { _isChatLocked = true; _isConnectionLoading = false; });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
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

      if (mounted) {
        if (_messages.length != newMsgs.length || _isLoading) {
          final wasAtBottom = _scrollController.hasClients && _scrollController.position.pixels == _scrollController.position.maxScrollExtent;
          setState(() {
            _messages = newMsgs;
            _isLoading = false;
          });
          if (wasAtBottom || _isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
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
    };
    
    setState(() => _messages.add(tempMsg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _myUid,
        'receiver_id': widget.targetUserId,
        'text': text,
        'is_image': false,
      });

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

  @override
  Widget build(BuildContext context) {
    final bgColor = _chatThemes[widget.targetUserId] ?? const Color(0xFF0D0F14);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF0D0F14), // WhatsApp style app bar
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(radius: 20, backgroundImage: _safeImageProvider(widget.avatarUrl), backgroundColor: const Color(0xFF1A1A2E)),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF050508), width: 2),
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
                  Text(widget.isGroupChat ? 'Group Chat' : 'online', style: TextStyle(color: widget.isGroupChat ? Colors.white54 : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white, size: 22), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
            color: const Color(0xFF1B202D),
            onSelected: (value) async {
              if (value == 'wallpaper') {
                _showThemePicker();
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
                      backgroundColor: const Color(0xFF00E5FF),
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
              const PopupMenuItem(value: 'clear', child: Text('Clear chat', style: TextStyle(color: Colors.white))),
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
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
              : (_messages.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.waving_hand, color: Color(0xFF00E5FF), size: 40),
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
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                if (!isImage) {
                                  Clipboard.setData(ClipboardData(text: msg['text'] as String));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Message copied'),
                                      backgroundColor: const Color(0xFF3B4CCA),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: isMe
                                              ? const LinearGradient(colors: [Color(0xFF00C2E0), Color(0xFF3B4CCA)])
                                              : null,
                                          color: isMe ? null : Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(20),
                                            topRight: const Radius.circular(20),
                                            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                          ),
                                        ),
                                        padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: isImage 
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: _buildImage(msg['text'] as String),
                                              )
                                            : Text(msg['text'] as String, style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 14, height: 1.4)),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.done_all, color: Color(0xFF00E5FF), size: 12),
                                          ],
                                        ],
                                      ),
                                    ],
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
          if (widget.isClosed)
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
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, color: Color(0xFF8B5CF6), size: 32),
                        SizedBox(height: 12),
                        Text('Connection Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 6),
                        Text('Both users must mutually connect and accept the Knock request before chatting is unlocked.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
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
                color: const Color(0xFF0D0D12),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _sendImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle),
                      child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white54, size: 22),
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
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF3B4CCA)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)));

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
      color: const Color(0xFFEC4899),
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
                border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.05), blurRadius: 10),
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
                        Text(text, style: const TextStyle(color: Color(0xFFEC4899), fontSize: 14, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const Icon(Icons.favorite, color: Color(0xFFEC4899), size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


