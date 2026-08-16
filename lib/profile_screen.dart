// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: unused_field, unused_element
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
// removed invalid import
import 'rush_in_consumer_detail_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/mapbox_helpers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'services/location_service.dart';

import 'widgets/location_picker_sheet.dart';
import 'widgets/profile_detail_sheet.dart';
// import 'follow_list_screen.dart'; // removed unused
import 'auth_screen.dart';

import 'package:url_launcher/url_launcher.dart';
import 'edit_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'admin_dashboard_screen.dart';
import 'widgets/skeleton_loaders.dart';
import 'widgets/tiltable_hero_section.dart';
import 'services/doodle_theme.dart';
import 'communities_screen.dart';

// ----------------------------------------------------
// UI Constants — Unified App Design System
// ----------------------------------------------------
class ProfileColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgSecondary = Color(0xFF000000);
  static const bgTertiary = Color(0xFF000000);
  static const bgCard = Color(0xFF000000);
  static const bgGlass = Color(0xCC000000);
  static const cyan = Color(0xFFFF6B00);
  static const purple = Color(0xFFFF7E40);
  static const blue = Color(0xFF4E8BFF);
  static const green = Color(0xFF4ADE80);
  static const red = Color(0xFFFF3D5A);
  static const pink = Color(0xFFFF3D00);
  static const orange = Color(0xFFFF6B00);
  static const teal = Color(0xFF14B8A6);
  static const amber =
      Color(0xFFF4A926); // kept for backward compat in dashboard
  static const coral =
      Color(0xFFE8735A); // kept for backward compat in dashboard
  static const violet = Color(0xFFFF7E40); // alias
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textMuted = Color(0xFF616161);
  static const borderSubtle = Color(0x14FFFFFF);
  static const borderLight = Color(0x1EFFFFFF);
  static final glass = Colors.white.withValues(alpha: 0.05);
  static final gborder = Colors.white.withValues(alpha: 0.08);
}

const LinearGradient mainGradient = LinearGradient(
  colors: [ProfileColors.cyan, ProfileColors.blue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient neonGradient = LinearGradient(
  colors: [Color(0xFFFF6B00), Color(0xFFFF8A00), Color(0xFFFFC107)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, means it's my own profile
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Logic Variables
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _savedPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  int _totalRushInsCount = 0;
  late AnimationController _orbController;
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  int _activeTabIndex = 0; // 0=Grid, 1=Saved/Tagged
  int _contributionScore = 100;
  List<Map<String, dynamic>> _joinedCommunities = [];
  bool _requestSent = false;

  // Settings State Variables
  bool _pushNotifications = true;
  bool _locationServices = true;
  bool _ghostMode = false;
  bool _sparkNotifications = true;
  bool _autoMatchSpark = false;
  bool _activityStatus = true;
  bool _saveToCameraRoll = false;
  double _matchRadius = 15.0;
  bool _isGlobal = false;
  double _ageMin = 21.0;
  double _ageMax = 35.0;
  String _mediaQuality = 'High';
  bool _isPublic = true;
  String _navTransition = 'Slide';



  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _loadProfile();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList('home_bookmarks') ?? [];
    if (savedIds.isEmpty) return;

    try {
      final postsRes = await Supabase.instance.client
          .from('posts')
          .select()
          .inFilter('id', savedIds)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _savedPosts = List<Map<String, dynamic>>.from(postsRes);
        });
      }
    } catch (_) {}
  }



  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = widget.userId ?? _myUid;
      if (uid.isEmpty) return;

      final pRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      final followersReq = await Supabase.instance.client
          .from('requests')
          .select('id')
          .eq('target_id', uid)
          .eq('target_type', 'follow')
          .eq('status', 'approved');
      final followingReq = await Supabase.instance.client
          .from('requests')
          .select('id')
          .eq('sender_id', uid)
          .eq('target_type', 'follow')
          .eq('status', 'approved');
      final postsRes = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      bool isFollowing = false;
      bool reqSent = false;
      if (widget.userId != null && widget.userId != _myUid) {
        final check = await Supabase.instance.client
            .from('requests')
            .select('id')
            .eq('sender_id', _myUid)
            .eq('target_id', uid)
            .eq('target_type', 'follow')
            .maybeSingle();
        isFollowing = check != null;

        final msgCheck = await Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('sender_id', _myUid)
            .eq('receiver_id', uid)
            .limit(1);
        reqSent = (msgCheck as List).isNotEmpty;
      }

      final rushInsRes = await Supabase.instance.client
          .from('activities')
          .select('id')
          .eq('user_id', uid)
          .eq('is_rush_in', true);
      final knocksRes = await Supabase.instance.client
          .from('requests')
          .select('id')
          .eq('sender_id', uid)
          .eq('target_type', 'knock');
      final knocksAcceptedRes = await Supabase.instance.client
          .from('requests')
          .select('id')
          .eq('target_id', uid)
          .eq('target_type', 'knock')
          .eq('status', 'approved');
      final joinedRushInsRes = await Supabase.instance.client
          .from('requests')
          .select('id')
          .eq('sender_id', uid)
          .inFilter('target_type', ['rush_in', 'activity']).eq(
              'status', 'approved');
      final likesRes = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', uid);
      final commentsRes = await Supabase.instance.client
          .from('post_comments')
          .select('id')
          .eq('user_id', uid);
      final messagesRes = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('sender_id', uid)
          .limit(500);

      final membersRes = await Supabase.instance.client
          .from('text_camp_members')
          .select('camp_id')
          .eq('user_id', uid);
      final campIds =
          (membersRes as List).map((m) => m['camp_id'].toString()).toList();
      List<Map<String, dynamic>> joinedCamps = [];
      if (campIds.isNotEmpty) {
        final campsRes = await Supabase.instance.client
            .from('text_camps')
            .select()
            .inFilter('id', campIds);
        joinedCamps = List<Map<String, dynamic>>.from(campsRes);
      }

      final int score = 100 +
          (postsRes.length * 10) +
          (rushInsRes.length * 15) +
          (knocksRes.length * 5) +
          (knocksAcceptedRes.length * 10) +
          (joinedRushInsRes.length * 15) +
          (joinedCamps.length * 20) +
          (likesRes.length * 2) +
          (commentsRes.length * 5) +
          (messagesRes.length * 1);

      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _profile = pRes;
          _followersCount = followersReq.length;
          _followingCount = followingReq.length;
          _totalRushInsCount = rushInsRes.length + joinedRushInsRes.length;
          _userPosts = List<Map<String, dynamic>>.from(postsRes);
          _isFollowing = isFollowing;
          _requestSent = reqSent;
          _isPublic = _profile?['is_public'] ?? true;
          _contributionScore = score;
          _joinedCommunities = joinedCamps;

          _pushNotifications = prefs.getBool('push_notifications') ?? true;
          _locationServices = prefs.getBool('location_services') ?? true;
          _ghostMode = prefs.getBool('ghost_mode') ?? false;
          _sparkNotifications = prefs.getBool('spark_notifications') ?? true;
          _autoMatchSpark = prefs.getBool('auto_match_spark') ?? false;
          _saveToCameraRoll = prefs.getBool('save_camera_roll') ?? false;
          _matchRadius = prefs.getDouble('discovery_radius') ?? 15.0;
          _isGlobal = prefs.getBool('is_global') ?? false;
          _ageMin = prefs.getDouble('age_range_min') ?? 21.0;
          _ageMax = prefs.getDouble('age_range_max') ?? 35.0;
          _mediaQuality = prefs.getString('media_quality') ?? 'High';
          _navTransition = prefs.getString('nav_transition') ?? 'Slide';

          _loadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _toggleFollow() async {
    final uid = widget.userId;
    if (_myUid.isEmpty || uid == null) return;

    setState(() {
      _isFollowing = !_isFollowing;
      _followersCount += _isFollowing ? 1 : -1;
    });

    try {
      if (_isFollowing) {
        await Supabase.instance.client.from('requests').upsert({
          'sender_id': _myUid,
          'target_id': uid,
          'target_type': 'follow',
          'status': 'approved',
        });
      } else {
        await Supabase.instance.client
            .from('requests')
            .delete()
            .eq('sender_id', _myUid)
            .eq('target_id', uid)
            .eq('target_type', 'follow');
      }
    } catch (_) {
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });
    }
  }

  ImageProvider _buildSafeImageProvider(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) {
      return const NetworkImage(
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop');
    }
    if (urlStr.startsWith('http')) return NetworkImage(urlStr);
    try {
      final base64Str = urlStr.contains(',') ? urlStr.split(',').last : urlStr;
      return MemoryImage(base64Decode(base64Str));
    } catch (_) {
      return const NetworkImage(
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop');
    }
  }

  void _onLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  void _onEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EditProfileScreen(initialProfile: _profile ?? {})),
    );
    if (result == true) {
      _loadProfile(); // Refresh profile data
    }
  }

  void _onShareProfile() {
    final name = _profile?['name'] ?? 'Relaya User';
    final username = _profile?['username'] ?? '';
    final url = 'https://meetra.app/profile/$username';
    Share.share('Check out $name on Relaya!\n$url');
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: doodle ? DoodleColors.cream : ProfileColors.bgPrimary,
        body: SafeArea(
            child: SkeletonLoaders.genericListSkeleton(
                doodle: isDoodleMode(context))),
      );
    }

    final p = _profile ?? {};
    final isMe = widget.userId == null || widget.userId == _myUid;
    final name = p['name'] ?? p['full_name'] ?? 'User';
    final username = p['username'] ?? name.replaceAll(' ', '.').toLowerCase();
    final bio = p['bio'] ?? '"Chasing sunsets & stories \u2728"';
    final dob = p['dob'] as String?;
    final gender = p['gender'] as String?;
    final location = (locationService.activeLocation.isNotEmpty && isMe)
        ? locationService.activeLocation
        : (p['city'] ?? p['location'] ?? 'Mumbai, India');
    final avatarUrl = p['avatar_url'] ?? '';
    final isPublic = p['is_public'] ?? true;
    final canViewContent = isMe || isPublic || _isFollowing;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: doodle ? DoodleColors.cream : ProfileColors.bgPrimary,
      drawer: _buildManagementDashboard(),
      endDrawer: _buildSettingsPanel(),
      body: Stack(
        children: [
          // Doodle background decorations
          if (doodle)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Container(decoration: DoodleDecorations.parchmentBg()),
                    CustomPaint(
                        painter: ScatteredDoodlesPainter(
                            seed: 99,
                            density: 0.3,
                            color: const Color(0x18B8956E))),
                  ],
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopNav(username, isMe),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        TiltableHeroSection(
                            child: _buildHeroSection(name, username, bio,
                                location, avatarUrl, isMe, dob, gender)),
                        _buildPostsTabs(isMe),
                        _buildPostsContent(canViewContent, isMe),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== 1. TOP NAV (Glassmorphic) ==============
  Widget _buildTopNav(String username, bool isMe) {
    final doodle = isDoodleMode(context);
    if (doodle) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: DoodleColors.cream,
          border: Border(
              bottom: BorderSide(color: DoodleColors.cardBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isMe)
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DoodleColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DoodleColors.cardBorder),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      color: DoodleColors.textSecondary, size: 18),
                ),
              )
            else
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DoodleColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DoodleColors.cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: DoodleColors.textSecondary, size: 18),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: DoodleDecorations.card(color: DoodleColors.orange),
              child: Text(
                'MY PROFILE',
                style: DoodleFonts.heading(
                    fontSize: 20, color: DoodleColors.brown),
              ),
            ),
            if (isMe)
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DoodleColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DoodleColors.cardBorder),
                  ),
                  child: const Icon(Icons.settings_outlined,
                      color: DoodleColors.textSecondary, size: 18),
                ),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: ProfileColors.bgGlass,
            border: Border(
                bottom:
                    BorderSide(color: ProfileColors.borderSubtle, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isMe)
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child:
                      _buildNavIconBtn(Icons.grid_view_rounded, hasBadge: true),
                )
              else
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: _buildNavIconBtn(Icons.arrow_back_ios_new),
                ),
              ShaderMask(
                shaderCallback: (bounds) => neonGradient.createShader(bounds),
                child: Text(
                  '@$username',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (isMe)
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                  child: _buildNavIconBtn(Icons.settings_outlined),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIconBtn(IconData icon, {bool hasBadge = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ProfileColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileColors.cyan.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: ProfileColors.cyan.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: ProfileColors.textSecondary, size: 18),
          if (hasBadge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [ProfileColors.pink, ProfileColors.orange]),
                  border:
                      Border.all(color: ProfileColors.bgPrimary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: ProfileColors.pink.withValues(alpha: 0.6),
                        blurRadius: 6)
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                      duration: 2.seconds,
                      begin: const Offset(1, 1),
                      end: const Offset(1.3, 1.3))
                  .fade(end: 0.5),
            ),
        ],
      ),
    );
  }

  // ============== 2. PROFILE HERO ==============
  Widget _buildHeroSection(
      String name,
      String username,
      String bio,
      String location,
      String avatarUrl,
      bool isMe,
      String? dob,
      String? gender) {
    final doodle = isDoodleMode(context);
    String initials = name
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    if (initials.isEmpty) initials = 'U';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Avatar — doodle hand-drawn circle in light, neon ring in dark
              doodle
                  ? SizedBox(
                      width: 110,
                      height: 110,
                      child: GestureDetector(
                        onTap: () =>
                            _showPhotoPreview(context, avatarUrl, initials),
                        child: CustomPaint(
                          painter: SketchCirclePainter(
                              color: DoodleColors.orange, strokeWidth: 3),
                          child: Center(
                            child: ClipOval(
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: avatarUrl.isNotEmpty
                                    ? Image(
                                        image:
                                            _buildSafeImageProvider(avatarUrl),
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: DoodleColors.pastelPeach,
                                        child: Center(
                                          child: Text(initials,
                                              style: DoodleFonts.heading(
                                                  fontSize: 32,
                                                  color: DoodleColors.orange)),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () =>
                          _showPhotoPreview(context, avatarUrl, initials),
                      child: Container(
                        width: 106,
                        height: 106,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6B00),
                            width: 3,
                          ),
                        ),
                        child: avatarUrl.isNotEmpty
                            ? CircleAvatar(
                                backgroundImage:
                                    _buildSafeImageProvider(avatarUrl),
                                backgroundColor: Colors.transparent,
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1E1E1E),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.inter(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF6B00),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
              const SizedBox(height: 16),

              // 2. Centered Name
              Text(
                name,
                style: doodle
                    ? DoodleFonts.heading(
                        fontSize: 28, color: DoodleColors.brown)
                    : GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(height: 4),

              // 3. Centered Username + Age + Gender
              Builder(builder: (context) {
                int? age;
                if (dob != null && dob.isNotEmpty) {
                  try {
                    final bdate = DateTime.parse(dob);
                    final today = DateTime.now();
                    age = today.year - bdate.year;
                    if (today.month < bdate.month ||
                        (today.month == bdate.month && today.day < bdate.day)) {
                      age = age - 1;
                    }
                  } catch (_) {}
                }

                String subtitle = '@${username.toLowerCase()}';
                if (age != null) subtitle += ' • $age';
                if (gender != null && gender.isNotEmpty)
                  subtitle += ' • $gender';

                return Text(
                  subtitle,
                  style: doodle
                      ? DoodleFonts.body(
                          fontSize: 16, color: DoodleColors.brown)
                      : GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                );
              }),
              const SizedBox(height: 8),

              // 4. Centered Location with Pin Icon
              ValueListenableBuilder<String>(
                valueListenable: locationService.activeLocationNotifier,
                builder: (context, activeLoc, _) {
                  final displayLoc =
                      (activeLoc.isNotEmpty && isMe) ? activeLoc : location;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: doodle
                            ? DoodleColors.brown
                            : const Color(0xFFFF6B00),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayLoc.isEmpty ? 'New York, NY' : displayLoc,
                        style: doodle
                            ? DoodleFonts.body(
                                fontSize: 14,
                                color:
                                    DoodleColors.brown.withValues(alpha: 0.8))
                            : GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // 5. Centered Bio
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  bio.isEmpty
                      ? 'Adventure seeker | Event host | Music lover'
                      : bio,
                  textAlign: TextAlign.center,
                  style: doodle
                      ? DoodleFonts.body(
                          fontSize: 14, color: DoodleColors.brown)
                      : GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // 6. Centered Capsule Outline Button
              GestureDetector(
                onTap: (isMe || _requestSent)
                    ? (isMe ? _onEditProfile : null)
                    : () {
                        if (_profile != null) {
                          showMessageRequestSheet(
                            context,
                            _profile!,
                            onSent: () {
                              if (mounted) {
                                setState(() => _requestSent = true);
                              }
                            },
                          );
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  decoration: BoxDecoration(
                    color: _requestSent
                        ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _requestSent
                          ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isMe
                        ? 'Edit Profile'
                        : (_requestSent ? 'Request Sent' : 'Request'),
                    style: GoogleFonts.inter(
                      color:
                          _requestSent ? const Color(0xFF22C55E) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 7. Large Centered Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNewStatColumn(
                      icon: Icons.flash_on,
                      val: '$_totalRushInsCount',
                      label: 'RUSH-INS',
                      iconColor: const Color(0xFFFF6B00),
                      onTap: _showAllRushInsSheet,
                    ),
                    _buildNewStatColumn(
                      icon: Icons.auto_awesome,
                      val: '$_contributionScore',
                      label: 'CONTRIBUTIONS',
                      iconColor: const Color(0xFFFFD54F),
                      onTap: _showContributionsSheet,
                    ),
                    _buildNewStatColumn(
                      icon: Icons.groups_rounded,
                      val: '${_joinedCommunities.length}',
                      label: 'ACTIVE-IN',
                      iconColor: const Color(0xFF4E8BFF),
                      onTap: _showActiveInCommunitiesSheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewStatColumn({
    required IconData icon,
    required String val,
    required String label,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final doodle = isDoodleMode(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) onTap();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: doodle
              ? DoodleDecorations.card(color: DoodleColors.cream)
              : BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                        color: iconColor.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                val,
                style: doodle
                    ? DoodleFonts.heading(
                        fontSize: 22, color: DoodleColors.brown)
                    : GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: doodle
                    ? DoodleFonts.body(fontSize: 11, color: DoodleColors.brown)
                    : GoogleFonts.inter(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54,
                      ),
              ),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
            duration: 3000.ms, color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }

  void _showContributionsSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
          decoration: doodle
              ? DoodleDecorations.card(
                  color: DoodleColors.cream, borderColor: DoodleColors.brown)
              : const BoxDecoration(
                  color: Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: doodle
                        ? DoodleColors.brown.withValues(alpha: 0.3)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contributions',
                    style: doodle
                        ? DoodleFonts.heading(
                            fontSize: 20, color: DoodleColors.brown)
                        : GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_contributionScore',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFD54F)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Your community contribution score',
                style: doodle
                    ? DoodleFonts.body(
                        fontSize: 12,
                        color: DoodleColors.brown.withValues(alpha: 0.7))
                    : GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 64,
                          color:
                              const Color(0xFFFFD54F).withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'Keep hosting and joining activities to increase your contribution score and unlock premium badges!',
                        textAlign: TextAlign.center,
                        style: doodle
                            ? DoodleFonts.body(
                                fontSize: 14, color: DoodleColors.brown)
                            : GoogleFonts.inter(
                                fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showActiveInCommunitiesSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
          decoration: doodle
              ? DoodleDecorations.card(
                  color: DoodleColors.cream, borderColor: DoodleColors.brown)
              : const BoxDecoration(
                  color: Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: doodle
                        ? DoodleColors.brown.withValues(alpha: 0.3)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active In Communities',
                    style: doodle
                        ? DoodleFonts.heading(
                            fontSize: 20, color: DoodleColors.brown)
                        : GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4E8BFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_joinedCommunities.length}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4E8BFF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Real-world social loops joined across Meetra',
                style: doodle
                    ? DoodleFonts.body(
                        fontSize: 12,
                        color: DoodleColors.brown.withValues(alpha: 0.7))
                    : GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
              ),
              const SizedBox(height: 16),
              if (_joinedCommunities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.groups_outlined,
                            size: 48,
                            color: doodle
                                ? DoodleColors.brown.withValues(alpha: 0.4)
                                : Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'Not active in any communities yet',
                          style: doodle
                              ? DoodleFonts.body(
                                  fontSize: 14, color: DoodleColors.brown)
                              : GoogleFonts.inter(
                                  fontSize: 14, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _joinedCommunities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final row = _joinedCommunities[i];
                      final name = row['name']?.toString() ?? 'Community';
                      final cat = row['category']?.toString() ?? 'General';
                      final avatar = row['avatar_url']?.toString() ??
                          'https://images.unsplash.com/photo-1516862523118-a3724eb136d7?auto=format&fit=crop&w=150&q=80';
                      final members = row['member_count'] ?? 1;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          final comm = Community(
                            id: row['id']?.toString() ?? '',
                            name: name,
                            category: cat,
                            creatorId: row['creator_id']?.toString() ?? '',
                            memberCount: members is int
                                ? members
                                : int.tryParse(members.toString()) ?? 1,
                            avatar: avatar,
                            lastMessage: 'Welcome to $name!',
                            lastMessageTime: 'Active',
                            unreadCount: 0,
                            locationDistrict:
                                row['location_district']?.toString() ??
                                    'Unknown',
                            channels: [
                              CommunityChannel(name: 'general', messages: [])
                            ],
                            isPrivate: row['is_private'] ?? false,
                          );
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CommunityChatRoomScreen(
                                      community: comm)));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: doodle
                              ? DoodleDecorations.card(
                                  color: DoodleColors.paper,
                                  borderColor: DoodleColors.cardBorder,
                                  radius: 14)
                              : BoxDecoration(
                                  color: const Color(0xFF16161D),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08)),
                                ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  avatar,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: const Color(0xFF27272A),
                                    child: const Icon(Icons.groups,
                                        color: Colors.white54),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: doodle
                                          ? DoodleFonts.heading(
                                              fontSize: 16,
                                              color: DoodleColors.brown)
                                          : GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B00)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            cat,
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFFF6B00)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$members members',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.white54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 16, color: Colors.white38),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAllRushInsSheet() {
    final doodle = isDoodleMode(context);
    final uid = widget.userId ?? _myUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          decoration: doodle
              ? DoodleDecorations.card(
                  color: DoodleColors.cream, borderColor: DoodleColors.brown)
              : const BoxDecoration(
                  color: Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: doodle
                        ? DoodleColors.brown.withValues(alpha: 0.3)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rush-In History',
                    style: doodle
                        ? DoodleFonts.heading(
                            fontSize: 20, color: DoodleColors.brown)
                        : GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_totalRushInsCount',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B00)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'All rush-ins hosted and joined',
                style: doodle
                    ? DoodleFonts.body(
                        fontSize: 12,
                        color: DoodleColors.brown.withValues(alpha: 0.7))
                    : GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: () async {
                    // Fetch Hosted Rush-ins
                    final hostedRes = await Supabase.instance.client
                        .from('activities')
                        .select(
                            '*, profiles!activities_user_id_fkey(name, avatar_url)')
                        .eq('user_id', uid)
                        .eq('is_rush_in', true);

                    // Fetch Joined Rush-ins
                    final reqsRes = await Supabase.instance.client
                        .from('requests')
                        .select('target_id')
                        .eq('sender_id', uid)
                        .eq('status', 'approved')
                        .inFilter('target_type', ['rush_in', 'activity']);

                    final targetIds = (reqsRes as List)
                        .map((r) => r['target_id'].toString())
                        .toList();
                    List<dynamic> joinedRes = [];
                    if (targetIds.isNotEmpty) {
                      final acts = await Supabase.instance.client
                          .from('activities')
                          .select(
                              '*, profiles!activities_user_id_fkey(name, avatar_url)')
                          .inFilter('id', targetIds)
                          .eq('is_rush_in', true);
                      joinedRes = acts as List;
                    }

                    List<Map<String, dynamic>> combined = [];
                    for (final r in (hostedRes as List)) {
                      final m = Map<String, dynamic>.from(r);
                      m['relation'] = 'hosted';
                      combined.add(m);
                    }
                    for (final r in joinedRes) {
                      final m = Map<String, dynamic>.from(r);
                      // prevent duplicates if they somehow requested their own
                      if (!combined.any((x) => x['id'] == m['id'])) {
                        m['relation'] = 'joined';
                        combined.add(m);
                      }
                    }

                    combined.sort((a, b) {
                      final dtA = DateTime.tryParse(
                              a['created_at']?.toString() ?? '') ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final dtB = DateTime.tryParse(
                              b['created_at']?.toString() ?? '') ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return dtB.compareTo(dtA);
                    });

                    return combined;
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(
                              color: const Color(0xFFFF6B00)));
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.flash_off,
                                  size: 48,
                                  color: doodle
                                      ? DoodleColors.brown
                                          .withValues(alpha: 0.4)
                                      : Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                'No rush-ins found',
                                style: doodle
                                    ? DoodleFonts.body(
                                        fontSize: 14, color: DoodleColors.brown)
                                    : GoogleFonts.inter(
                                        fontSize: 14, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final now = DateTime.now().toUtc();
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final act = list[i];
                        final isHosted = act['relation'] == 'hosted';

                        // Status logic
                        final actStr = act['activity_time'] as String? ??
                            act['created_at'] as String?;
                        final expStr = act['expires_at'] as String?;
                        final start =
                            actStr != null ? DateTime.tryParse(actStr) : null;
                        final end = expStr != null
                            ? DateTime.tryParse(expStr)
                            : start?.add(Duration(
                                hours: act['duration_hours'] as int? ?? 6));

                        String statusLabel = 'UNKNOWN';
                        Color sColor = Colors.white38;
                        if (start != null && end != null) {
                          if (now.isBefore(start)) {
                            statusLabel = 'UPCOMING';
                            sColor = const Color(0xFF22C55E); // green
                          } else if (now.isBefore(end)) {
                            statusLabel = 'LIVE NOW';
                            sColor = const Color(0xFFEF4444); // red
                          } else {
                            statusLabel = 'EXPIRED';
                            sColor = Colors.white38;
                          }
                        }

                        final title = act['title']?.toString() ?? 'Untitled';
                        final loc = act['location_name']?.toString() ?? '';
                        final hostMap =
                            act['profiles'] as Map<String, dynamic>?;
                        final hostName = hostMap?['name']?.toString() ?? 'Host';

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.pop(ctx);
                            Future.delayed(const Duration(milliseconds: 150),
                                () {
                              if (mounted) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            RushInConsumerDetailView(
                                                activity: act,
                                                onInteraction: () {})));
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: doodle
                                ? DoodleDecorations.card(
                                    color: DoodleColors.paper,
                                    borderColor: DoodleColors.cardBorder,
                                    radius: 14)
                                : BoxDecoration(
                                    color: const Color(0xFF16161D),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.08)),
                                  ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isHosted
                                                ? const Color(0xFFFF6B00)
                                                : const Color(0xFF4E8BFF))
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isHosted ? 'HOSTED' : 'JOINED',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isHosted
                                                ? const Color(0xFFFF6B00)
                                                : const Color(0xFF4E8BFF)),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          if (statusLabel == 'LIVE NOW') ...[
                                            Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                    color: sColor,
                                                    shape: BoxShape.circle)),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(statusLabel,
                                              style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: sColor)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  title,
                                  style: doodle
                                      ? DoodleFonts.heading(
                                          fontSize: 16,
                                          color: DoodleColors.brown)
                                      : GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                if (loc.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 12, color: Colors.white38),
                                      const SizedBox(width: 4),
                                      Text(loc,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.white54)),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person,
                                        size: 12, color: Colors.white38),
                                    const SizedBox(width: 4),
                                    Text('by $hostName',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white54)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCol(
      String val, String label, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(val,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(String icon, String val, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: ProfileColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ProfileColors.gborder),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(val,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: ProfileColors.textMuted,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // ============== 3. POSTS LAYOUT ==============
  Widget _buildPostsTabs(bool isMe) {
    final doodle = isDoodleMode(context);
    if (doodle) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.all(4),
        decoration: DoodleDecorations.card(
            color: DoodleColors.amber.withValues(alpha: 0.3)),
        child: Row(
          children: [
            _buildTabBtn(0, 'GRID'),
            _buildTabBtn(1, isMe ? 'SAVED' : 'TAGGED'),
          ],
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ProfileColors.borderSubtle)),
      ),
      child: Row(
        children: [
          _buildTabBtn(0, 'GRID'),
          _buildTabBtn(1, isMe ? 'SAVED' : 'TAGGED'),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int index, String title) {
    bool active = _activeTabIndex == index;
    final doodle = isDoodleMode(context);

    if (doodle) {
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _activeTabIndex = index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: active
                ? DoodleDecorations.card(color: DoodleColors.orange, radius: 4)
                : null,
            child: Text(title,
                style: DoodleFonts.heading(
                    fontSize: 14,
                    color: active
                        ? DoodleColors.brown
                        : DoodleColors.brown.withValues(alpha: 0.5))),
          ),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: active
                ? const Border(
                    bottom: BorderSide(color: ProfileColors.cyan, width: 2))
                : null,
          ),
          child: Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color:
                      active ? ProfileColors.cyan : ProfileColors.textMuted)),
        ),
      ),
    );
  }

  Widget _buildPostsContent(bool canView, bool isMe) {
    if (!canView) {
      return Container(
        padding: const EdgeInsets.all(60),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.lock_outline,
                size: 48, color: ProfileColors.textMuted),
            const SizedBox(height: 16),
            Text('Private Account',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("Follow this user to see their content.",
                style: GoogleFonts.inter(
                    color: ProfileColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final displayPosts = _activeTabIndex == 1 ? _savedPosts : _userPosts;

    if (displayPosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(60),
        alignment: Alignment.center,
        child: Text(_activeTabIndex == 1 ? 'No saved posts' : 'No posts yet',
            style: GoogleFonts.inter(
                color: ProfileColors.textMuted, fontSize: 14)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: displayPosts.length,
      itemBuilder: (context, index) {
        final post = displayPosts[index];
        final img = post['image_url']?.toString();
        ImageProvider? provider = _buildSafeImageProvider(img);

        return GestureDetector(
          onLongPress: () {
            // For deleting post logic
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              color: ProfileColors.bgTertiary,
              child: (img != null && img.isNotEmpty)
                  ? Image(image: provider, fit: BoxFit.cover)
                  : Center(
                      child: Text(post['content'] ?? '',
                          maxLines: 2,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white54),
                          textAlign: TextAlign.center),
                    ),
            ),
          ),
        );
      },
    );
  }

  // ============== 4. MANAGEMENT DASHBOARD (LEFT DRAWER) ==============
  Widget _buildManagementDashboard() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    return Drawer(
      backgroundColor: ProfileColors.bgSecondary,
      width: MediaQuery.of(context).size.width * 0.88 > 380
          ? 380
          : MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ProfileColors.cyan.withValues(alpha: 0.08),
                      Colors.transparent
                    ]),
                border: const Border(
                    bottom: BorderSide(color: ProfileColors.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        neonGradient.createShader(bounds),
                    child: Text('⬡ Dashboard',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: ProfileColors.glass,
                          shape: BoxShape.circle,
                          border: Border.all(color: ProfileColors.gborder)),
                      child: const Icon(Icons.close,
                          size: 18, color: ProfileColors.textSecondary),
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('requests')
                    .stream(primaryKey: ['id']),
                builder: (context, reqSnap) {
                  final allReqs = reqSnap.data ?? [];
                  final msgCount = allReqs
                      .where((r) =>
                          r['target_id'] == uid &&
                          r['target_type'] == 'message' &&
                          r['status'] == 'pending')
                      .length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_profile?['is_super_admin'] == true) ...[
                        // ── SECTION 4: SYSTEM ADMINISTRATION ──
                        _buildSectionTitle('⚡ SYSTEM ADMIN'),
                        _buildDashItem(
                            Icons.admin_panel_settings,
                            'red',
                            'Super Admin Panel',
                            'Supreme power over the Relaya ecosystem',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminDashboardScreen()))),
                        const SizedBox(height: 30),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashItem(
      IconData icon, String colorName, String title, String desc,
      {String? badge, VoidCallback? onTap}) {
    Color getBaseColor() {
      switch (colorName) {
        case 'amber':
          return ProfileColors.cyan;
        case 'coral':
          return ProfileColors.pink;
        case 'violet':
          return ProfileColors.purple;
        case 'blue':
          return ProfileColors.blue;
        case 'green':
          return ProfileColors.green;
        case 'pink':
          return ProfileColors.pink;
        case 'teal':
          return ProfileColors.teal;
        case 'red':
          return ProfileColors.red;
        default:
          return ProfileColors.textMuted;
      }
    }

    Color c = getBaseColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ProfileColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ProfileColors.gborder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [
                  c.withValues(alpha: 0.2),
                  c.withValues(alpha: 0.05)
                ]),
                border: Border.all(color: c.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ProfileColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: ProfileColors.textMuted),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: ProfileColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(badge,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ProfileColors.red)),
              ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: ProfileColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double)
      await prefs.setDouble(key, value);
    else if (value is String)
      await prefs.setString(key, value);
    else if (value is int) await prefs.setInt(key, value);
  }

  void _showBottomSlider(
      {required String title,
      required String subtitle,
      required Widget slider,
      required VoidCallback onSave}) {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : ProfileColors.bgSecondary,
      shape: doodle
          ? null
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: doodle
                    ? DoodleFonts.heading(
                        color: DoodleColors.brown, fontSize: 24)
                    : GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ProfileColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: doodle
                    ? DoodleFonts.body(
                        color: DoodleColors.brown.withValues(alpha: 0.7),
                        fontSize: 14)
                    : GoogleFonts.inter(
                        fontSize: 13, color: ProfileColors.textMuted)),
            const SizedBox(height: 32),
            slider,
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                onSave();
                Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: doodle
                    ? DoodleDecorations.card(color: DoodleColors.orange)
                        .copyWith(borderRadius: BorderRadius.circular(12))
                    : BoxDecoration(
                        gradient: mainGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                            BoxShadow(
                                color:
                                    ProfileColors.cyan.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]),
                child: Center(
                    child: Text('Save Changes',
                        style: doodle
                            ? DoodleFonts.body(
                                    color: DoodleColors.cream, fontSize: 18)
                                .copyWith(fontWeight: FontWeight.bold)
                            : GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchRadiusSheet() {
    double tempVal = _matchRadius;
    final doodle = isDoodleMode(context);
    _showBottomSlider(
      title: 'Match Radius',
      subtitle: 'Set the maximum distance for potential matches.',
      slider: StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          children: [
            Text('${tempVal.toInt()} km',
                style: doodle
                    ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 26)
                        .copyWith(fontWeight: FontWeight.bold)
                    : GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ProfileColors.cyan)),
            SliderTheme(
              data: doodle
                  ? SliderThemeData(
                      activeTrackColor: DoodleColors.blue,
                      inactiveTrackColor: DoodleColors.paper,
                      thumbColor: DoodleColors.orange,
                      overlayColor: DoodleColors.orange.withValues(alpha: 0.2),
                    )
                  : SliderTheme.of(context),
              child: Slider(
                value: tempVal,
                min: 1,
                max: 200,
                divisions: 199,
                activeColor: doodle ? null : ProfileColors.cyan,
                inactiveColor:
                    doodle ? null : ProfileColors.cyan.withValues(alpha: 0.2),
                onChanged: (v) => setSheetState(() => tempVal = v),
              ),
            ),
          ],
        );
      }),
      onSave: () {
        setState(() => _matchRadius = tempVal);
        _saveSetting('discovery_radius', tempVal);
      },
    );
  }

  void _showAgePrefSheet() {
    double tempMin = _ageMin;
    double tempMax = _ageMax;
    final doodle = isDoodleMode(context);
    _showBottomSlider(
      title: 'Age Preference',
      subtitle: 'Select the age range of people you want to see.',
      slider: StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          children: [
            Text('${tempMin.toInt()} - ${tempMax.toInt()} years old',
                style: doodle
                    ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 22)
                        .copyWith(fontWeight: FontWeight.bold)
                    : GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ProfileColors.cyan)),
            SliderTheme(
              data: doodle
                  ? SliderThemeData(
                      activeTrackColor: DoodleColors.blue,
                      inactiveTrackColor: DoodleColors.paper,
                      thumbColor: DoodleColors.orange,
                      overlayColor: DoodleColors.orange.withValues(alpha: 0.2),
                    )
                  : SliderTheme.of(context),
              child: RangeSlider(
                values: RangeValues(tempMin, tempMax),
                min: 18,
                max: 99,
                divisions: 81,
                activeColor: doodle ? null : ProfileColors.cyan,
                inactiveColor:
                    doodle ? null : ProfileColors.cyan.withValues(alpha: 0.2),
                onChanged: (v) => setSheetState(() {
                  tempMin = v.start;
                  tempMax = v.end;
                }),
              ),
            ),
          ],
        );
      }),
      onSave: () {
        setState(() {
          _ageMin = tempMin;
          _ageMax = tempMax;
        });
        _saveSetting('age_range_min', tempMin);
        _saveSetting('age_range_max', tempMax);
      },
    );
  }

  String _getVibeVisibilitySummary() {
    final vibes = (_profile?['visible_vibes'] as List?)?.cast<String>() ?? [];
    if (vibes.isEmpty) return 'All Sections';
    if (vibes.length <= 2) return vibes.join(', ');
    return '${vibes.length} selected';
  }

  void _showVibeVisibilitySheet() {
    final currentVibes = Set<String>.from(
      (_profile?['visible_vibes'] as List?)?.cast<String>() ?? [],
    );

    const allVibes = [
      {'icon': '📚', 'label': 'Study', 'c1': 0xFF0F0C29, 'c2': 0xFF302B63},
      {'icon': '💪', 'label': 'Fitness', 'c1': 0xFF1A0000, 'c2': 0xFF7F1D1D},
      {'icon': '🎵', 'label': 'Music', 'c1': 0xFF150020, 'c2': 0xFF5B21B6},
      {'icon': '🚀', 'label': 'Startup', 'c1': 0xFF030C1A, 'c2': 0xFF1E3A8A},
      {'icon': '✈️', 'label': 'Travel', 'c1': 0xFF022C22, 'c2': 0xFF064E3B},
      {'icon': '🎮', 'label': 'Gaming', 'c1': 0xFF0D0028, 'c2': 0xFF3B0764},
      {
        'icon': '📸',
        'label': 'Photography',
        'c1': 0xFF1A0E00,
        'c2': 0xFF78350F
      },
      {'icon': '🍳', 'label': 'Cooking', 'c1': 0xFF1A0500, 'c2': 0xFF7C2D12},
      {'icon': '🎤', 'label': 'Perform', 'c1': 0xFF022C22, 'c2': 0xFF065F46},
      {'icon': '🤖', 'label': 'Tech & AI', 'c1': 0xFF001A25, 'c2': 0xFF082F49},
      {'icon': '❤️', 'label': 'Dating', 'c1': 0xFF2D0018, 'c2': 0xFF831843},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: ProfileColors.bgSecondary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: ProfileColors.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: ProfileColors.textMuted,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  Text('Explore Visibility',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: ProfileColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    'Choose which sections your profile appears in. Empty = visible everywhere.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ProfileColors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: allVibes.map((v) {
                          final label = v['label'] as String;
                          final icon = v['icon'] as String;
                          final active = currentVibes.contains(label);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (active) {
                                  currentVibes.remove(label);
                                } else {
                                  currentVibes.add(label);
                                }
                              });
                            },
                            child: Container(
                              width: (MediaQuery.of(ctx).size.width - 60) / 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: active
                                    ? LinearGradient(colors: [
                                        Color(v['c1'] as int),
                                        Color(v['c2'] as int)
                                      ])
                                    : null,
                                color: active ? null : ProfileColors.bgTertiary,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: active
                                        ? ProfileColors.cyan
                                            .withValues(alpha: 0.5)
                                        : ProfileColors.borderSubtle,
                                    width: active ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Text(icon,
                                      style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(label,
                                          style: GoogleFonts.inter(
                                              color: active
                                                  ? Colors.white
                                                  : ProfileColors.textSecondary,
                                              fontSize: 13,
                                              fontWeight: active
                                                  ? FontWeight.w700
                                                  : FontWeight.w500))),
                                  if (active)
                                    const Icon(Icons.check_circle,
                                        color: ProfileColors.cyan, size: 18),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (_myUid.isNotEmpty) {
                        await Supabase.instance.client.from('profiles').update({
                          'visible_vibes': currentVibes.toList(),
                        }).eq('id', _myUid);
                        _loadProfile(); // Refresh
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [ProfileColors.cyan, ProfileColors.purple]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text('Apply',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============== BOLROOM ANONYMITY SHEETS ==============
  Future<void> _goToEditProfile() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditProfileScreen(initialProfile: _profile ?? {})));
    if (result == true) {
      _loadProfile();
    }
  }

  void _showChangePasswordSheet() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    String? errorText;

    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Password',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: currentPasswordCtrl,
                  obscureText: obscureCurrent,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Current Password',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: ProfileColors.glass,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setSheetState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'New Password',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: ProfileColors.glass,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: ProfileColors.red, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierDismissible: true,
                          barrierColor: Colors.black87,
                          pageBuilder: (_, __, ___) => const ForgotPasswordFlow(),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                        ),
                      );
                    },
                    child: const Text('Forgot Password?', style: TextStyle(color: ProfileColors.cyan, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ProfileColors.cyan,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving ? null : () async {
                      final currentPw = currentPasswordCtrl.text.trim();
                      final newPw = newPasswordCtrl.text.trim();
                      if (currentPw.isEmpty || newPw.isEmpty) {
                        setSheetState(() => errorText = "Please fill out both fields.");
                        return;
                      }
                      setSheetState(() { isSaving = true; errorText = null; });
                      
                      try {
                        final email = Supabase.instance.client.auth.currentUser?.email;
                        if (email == null) throw Exception("No email found for current user.");
                        
                        await Supabase.instance.client.auth.signInWithPassword(
                          email: email,
                          password: currentPw,
                        );
                        
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPw),
                        );
                        
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Password updated successfully.'),
                          backgroundColor: ProfileColors.green,
                        ));
                      } on AuthException catch (e) {
                        setSheetState(() {
                          isSaving = false;
                          errorText = e.message;
                        });
                      } catch (e) {
                        setSheetState(() {
                          isSaving = false;
                          errorText = e.toString();
                        });
                      }
                    },
                    child: isSaving 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Save',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        });
      },
    );
  }

  void _showDeleteAccountSheet() {
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    bool isDeleting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ProfileColors.red.withValues(alpha: 0.15),
                      ),
                      child: const Icon(Icons.delete_forever,
                          color: ProfileColors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delete Account',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ProfileColors.red)),
                        Text('This action is permanent and irreversible.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: ProfileColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ProfileColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: ProfileColors.red.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'Deleting your account will permanently remove all your data including your profile, photos, messages, and matches. This cannot be undone.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ProfileColors.textSecondary,
                        height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Enter your password to confirm',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ProfileColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: ProfileColors.glass,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: ProfileColors.red.withValues(alpha: 0.6))),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54),
                      onPressed: () =>
                          setSheetState(() => obscure = !obscure),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!,
                      style: const TextStyle(
                          color: ProfileColors.red, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ProfileColors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isDeleting
                        ? null
                        : () async {
                            final pw = passwordCtrl.text.trim();
                            if (pw.isEmpty) {
                              setSheetState(() =>
                                  errorText = 'Please enter your password.');
                              return;
                            }
                            setSheetState(() {
                              isDeleting = true;
                              errorText = null;
                            });
                            try {
                              final sb = Supabase.instance.client;
                              final email =
                                  sb.auth.currentUser?.email ?? '';
                              if (email.isEmpty)
                                throw Exception('No account email found.');

                              // Step 1: Re-authenticate to verify password
                              await sb.auth.signInWithPassword(
                                  email: email, password: pw);

                              final uid = _myUid;

                              // Step 2: Delete all user data rows
                              await Future.wait([
                                sb.from('profiles').delete().eq('id', uid),
                                sb.from('requests')
                                    .delete()
                                    .or('sender_id.eq.$uid,target_id.eq.$uid'),
                                sb.from('messages')
                                    .delete()
                                    .or('sender_id.eq.$uid,receiver_id.eq.$uid')
                                    .catchError((_) {}),
                              ]);

                              // Step 3: Delete auth user
                              await sb.auth.admin.deleteUser(uid)
                                  .catchError((_) {
                                // admin API may not be available; sign out instead
                              });

                              await sb.auth.signOut();

                              if (!mounted) return;
                              Navigator.of(context, rootNavigator: true)
                                  .pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const AuthScreen()),
                                (route) => false,
                              );
                            } on AuthException catch (e) {
                              setSheetState(() {
                                isDeleting = false;
                                errorText = e.message.contains('Invalid')
                                    ? 'Incorrect password. Please try again.'
                                    : e.message;
                              });
                            } catch (e) {
                              setSheetState(() {
                                isDeleting = false;
                                errorText = e.toString();
                              });
                            }
                          },
                    child: isDeleting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Delete My Account Permanently',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          );
        });
      },
    );
  }

  void _showNavTransitionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileColors.bgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Navigation Style',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ProfileColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Customize how you swipe between pages.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: ProfileColors.textMuted)),
              const SizedBox(height: 24),
              ...['Slide', 'Fade', 'Scale', '3D Flip'].map((style) {
                final isSelected = _navTransition == style;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _navTransition = style);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('nav_transition', style);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Navigation set to $style'),
                          backgroundColor: ProfileColors.cyan,
                          duration: const Duration(seconds: 1)));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: ProfileColors.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSelected
                              ? ProfileColors.cyan
                              : ProfileColors.borderSubtle,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(style,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : ProfileColors.textSecondary)),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: ProfileColors.cyan),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ============== 5. SETTINGS PANEL (RIGHT DRAWER) ==============
  Widget _buildSettingsPanel() {
    return Drawer(
      backgroundColor: ProfileColors.bgSecondary,
      width: MediaQuery.of(context).size.width * 0.88 > 380
          ? 380
          : MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ProfileColors.purple.withValues(alpha: 0.08),
                      Colors.transparent
                    ]),
                border: const Border(
                    bottom: BorderSide(color: ProfileColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: ProfileColors.glass,
                          shape: BoxShape.circle,
                          border: Border.all(color: ProfileColors.gborder)),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: ProfileColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Settings',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ProfileColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildSectionTitle('Account'),
                  _buildSettingsRow(
                      Icons.person_outline, 'Personal Information',
                      hasArrow: true, onTap: _goToEditProfile),
                  _buildSettingsRow(Icons.lock_outline, 'Change Password',
                      hasArrow: true, onTap: _showChangePasswordSheet),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Preferences'),
                  _buildSettingsRow(
                      Icons.notifications_none, 'Push Notifications',
                      toggleValue: _pushNotifications, onToggle: (v) {
                    setState(() => _pushNotifications = v);
                    _saveSetting('push_notifications', v);
                  }),
                  _buildSettingsRow(
                      Icons.light_mode_outlined, 'Light Mode',
                      hasArrow: false, onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Light mode will be available in future updates.'),
                        backgroundColor: ProfileColors.cyan));
                  }),
                  _buildSettingsRow(
                      Icons.swipe_outlined, 'Navigation Transition',
                      valueText: _navTransition,
                      valueColor: ProfileColors.cyan,
                      hasArrow: true,
                      onTap: _showNavTransitionSheet),
                  // Discovery Location — unified search picker (opens real search sheet)
                  ValueListenableBuilder<String>(
                      valueListenable: locationService.activeLocationNotifier,
                      builder: (context, activeLoc, _) {
                        return _buildSettingsRow(
                          Icons.explore_outlined,
                          'Discovery Location',
                          valueText:
                              activeLoc.isEmpty ? 'Tap to set' : activeLoc,
                          valueColor: const Color(0xFFFF6B00),
                          hasArrow: true,
                          onTap: () => showLocationSearchSheet(context),
                        );
                      }),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Privacy'),
                  _buildSettingsRow(Icons.block, 'Blocked Accounts',
                      hasArrow: true, onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BlockedUsersScreen(myUid: _myUid)));
                  }),
                  const SizedBox(height: 24),


                  _buildSectionTitle('Support & About'),
                  _buildSettingsRow(Icons.help_outline, 'Help Center',
                      hasArrow: true),
                  _buildSettingsRow(
                      Icons.report_problem_outlined, 'Report a Problem',
                      hasArrow: true),
                  _buildSettingsRow(Icons.article_outlined, 'Privacy Policy',
                      hasArrow: true),
                  _buildSettingsRow(Icons.gavel_outlined, 'Terms of Service',
                      hasArrow: true),
                  _buildSettingsRow(Icons.info_outline, 'App Version',
                      valueText: 'v3.2.1', hasArrow: false),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Danger Zone'),
                  _buildSettingsRow(Icons.logout, 'Log Out',
                      isDanger: true, onTap: _onLogout),
                  _buildSettingsRow(Icons.delete_forever, 'Delete Account',
                      isDanger: true, onTap: _showDeleteAccountSheet),

                  const SizedBox(height: 32),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4, top: 12),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: ProfileColors.cyan,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ProfileColors.textMuted,
                  letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title,
      {String? valueText,
      Color? valueColor,
      bool hasArrow = false,
      bool isDanger = false,
      bool? toggleValue,
      ValueChanged<bool>? onToggle,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTap != null) onTap();
        if (onToggle != null && toggleValue != null) onToggle(!toggleValue);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDanger
              ? ProfileColors.red.withValues(alpha: 0.05)
              : ProfileColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDanger
                  ? ProfileColors.red.withValues(alpha: 0.15)
                  : ProfileColors.gborder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDanger
                    ? ProfileColors.red.withValues(alpha: 0.1)
                    : ProfileColors.cyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 18,
                  color: isDanger
                      ? ProfileColors.red
                      : ProfileColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDanger
                          ? ProfileColors.red
                          : ProfileColors.textPrimary)),
            ),
            const SizedBox(width: 12),
            if (valueText != null)
              Flexible(
                child: Text(
                  valueText,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? ProfileColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            if (valueText != null && hasArrow) const SizedBox(width: 8),
            if (toggleValue != null)
              SizedBox(
                height: 24,
                child: Switch(
                  value: toggleValue,
                  onChanged: onToggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFFFF6B00), // Brand orange
                  inactiveThumbColor: ProfileColors.textMuted,
                  inactiveTrackColor: Colors.white10,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else if (hasArrow)
              Icon(Icons.arrow_forward_ios,
                  size: 14,
                  color: ProfileColors.textMuted.withValues(alpha: 0.5)),
          ],
        ),
      ).animate(target: 1).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.02, 1.02),
          duration: 200.ms,
          curve: Curves.easeOutBack),
    );
  }

  void _showPhotoPreview(BuildContext ctx, String avatarUrl, String initial) {
    showDialog(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: Center(
              child: ClipOval(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: avatarUrl.isNotEmpty
                      ? Image(
                          image: _buildSafeImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _fallbackAvatarCenterText(initial))
                      : _fallbackAvatarCenterText(initial),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatarCenterText(String initial) {
    return Container(
      color: DoodleColors.pastelPeach,
      child: Center(
        child: Text(initial,
            style:
                DoodleFonts.heading(fontSize: 90, color: DoodleColors.orange)),
      ),
    );
  }
}

// ----------------------------------------------------
// Animated Ambient Background Orbs
// ----------------------------------------------------
class _AmbientOrbPainter extends CustomPainter {
  final double progress;
  _AmbientOrbPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    final p = Curves.easeInOut.transform(progress);

    // Orb 1: Cyan top-right
    paint.color = ProfileColors.cyan.withValues(alpha: 0.15);
    canvas.drawCircle(
      Offset(size.width * 0.8 - (p * 40), size.height * 0.2 + (p * 50)),
      120,
      paint,
    );

    // Orb 2: Purple bottom-left
    paint.color = ProfileColors.purple.withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(size.width * 0.2 + (p * 50), size.height * 0.7 - (p * 40)),
      150,
      paint,
    );

    // Orb 3: Pink mid-right
    paint.color = ProfileColors.pink.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.6 + (p * 30), size.height * 0.5 + (p * 60)),
      100,
      paint,
    );
  }

  @override
  bool shouldRepaint(_AmbientOrbPainter old) => old.progress != progress;
}

// =============================================================================
// MINI-MAP LOCATION PICKER (SETTINGS)
// =============================================================================
class LocationMapPickerSheet extends StatefulWidget {
  final Function(String name, double lat, double lng) onLocationSelected;

  const LocationMapPickerSheet({super.key, required this.onLocationSelected});

  @override
  State<LocationMapPickerSheet> createState() => _LocationMapPickerSheetState();
}

class _LocationMapPickerSheetState extends State<LocationMapPickerSheet> {
  MapController? _googleMapController;
  final TextEditingController _searchCtrl = TextEditingController();

  LatLng _selectedPoint = const LatLng(0, 0); // Default, updated on init
  bool _isMapDarkMode = true;
  bool _isResolving = false;
  String _resolvedName = '';

  List<dynamic> _searchResults = [];
  Timer? _debounce;
  bool _fetchingGps = false;

  @override
  void initState() {
    super.initState();
    // Initialize map point to current active location if it exists
    final currentLat = locationService.activeLat;
    final currentLng = locationService.activeLng;
    if (currentLat != null && currentLng != null) {
      _selectedPoint = LatLng(currentLat, currentLng);
      _resolvedName = locationService.activeLocation;
    } else {
      _fetchLiveGps();
    }
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveGps() async {
    setState(() => _fetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _fetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.location_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Please enable location services'))
            ]),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _fetchingGps = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.not_listed_location, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Location permission denied'))
              ]),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _fetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.settings, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                  child:
                      Text('Location permanently denied. Enable in settings.'))
            ]),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => Geolocator.openAppSettings()),
          ));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15)));

      if (mounted) {
        setState(() {
          _selectedPoint = LatLng(position.latitude, position.longitude);
          _fetchingGps = false;
        });
        _googleMapController?.animateToLatLng(_selectedPoint, zoom: 14.0);
        _reverseGeocode(_selectedPoint);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
                'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}')
          ]),
          backgroundColor: ProfileColors.cyan,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Could not get location: $e'))
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _searchPlace(val));
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final proxyUrl =
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1')}';
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data
                .map((it) => {
                      'name':
                          it['display_name'].toString().split(',').first.trim(),
                      'full_name': it['display_name'].toString(),
                      'lat': double.parse(it['lat']),
                      'lng': double.parse(it['lon']),
                    })
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final pt = LatLng(result['lat'], result['lng']);
    setState(() {
      _selectedPoint = pt;
      _searchResults = [];
      _searchCtrl.text = '';
      _resolvedName = result['name'];
    });
    _googleMapController?.animateToLatLng(pt, zoom: 14);
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _searchResults = [];
    });
    _googleMapController?.animateToLatLng(point, zoom: 14);
    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _isResolving = true);
    try {
      final res = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${p.latitude}&lon=${p.longitude}&zoom=14&addressdetails=1'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          final address = data['address'] ?? {};
          final landmark = data['name'] ??
              address['amenity'] ??
              address['building'] ??
              address['historic'] ??
              address['leisure'];
          final display = landmark ?? (data['display_name'] ?? '');
          setState(() {
            _resolvedName = display.toString().split(',').first;
            _isResolving = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: ProfileColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: ProfileColors.borderSubtle))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Location',
                        style: GoogleFonts.playfairDisplay(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Choose where you want to discover.',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 13)),
                  ],
                ),
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: ProfileColors.bgCard,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white54, size: 18))),
              ],
            ),
          ),

          // Map Canvas
          Expanded(
            child: Stack(
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(_isMapDarkMode
                      ? [
                          -1.0,
                          0.0,
                          0.0,
                          0.0,
                          255.0,
                          0.0,
                          -1.0,
                          0.0,
                          0.0,
                          255.0,
                          0.0,
                          0.0,
                          -1.0,
                          0.0,
                          255.0,
                          0.0,
                          0.0,
                          0.0,
                          1.0,
                          0.0,
                        ]
                      : [
                          1.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          1.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          1.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          0.0,
                          1.0,
                          0.0,
                        ]),
                  child: AppMapView(
                    onMapReady: (c) => _googleMapController = c,
                    initialCenter: _selectedPoint,
                    initialZoom: 14.0,
                    myLocationEnabled: true,
                    onTap: _onMapTap,
                    markers: [
                      SimpleMarker(
                        id: 'selected',
                        position: _selectedPoint,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
                if (_isMapDarkMode)
                  Container(
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.1)),

                // Search Input
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10)),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                  hintText: 'Search city or landmark...',
                                  hintStyle: TextStyle(
                                      color: Colors.white54, fontSize: 14),
                                  border: InputBorder.none,
                                  icon: Icon(Icons.search,
                                      color: ProfileColors.amber, size: 20)),
                            ),
                          ),
                        ),
                      ),
                      // Search Results
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: ProfileColors.amber
                                      .withValues(alpha: 0.3))),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (ctx, i) {
                              final r = _searchResults[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined,
                                    color: ProfileColors.amber, size: 16),
                                title: Text(r['name'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(r['full_name'],
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () => _selectSearchResult(r),
                              );
                            },
                          ),
                        )
                    ],
                  ),
                ),

                // Action Buttons Right Side (Day/Night & GPS)
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _isMapDarkMode = !_isMapDarkMode),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10)),
                          child: Icon(
                              _isMapDarkMode
                                  ? Icons.wb_sunny
                                  : Icons.nightlight_round,
                              color: _isMapDarkMode
                                  ? Colors.yellow
                                  : ProfileColors.amber,
                              size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _fetchLiveGps,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: ProfileColors.amber,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: ProfileColors.amber
                                        .withValues(alpha: 0.4),
                                    blurRadius: 12)
                              ]),
                          child: _fetchingGps
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                      color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.my_location,
                                  color: Colors.black, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar (Save Location)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: ProfileColors.bgPrimary,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Selected Base',
                          style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _isResolving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: ProfileColors.amber))
                          : Text(
                              _resolvedName.isEmpty ? 'Tap map' : _resolvedName,
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    if (_resolvedName.isEmpty) return;
                    widget.onLocationSelected(_resolvedName,
                        _selectedPoint.latitude, _selectedPoint.longitude);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: _resolvedName.isEmpty
                          ? Colors.white12
                          : ProfileColors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Confirm',
                        style: GoogleFonts.inter(
                            color: _resolvedName.isEmpty
                                ? Colors.white38
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BLOCKED USERS SCREEN
// ═══════════════════════════════════════════════════════════════════

class BlockedUsersScreen extends StatefulWidget {
  final String myUid;
  const BlockedUsersScreen({super.key, required this.myUid});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    setState(() => _loading = true);
    try {
      // Fetch rows where I am the blocker (sender) and target_type = 'block'
      final rows = await Supabase.instance.client
          .from('requests')
          .select('target_id, created_at, profiles!requests_target_id_fkey(id, name, username, profile_image_url)')
          .eq('sender_id', widget.myUid)
          .eq('target_type', 'block');
      setState(() {
        _blocked = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      // Fallback: try without join
      try {
        final rows = await Supabase.instance.client
            .from('requests')
            .select('target_id, created_at')
            .eq('sender_id', widget.myUid)
            .eq('target_type', 'block');
        // Fetch profiles separately
        final targetIds = (rows as List).map((r) => r['target_id'] as String).toList();
        List<Map<String, dynamic>> enriched = [];
        for (final id in targetIds) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('id, name, username, profile_image_url')
              .eq('id', id)
              .maybeSingle();
          if (profile != null) enriched.add(profile);
        }
        setState(() {
          _blocked = enriched;
          _loading = false;
        });
      } catch (e) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unblock(String targetId) async {
    await Supabase.instance.client
        .from('requests')
        .delete()
        .eq('sender_id', widget.myUid)
        .eq('target_id', targetId)
        .eq('target_type', 'block');
    await _loadBlocked();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User unblocked.'),
          backgroundColor: Color(0xFF22C55E)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ProfileColors.bgSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Blocked Accounts',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: ProfileColors.borderSubtle)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ProfileColors.cyan))
          : _blocked.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _blocked.length,
                  itemBuilder: (ctx, i) => _buildBlockedCard(_blocked[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ProfileColors.glass,
              border: Border.all(color: ProfileColors.borderSubtle),
            ),
            child: const Icon(Icons.block, size: 36, color: ProfileColors.textMuted),
          ),
          const SizedBox(height: 20),
          Text('No blocked accounts',
              style: GoogleFonts.inter(
                  color: ProfileColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text("Users you block won't appear in your feed\nand can't contact you.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: ProfileColors.textMuted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBlockedCard(Map<String, dynamic> item) {
    // item may be the joined profile or just a profile map
    final profile = item['profiles'] as Map<String, dynamic>? ?? item;
    final name = profile['name'] ?? profile['username'] ?? 'Unknown User';
    final username = profile['username'] ?? '';
    final avatar = profile['profile_image_url'] ?? '';
    final targetId = profile['id'] ?? item['target_id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ProfileColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfileColors.borderSubtle),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: ProfileColors.glass,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        title: Text(name,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        subtitle: username.isNotEmpty
            ? Text('@$username',
                style: GoogleFonts.inter(
                    color: ProfileColors.textMuted, fontSize: 13))
            : null,
        trailing: GestureDetector(
          onTap: () => _showUnblockDialog(targetId, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ProfileColors.red.withValues(alpha: 0.6)),
              color: ProfileColors.red.withValues(alpha: 0.12),
            ),
            child: Text('Unblock',
                style: GoogleFonts.inter(
                    color: ProfileColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15, end: 0);
  }

  void _showUnblockDialog(String targetId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ProfileColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unblock $name?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            '$name will be able to see your profile and contact you again.',
            style: const TextStyle(color: ProfileColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: ProfileColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unblock(targetId);
            },
            child: const Text('Unblock',
                style: TextStyle(
                    color: ProfileColors.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
