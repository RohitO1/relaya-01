import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'widgets/skeleton_loaders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messages_screen.dart';
import 'communities_screen.dart';
import 'knocks_list_screen.dart';
import 'services/doodle_theme.dart';
import 'services/location_service.dart';
import 'widgets/create_community_sheet.dart';

enum ChatItemType { dm, group, channel, request }

class ChatListItem {
  final ChatItemType type;
  final DateTime lastActivity;
  final String? partnerId;
  final Map<String, dynamic>? dmLastMessage;
  final Community? community;
  final int? unreadCount;

  ChatListItem({
    required this.type,
    required this.lastActivity,
    this.partnerId,
    this.dmLastMessage,
    this.community,
    this.unreadCount,
  });
}

class ChatScreen extends StatefulWidget {
  final bool isBolroomMode;
  const ChatScreen({super.key, this.isBolroomMode = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  bool _isLoading = true;
  List<ChatListItem> _unifiedItems = [];
  final Map<String, Map<String, String>> _profileCache = {};
  final Map<String, int> _unreadCounts = {};
  final Set<String> _locallyDeletedChats = {};
  int _pendingKnocksCount = 0;
  Timer? _pollingTimer;

  // UI state matching reference image
  final PageController _pageController = PageController(initialPage: 0);
  int _currentIndex = 0;

  // Source tags for conversations (simulated based on index)
  static const _sourceTags = [
    'Explore',
    'Rush-in',
    'General',
    'Activity',
    'Explore',
    'General'
  ];

  @override
  void initState() {
    super.initState();
    _loadDeletedChats();
    _fetchConversations();
    _pollingTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _fetchConversations());
    locationService.activeDistrictNotifier.addListener(_onLocationChanged);
  }

  String _communitySearchQuery = '';
  List<Community> _searchedCommunities = [];
  bool _isSearchingCommunities = false;
  Timer? _searchDebounceTimer;

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  void _searchCommunities(String query) {
    if (_searchDebounceTimer?.isActive ?? false) _searchDebounceTimer!.cancel();
    setState(() {
      _communitySearchQuery = query;
      if (query.isEmpty) {
        _isSearchingCommunities = false;
        _searchedCommunities.clear();
        return;
      }
      _isSearchingCommunities = true;
    });

    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await Supabase.instance.client
            .from('text_camps')
            .select('*, text_camp_messages(user_id, text, created_at)')
            .or('name.ilike.%$query%,location_district.ilike.%$query%')
            .order('member_count', ascending: false)
            .limit(50);

        final List<Community> searchResults = [];
        final List data = res as List;
        for (var row in data) {
          searchResults.add(Community(
            id: row['id'].toString(),
            name: row['name'] as String,
            category: row['category'] as String? ?? 'General',
            creatorId: row['creator_id'] as String? ?? '',
            memberCount: row['member_count'] as int? ?? 1,
            avatar: row['avatar_url'] as String? ??
                'https://images.unsplash.com/photo-1516862523118-a3724eb136d7?auto=format&fit=crop&w=150&q=80',
            lastMessage: 'Welcome to ${row['name']}!',
            lastMessageTime: 'Just now',
            unreadCount: 0,
            locationDistrict: row['location_district'] as String?,
            channels: [CommunityChannel(name: 'general', messages: [])],
            isPrivate: row['is_private'] as bool? ?? false,
            description: row['description'] as String?,
            locationState: row['location_state'] as String?,
            bannerColor: row['banner_color'] as String? ?? '',
            icon: row['icon'] as String? ?? '',
            avatarUrl: row['avatar_url'] as String?,
          ));
        }

        if (mounted && _communitySearchQuery == query) {
          setState(() {
            _searchedCommunities = searchResults;
          });
        }
      } catch (e) {
        debugPrint('Error searching communities: $e');
      }
    });
  }

  Future<void> _loadDeletedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('deleted_chats') ?? [];
    if (mounted) {
      setState(() {
        _locallyDeletedChats.addAll(list);
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pageController.dispose();
    locationService.activeDistrictNotifier.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _fetchConversations() async {
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

      final requestsRes = await Supabase.instance.client
          .from('requests')
          .select('id')
          .eq('target_id', _myUid)
          .eq('status', 'pending')
          .eq('target_type', 'profile');
      final knocksCount = (requestsRes as List).length;

      final Map<String, Map<String, dynamic>> convos = {};
      final Map<String, int> unreads = {};
      final Set<String> _mySents = {};
      final Set<String> _theirSents = {};

      for (final m in (allMsgs as List)) {
        final partnerId =
            m['sender_id'] == _myUid ? m['receiver_id'] : m['sender_id'];
        if (partnerId == null || _locallyDeletedChats.contains(partnerId))
          continue;

        if (m['sender_id'] == _myUid) {
          _mySents.add(partnerId);
        } else {
          _theirSents.add(partnerId);
          if (m['is_read'] == false) {
            unreads[partnerId] = (unreads[partnerId] ?? 0) + 1;
          }
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
            _profileCache[partnerId] = {
              'name': 'User',
              'avatar': 'https://picsum.photos/seed/$partnerId/100'
            };
          }
        }
      }

      // Fetch Communities (Groups & Channels)
      final membersRes = await Supabase.instance.client
          .from('text_camp_members')
          .select('camp_id')
          .eq('user_id', _myUid);
      final joinedIds =
          (membersRes as List).map((m) => m['camp_id'].toString()).toSet();

      List<Community> communities = [];
      if (joinedIds.isNotEmpty) {
        final campsRes = await Supabase.instance.client
            .from('text_camps')
            .select('*, text_camp_messages(user_id, text, created_at)')
            .inFilter('id', joinedIds.toList())
            .order('created_at', ascending: false)
            .order('created_at',
                referencedTable: 'text_camp_messages', ascending: false)
            .limit(1, referencedTable: 'text_camp_messages');

        final prefs = await SharedPreferences.getInstance();
        communities = (campsRes as List).map((row) {
          final messagesList = row['text_camp_messages'] as List?;
          String lastMsg = "Welcome to ${row['name']}!";
          String lastMsgTime = "Just now";
          int unreadCount = 0;
          DateTime lastMsgDt = DateTime.parse(row['created_at']?.toString() ??
              DateTime.now().toIso8601String());

          if (messagesList != null && messagesList.isNotEmpty) {
            final first = messagesList.first;
            final rawText = first['text'] as String? ?? '';
            if (rawText.startsWith('[IMAGE]')) {
              lastMsg = '📷 Photo';
            } else if (rawText.startsWith('[AUDIO]')) {
              lastMsg = '🎵 Voice message';
            } else {
              lastMsg = rawText;
            }
            final createdAtStr = first['created_at'] as String?;
            if (createdAtStr != null) {
              try {
                lastMsgDt = DateTime.parse(createdAtStr).toLocal();
                lastMsgTime = _formatTimestamp(lastMsgDt.toIso8601String());
              } catch (_) {}
            }
            final senderId = first['user_id'] as String? ?? '';
            if (senderId != _myUid) {
              final lastReadStr =
                  prefs.getString('community_last_read_${row['id']}');
              if (lastReadStr != null && createdAtStr != null) {
                try {
                  final lastRead = DateTime.parse(lastReadStr);
                  if (lastMsgDt.isAfter(lastRead)) {
                    unreadCount = 1;
                  }
                } catch (_) {}
              } else {
                unreadCount = 1;
              }
            }
          }

          return Community(
            id: row['id'] ?? '',
            name: row['name'] ?? '',
            category: row['category'] ?? 'General',
            creatorId: row['creator_id'] ?? '',
            memberCount: row['member_count'] ?? 1,
            avatar: row['avatar_url'] ??
                'https://images.unsplash.com/photo-1516862523118-a3724eb136d7?auto=format&fit=crop&w=150&q=80',
            lastMessage: lastMsg,
            lastMessageTime: lastMsgTime,
            unreadCount: unreadCount,
            locationDistrict: row['location_district'] as String?,
            channels: [], // mock
            isPrivate: row['is_private'] ?? false,
            chatType: row['chat_type'] ?? 'group',
            isBroadcastOnly: row['is_broadcast_only'] ?? false,
            description: row['description'] as String?,
            locationState: row['location_state'] as String?,
            bannerColor: row['banner_color'] as String? ?? '',
            icon: row['icon'] as String? ?? '',
            avatarUrl: row['avatar_url'] as String?,
          );
        }).toList();
      }

      final List<ChatListItem> items = [];

      // Process DMs and Requests
      for (final kv in convos.entries) {
        final partnerId = kv.key;
        final msg = kv.value;
        final isRequest =
            !_mySents.contains(partnerId) && _theirSents.contains(partnerId);

        items.add(ChatListItem(
          type: isRequest ? ChatItemType.request : ChatItemType.dm,
          lastActivity:
              DateTime.tryParse(msg['created_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
          partnerId: partnerId,
          dmLastMessage: msg,
          unreadCount: unreads[partnerId] ?? 0,
        ));
      }

      // Add Communities
      for (final c in communities) {
        items.add(ChatListItem(
          type: c.chatType == 'channel'
              ? ChatItemType.channel
              : ChatItemType.group,
          lastActivity: DateTime.tryParse(c.lastMessageTime) ??
              DateTime.now(), // approximation, we need actual dt
          community: c,
          unreadCount: c.unreadCount,
        ));
      }

      // Sort
      items.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      if (mounted) {
        setState(() {
          _unreadCounts.clear();
          _unreadCounts.addAll(unreads);
          _unifiedItems = items;
          _pendingKnocksCount = knocksCount;
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
      if (!isoString.endsWith('Z') && !isoString.contains('+')) {
        isoString = '${isoString}Z';
      }
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

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Create New',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading:
                    const Icon(Icons.person_add_outlined, color: Colors.white),
                title: Text('New Direct Message',
                    style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showComposeSheet();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.people_alt_outlined, color: Colors.white),
                title: Text('New Group',
                    style: GoogleFonts.inter(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  showAdvancedCreateCommunitySheet(context, () {
                    _fetchConversations();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComposeSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF000000),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Text('New Message',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                        child: Text('Followers list will appear here',
                            style: TextStyle(color: Colors.white38))),
                  ),
                ],
              );
            },
          );
        });
  }

  Future<void> _handleDelete(String partnerId) async {
    setState(() {
      _unifiedItems.removeWhere(
          (c) => c.type == ChatItemType.dm && c.partnerId == partnerId);
      _locallyDeletedChats.add(partnerId);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList('deleted_chats', _locallyDeletedChats.toList());

      await Supabase.instance.client.from('messages').delete().or(
          'and(sender_id.eq.$_myUid,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$_myUid)');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Chat deleted')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete chat: $e')));
    }
  }

  Future<void> _handleMute(String partnerId) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Chat muted')));
  }

  void _showChatOptions(String partnerId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B202D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Options for $name',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Chat',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDelete(partnerId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined,
                    color: Colors.white),
                title: const Text('Mute Chat',
                    style: TextStyle(color: Colors.white)),
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
    final doodle = isDoodleMode(context);
    return Scaffold(
      backgroundColor: doodle ? DoodleColors.cream : const Color(0xFF000000),
      body: Stack(
        children: [
          // Doodle background
          if (doodle)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Container(decoration: DoodleDecorations.parchmentBg()),
                    CustomPaint(
                        painter: ScatteredDoodlesPainter(
                            seed: 55,
                            density: 0.3,
                            color: const Color(0x18B8956E))),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ──
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 16, bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TEXT CAMPS',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {}, // Search action
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.search,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showCreateOptions, // Plus action
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF6B00)),
                          ),
                          child: const Icon(Icons.add,
                              color: Color(0xFFFF6B00), size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // ── Section Title (Direct Messages or Groups) ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_pageController.hasClients) {
                            _pageController.animateToPage(0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut);
                          }
                          setState(() => _currentIndex = 0);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direct Messages',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: _currentIndex == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _currentIndex == 0
                                    ? (doodle
                                        ? DoodleColors.textPrimary
                                        : Colors.white)
                                    : (doodle
                                        ? DoodleColors.textSecondary
                                        : Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_currentIndex == 0)
                              Container(
                                  width: 32,
                                  height: 2,
                                  color: const Color(0xFFFF6B00))
                            else
                              const SizedBox(height: 2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () {
                          if (_pageController.hasClients) {
                            _pageController.animateToPage(1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut);
                          }
                          setState(() => _currentIndex = 1);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Communities',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: _currentIndex == 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _currentIndex == 1
                                    ? (doodle
                                        ? DoodleColors.textPrimary
                                        : Colors.white)
                                    : (doodle
                                        ? DoodleColors.textSecondary
                                        : Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_currentIndex == 1)
                              Container(
                                  width: 32,
                                  height: 2,
                                  color: const Color(0xFFFF6B00))
                            else
                              const SizedBox(height: 2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () {
                          if (_pageController.hasClients) {
                            _pageController.animateToPage(2,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut);
                          }
                          setState(() => _currentIndex = 2);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Requests',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: _currentIndex == 2
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _currentIndex == 2
                                        ? (doodle
                                            ? DoodleColors.textPrimary
                                            : Colors.white)
                                        : (doodle
                                            ? DoodleColors.textSecondary
                                            : Colors.white54),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_currentIndex == 2)
                              Container(
                                  width: 32,
                                  height: 2,
                                  color: const Color(0xFFFF6B00))
                            else
                              const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Content area ──
                Expanded(
                  child: _myUid.isEmpty
                      ? Center(
                          child: Text('Please sign in to see messages',
                              style: TextStyle(
                                  color: doodle
                                      ? DoodleColors.textMuted
                                      : Colors.white54)))
                      : _isLoading
                          ? SkeletonLoaders.chatListSkeleton(
                              doodle: isDoodleMode(context))
                          : PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() => _currentIndex = index);
                              },
                              children: [
                                _buildListView(ChatItemType.dm),
                                _buildListView(ChatItemType.group),
                                _buildListView(ChatItemType.request),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
// Removed FloatingActionButton because tabs were added to the header
    );
  }

  Widget _buildListView(ChatItemType targetType) {
    if (targetType == ChatItemType.group && _communitySearchQuery.isNotEmpty) {
      return Column(
        children: [
          _buildPremiumSearchBar(),
          if (_searchedCommunities.isEmpty && _isSearchingCommunities)
            const Expanded(
                child: Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFFF6B00)))),
          if (_searchedCommunities.isEmpty && !_isSearchingCommunities)
            Expanded(
                child: Center(
                    child: Text("No communities found.",
                        style: GoogleFonts.inter(color: Colors.white54)))),
          if (_searchedCommunities.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchedCommunities.length,
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                itemBuilder: (context, index) {
                  return _buildCommunityCard(_searchedCommunities[index]);
                },
              ),
            ),
        ],
      );
    }

    final userDistrict = locationService.activeDistrict.toLowerCase().trim();

    final filtered = _unifiedItems.where((i) {
      if (targetType == ChatItemType.dm) return i.type == ChatItemType.dm;
      if (targetType == ChatItemType.request)
        return i.type == ChatItemType.request;
      if (i.type != ChatItemType.group && i.type != ChatItemType.channel)
        return false;
      // Location filter: if user has an active district, only show communities
      // that are untagged or match the active district.
      final c = i.community!;
      if (userDistrict.isNotEmpty && userDistrict != 'unknown') {
        final cd = (c.locationDistrict ?? '').toLowerCase().trim();
        if (cd.isNotEmpty && cd != 'unknown') {
          return cd.contains(userDistrict) || userDistrict.contains(cd);
        }
      }
      return true;
    }).toList();

    Widget body;
    if (filtered.isEmpty) {
      if (targetType == ChatItemType.group ||
          targetType == ChatItemType.channel) {
        body = _buildCommunitiesEmptyState();
      } else if (targetType == ChatItemType.request) {
        body = _buildRequestsEmptyState();
      } else {
        body = _buildEmptyState();
      }
    } else {
      final showKnocks =
          targetType == ChatItemType.dm && _pendingKnocksCount > 0;

      body = ListView.builder(
        itemCount: filtered.length + (showKnocks ? 1 : 0),
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        itemBuilder: (context, index) {
          if (showKnocks && index == 0) return _buildKnocksRow();
          final itemIndex = showKnocks ? index - 1 : index;
          final item = filtered[itemIndex];

          if (item.type == ChatItemType.dm ||
              item.type == ChatItemType.request) {
            return _buildConversationRow(
                item.partnerId!, item.dmLastMessage!, itemIndex,
                isRequestType: item.type == ChatItemType.request);
          } else {
            return _buildCommunityCard(item.community!);
          }
        },
      );
    }

    if (targetType == ChatItemType.group) {
      return Column(children: [
        _buildPremiumSearchBar(),
        Expanded(child: body),
      ]);
    }
    return body;
  }

  Widget _buildCommunitiesEmptyState() {
    final userDistrict = locationService.activeDistrict;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 2),
              ),
              child: const Icon(Icons.people_outline,
                  size: 52, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            Text(
              userDistrict.isNotEmpty
                  ? 'No communities in $userDistrict'
                  : 'No communities yet',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              userDistrict.isNotEmpty
                  ? 'Be the first to create a local community for your area!'
                  : 'Join or create a community to connect with people around you.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                color: Color(0xFFFF6B00), size: 44),
          ),
          const SizedBox(height: 20),
          Text('No Pending Requests',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'When someone sends you a first message,\nit will appear here for review.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.white38, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState() {
    final doodle = isDoodleMode(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: doodle ? DoodleColors.paper : Colors.transparent,
              border: Border.all(
                  color: doodle ? DoodleColors.cardBorder : Colors.white12,
                  width: doodle ? 2 : 2),
            ),
            child: Icon(Icons.near_me_outlined,
                size: 60, color: doodle ? DoodleColors.orange : Colors.white),
          ),
          const SizedBox(height: 24),
          Text('No messages yet',
              style: doodle
                  ? DoodleFonts.subheading(
                      fontSize: 24, fontWeight: FontWeight.w700)
                  : GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
          const SizedBox(height: 12),
          Text('Start a conversation with your connections.',
              style: doodle
                  ? DoodleFonts.body(
                      fontSize: 14, color: DoodleColors.textSecondary)
                  : GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
          const SizedBox(height: 32),
          if (doodle)
            DoodleButton(
                text: 'Start a chat',
                onTap: _showComposeSheet,
                icon: Icons.chat_bubble_outline)
          else
            ElevatedButton(
              onPressed: _showComposeSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: Text('Start a chat',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  // ── Knocks Row ──
  Widget _buildKnocksRow() {
    return InkWell(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const KnocksListScreen()));
        _fetchConversations(); // Refresh knocks count when returning
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Icon(Icons.person_add_outlined,
                      color: Colors.white70),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B00),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_pendingKnocksCount',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
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
                  Text(
                    'Knock Requests',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$_pendingKnocksCount pending request${_pendingKnocksCount == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF6B00),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // ── Conversation row matching reference exactly ──
  Widget _buildConversationRow(
      String partnerId, Map<String, dynamic> lastMsg, int index,
      {bool isRequestType = false}) {
    final profile = _profileCache[partnerId] ?? {'name': 'User', 'avatar': ''};
    final name = profile['name']!;
    final avatar = profile['avatar']!;

    final isImage = lastMsg['is_image'] == true;
    final msgText =
        isImage ? 'Sent an image' : (lastMsg['text'] as String? ?? '');
    final unreadCount = _unreadCounts[partnerId] ?? 0;
    final timeStr = _formatTimestamp(lastMsg['created_at']);
    final isUnread = unreadCount > 0;

    // Source tag for this conversation
    final sourceTag = _sourceTags[index % _sourceTags.length];
    final tagColor = _getTagColor(sourceTag);
    final doodle = isDoodleMode(context);

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
              isUnlocked: !isRequestType,
            ),
          ),
        );
        _fetchConversations();
      },
      child: Container(
        margin: EdgeInsets.symmetric(
            horizontal: doodle ? 16 : 0, vertical: doodle ? 6 : 0),
        decoration: doodle ? DoodleDecorations.card() : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              doodle
                  ? DoodleAvatar(
                      url: avatar,
                      size: 52,
                      borderColor: isUnread
                          ? DoodleColors.orange
                          : DoodleColors.cardBorder)
                  : CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF1A1A1A),
                      backgroundImage:
                          avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
              const SizedBox(width: 14),

              // Name, message, source tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: doodle
                          ? DoodleFonts.subheading(
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: DoodleColors.textPrimary,
                              fontSize: 18,
                            )
                          : GoogleFonts.inter(
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRequestType ? 'Sent you a message request' : msgText,
                      style: doodle
                          ? DoodleFonts.body(
                              color: isUnread
                                  ? DoodleColors.textPrimary
                                  : DoodleColors.textSecondary,
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )
                          : GoogleFonts.inter(
                              color: isUnread
                                  ? Colors.white70
                                  : const Color(0xFF7A7A7A),
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Source tag chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: doodle
                          ? DoodleDecorations.chip()
                          : BoxDecoration(
                              color: tagColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                      child: Text(
                        sourceTag,
                        style: doodle
                            ? DoodleFonts.label(
                                color: DoodleColors.textMuted, fontSize: 10)
                            : GoogleFonts.inter(
                                color: tagColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Timestamp and Unread Badge Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      timeStr,
                      style: doodle
                          ? DoodleFonts.caption(
                              color: DoodleColors.textHint, fontSize: 12)
                          : GoogleFonts.inter(
                              color: const Color(0xFF7A7A7A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: doodle
                            ? DoodleColors.coral
                            : const Color(0xFFFF6B00),
                        shape: BoxShape.circle,
                        border: doodle
                            ? Border.all(color: DoodleColors.cream, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
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

  // ── Premium Community / Group Card ──
  Widget _buildPremiumSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1629).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400),
              onChanged: _searchCommunities,
              decoration: InputDecoration(
                hintText: 'Search communities or cities...',
                hintStyle: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                    fontWeight: FontWeight.w400),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.35), size: 20),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityCard(Community c) {
    final bool isUnread = c.unreadCount > 0;
    final userDistrict = locationService.activeDistrict.toLowerCase().trim();
    final communityDistrict = (c.locationDistrict ?? '').toLowerCase().trim();
    final bool isLocal = userDistrict.isNotEmpty &&
        communityDistrict.isNotEmpty &&
        (communityDistrict.contains(userDistrict) ||
            userDistrict.contains(communityDistrict));
    final Color accentColor = _categoryColor(c.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) =>
                  CommunityChatRoomScreen(community: c),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0.04, 0), end: Offset.zero)
                      .animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 280),
            ),
          );
          _fetchConversations();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isUnread
                      ? [
                          accentColor.withValues(alpha: 0.12),
                          const Color(0xFF0E0A1A),
                        ]
                      : [
                          const Color(0xFF16131F),
                          const Color(0xFF0E0A18),
                        ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isUnread
                      ? accentColor.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.07),
                  width: 1.0,
                ),
                boxShadow: [
                  if (isUnread)
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left accent stripe
                  if (isUnread)
                    Container(
                      width: 3,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          bottomLeft: Radius.circular(22),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 3),

                  const SizedBox(width: 14),

                  // Avatar with glow effect
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Glow ring behind avatar
                      if (isUnread)
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(-4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isUnread
                                ? accentColor.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(c.avatar),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Local indicator
                      if (isLocal)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0E0A18), width: 2),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 8),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Main content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + time row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c.lastMessageTime,
                                style: GoogleFonts.inter(
                                  color: isUnread
                                      ? accentColor
                                      : Colors.white.withValues(alpha: 0.25),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Last message
                          Text(
                            c.lastMessage,
                            style: GoogleFonts.inter(
                              color: isUnread
                                  ? Colors.white.withValues(alpha: 0.65)
                                  : Colors.white.withValues(alpha: 0.35),
                              fontSize: 12.5,
                              fontWeight:
                                  isUnread ? FontWeight.w500 : FontWeight.w400,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Bottom metadata row
                          Row(
                            children: [
                              // Category pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: accentColor.withValues(alpha: 0.2),
                                      width: 0.8),
                                ),
                                child: Text(
                                  c.category,
                                  style: GoogleFonts.inter(
                                    color: accentColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Location pill
                              if ((c.locationDistrict ?? '').isNotEmpty &&
                                  c.locationDistrict != 'Unknown')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.place_rounded,
                                        color: isLocal
                                            ? const Color(0xFFFF6B00)
                                            : Colors.white
                                                .withValues(alpha: 0.25),
                                        size: 9,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        c.locationDistrict!,
                                        style: GoogleFonts.inter(
                                          color: isLocal
                                              ? Colors.white
                                                  .withValues(alpha: 0.55)
                                              : Colors.white
                                                  .withValues(alpha: 0.22),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              // Members count
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    color: Colors.white.withValues(alpha: 0.22),
                                    size: 11,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${c.memberCount}',
                                    style: GoogleFonts.inter(
                                      color:
                                          Colors.white.withValues(alpha: 0.28),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right: unread badge
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: isUnread
                        ? Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.55),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '${c.unreadCount}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.1),
                            size: 20,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('study') ||
        lower.contains('tech') ||
        lower.contains('code')) return const Color(0xFF6366F1);
    if (lower.contains('fit') ||
        lower.contains('gym') ||
        lower.contains('sport')) return const Color(0xFF22C55E);
    if (lower.contains('music') || lower.contains('art'))
      return const Color(0xFFEC4899);
    if (lower.contains('food') || lower.contains('coffee'))
      return const Color(0xFFF97316);
    if (lower.contains('travel')) return const Color(0xFF06B6D4);
    if (lower.contains('gaming') || lower.contains('game'))
      return const Color(0xFF8B5CF6);
    return const Color(0xFFFF6B00);
  }
}
