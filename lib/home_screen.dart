// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: avoid_print, unused_element, unused_field, use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'profile_screen.dart';
import 'services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'image_upload_service.dart';
import 'widgets/location_picker_sheet.dart';

import 'bolroom/bolroom_shell.dart';
import 'communities_screen.dart';
import 'main.dart';
import 'notifications_screen.dart';
import 'services/doodle_theme.dart';
import 'search_users_screen.dart';

// ==========================================
// COLORS & CONSTANTS
// ==========================================
class HomeColors {
  // Deep dark base inspired by the reference image
  static const bg = Color(0xFF000000);   // pure black
  static const bg2 = Color(0xFF0A0C12);  // near-black
  static const card = Color(0xFF10121A); // card surface — dark luxury slate
  static const cardH = Color(0xFF171A26); // card hover / elevated
  // Neon accent palette
  static const cyan = Color(0xFFFF6B00);    // brand orange
  static const purple = Color(0xFFFF7E40);  // warm amber
  static const pink = Color(0xFFFF3D00);    // deep orange-red
  static const orange = Color(0xFFFF6B00);  // vibrant brand orange
  static const blue = Color(0xFF4E8BFF);    // bright blue
  static const green = Color(0xFF4ADE80);   // neon green
  static const yellow = Color(0xFFFFC107);  // amber glow
  static const red = Color(0xFFFF3D5A);     // coral red
  // Text hierarchy
  static const txt = Color(0xFFFFFFFF);     // pure white
  static const txt2 = Color(0xFF9E9E9E);    // muted grey
  static const muted = Color(0xFF616161);   // deep muted
  // Glass surfaces and buttons
  static const glass = Color(0xFF0C0E14);   // dark obsidian buttons
  static const gb = Color(0x0AFFFFFF);      // softer frosted glass border
  // Extra: glow colors for ambient FX
  static const glowCyan = Color(0x20FF6B00);
  static const glowPurple = Color(0x20FF7E40);
  static const glowMagenta = Color(0x20FF3D00);
}

const _kInterests = [
  {'key': 'music', 'icon': Icons.music_note, 'label': 'Music'},
  {'key': 'health', 'icon': Icons.favorite_border, 'label': 'Health'},
  {'key': 'tech', 'icon': Icons.laptop, 'label': 'Tech'},
  {'key': 'dance', 'icon': Icons.directions_run, 'label': 'Dance'},
  {'key': 'art', 'icon': Icons.palette, 'label': 'Art'},
  {'key': 'study', 'icon': Icons.menu_book, 'label': 'Study'},
  {'key': 'sports', 'icon': Icons.sports_basketball, 'label': 'Sports'},
  {'key': 'food', 'icon': Icons.restaurant, 'label': 'Food'},
  {'key': 'travel', 'icon': Icons.flight, 'label': 'Travel'},
  {'key': 'gaming', 'icon': Icons.sports_esports, 'label': 'Gaming'},
];

// Match percentage gradient colors
List<Color> _matchGradient(int pct) {
  if (pct >= 70) return [HomeColors.cyan, HomeColors.green];
  if (pct >= 55) return [HomeColors.purple, HomeColors.pink];
  if (pct >= 40) return [HomeColors.orange, HomeColors.yellow];
  return [HomeColors.blue, HomeColors.cyan];
}

Color _matchColor(int pct) {
  if (pct >= 70) return HomeColors.green;
  if (pct >= 55) return HomeColors.purple;
  if (pct >= 40) return HomeColors.orange;
  return HomeColors.blue;
}

// ==========================================
// HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  final _scrollCtrl = ScrollController();

  // -- State --
  String? _activeFilter; // null = "For You"
  bool _fabVisible = true;
  double _lastScrollY = 0;

  // -- Feed --
  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = true;
  final Map<String, int> _likeCounts = {};
  final Map<String, bool> _userLikedMap = {};
  final Map<String, int> _commentCounts = {};
  final Map<String, List<Map<String, dynamic>>> _commentPreviews = {};
  final Set<String> _bookmarkedPosts = {};
  final Set<String> _hiddenPosts = {};

  // -- Profile cache (for comments/header) --
  Map<String, dynamic>? _myProfile;

  // -- Panels --
  bool _notifOpen = false;
  bool _msgOpen = false;
  String _msgTab = 'chats';
  Set<String> _followingIds = {};

  // -- Messages data --
  List<Map<String, dynamic>> _chatList = [];
  bool _loadingChats = false;

  // -- Location --
  double? _myLat, _myLng;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    locationService.activeLocationNotifier.addListener(_onLocationChanged);
    locationService.coordinatesUpdateNotifier.addListener(_onLocationChanged);
    _loadFeed();
    _loadBookmarks();
    _loadChats();
    _initLocation();
    _loadMyProfile();
  }

  void _onLocationChanged() {
    _loadFeed();
  }

  @override
  void dispose() {
    locationService.activeLocationNotifier.removeListener(_onLocationChanged);
    locationService.coordinatesUpdateNotifier.removeListener(_onLocationChanged);
    _scrollCtrl.dispose();
    for (final notifier in _carouselPageMap.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final cur = _scrollCtrl.offset;
    if (cur > _lastScrollY + 10 && cur > 200 && _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (cur < _lastScrollY - 10 && !_fabVisible) {
      setState(() => _fabVisible = true);
    }
    _lastScrollY = cur;
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      _myLat = pos.latitude;
      _myLng = pos.longitude;
    } catch (_) {}
  }

  // ==========================================
  // DATA LOADING
  // ==========================================
    Future<void> _loadFeed() async {
    setState(() => _loadingPosts = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      
      // Load following ids
      if (uid != null) {
        try {
          final followsReq = await _sb.from('requests')
              .select('target_id')
              .eq('sender_id', uid)
              .eq('target_type', 'follow')
              .eq('status', 'approved');
          final ids = (followsReq as List? ?? [])
              .map((r) => r['target_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          if (mounted) setState(() => _followingIds = ids);
        } catch (e) {
          debugPrint('loadFeed following error: $e');
        }
      }

      // Build base query
      var postQuery = _sb.from('posts')
          .select('*, profiles!posts_user_id_fkey(name, avatar_url)');

      List<dynamic> rows = [];
      
      final currentDistrict = locationService.activeDistrict.trim();
      if (currentDistrict.isNotEmpty && currentDistrict != 'Unknown') {
        postQuery = postQuery.ilike('district', '%$currentDistrict%');
      }
      
      if (_activeFilter == 'Trending') {
        rows = await postQuery.order('created_at', ascending: false).limit(50);
      } else {
        // default local feed (oldest first)
        rows = await postQuery.order('created_at', ascending: true).limit(50);
      }

      // Flatten the join so each post map has user_name and avatar_url at top level
      final flatRows = (rows).map((r) {
        final m = Map<String, dynamic>.from(r);
        final profile = m['profiles'] is Map ? m['profiles'] as Map : null;
        m['user_name'] = profile?['name'] ?? 'User';
        m['avatar_url'] = profile?['avatar_url'] ?? '';
        m.remove('profiles');
        return m;
      }).toList();

      final hiddenRows = uid != null
          ? await _sb.from('hidden_feed').select().eq('user_id', uid)
          : [];
      final hiddenIds = (hiddenRows as List? ?? [])
          .map((r) {
            final m = r as Map?;
            return (m?['post_id'] ?? m?['rush_in_id'] ?? '').toString();
          })
          .where((id) => id.isNotEmpty)
          .toSet();

      final postsRows = flatRows
          .where((p) => !hiddenIds.contains(p['id']?.toString()))
          .toList();
          
      // Sort: Followed users first, then by date (unless Trending)
      if (_activeFilter != 'Trending') {
        postsRows.sort((a, b) {
          final aUserId = a['user_id']?.toString() ?? '';
          final bUserId = b['user_id']?.toString() ?? '';
          final aFollows = _followingIds.contains(aUserId) || aUserId == uid;
          final bFollows = _followingIds.contains(bUserId) || bUserId == uid;
          
          if (aFollows && !bFollows) return -1;
          if (!aFollows && bFollows) return 1;
          
          // Secondary sort by date (Ascending)
          final aDate = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
          final bDate = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate); // Ascending
        });
      }

      if (mounted) {
        setState(() {
          _posts = postsRows;
          _hiddenPosts.addAll(hiddenIds);
          _loadingPosts = false;
        });
        // Load interactions
        final ids = postsRows
            .map((p) => p['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        _fetchPostInteractions(ids);
      }
    } catch (e) {
      debugPrint('loadFeed error: $e');
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _fetchPostInteractions(List<String> postIds) async {
    if (postIds.isEmpty) return;
    final uid = _sb.auth.currentUser?.id;
    try {
      final likesRows = await _sb.from('post_likes').select('post_id, user_id').inFilter('post_id', postIds);
      final likesByPost = <String, List<String>>{};
      for (final r in likesRows) {
        final pid = r['post_id']?.toString() ?? '';
        final userId = r['user_id']?.toString() ?? '';
        if (pid.isNotEmpty && userId.isNotEmpty) {
          likesByPost.putIfAbsent(pid, () => []).add(userId);
        }
      }

      final commentsRows = await _sb
          .from('post_comments')
          .select('post_id, id, user_name, avatar_url, text, created_at')
          .inFilter('post_id', postIds)
          .order('created_at', ascending: false);
      final commentsByPost = <String, List<Map<String, dynamic>>>{};
      for (final r in commentsRows) {
        final pid = r['post_id']?.toString() ?? '';
        if (pid.isNotEmpty) {
          commentsByPost.putIfAbsent(pid, () => []).add(Map<String, dynamic>.from(r));
        }
      }

      if (mounted) {
        setState(() {
          for (final pid in postIds) {
            final likers = likesByPost[pid] ?? [];
            _likeCounts[pid] = likers.length;
            _userLikedMap[pid] = uid != null && likers.contains(uid);
            final allComments = commentsByPost[pid] ?? [];
            _commentCounts[pid] = allComments.length;
            _commentPreviews[pid] = allComments.reversed.take(2).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('fetchPostInteractions error: $e');
    }
  }

  Future<void> _toggleLike(String postId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    final alreadyLiked = _userLikedMap[postId] ?? false;
    setState(() {
      _userLikedMap[postId] = !alreadyLiked;
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) + (alreadyLiked ? -1 : 1);
    });
    try {
      if (alreadyLiked) {
        await _sb.from('post_likes').delete().eq('post_id', postId).eq('user_id', uid);
      } else {
        await _sb.from('post_likes').insert({'post_id': postId, 'user_id': uid});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userLikedMap[postId] = alreadyLiked;
          _likeCounts[postId] = (_likeCounts[postId] ?? 0) + (alreadyLiked ? 1 : -1);
        });
      }
    }
  }
  
  Future<void> _toggleFollow(String targetUserId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null || targetUserId == uid) return;
    
    final isFollowing = _followingIds.contains(targetUserId);
    setState(() {
      if (isFollowing) {
        _followingIds.remove(targetUserId);
      } else {
        _followingIds.add(targetUserId);
      }
    });

    try {
      if (isFollowing) {
        // Unfollow
        await _sb.from('requests').delete()
          .eq('sender_id', uid)
          .eq('target_id', targetUserId)
          .eq('target_type', 'follow');
      } else {
        // Check if user is public or private. For UI speed, we'll assume public and just insert as approved for now.
        // A true private check would need profile lookup. For MVP, follow inserts 'approved'.
        await _sb.from('requests').upsert({
          'sender_id': uid,
          'target_id': targetUserId,
          'target_type': 'follow',
          'status': 'approved',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      // Revert optimism
      setState(() {
        if (isFollowing) {
          _followingIds.add(targetUserId);
        } else {
          _followingIds.remove(targetUserId);
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to follow: $e')));
    }
  }

  Future<void> _addComment(String postId, String text) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null || text.trim().isEmpty) return;
    final me = _myProfile;
    final userName = me?['name'] ?? me?['full_name'] ?? 'You';
    final avatarUrl = me?['avatar_url'] ?? '';
    final newComment = <String, dynamic>{
      'post_id': postId,
      'user_id': uid,
      'user_name': userName,
      'avatar_url': avatarUrl,
      'text': text.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _commentCounts[postId] = (_commentCounts[postId] ?? 0) + 1;
      final prev = List<Map<String, dynamic>>.from(_commentPreviews[postId] ?? []);
      prev.add(newComment);
      _commentPreviews[postId] = prev.length > 2 ? prev.sublist(prev.length - 2) : prev;
    });
    try {
      await _sb.from('post_comments').insert(newComment);
    } catch (e) {
      debugPrint('addComment error: $e');
    }
  }

  Future<void> _hidePost(String postId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _hiddenPosts.add(postId);
      _posts.removeWhere((p) => p['id'].toString() == postId);
    });
    try {
      await _sb.from('hidden_feed').insert({'user_id': uid, 'post_id': postId});
    } catch (_) {}
  }

  void _toggleBookmark(String postId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_bookmarkedPosts.contains(postId)) {
        _bookmarkedPosts.remove(postId);
      } else {
        _bookmarkedPosts.add(postId);
      }
    });
    _saveBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('home_bookmarks') ?? [];
    if (mounted) setState(() => _bookmarkedPosts.addAll(list));
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('home_bookmarks', _bookmarkedPosts.toList());
  }

  // -- Profile cache --
  Future<void> _loadMyProfile() async {
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;
      final me = await _sb.from('profiles').select().eq('id', uid).maybeSingle();
      if (me != null && mounted) setState(() => _myProfile = me);
    } catch (e) {
      debugPrint('loadMyProfile error: $e');
    }
  }

  // -- Messages --
  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await _sb.from('messages').select().or('sender_id.eq.$uid,receiver_id.eq.$uid').order('created_at', ascending: false).limit(50);
      // Group by conversation partner
      final Map<String, Map<String, dynamic>> convos = {};
      for (final r in (rows as List)) {
        final partnerId = r['sender_id'] == uid ? r['receiver_id'] : r['sender_id'];
        if (!convos.containsKey(partnerId)) {
          convos[partnerId] = Map<String, dynamic>.from(r);
        }
      }
      if (mounted) setState(() { _chatList = convos.values.toList(); _loadingChats = false; });
    } catch (e) {
      debugPrint('loadChats error: $e');
      if (mounted) setState(() => _loadingChats = false);
    }
  }

  // Filtered posts
  List<Map<String, dynamic>> get _filteredPosts {
    if (_activeFilter == 'Trending') {
      final list = List<Map<String, dynamic>>.from(_posts);
      list.sort((a, b) {
        final aId = a['id'].toString();
        final bId = b['id'].toString();
        final aLikes = _likeCounts[aId] ?? 0;
        final aComments = _commentCounts[aId] ?? 0;
        final bLikes = _likeCounts[bId] ?? 0;
        final bComments = _commentCounts[bId] ?? 0;
        final likeCmp = bLikes.compareTo(aLikes);
        if (likeCmp != 0) return likeCmp;
        return bComments.compareTo(aComments);
      });
      return list;
    }
    return _posts;
  }

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    return Scaffold(
      backgroundColor: doodle ? DoodleColors.cream : HomeColors.bg,
      body: Stack(
        children: [
          // Ambient bg — doodle in light, neon orbs in dark
          Positioned.fill(child: _AmbientBackground()),

          // Main content
          RefreshIndicator(
            onRefresh: _loadFeed,
            color: doodle ? DoodleColors.brown : HomeColors.cyan,
            backgroundColor: doodle ? DoodleColors.cream : HomeColors.card,
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // Header
                SliverToBoxAdapter(child: _buildHeader()),
                // Chatrooms Section
                SliverToBoxAdapter(child: _buildChatroomsSection()),
                // Filter bar
                SliverPersistentHeader(pinned: true, delegate: _FilterBarDelegate(
                  activeFilter: _activeFilter,
                  onFilterChanged: (f) {
                    setState(() {
                      _activeFilter = (f == 'Trending') ? f : null;
                    });
                    _loadFeed();
                  },
                  onLocationTap: () => _showLocationFilter(),
                )),
                // Feed
                if (_loadingPosts)
                  SliverToBoxAdapter(child: _buildLoadingSkeleton())
                else if (_filteredPosts.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyFeed())
                else
                  SliverList(delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i >= _filteredPosts.length) return _buildLoadingSkeleton();
                      return _buildPostCard(_filteredPosts[i]);
                    },
                    childCount: _filteredPosts.length,
                  )),
                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // FAB with pulsing neon ring
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            bottom: _fabVisible ? 20 : -70,
            right: 20,
            child: _buildFAB(),
          ),

          // Notification overlay
          if (_notifOpen) _buildNotificationPanel(),

          // Message overlay
          if (_msgOpen) _buildMessagePanel(),
        ],
      ),
    );
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildHeader() {
    final doodle = isDoodleMode(context);
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 8),
      color: doodle ? DoodleColors.cream : Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          doodle
            ? Row(
                children: [
                  Text(
                    'Relaya',
                    style: DoodleFonts.heading(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: DoodleColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.rotate(
                    angle: -0.2,
                    child: Icon(Icons.send_rounded, color: DoodleColors.sketchLineLight, size: 20),
                  ),
                ],
              )
            : Text(
                'RELAYA',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.0,
                ),
              ),
          // Search & Notification Icons
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUsersScreen()));
                },
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.search, color: doodle ? DoodleColors.textSecondary : Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('notifications')
                    .stream(primaryKey: ['id'])
                    .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '')
                    .map((items) => items.where((item) => item['is_read'] == false).toList()),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data?.length ?? 0;
                  final hasUnread = unreadCount > 0;
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.notifications_none, color: doodle ? DoodleColors.textSecondary : Colors.white, size: 28),
                          if (hasUnread)
                            Positioned(
                              top: 4,
                              right: 6,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: doodle ? DoodleColors.coral : const Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: doodle ? DoodleColors.cream : Colors.black, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBtn(IconData icon, VoidCallback onTap, {bool hasNotif = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HomeColors.glass,
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, color: HomeColors.txt2, size: 17)),
            if (hasNotif) Positioned(top: 7, right: 7, child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [HomeColors.pink, HomeColors.orange]),
                border: Border.all(color: HomeColors.bg, width: 1.5),
                boxShadow: [BoxShadow(color: HomeColors.pink.withValues(alpha: 0.6), blurRadius: 6)],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: Offset(1, 1), end: Offset(1.3, 1.3)).fade(end: 0.5)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CHATROOMS SECTION (BolRoom)
  // ==========================================
  Widget _buildChatroomsSection() {
    return const EchoNexusBanner();
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final doodle = isDoodleMode(context);
    final postId = post['id'].toString();
    final userName = post['user_name'] ?? post['author_name'] ?? 'User';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    String postAvatarUrl = post['avatar_url']?.toString() ?? '';
    if (postAvatarUrl.isNotEmpty && !postAvatarUrl.startsWith('http') && !postAvatarUrl.startsWith('data:')) {
      postAvatarUrl = '';
    }
    final content = post['content'] ?? post['text'] ?? '';
    final createdAt = post['created_at'] ?? '';
    final interest = post['interest'] ?? '';
    final city = post['city'] ?? post['location'] ?? '';
    final tags = (post['tags'] as List?)?.cast<String>() ?? [];
    final images = (post['images'] as List?)?.cast<String>() ?? [];
    final imageUrl = post['image_url']?.toString();
    final allImages = [...images, if (imageUrl != null && imageUrl.isNotEmpty) imageUrl];
    final likeCount = _likeCounts[postId] ?? 0;
    final isLiked = _userLikedMap[postId] ?? false;
    final commentCount = _commentCounts[postId] ?? 0;
    final isBookmarked = _bookmarkedPosts.contains(postId);
    
    final postUserId = post['user_id']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: doodle ? 12 : 0, right: doodle ? 12 : 0, top: doodle ? 4 : 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: doodle
        ? DoodleDecorations.card()
        : BoxDecoration(
            color: HomeColors.bg,
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () {
                    if (postUserId.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: postUserId)));
                    }
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: postAvatarUrl.isEmpty ? LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: _gradientForInitial(initial),
                      ) : null,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                    ),
                    child: ClipOval(child: postAvatarUrl.isNotEmpty
                        ? Image.network(postAvatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initial, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))))
                        : Center(child: Text(initial, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () {
                          if (postUserId.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: postUserId)));
                          }
                        },
                        child: Text(userName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                      ),
                      if (interest.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: HomeColors.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(interest, style: GoogleFonts.inter(fontSize: 9, color: HomeColors.cyan, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(_timeAgo(createdAt), style: GoogleFonts.inter(fontSize: 11, color: HomeColors.muted)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.circle, size: 3, color: HomeColors.muted),
                        const SizedBox(width: 6),
                        Text(city, style: GoogleFonts.inter(fontSize: 11, color: HomeColors.muted)),
                      ],
                    ]),
                  ],
                )),
                _buildPostMoreBtn(postId),
              ],
            ),
          ),

          // Content
          if (content.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildPostText(content),
          ),

          // Images
          if (allImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPostImageCarousel(postId, allImages),
            ),

          // Tags
          if (tags.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) => Text(
              t, 
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: HomeColors.blue)
            )).toList()),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _buildActionBtn(isLiked ? Icons.favorite : Icons.favorite_border, '$likeCount', isLiked ? HomeColors.pink : HomeColors.txt2, () => _toggleLike(postId)),
                const SizedBox(width: 16),
                _buildActionBtn(Icons.chat_bubble_outline, '$commentCount', HomeColors.txt2, () => _showCommentSheet(postId)),
                const Spacer(),
                _buildActionBtn(isBookmarked ? Icons.bookmark : Icons.bookmark_border, '', isBookmarked ? HomeColors.yellow : HomeColors.txt2, () => _toggleBookmark(postId)),
                const SizedBox(width: 16),
                _buildActionBtn(Icons.share_outlined, '', HomeColors.txt2, () {
                  final text = content.length > 100 ? content.substring(0, 97) + '...' : content;
                  Share.share('Check out this post on Relaya:\n"$text"');
                }),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  List<Color> _gradientForInitial(String initial) {
    final gradients = [
      [HomeColors.cyan, HomeColors.green],
      [HomeColors.purple, HomeColors.pink],
      [HomeColors.orange, HomeColors.yellow],
      [HomeColors.blue, HomeColors.cyan],
      [HomeColors.green, HomeColors.cyan],
      [HomeColors.pink, HomeColors.red],
    ];
    return gradients[initial.codeUnitAt(0) % gradients.length];
  }

  Widget _buildPostText(String text) {
    // Process hashtags
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(#\w+|@\w+)');
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final tag = match.group(0)!;
      spans.add(TextSpan(
        text: tag,
        style: TextStyle(color: tag.startsWith('#') ? HomeColors.cyan : HomeColors.purple, fontWeight: FontWeight.w500),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 13, height: 1.6, color: HomeColors.txt),
        children: spans,
      ),
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
    );
  }

  // Instagram-style 1:1 post image carousel
  final Map<String, ValueNotifier<int>> _carouselPageMap = {};

  Widget _buildPostImageCarousel(String postId, List<String> images) {
    _carouselPageMap.putIfAbsent(postId, () => ValueNotifier<int>(0));
    final pageNotifier = _carouselPageMap[postId]!;
    final controller = PageController();

    return Column(
      children: [
        // 1:1 square image area (full card width, no padding)
        AspectRatio(
          aspectRatio: 1.0,
          child: PageView.builder(
            controller: controller,
            itemCount: images.length,
            onPageChanged: (i) => pageNotifier.value = i,
            itemBuilder: (_, i) => _buildSquareImageItem(images[i]),
          ),
        ),
        // Dot indicators for multi-image posts
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ValueListenableBuilder<int>(
              valueListenable: pageNotifier,
              builder: (_, currentPage, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final isActive = i == currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isActive
                          ? HomeColors.cyan
                          : HomeColors.muted.withValues(alpha: 0.4),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSquareImageItem(String url) {
    Widget imageWidget = Center(child: Icon(Icons.image, color: HomeColors.muted, size: 30));

    if (url.startsWith('http')) {
      imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) =>
            Center(child: Icon(Icons.broken_image_outlined, color: HomeColors.muted, size: 36)),
      );
    } else if (url.startsWith('data:image')) {
      try {
        final b64 = url.split(',').last;
        imageWidget = Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              Center(child: Icon(Icons.broken_image_outlined, color: HomeColors.muted, size: 36)),
        );
      } catch (_) {}
    }

    return Container(
      color: HomeColors.bg2,
      child: imageWidget,
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: label.isNotEmpty && color != HomeColors.muted ? 0.08 : 0.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            if (label.isNotEmpty) ...[const SizedBox(width: 5), Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color))],
          ],
        ),
      ),
    );
  }

  Widget _buildPostMoreBtn(String postId) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HomeColors.bg2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: HomeColors.gb),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildMoreOption(Icons.volume_off, 'Mute User', () { Navigator.pop(ctx); }),
              _buildMoreOption(Icons.visibility_off, 'Hide Post', () { Navigator.pop(ctx); _hidePost(postId); }),
              _buildMoreOption(Icons.link, 'Copy Link', () { Navigator.pop(ctx); }),
              _buildMoreOption(Icons.flag, 'Report Post', () { Navigator.pop(ctx); }, isRed: true),
            ]),
          ),
        );
      },
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: Icon(Icons.more_horiz, color: HomeColors.muted, size: 18),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String label, VoidCallback onTap, {bool isRed = false}) {
    return ListTile(
      leading: Icon(icon, color: isRed ? HomeColors.red : HomeColors.txt2, size: 20),
      title: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: isRed ? HomeColors.red : HomeColors.txt2)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  // ==========================================
  // COMMENT SHEET
  // ==========================================
  void _showCommentSheet(String postId) {
    final textCtrl = TextEditingController();
    final previews = _commentPreviews[postId] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final doodle = isDoodleMode(ctx);
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: doodle
            ? DoodleDecorations.card(color: DoodleColors.cream)
            : BoxDecoration(
                color: HomeColors.bg2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: HomeColors.gb),
              ),
          child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.3) : Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Comments', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.txt)),
            ),
            Expanded(
              child: previews.isEmpty
                  ? Center(child: Text('No comments yet', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 16) : GoogleFonts.inter(color: HomeColors.muted, fontSize: 13)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: previews.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          doodle 
                            ? DoodleAvatar(size: 28, url: '', borderColor: DoodleColors.orange, fallback: Center(child: Text((c['user_name'] ?? 'U')[0], style: DoodleFonts.label(color: DoodleColors.orange))))
                            : CircleAvatar(radius: 14, backgroundColor: HomeColors.card, child: Text((c['user_name'] ?? 'U')[0], style: GoogleFonts.inter(fontSize: 10, color: HomeColors.txt))),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['user_name'] ?? 'User', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                            Text(c['text'] ?? '', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 14) : GoogleFonts.inter(fontSize: 12, color: HomeColors.txt2)),
                          ])),
                        ]),
                      )).toList(),
                    ),
            ),
            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: doodle ? DoodleColors.brown.withValues(alpha: 0.3) : HomeColors.gb))),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: textCtrl,
                  style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16) : GoogleFonts.inter(fontSize: 13, color: HomeColors.txt),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 16) : GoogleFonts.inter(color: HomeColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                )),
                IconButton(
                  icon: Icon(Icons.send, color: doodle ? DoodleColors.blue : HomeColors.cyan, size: 20),
                  onPressed: () {
                    if (textCtrl.text.trim().isNotEmpty) {
                      _addComment(postId, textCtrl.text);
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ]),
            ),
          ],
        ),
      );
      },
    );
  }

  // ==========================================
  // POST CREATION MODAL
  // ==========================================
  void _showCreatePostModal() {
    final textCtrl = TextEditingController();
    final selectedTags = <String>{};
    String? uploadedImageUrl;
    bool isPosting = false;
    // Auto-enable location if user has one set
    bool attachLocation = locationService.activeLocation.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final doodle = isDoodleMode(ctx);
        return StatefulBuilder(builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: doodle
              ? DoodleDecorations.card(color: DoodleColors.cream)
              : BoxDecoration(
                  color: HomeColors.bg2,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: HomeColors.gb),
                ),
            child: Column(
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.3) : Colors.white24, borderRadius: BorderRadius.circular(2))),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Create Post', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.txt)),
                    GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(
                      width: 32, height: 32,
                      decoration: doodle 
                        ? DoodleDecorations.card(color: DoodleColors.paper)
                        : BoxDecoration(shape: BoxShape.circle, color: HomeColors.glass, border: Border.all(color: HomeColors.gb)),
                      child: Icon(Icons.close, color: doodle ? DoodleColors.brown : HomeColors.txt2, size: 16),
                    )),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User row
                      Row(children: [
                        doodle 
                          ? DoodleAvatar(size: 40, url: '', borderColor: DoodleColors.orange, fallback: Center(child: Text((_myProfile?['name'] ?? 'M')[0].toUpperCase(), style: DoodleFonts.heading(color: DoodleColors.orange))))
                          : Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [HomeColors.cyan, HomeColors.purple]),
                              ),
                              child: Center(child: Text(
                                (_myProfile?['name'] ?? 'M')[0].toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              )),
                            ),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_myProfile?['name'] ?? _myProfile?['full_name'] ?? 'You', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 16) : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                          Row(children: [
                            Icon(Icons.public, size: 10, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : HomeColors.muted),
                            const SizedBox(width: 4),
                            Text('Public Post', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 12) : GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
                          ]),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      // Text area
                      Container(
                        decoration: doodle
                          ? DoodleDecorations.card(color: DoodleColors.paper)
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: HomeColors.card,
                              border: Border.all(color: HomeColors.gb),
                            ),
                        child: TextField(
                          controller: textCtrl,
                          maxLines: 5,
                          style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16).copyWith(height: 1.6) : GoogleFonts.inter(fontSize: 14, color: HomeColors.txt, height: 1.6),
                          decoration: InputDecoration(
                            hintText: "What's on your mind? Share your thoughts, experiences, or ask a question...",
                            hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 16) : GoogleFonts.inter(color: HomeColors.muted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                      // Image Preview (shown after upload)
                      if (uploadedImageUrl != null) ...[
                        const SizedBox(height: 12),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(aspectRatio: 1.0, child: Image.network(
                                uploadedImageUrl!,
                                width: double.infinity,

                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: HomeColors.card, child: const Center(child: Icon(Icons.broken_image, color: Colors.white24))),
                              )),
                            ),
                            Positioned(top: 8, right: 8,
                              child: GestureDetector(
                                onTap: () => setSheet(() => uploadedImageUrl = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Tags
                      Text('Tag Interests', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 14) : GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: HomeColors.txt2)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        '🎵 Music', '💪 Health', '💻 Tech', '💃 Dance', '🎨 Art',
                        '📚 Study', '🏀 Sports', '🍕 Food', '✈️ Travel', '🎮 Gaming',
                      ].map((t) => GestureDetector(
                        onTap: () => setSheet(() {
                          if (selectedTags.contains(t)) { selectedTags.remove(t); } else { selectedTags.add(t); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: doodle
                            ? DoodleDecorations.card(color: selectedTags.contains(t) ? DoodleColors.orange.withValues(alpha: 0.3) : DoodleColors.paper)
                            : BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: selectedTags.contains(t) ? HomeColors.cyan.withValues(alpha: 0.08) : HomeColors.card,
                                border: Border.all(color: selectedTags.contains(t) ? HomeColors.cyan : HomeColors.gb),
                              ),
                          child: Text(t, style: doodle ? DoodleFonts.body(color: selectedTags.contains(t) ? DoodleColors.orange : DoodleColors.brown, fontSize: 13) : GoogleFonts.inter(fontSize: 11, color: selectedTags.contains(t) ? HomeColors.cyan : HomeColors.txt2, fontWeight: FontWeight.w500)),
                        ),
                      )).toList()),
                      const SizedBox(height: 14),
                        // Options + Post btn
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: doodle ? DoodleColors.brown.withValues(alpha: 0.3) : HomeColors.gb))),
                        child: Row(
                          children: [
                            // Image upload button
                            GestureDetector(
                              onTap: () async {
                                final url = await ImageUploadService.pickAndUpload(context: ctx, folder: 'posts');
                                if (url != null) setSheet(() => uploadedImageUrl = url);
                              },
                              child: Container(
                                width: 34, height: 34,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: doodle
                                  ? DoodleDecorations.card(color: uploadedImageUrl != null ? DoodleColors.green.withValues(alpha: 0.3) : DoodleColors.paper)
                                  : BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: uploadedImageUrl != null ? HomeColors.cyan.withValues(alpha: 0.15) : HomeColors.glass,
                                      border: Border.all(color: uploadedImageUrl != null ? HomeColors.cyan : HomeColors.gb),
                                    ),
                                child: Icon(Icons.image, color: uploadedImageUrl != null ? (doodle ? DoodleColors.green : HomeColors.cyan) : (doodle ? DoodleColors.brown.withValues(alpha: 0.5) : HomeColors.txt2), size: 16),
                              ),
                            ),
                            // Live location text
                            Builder(
                              builder: (ctx) {
                                final profileDistrict = (_myProfile?['district'] ?? '').toString().trim();
                                final profileState = (_myProfile?['state'] ?? '').toString().trim();
                                final svcDistrict = locationService.activeDistrict.trim();
                                final svcState = locationService.activeState.trim();
                                final String dist = profileDistrict.isNotEmpty ? profileDistrict : svcDistrict;
                                final String st = profileState.isNotEmpty ? profileState : svcState;
                                if (dist.isEmpty && st.isEmpty) return const SizedBox.shrink();
                                final displayText = [dist, st].where((s) => s.isNotEmpty).join(', ');
                                return GestureDetector(
                                  onTap: () => showLocationSearchSheet(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, color: doodle ? DoodleColors.orange : HomeColors.cyan, size: 14),
                                      const SizedBox(width: 4),
                                      Text(displayText, style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 13) : GoogleFonts.inter(fontSize: 11, color: HomeColors.cyan, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: isPosting ? null : () async {
                                if (textCtrl.text.trim().isEmpty && uploadedImageUrl == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something or add a photo!'), backgroundColor: HomeColors.red));
                                  return;
                                }
                                final uid = _sb.auth.currentUser?.id;
                                if (uid == null) return;
                                setSheet(() => isPosting = true);
                                try {
                                  // Auto-attach location metadata to every post
                                  final svcDist = locationService.activeDistrict.trim();
                                  final svcSt = locationService.activeState.trim();
                                  final profDist = (_myProfile?['district'] ?? '').toString().trim();
                                  final profSt = (_myProfile?['state'] ?? '').toString().trim();
                                  final postDistrict = svcDist.isNotEmpty ? svcDist : profDist;
                                  final postState = svcSt.isNotEmpty ? svcSt : profSt;
                                  final postData = <String, dynamic>{
                                    'user_id': uid,
                                    'content': textCtrl.text.trim(),
                                    'image_url': uploadedImageUrl ?? '',
                                    'district': postDistrict,
                                    'state': postState,
                                    'lat': locationService.activeLat ?? 0,
                                    'lng': locationService.activeLng ?? 0,
                                  };
                                  await _sb.from('posts').insert(postData);
                                  Navigator.pop(ctx);
                                  _loadFeed();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Post published!'), duration: Duration(seconds: 2), backgroundColor: HomeColors.green));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e'), duration: const Duration(seconds: 2), backgroundColor: HomeColors.red));
                                  setSheet(() => isPosting = false);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: doodle
                                  ? DoodleDecorations.card(color: isPosting ? DoodleColors.paper : DoodleColors.green)
                                  : BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(colors: isPosting ? [HomeColors.muted, HomeColors.muted] : [HomeColors.cyan, HomeColors.green]),
                                    ),
                                child: isPosting
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                    : Row(children: [
                                        Icon(Icons.send, size: 14, color: Colors.black),
                                        const SizedBox(width: 4),
                                        Text('Post', style: doodle ? DoodleFonts.heading(color: Colors.black, fontSize: 16) : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
                                      ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      },
    );
  }

  Widget _buildCmOpt(IconData icon) {
    return Container(
      width: 34, height: 34,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: HomeColors.glass,
        border: Border.all(color: HomeColors.gb),
      ),
      child: Icon(icon, color: HomeColors.txt2, size: 14),
    );
  }

  // ==========================================
  // NOTIFICATION PANEL
  // ==========================================
  Widget _buildNotificationPanel() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _notifOpen = false),
          child: Container(color: Colors.black54),
        ),
        Positioned(
          top: 0, right: 0, bottom: 0, width: MediaQuery.of(context).size.width * 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: HomeColors.bg2,
              border: Border(left: BorderSide(color: HomeColors.gb)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Notifications', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.txt)),
                        GestureDetector(
                          onTap: () => setState(() => _notifOpen = false),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: HomeColors.glass, border: Border.all(color: HomeColors.gb)),
                            child: Icon(Icons.close, color: HomeColors.txt2, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildNotifItem(Icons.bolt, HomeColors.orange, 'Rush-in Accepted! ⚡', 'Your request for "Late Night Coffee" has been accepted.', '2m ago', true),
                        _buildNotifItem(Icons.calendar_today, HomeColors.cyan, 'Activity Approved 🎉', 'You\'ve been approved to join "Weekend Trek to Rajmachi"', '15m ago', true),
                        _buildNotifItem(Icons.star, HomeColors.purple, 'New AI Match! 💫', 'You have a new high-compatibility match based on your interests.', '1h ago', true),
                        _buildNotifItem(Icons.favorite, HomeColors.pink, 'Event Reminder', 'Concert Night starts in 3 hours. Don\'t forget!', '2h ago', false),
                        _buildNotifItem(Icons.person_add, HomeColors.green, 'Companion Connected', 'Someone accepted your connection request.', '4h ago', false),
                        _buildNotifItem(Icons.access_time, HomeColors.blue, 'Waitlist Update', 'A spot opened for "Street Food Crawl". Claim it now!', '5h ago', false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().slideX(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildNotifItem(IconData icon, Color color, String title, String desc, String time, bool unread) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: unread ? HomeColors.cyan.withValues(alpha: 0.03) : Colors.transparent,
        border: Border.all(color: unread ? HomeColors.cyan.withValues(alpha: 0.1) : Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.15)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.txt)),
            const SizedBox(height: 2),
            Text(desc, style: GoogleFonts.inter(fontSize: 11, color: HomeColors.muted, height: 1.4)),
          ])),
          Text(time, style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
        ],
      ),
    );
  }

  // ==========================================
  // MESSAGE PANEL
  // ==========================================
  Widget _buildMessagePanel() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _msgOpen = false),
          child: Container(color: Colors.black54),
        ),
        Positioned(
          top: 0, right: 0, bottom: 0, width: MediaQuery.of(context).size.width * 0.95,
          child: Container(
            decoration: BoxDecoration(
              color: HomeColors.bg2,
              border: Border(left: BorderSide(color: HomeColors.gb)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Messages', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.txt)),
                        GestureDetector(
                          onTap: () => setState(() => _msgOpen = false),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: HomeColors.glass, border: Border.all(color: HomeColors.gb)),
                            child: Icon(Icons.close, color: HomeColors.txt2, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _msgTab = 'chats'),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _msgTab == 'chats' ? HomeColors.cyan : Colors.transparent, width: 2))),
                        child: Text('Chats', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _msgTab == 'chats' ? HomeColors.cyan : HomeColors.muted), textAlign: TextAlign.center),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _msgTab = 'communities'),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _msgTab == 'communities' ? HomeColors.cyan : Colors.transparent, width: 2))),
                        child: Text('Communities', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _msgTab == 'communities' ? HomeColors.cyan : HomeColors.muted), textAlign: TextAlign.center),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: HomeColors.card,
                        border: Border.all(color: HomeColors.gb),
                      ),
                      child: Row(children: [
                        Icon(Icons.search, color: HomeColors.muted, size: 13),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          style: GoogleFonts.inter(fontSize: 12, color: HomeColors.txt),
                          decoration: InputDecoration(
                            hintText: 'Search messages...',
                            hintStyle: GoogleFonts.inter(color: HomeColors.muted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        )),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Content
                  Expanded(
                    child: _msgTab == 'chats'
                        ? _buildChatsList()
                        : _buildCommunitiesList(),
                  ),
                ],
              ),
            ),
          ),
        ).animate().slideX(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildChatsList() {
    if (_loadingChats) return Center(child: CircularProgressIndicator(strokeWidth: 2, color: HomeColors.cyan));
    if (_chatList.isEmpty) return Center(child: Text('No messages yet', style: GoogleFonts.inter(color: HomeColors.muted, fontSize: 13)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _chatList.length,
      itemBuilder: (ctx, i) {
        final chat = _chatList[i];
        final name = chat['sender_name'] ?? chat['receiver_name'] ?? 'User';
        final msg = chat['content'] ?? chat['text'] ?? '';
        final time = _timeAgo(chat['created_at'] ?? '');
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.gb))),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: _gradientForInitial(name.isNotEmpty ? name[0] : 'U'))),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                Text(time, style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
              ]),
              const SizedBox(height: 2),
              Text(msg, style: GoogleFonts.inter(fontSize: 11, color: HomeColors.muted), overflow: TextOverflow.ellipsis, maxLines: 1),
            ])),
          ]),
        );
      },
    );
  }

  Widget _buildCommunitiesList() {
    // Use the real CommunitiesListWidget that reads from text_camps in Supabase.
    // This ensures communities are completely separate from direct messages.
    return const CommunitiesListWidget();
  }



  // ==========================================
  // SUBSCRIPTION MODAL
  // ==========================================
  void _showSubscriptionModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: HomeColors.bg2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HomeColors.gb),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [HomeColors.purple.withValues(alpha: 0.2), HomeColors.pink.withValues(alpha: 0.2)]),
              ),
              child: Center(child: Text('🔒', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 16),
            Text('Unlock Full Profiles', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.txt)),
            const SizedBox(height: 6),
            Text('Subscribe to Meetra Premium to view profiles, send messages, and connect with people from the feed.',
                style: GoogleFonts.inter(fontSize: 12, color: HomeColors.muted, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // Features
            ...[
              ['View & visit user profiles', Icons.check_circle],
              ['Direct message from feed', Icons.check_circle],
              ['Unlimited AI matches', Icons.check_circle],
              ['Priority event bookings', Icons.check_circle],
            ].map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(f[1] as IconData, color: HomeColors.cyan, size: 13),
                const SizedBox(width: 8),
                Text(f[0] as String, style: GoogleFonts.inter(fontSize: 12, color: HomeColors.txt2)),
              ]),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: HomeColors.card,
                    border: Border.all(color: HomeColors.gb),
                  ),
                  child: Text('Maybe Later', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.txt2), textAlign: TextAlign.center),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redirecting to subscription...'))); },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [HomeColors.purple, HomeColors.pink]),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.star, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Upgrade', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              )),
            ]),
          ]),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  // ==========================================
  // LOCATION FILTER — uses unified search-based picker
  // ==========================================
  void _showLocationFilter() {
    showLocationSearchSheet(context);
  }

  // ==========================================
  // FAB
  // ==========================================
  Widget _buildFAB() {
    return GestureDetector(
      onTap: _showCreatePostModal,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing glow ring
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: HomeColors.cyan.withValues(alpha: 0.3), width: 1.5),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: Offset(1, 1), end: Offset(1.15, 1.15)).fade(begin: 0.6, end: 0.0),
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomeColors.cyan,
              boxShadow: [
                BoxShadow(color: HomeColors.cyan.withValues(alpha: 0.25), blurRadius: 20, offset: Offset(0, 4)),
              ],
            ),
            child: Icon(Icons.add, color: Colors.black, size: 24),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LOADING & EMPTY STATES
  // ==========================================
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: List.generate(3, (_) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: HomeColors.card,
          border: Border.all(color: HomeColors.gb),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: HomeColors.bg2)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 120, height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: HomeColors.bg2)),
              const SizedBox(height: 6),
              Container(width: 80, height: 10, decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: HomeColors.bg2)),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(width: double.infinity, height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: HomeColors.bg2)),
          const SizedBox(height: 6),
          Container(width: 200, height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: HomeColors.bg2)),
        ]),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.3, end: 0.6, duration: 1500.ms))),
    );
  }

  Widget _buildEmptyFeed() {
    final doodle = isDoodleMode(context);
    final city = locationService.activeDistrict.isNotEmpty
        ? locationService.activeDistrict
        : 'your area';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const SizedBox(height: 48),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 24)],
            ),
            child: const Center(child: Icon(Icons.location_city_rounded, color: Colors.white, size: 34)),
          ),
          const SizedBox(height: 20),
          Text(
            'No posts in $city yet',
            textAlign: TextAlign.center,
            style: doodle
                ? DoodleFonts.heading(fontSize: 20, fontWeight: FontWeight.w800)
                : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: HomeColors.txt),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to spark a conversation in $city!',
            textAlign: TextAlign.center,
            style: doodle
                ? DoodleFonts.body(fontSize: 13, color: DoodleColors.textSecondary)
                : GoogleFonts.inter(fontSize: 13, color: HomeColors.muted),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => showLocationSearchSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 14),
                  const SizedBox(width: 6),
                  Text('Try a different city',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFFF6B00))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ==========================================
// FILTER BAR DELEGATE
// ==========================================
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final String? activeFilter;
  final ValueChanged<String?> onFilterChanged;
  final VoidCallback onLocationTap;

  _FilterBarDelegate({
    required this.activeFilter,
    required this.onFilterChanged,
    required this.onLocationTap,
  });

  @override
  double get maxExtent => 50;
  @override
  double get minExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final doodle = isDoodleMode(context);
    return SizedBox(
      height: 50,
      child: Container(
        color: doodle ? DoodleColors.cream : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Flexible(
              child: ValueListenableBuilder<String>(
                valueListenable: locationService.activeDistrictNotifier,
                builder: (context, district, _) {
                  return Text(
                    district.isNotEmpty ? district : 'Nearby',
                    style: doodle
                      ? DoodleFonts.subheading(fontSize: 22, fontWeight: FontWeight.w700)
                      : GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Row(
              children: [
                _buildFilterChip('Trending', activeFilter == 'Trending', () => onFilterChanged('Trending'), doodle),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onLocationTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: doodle ? DoodleColors.paper : const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: doodle ? DoodleColors.cardBorder : Colors.white24, width: 1),
                    ),
                    child: Icon(Icons.location_on, color: doodle ? DoodleColors.orange : const Color(0xFFFF6B00), size: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, VoidCallback onTap, bool doodle) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: doodle
          ? DoodleDecorations.chip(selected: isActive)
          : BoxDecoration(
              color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? Colors.white24 : Colors.white12,
                width: 1,
              ),
            ),
        child: Text(
          label,
          style: doodle
            ? DoodleFonts.label(
                fontSize: 11,
                color: isActive ? DoodleColors.textPrimary : DoodleColors.textMuted,
              )
            : GoogleFonts.inter(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) =>
      activeFilter != oldDelegate.activeFilter;
}

// ==========================================
// AMBIENT BACKGROUND — Futuristic 3D depth glow
// Inspired by the TechHR India '26 image:
// Deep indigo sky, neon purple/cyan/magenta orbs,
// soft bloom effects creating a 3D-depth illusion
// ==========================================
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    // Doodle mode: parchment background with scattered doodle decorations
    if (isDoodleMode(context)) {
      return IgnorePointer(
        child: Stack(
          children: [
            Container(
              decoration: DoodleDecorations.parchmentBg(),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: ScatteredDoodlesPainter(
                  seed: 77,
                  density: 0.35,
                  color: const Color(0x1AB8956E),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Dark mode: original neon orbs
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            color: HomeColors.bg,
          ),
          Positioned(top: -100, right: -80, child: Container(
            width: 340, height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [HomeColors.cyan.withValues(alpha: 0.03), Colors.transparent],
                stops: const [0.0, 1.0],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(duration: 10.seconds, begin: Offset.zero, end: Offset(30, -20))
            .scale(begin: Offset(1, 1), end: Offset(1.1, 1.1))),
          Positioned(top: 180, left: -70, child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [HomeColors.purple.withValues(alpha: 0.04), Colors.transparent],
                stops: const [0.0, 1.0],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(duration: 12.seconds, begin: Offset.zero, end: Offset(-20, 25), delay: 2.seconds)
            .scale(begin: Offset(1, 1), end: Offset(0.9, 0.9))),
          Positioned(bottom: 120, right: -50, child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [HomeColors.pink.withValues(alpha: 0.03), Colors.transparent],
                stops: const [0.0, 1.0],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(duration: 9.seconds, begin: Offset.zero, end: Offset(18, -22), delay: 4.seconds)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meetra "M" logo painter — thick, rounded, gradient (purple→pink→orange)
// matches the brand identity provided by the user.
// ─────────────────────────────────────────────────────────────────────────────
class _MeetraMLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;


    // stroke thickness proportional to size
    const strokeW = 0.22; // 22% of width

    // The M shape — drawn as a filled outline path to allow gradient fill
    // Left foot, up left arch, down to valley, up right arch, right foot

    // Key x-positions (normalised 0–1 times w)
    final x0 = w * 0.00;  // far left
    final x1 = w * 0.19;  // left outer edge top
    final x2 = w * 0.50;  // centre
    final x3 = w * 0.81;  // right outer edge top
    final x4 = w * 1.00;  // far right

    // Key y-positions
    final yTop   = h * 0.00;
    final yMid   = h * 0.48; // valley bottom
    final yBot   = h * 1.00;

    // Stroke half-width for offset
    final sw = w * strokeW / 2;

    // Outer path (clockwise outer edge of the thick M stroke)
    final outer = Path();
    outer.moveTo(x0, yBot);                          // bottom-left foot outer
    outer.cubicTo(x0, yMid + sw, x1 - sw, yTop + sw,  x1, yTop); // left arch outer
    outer.cubicTo(x1 + sw * 0.5, yTop, x2 - sw, yMid - sw * 0.3, x2, yMid); // left leg to valley outer
    outer.cubicTo(x2 + sw, yMid - sw * 0.3, x3 - sw * 0.5, yTop, x3, yTop); // valley to right leg outer
    outer.cubicTo(x3 + sw, yTop + sw, x4, yMid + sw, x4, yBot); // right arch outer
    outer.lineTo(x4 - sw * 2, yBot);

    // inner path (counter-clockwise inner edge of M)
    final innerRightFoot = Offset(x4 - sw * 2, yBot);
    outer.cubicTo(innerRightFoot.dx, yMid + sw * 1.5, x3 + sw * 0.3, yTop + sw * 2, x3, yTop + sw * 2); // right arch inner
    outer.cubicTo(x3 - sw * 0.3, yTop + sw * 2, x2 + sw, yMid + sw * 0.5, x2, yMid + sw * 1.5); // right leg inner
    outer.cubicTo(x2 - sw, yMid + sw * 0.5, x1 + sw * 0.3, yTop + sw * 2, x1, yTop + sw * 2); // left leg inner
    outer.cubicTo(x1 - sw * 0.3, yTop + sw * 2, x0 + sw * 2, yMid + sw * 1.5, x0 + sw * 2, yBot); // left arch inner
    outer.close();

    // Create gradient shader (purple → pink → orange) mapped to full width
    final gradient = ui.Gradient.linear(
      Offset(x0, h / 2),
      Offset(x4, h / 2),
      [
        const Color(0xFFFF6B00), // brand orange
        const Color(0xFFFF7E40), // warm amber
        const Color(0xFFFF8A00), // rich orange
        const Color(0xFFFF8A00), // orange (hold)
        const Color(0xFFFFC107), // amber glow
      ],
      [0.0, 0.2, 0.45, 0.55, 1.0],
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(outer, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// BOLROOM ORBITAL BANNER
// ==========================================
class EchoNexusBanner extends StatelessWidget {
  const EchoNexusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bolrooms_hero.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF161622),
                          Color(0xFF0C0C12),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.contactless_outlined,
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                        size: 80,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.contactless_outlined,
                            color: Color(0xFFFF6B00),
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'BOLROOMS',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.normal,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E0E08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF3D00).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'ANONYMOUS',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF3D00),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Enter a world where identity fades and real connections form.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildActionButton(
                            context,
                            icon: Icons.headset_mic_outlined,
                            label: 'Voicerooms',
                            iconColor: const Color(0xFFFF6B00),
                          ),
                          _buildActionButton(
                            context,
                            icon: Icons.groups_outlined,
                            label: 'Communities',
                            iconColor: const Color(0xFF4E8BFF),
                          ),
                          _buildActionButton(
                            context,
                            icon: Icons.chat_bubble_outline,
                            label: 'Messages',
                            iconColor: const Color(0xFFFFD54F),
                          ),
                          _buildActionButton(
                            context,
                            icon: Icons.person_outline,
                            label: 'Profile',
                            iconColor: const Color(0xFFF48FB1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (label == 'Voicerooms') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BolroomShell()));
            } else if (label == 'Communities') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunitiesStandaloneScreen()));
            } else if (label == 'Messages') {
              MainDashboard.switchTab(context, 3);
            } else if (label == 'Profile') {
              MainDashboard.switchTab(context, 4);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
