// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: avoid_print, unused_element, unused_field, use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:math' as math;
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
import 'widgets/app_header_actions.dart';
import 'bolroom/bolroom_shell.dart';
// ==========================================
// COLORS & CONSTANTS
// ==========================================
class HomeColors {
  // Deep dark base inspired by the reference image
  static const bg = Color(0xFF06070B);   // rich dark ink
  static const bg2 = Color(0xFF0A0C14);  // near-black
  static const card = Color(0xFF10121A); // card surface — dark luxury slate
  static const cardH = Color(0xFF171A26); // card hover / elevated
  // Neon accent palette
  static const cyan = Color(0xFF00E5CC);    // bright cyan
  static const purple = Color(0xFF9D4EDD);  // vivid purple
  static const pink = Color(0xFFFF2E97);    // hot magenta-pink
  static const orange = Color(0xFFFF6B35);  // warm neon orange
  static const blue = Color(0xFF4E8BFF);    // bright blue
  static const green = Color(0xFF00E676);   // neon green
  static const yellow = Color(0xFFFFC107);  // amber glow
  static const red = Color(0xFFFF3D5A);     // coral red
  // Text hierarchy
  static const txt = Color(0xFFF0F4FF);     // bright white-blue
  static const txt2 = Color(0xFF93A2C4);    // muted periwinkle
  static const muted = Color(0xFF4B5A7D);   // deep muted blue
  // Glass surfaces and buttons
  static const glass = Color(0xFF141722);   // dark slate buttons
  static const gb = Color(0x12FFFFFF);      // softer frosted glass border
  // Extra: glow colors for ambient FX
  static const glowCyan = Color(0x2000E5CC);
  static const glowPurple = Color(0x209D4EDD);
  static const glowMagenta = Color(0x20FF2E97);
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
    _scrollCtrl.dispose();
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
        final followsReq = await _sb.from('requests')
            .select('target_id')
            .eq('sender_id', uid)
            .eq('target_type', 'follow')
            .eq('status', 'approved');
        final ids = (followsReq as List).map((r) => r['target_id'].toString()).toSet();
        if (mounted) setState(() => _followingIds = ids);
      }

      // posts table: id, user_id, content, image_url, created_at, district, state
      // Join with profiles to get user display name + avatar
      // Filter by user's current district for location-aware feed
      final currentDistrict = locationService.activeLocation.split(',').first.trim();
      var postQuery = _sb.from('posts')
          .select('*, profiles!posts_user_id_fkey(name, avatar_url)');
      if (currentDistrict.isNotEmpty) {
        postQuery = postQuery.ilike('district', '%$currentDistrict%');
      }
      final rows = await postQuery
          .order('created_at', ascending: false)
          .limit(50);
      // Flatten the join so each post map has user_name and avatar_url at top level
      final flatRows = (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r);
        final profile = m['profiles'] as Map?;
        m['user_name'] = profile?['name'] ?? 'User';
        m['avatar_url'] = profile?['avatar_url'] ?? '';
        m.remove('profiles');
        return m;
      }).toList();

      final hiddenRows = uid != null
          ? await _sb.from('hidden_feed').select('rush_in_id').eq('user_id', uid)
          : [];
      final hiddenIds = (hiddenRows).map((r) => r['rush_in_id']?.toString() ?? '').toSet();

      final postsRows = flatRows
          .where((p) => !hiddenIds.contains(p['id']?.toString()))
          .toList();
          
      // Sort: Followed users first, then by date
      postsRows.sort((a, b) {
        final aUserId = a['user_id']?.toString() ?? '';
        final bUserId = b['user_id']?.toString() ?? '';
        final aFollows = _followingIds.contains(aUserId) || aUserId == uid;
        final bFollows = _followingIds.contains(bUserId) || bUserId == uid;
        
        if (aFollows && !bFollows) return -1;
        if (!aFollows && bFollows) return 1;
        
        // Secondary sort by date
        final aDate = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final bDate = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate); // Descending
      });

      if (mounted) {
        setState(() {
          _posts = postsRows;
          _hiddenPosts.addAll(hiddenIds);
          _loadingPosts = false;
        });
        // Load interactions
        final ids = postsRows.map((p) => p['id'].toString()).toList();
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
      for (final r in (likesRows as List)) {
        final pid = r['post_id'] as String;
        likesByPost.putIfAbsent(pid, () => []).add(r['user_id'] as String);
      }

      final commentsRows = await _sb
          .from('post_comments')
          .select('post_id, id, user_name, avatar_url, text, created_at')
          .inFilter('post_id', postIds)
          .order('created_at', ascending: false);
      final commentsByPost = <String, List<Map<String, dynamic>>>{};
      for (final r in (commentsRows as List)) {
        final pid = r['post_id'] as String;
        commentsByPost.putIfAbsent(pid, () => []).add(Map<String, dynamic>.from(r));
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
    if (_activeFilter == null) return _posts;
    return _posts.where((p) {
      final tags = (p['tags'] as List?)?.cast<String>() ?? [];
      final interest = p['interest']?.toString().toLowerCase() ?? '';
      return interest == _activeFilter || tags.any((t) => t.toLowerCase().contains(_activeFilter!));
    }).toList();
  }

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: Stack(
        children: [
          // Ambient bg — futuristic 3D glow orbs
          const _AmbientBackground(),

          // Main content
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader()),
              // Chatrooms Section
              SliverToBoxAdapter(child: _buildChatroomsSection()),
              // Filter bar
              SliverPersistentHeader(pinned: true, delegate: _FilterBarDelegate(
                activeFilter: _activeFilter,
                onFilterChanged: (f) => setState(() => _activeFilter = f),
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
    final hour = DateTime.now().hour;
    String greeting, emoji;
    if (hour < 6) { greeting = 'Good Night'; emoji = '🌙'; }
    else if (hour < 12) { greeting = 'Good Morning'; emoji = '☀️'; }
    else if (hour < 17) { greeting = 'Good Afternoon'; emoji = '☀️'; }
    else if (hour < 21) { greeting = 'Good Evening'; emoji = '🌅'; }
    else { greeting = 'Good Night'; emoji = '🌙'; }

    return ClipRect(
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 16, right: 16, bottom: 14),
          decoration: BoxDecoration(
            color: HomeColors.bg, // solid black, no gradient/translucency
          ),
          child: Row(
            children: [
              // Meetra M Logo (custom painted, gradient, thick rounded)
              SizedBox(width: 42, height: 42, child: CustomPaint(painter: _MeetraMLogoPainter())),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$emoji $greeting', style: GoogleFonts.inter(fontSize: 10, color: HomeColors.txt2, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  // Wordmark — futuristic gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF9D4EDD), Color(0xFFFF2E97), Color(0xFF00F0FF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: Text(
                      'Meetra',
                      style: GoogleFonts.boogaloo(
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              )),
              const AppHeaderActions(
                containerColor: Color(0xFF161A25),
                iconColor: Color(0xFFF0F4FF),
                borderColor: Color(0x1AFFFFFF),
              ),
            ],
          ),
        ),
    ).animate().fadeIn(duration: 400.ms);
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

  // ==========================================
  // POST CARD
  // ==========================================
  Widget _buildPostCard(Map<String, dynamic> post) {
    final postId = post['id'].toString();
    final userName = post['user_name'] ?? post['author_name'] ?? 'User';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final postAvatarUrl = post['avatar_url']?.toString() ?? '';
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
    // final isMe = _sb.auth.currentUser?.id == postUserId; // removed unused
    // final isFollowingUser = _followingIds.contains(postUserId); // removed unused

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: HomeColors.card.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: HomeColors.cyan.withValues(alpha: 0.02), blurRadius: 2, spreadRadius: -1, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Avatar (Clear, unblurred)
                GestureDetector(
                  onTap: () {
                    if (postUserId.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: postUserId)));
                    }
                  },
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: postAvatarUrl.isEmpty ? LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: _gradientForInitial(initial),
                      ) : null,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.5),
                    ),
                    child: ClipOval(child: postAvatarUrl.isNotEmpty
                        ? Image.network(postAvatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initial, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))))
                        : Center(child: Text(initial, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
                  ),
                ),
                const SizedBox(width: 10),
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
                        child: Text(userName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.access_time, size: 8, color: HomeColors.muted),
                      const SizedBox(width: 3),
                      Text(_timeAgo(createdAt), style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.location_on, size: 8, color: HomeColors.muted),
                        const SizedBox(width: 2),
                        Text(city, style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
                      ],
                      if (interest.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(interest, style: GoogleFonts.inter(fontSize: 10, color: HomeColors.cyan, fontWeight: FontWeight.w500)),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: _buildPostText(content),
          ),

          // Images
          if (allImages.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _buildImageGrid(allImages),
          ),

          // Tags
          if (tags.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Wrap(spacing: 4, runSpacing: 4, children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: HomeColors.cyan.withValues(alpha: 0.06),
                border: Border.all(color: HomeColors.cyan.withValues(alpha: 0.12)),
              ),
              child: Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: HomeColors.cyan)),
            )).toList()),
          ),

          // Actions
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
            ),
            child: Row(
              children: [
                _buildActionBtn(isLiked ? Icons.favorite : Icons.favorite_border, '$likeCount', isLiked ? HomeColors.pink : HomeColors.muted, () => _toggleLike(postId)),
                const SizedBox(width: 4),
                _buildActionBtn(Icons.chat_bubble_outline, '$commentCount', HomeColors.muted, () => _showCommentSheet(postId)),
                const Spacer(),
                _buildActionBtn(isBookmarked ? Icons.bookmark : Icons.bookmark_border, '', isBookmarked ? HomeColors.yellow : HomeColors.muted, () => _toggleBookmark(postId)),
                _buildActionBtn(Icons.share, '', HomeColors.muted, () {
                  final text = content.length > 100 ? content.substring(0, 97) + '...' : content;
                  Share.share('Check out this post on Meetra:\n"$text"\n\nJoin the loop: https://meetra.app');
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

  Widget _buildImageGrid(List<String> images) {
    final count = images.length;
    if (count == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _buildImageItem(images[0], height: 200),
      );
    }
    if (count == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(children: images.map((img) => Expanded(child: Padding(
          padding: EdgeInsets.only(right: img == images.last ? 0 : 2),
          child: _buildImageItem(img, height: 140),
        ))).toList()),
      );
    }
    // 3+
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 200,
        child: Row(children: [
          Expanded(child: _buildImageItem(images[0], height: 200)),
          const SizedBox(width: 2),
          Expanded(child: Column(children: [
            Expanded(child: _buildImageItem(images.length > 1 ? images[1] : images[0])),
            const SizedBox(height: 2),
            Expanded(child: Stack(children: [
              _buildImageItem(images.length > 2 ? images[2] : images[0]),
              if (count > 3) Container(
                color: Colors.black54,
                child: Center(child: Text('+${count - 3}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ])),
          ])),
        ]),
      ),
    );
  }

  Widget _buildImageItem(String url, {double? height}) {
    Widget imageWidget = Center(child: Icon(Icons.image, color: HomeColors.muted, size: 30));
    
    if (url.startsWith('http')) {
      imageWidget = Image.network(url, fit: BoxFit.cover, width: double.infinity, height: height,
          errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image, color: HomeColors.muted, size: 30)));
    } else if (url.startsWith('data:image')) {
      try {
        final b64 = url.split(',').last;
        imageWidget = Image.memory(base64Decode(b64), fit: BoxFit.cover, width: double.infinity, height: height,
            errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image, color: HomeColors.muted, size: 30)));
      } catch (_) {}
    }

    return Container(
      height: height,
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
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.55,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: BoxDecoration(
          color: HomeColors.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: HomeColors.gb),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Comments', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.txt)),
            ),
            Expanded(
              child: previews.isEmpty
                  ? Center(child: Text('No comments yet', style: GoogleFonts.inter(color: HomeColors.muted, fontSize: 13)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: previews.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          CircleAvatar(radius: 14, backgroundColor: HomeColors.card, child: Text((c['user_name'] ?? 'U')[0], style: GoogleFonts.inter(fontSize: 10, color: HomeColors.txt))),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['user_name'] ?? 'User', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                            Text(c['text'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: HomeColors.txt2)),
                          ])),
                        ]),
                      )).toList(),
                    ),
            ),
            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: HomeColors.gb))),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: textCtrl,
                  style: GoogleFonts.inter(fontSize: 13, color: HomeColors.txt),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: GoogleFonts.inter(color: HomeColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                )),
                IconButton(
                  icon: Icon(Icons.send, color: HomeColors.cyan, size: 20),
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
      ),
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
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: HomeColors.bg2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: HomeColors.gb),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Create Post', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.txt)),
                    GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: HomeColors.glass, border: Border.all(color: HomeColors.gb)),
                      child: Icon(Icons.close, color: HomeColors.txt2, size: 16),
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
                        Container(
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
                          Text(_myProfile?['name'] ?? _myProfile?['full_name'] ?? 'You', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.txt)),
                          Row(children: [
                            Icon(Icons.public, size: 9, color: HomeColors.muted),
                            const SizedBox(width: 4),
                            Text('Public Post', style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
                          ]),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      // Text area
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: HomeColors.card,
                          border: Border.all(color: HomeColors.gb),
                        ),
                        child: TextField(
                          controller: textCtrl,
                          maxLines: 5,
                          style: GoogleFonts.inter(fontSize: 14, color: HomeColors.txt, height: 1.6),
                          decoration: InputDecoration(
                            hintText: "What's on your mind? Share your thoughts, experiences, or ask a question...",
                            hintStyle: GoogleFonts.inter(color: HomeColors.muted),
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
                              child: Image.network(
                                uploadedImageUrl!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(height: 180, color: HomeColors.card, child: const Center(child: Icon(Icons.broken_image, color: Colors.white24))),
                              ),
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
                      Text('Tag Interests', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: HomeColors.txt2)),
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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: selectedTags.contains(t) ? HomeColors.cyan.withValues(alpha: 0.08) : HomeColors.card,
                            border: Border.all(color: selectedTags.contains(t) ? HomeColors.cyan : HomeColors.gb),
                          ),
                          child: Text(t, style: GoogleFonts.inter(fontSize: 11, color: selectedTags.contains(t) ? HomeColors.cyan : HomeColors.txt2, fontWeight: FontWeight.w500)),
                        ),
                      )).toList()),
                      const SizedBox(height: 14),
                      // Options + Post btn
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: HomeColors.gb))),
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
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: uploadedImageUrl != null ? HomeColors.cyan.withValues(alpha: 0.15) : HomeColors.glass,
                                  border: Border.all(color: uploadedImageUrl != null ? HomeColors.cyan : HomeColors.gb),
                                ),
                                child: Icon(Icons.image, color: uploadedImageUrl != null ? HomeColors.cyan : HomeColors.txt2, size: 16),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (locationService.activeLocation.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set a location in Settings to tag your posts!'), backgroundColor: Colors.amber));
                                  return;
                                }
                                setSheet(() => attachLocation = !attachLocation);
                              },
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: attachLocation ? HomeColors.cyan.withValues(alpha: 0.15) : HomeColors.glass,
                                  border: Border.all(color: attachLocation ? HomeColors.cyan : HomeColors.gb),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on, color: attachLocation ? HomeColors.cyan : HomeColors.txt2, size: 16),
                                    if (attachLocation) ...[
                                      const SizedBox(width: 4),
                                      Text(locationService.activeLocation, style: GoogleFonts.inter(fontSize: 11, color: HomeColors.cyan, fontWeight: FontWeight.bold)),
                                    ]
                                  ],
                                ),
                              ),
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
                                  final locParts = locationService.activeLocation.split(',');
                                  final postDistrict = locParts.isNotEmpty ? locParts.first.trim() : '';
                                  final postState = locParts.length > 1 ? locParts[1].trim() : '';
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
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(colors: isPosting ? [HomeColors.muted, HomeColors.muted] : [HomeColors.cyan, HomeColors.green]),
                                ),
                                child: isPosting
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                    : Row(children: [
                                        Icon(Icons.send, size: 14, color: Colors.black),
                                        const SizedBox(width: 4),
                                        Text('Post', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
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
      )),
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCommunityCard('🏔️', 'Pune Trekkers', 'Weekend adventures with fellow hikers', 24),
        _buildCommunityCard('🎵', 'Open Mic Fam', 'Singers, poets & performers unite', 15),
        _buildCommunityCard('☕', 'Night Owls Coffee Club', 'Late night café explorers', 8),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Communities coming soon!'), duration: Duration(seconds: 1))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: HomeColors.cyan.withValues(alpha: 0.05),
              border: Border.all(color: HomeColors.cyan.withValues(alpha: 0.3), style: BorderStyle.solid),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline, color: HomeColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text('Create New Community', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.cyan)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.info_outline, size: 12, color: HomeColors.muted),
            const SizedBox(width: 4),
            Expanded(child: Text('You can only join communities where at least one member has been part of your journey through any section of the app.', style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted, height: 1.4))),
          ]),
        ),
      ],
    );
  }

  Widget _buildCommunityCard(String emoji, String name, String desc, int members) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: HomeColors.card,
        border: Border.all(color: HomeColors.gb),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: HomeColors.glass),
          child: Center(child: Text(emoji, style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.txt)),
          Text(desc, style: GoogleFonts.inter(fontSize: 10, color: HomeColors.muted)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.people, size: 10, color: HomeColors.cyan),
            const SizedBox(width: 4),
            Text('$members members', style: GoogleFonts.inter(fontSize: 10, color: HomeColors.cyan)),
          ]),
        ])),
      ]),
    );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const SizedBox(height: 48),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF9D4EDD), Color(0xFF4E8BFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: const Color(0xFF9D4EDD).withValues(alpha: 0.3), blurRadius: 24)],
            ),
            child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 30)),
          ),
          const SizedBox(height: 16),
          Text('Nothing here yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.txt)),
          const SizedBox(height: 6),
          Text('Be the first to spark a conversation!', style: GoogleFonts.inter(fontSize: 13, color: HomeColors.muted)),
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
  double get maxExtent => 56;
  @override
  double get minExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: HomeColors.bg,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
        ),
        child: SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _buildChip(context, Icons.local_fire_department, 'For You', activeFilter == null, () => onFilterChanged(null)),
              _buildChip(context, Icons.location_on, 'Nearby', false, onLocationTap, hasArrow: true),
              ..._kInterests.map((i) => _buildChip(
                context,
                i['icon'] as IconData,
                i['label'] as String,
                activeFilter == i['key'],
                () => onFilterChanged(activeFilter == i['key'] ? null : i['key'] as String),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label, bool active, VoidCallback onTap, {bool hasArrow = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: active
              ? const LinearGradient(colors: [Color(0xFF00E5CC), Color(0xFF4E8BFF)], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: active ? null : HomeColors.glass,
          border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: 0.04)),
          boxShadow: active ? [BoxShadow(color: const Color(0xFF00E5CC).withValues(alpha: 0.25), blurRadius: 10)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: active ? Colors.black : HomeColors.txt2),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? Colors.black : HomeColors.txt2)),
          if (hasArrow) ...[const SizedBox(width: 2), Icon(Icons.keyboard_arrow_down, size: 10, color: HomeColors.txt2)],
        ]),
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
    return IgnorePointer(
      child: Stack(
        children: [
          // Base gradient wash — deep black
          Container(
            color: HomeColors.bg,
          ),
          // Large cyan orb — top right
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
          // Vivid purple orb — center-left
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
          // Hot magenta orb — bottom right
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
        const Color(0xFF9D4EDD), // vivid purple
        const Color(0xFFBB4FE0), // violet-pink
        const Color(0xFFFF2E97), // hot magenta
        const Color(0xFFFF2E97), // magenta (hold)
        const Color(0xFF00F0FF), // electric cyan
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
class EchoNexusBanner extends StatefulWidget {
  const EchoNexusBanner({super.key});

  @override
  State<EchoNexusBanner> createState() => _EchoNexusBannerState();
}

class _EchoNexusBannerState extends State<EchoNexusBanner> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _orbit2Ctrl;
  late AnimationController _waveCtrl;
  late AnimationController _glowCtrl;

  // Anonymous profile data for orbiting avatars
  static const _outerAvatars = [
    {'initial': 'A', 'c1': Color(0xFF00E5CC), 'c2': Color(0xFF4E8BFF)},
    {'initial': 'K', 'c1': Color(0xFF9D4EDD), 'c2': Color(0xFFFF2E97)},
    {'initial': 'S', 'c1': Color(0xFFFF6B35), 'c2': Color(0xFFFFC107)},
    {'initial': 'R', 'c1': Color(0xFF00E676), 'c2': Color(0xFF00E5CC)},
    {'initial': 'M', 'c1': Color(0xFF4E8BFF), 'c2': Color(0xFF9D4EDD)},
  ];
  static const _innerAvatars = [
    {'initial': 'P', 'c1': Color(0xFFFF2E97), 'c2': Color(0xFFFF6B35)},
    {'initial': 'D', 'c1': Color(0xFF00E5CC), 'c2': Color(0xFF00E676)},
    {'initial': 'V', 'c1': Color(0xFFFFC107), 'c2': Color(0xFF4E8BFF)},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _orbit2Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _orbit2Ctrl.dispose();
    _waveCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BolroomShell())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C0E18), Color(0xFF060810)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow blobs
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) => Stack(children: [
                  Positioned(left: -40, top: -40, child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: const Color(0xFF9D4EDD).withValues(alpha: 0.15 + _glowCtrl.value * 0.1), blurRadius: 90),
                    ]),
                  )),
                  Positioned(right: -40, bottom: -40, child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: const Color(0xFF00E5CC).withValues(alpha: 0.15 + _glowCtrl.value * 0.1), blurRadius: 90),
                    ]),
                  )),
                ]),
              ),

              // Subtle grid
              Positioned.fill(child: CustomPaint(painter: _GridBackgroundPainter())),

              // DUAL ORBIT SYSTEM
              AnimatedBuilder(
                animation: Listenable.merge([_orbitCtrl, _orbit2Ctrl]),
                builder: (_, __) {
                  final a1 = _orbitCtrl.value * 2 * math.pi;
                  final a2 = -_orbit2Ctrl.value * 2 * math.pi; // counter-rotate
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer dashed ring
                      Transform.rotate(
                        angle: a1 * 0.3,
                        child: CustomPaint(size: const Size(180, 180), painter: _DashedRingPainter(color: Colors.white.withValues(alpha: 0.06))),
                      ),
                      // Inner dashed ring
                      Transform.rotate(
                        angle: -a2 * 0.4,
                        child: CustomPaint(size: const Size(110, 110), painter: _DashedRingPainter(color: Colors.white.withValues(alpha: 0.08))),
                      ),
                      // Outer orbit profiles (5 avatars, radius 80)
                      ...List.generate(_outerAvatars.length, (i) {
                        final theta = a1 + (i * 2 * math.pi / _outerAvatars.length);
                        final av = _outerAvatars[i];
                        return Transform.translate(
                          offset: Offset(80 * math.cos(theta), 80 * math.sin(theta)),
                          child: _buildOrbitAvatar(av['initial'] as String, av['c1'] as Color, av['c2'] as Color, 30),
                        );
                      }),
                      // Inner orbit profiles (3 avatars, radius 48, counter-rotate)
                      ...List.generate(_innerAvatars.length, (i) {
                        final theta = a2 + (i * 2 * math.pi / _innerAvatars.length);
                        final av = _innerAvatars[i];
                        return Transform.translate(
                          offset: Offset(48 * math.cos(theta), 48 * math.sin(theta)),
                          child: _buildOrbitAvatar(av['initial'] as String, av['c1'] as Color, av['c2'] as Color, 24),
                        );
                      }),
                    ],
                  );
                },
              ),

              // CENTER GLOWING ORB — triple ring pulse
              ScaleTransition(
                scale: Tween<double>(begin: 0.93, end: 1.07).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost glow
                    Container(width: 88, height: 88, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFF00E5CC).withValues(alpha: 0.25),
                        Colors.transparent,
                      ]),
                    )),
                    // Mid ring
                    Container(width: 72, height: 72, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFF00E5CC), Color(0xFF0C0E18)], stops: [0.15, 1.0]),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00E5CC).withValues(alpha: 0.5), blurRadius: 35),
                        BoxShadow(color: const Color(0xFF00E5CC).withValues(alpha: 0.2), blurRadius: 70),
                      ],
                    )),
                    // Inner dark core
                    Container(width: 50, height: 50, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0C0E18),
                      border: Border.all(color: const Color(0xFF00E5CC).withValues(alpha: 0.6), width: 1.5),
                    ), child: const Center(child: Icon(Icons.graphic_eq, color: Color(0xFF00E5CC), size: 24))),
                  ],
                ),
              ),

              // TEXT OVERLAYS — Top
              Positioned(
                top: 16, left: 20, right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BOLROOM', style: GoogleFonts.michroma(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2.5)),
                      const SizedBox(height: 3),
                      Text('LIVE ANONYMOUS AUDIO', style: GoogleFonts.inter(color: const Color(0xFF00E5CC), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(
                          color: const Color(0xFF00E676), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.6), blurRadius: 6)],
                        )),
                        const SizedBox(width: 6),
                        Text('DROP IN', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ]),
                    ),
                  ],
                ),
              ),

              // Bottom wave + stats
              Positioned(
                bottom: 14, left: 20, right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _buildWaveBar(8, color: HomeColors.purple),
                      _buildWaveBar(14, color: HomeColors.cyan),
                      _buildWaveBar(10, color: HomeColors.pink),
                      _buildWaveBar(18, color: HomeColors.blue),
                      _buildWaveBar(12, color: HomeColors.green),
                      _buildWaveBar(16, color: HomeColors.cyan),
                      _buildWaveBar(9, color: HomeColors.purple),
                    ]),
                    Text('8.4K TUNED IN', style: GoogleFonts.michroma(color: HomeColors.txt2, fontSize: 7, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.04, end: 0),
    );
  }

  Widget _buildOrbitAvatar(String initial, Color c1, Color c2, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
        border: Border.all(color: const Color(0xFF0C0E18), width: 2),
        boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Center(child: Text(initial, style: GoogleFonts.inter(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.w700))),
    );
  }

  Widget _buildWaveBar(double height, {Color? color}) {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, __) {
        final offset = (height % 4) * 0.4;
        final val = math.sin((_waveCtrl.value * math.pi * 2) + offset).abs();
        final h = height + (val * 7);
        return Container(
          margin: const EdgeInsets.only(right: 2.5),
          width: 3, height: h,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: (color ?? Colors.white).withValues(alpha: 0.5), blurRadius: 5)],
          ),
        );
      },
    );
  }
}

// Dashed ring painter for orbit tracks
class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final r = size.width / 2;
    final center = Offset(r, r);
    const dashAngle = math.pi / 18;
    const spaceAngle = math.pi / 22;
    double startAngle = 0;
    while (startAngle < math.pi * 2) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, dashAngle, false, paint);
      startAngle += dashAngle + spaceAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Grid background for banner
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.02)..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 22) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 22) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


