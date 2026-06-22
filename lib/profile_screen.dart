// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: unused_field, unused_element
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'services/theme_service.dart';
import 'services/location_service.dart';

import 'widgets/location_picker_sheet.dart';
// import 'follow_list_screen.dart'; // removed unused
import 'auth_screen.dart';
import 'dashboard_detail_screens.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'admin_dashboard_screen.dart';
import 'widgets/skeleton_loaders.dart';
import 'hosted_joined_screens.dart';
import 'services/doodle_theme.dart';

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
  static const amber = Color(0xFFF4A926); // kept for backward compat in dashboard
  static const coral = Color(0xFFE8735A); // kept for backward compat in dashboard
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

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Logic Variables
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;
  List<Map<String, dynamic>> _userPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  late AnimationController _orbController;
  final String _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
  int _activeTabIndex = 0; // 0=Grid, 1=Reels, 2=Experiences, 3=Tagged

  // Settings State Variables
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _locationServices = true;
  bool _ghostMode = false;
  bool _sparkNotifications = true;
  bool _autoMatchSpark = false;
  bool _saveToCameraRoll = false;
  double _matchRadius = 15.0;
  bool _isGlobal = false;
  double _ageMin = 21.0;
  double _ageMax = 35.0;
  String _mediaQuality = 'High';
  String _mapsApp = 'Google Maps';
  bool _isPublic = true;
  String _navTransition = 'Slide';

  // BolRoom Anonymity
  bool _bolroomAnonymous = false;
  String _bolroomAnonName = 'Anonymous';
  String _bolroomAnonAvatar = '';

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _loadProfile();
    _loadBolRoomAnonSettings();
  }

  Future<void> _loadBolRoomAnonSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bolroomAnonymous = prefs.getBool('bolroom_anonymous') ?? false;
        _bolroomAnonName = prefs.getString('bolroom_anon_name') ?? 'Anonymous';
        _bolroomAnonAvatar = prefs.getString('bolroom_anon_avatar') ?? '';
      });
    }
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

      final pRes = await Supabase.instance.client.from('profiles').select().eq('id', uid).maybeSingle();
      final followersReq = await Supabase.instance.client.from('requests').select('id').eq('target_id', uid).eq('target_type', 'follow').eq('status', 'approved');
      final followingReq = await Supabase.instance.client.from('requests').select('id').eq('sender_id', uid).eq('target_type', 'follow').eq('status', 'approved');
      final postsRes = await Supabase.instance.client.from('posts').select().eq('user_id', uid).order('created_at', ascending: false);
      
      bool isFollowing = false;
      if (widget.userId != null && widget.userId != _myUid) {
        final check = await Supabase.instance.client.from('requests').select('id').eq('sender_id', _myUid).eq('target_id', uid).eq('target_type', 'follow').maybeSingle();
        isFollowing = check != null;
      }
      
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _profile = pRes;
          _followersCount = followersReq.length;
          _followingCount = followingReq.length;
          _userPosts = List<Map<String, dynamic>>.from(postsRes);
          _isFollowing = isFollowing;
          _isPublic = _profile?['is_public'] ?? true;
          
          _pushNotifications = prefs.getBool('push_notifications') ?? true;
          _emailNotifications = prefs.getBool('email_notifications') ?? true;
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
          _mapsApp = prefs.getString('maps_app') ?? 'Google Maps';
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
        await Supabase.instance.client.from('requests').delete().eq('sender_id', _myUid).eq('target_id', uid).eq('target_type', 'follow');
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
      return const NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop');
    }
    if (urlStr.startsWith('http')) return NetworkImage(urlStr);
    try {
      final base64Str = urlStr.contains(',') ? urlStr.split(',').last : urlStr;
      return MemoryImage(base64Decode(base64Str));
    } catch (_) {
      return const NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop');
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
      MaterialPageRoute(builder: (_) => EditProfileScreen(initialProfile: _profile ?? {})),
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
  }  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: doodle ? DoodleColors.cream : ProfileColors.bgPrimary,
        body: SafeArea(child: SkeletonLoaders.genericListSkeleton(doodle: isDoodleMode(context))),
      );
    }

    final p = _profile ?? {};
    final isMe = widget.userId == null || widget.userId == _myUid;
    final name = p['name'] ?? p['full_name'] ?? 'User';
    final username = p['username'] ?? name.replaceAll(' ', '.').toLowerCase();
    final bio = p['bio'] ?? '"Chasing sunsets & stories \u2728"';
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
          if (doodle) Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Container(decoration: DoodleDecorations.parchmentBg()),
                  CustomPaint(painter: ScatteredDoodlesPainter(seed: 99, density: 0.3, color: const Color(0x18B8956E))),
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
                        _buildHeroSection(name, username, bio, location, avatarUrl, isMe),
                        _buildPostsTabs(),
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
          border: Border(bottom: BorderSide(color: DoodleColors.cardBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isMe)
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: DoodleColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DoodleColors.cardBorder),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: DoodleColors.textSecondary, size: 18),
                ),
              )
            else
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: DoodleColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DoodleColors.cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: DoodleColors.textSecondary, size: 18),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: DoodleDecorations.card(color: DoodleColors.orange),
              child: Text(
                'MY PROFILE',
                style: DoodleFonts.heading(fontSize: 20, color: DoodleColors.brown),
              ),
            ),
            if (isMe)
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: DoodleColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DoodleColors.cardBorder),
                  ),
                  child: const Icon(Icons.settings_outlined, color: DoodleColors.textSecondary, size: 18),
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
            border: Border(bottom: BorderSide(color: ProfileColors.borderSubtle, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isMe)
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: _buildNavIconBtn(Icons.grid_view_rounded, hasBadge: true),
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
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: ProfileColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileColors.cyan.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: ProfileColors.cyan.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: ProfileColors.textSecondary, size: 18),
          if (hasBadge)
            Positioned(
              top: 7, right: 7,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [ProfileColors.pink, ProfileColors.orange]),
                  border: Border.all(color: ProfileColors.bgPrimary, width: 1.5),
                  boxShadow: [BoxShadow(color: ProfileColors.pink.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.3, 1.3)).fade(end: 0.5),
            ),
        ],
      ),
    );
  }

  // ============== 2. PROFILE HERO ==============
  Widget _buildHeroSection(String name, String username, String bio, String location, String avatarUrl, bool isMe) {
    final doodle = isDoodleMode(context);
    String initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
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
                    child: CustomPaint(
                      painter: SketchCirclePainter(color: DoodleColors.orange, strokeWidth: 3),
                      child: Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: 96, height: 96,
                            child: avatarUrl.isNotEmpty
                              ? Image(image: _buildSafeImageProvider(avatarUrl), fit: BoxFit.cover)
                              : Container(
                                  color: DoodleColors.pastelPeach,
                                  child: Center(
                                    child: Text(initials, style: DoodleFonts.heading(fontSize: 32, color: DoodleColors.orange)),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
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
                          backgroundImage: _buildSafeImageProvider(avatarUrl),
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
              const SizedBox(height: 16),

              // 2. Centered Name
              Text(
                name,
                style: doodle ? DoodleFonts.heading(fontSize: 28, color: DoodleColors.brown) : GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),

              // 3. Centered Username
              Text(
                '@${username.toLowerCase()}',
                style: doodle ? DoodleFonts.body(fontSize: 16, color: DoodleColors.brown) : GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // 4. Centered Location with Pin Icon
              ValueListenableBuilder<String>(
                valueListenable: locationService.activeLocationNotifier,
                builder: (context, activeLoc, _) {
                  final displayLoc = (activeLoc.isNotEmpty && isMe) ? activeLoc : location;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: doodle ? DoodleColors.brown : const Color(0xFFFF6B00),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayLoc.isEmpty ? 'New York, NY' : displayLoc,
                        style: doodle ? DoodleFonts.body(fontSize: 14, color: DoodleColors.brown.withValues(alpha: 0.8)) : GoogleFonts.inter(
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
                  bio.isEmpty ? 'Adventure seeker | Event host | Music lover' : bio,
                  textAlign: TextAlign.center,
                  style: doodle ? DoodleFonts.body(fontSize: 14, color: DoodleColors.brown) : GoogleFonts.inter(
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
                onTap: isMe ? _onEditProfile : () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isMe ? 'Edit Profile' : 'Message',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 7. Large Centered Stats Card Container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: doodle
                  ? DoodleDecorations.card(color: DoodleColors.cream, borderColor: DoodleColors.brown)
                  : BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNewStatColumn(
                      icon: Icons.flash_on,
                      val: '24',
                      label: 'RUSH-INS',
                      iconColor: const Color(0xFFFF6B00),
                    ),
                    _buildNewStatColumn(
                      icon: Icons.calendar_today_outlined,
                      val: '18',
                      label: 'ACTIVITIES',
                      iconColor: const Color(0xFF4E8BFF),
                    ),
                    _buildNewStatColumn(
                      icon: Icons.people_outline,
                      val: '156',
                      label: 'CONNECTIONS',
                      iconColor: const Color(0xFFFFD54F),
                    ),
                    _buildNewStatColumn(
                      icon: Icons.emoji_events_outlined,
                      val: '98%',
                      label: 'RELIABILITY',
                      iconColor: const Color(0xFFFF8A00),
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
  }) {
    final doodle = isDoodleMode(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: doodle ? DoodleColors.brown : iconColor, size: 18),
          const SizedBox(height: 6),
          Text(
            val,
            style: doodle ? DoodleFonts.heading(fontSize: 20, color: DoodleColors.brown) : GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: doodle ? DoodleFonts.body(fontSize: 10, color: DoodleColors.brown) : GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white38,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String val, String label, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
            Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: ProfileColors.textMuted, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // ============== 3. POSTS LAYOUT ==============
  Widget _buildPostsTabs() {
    final doodle = isDoodleMode(context);
    if (doodle) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.all(4),
        decoration: DoodleDecorations.card(color: DoodleColors.amber.withValues(alpha: 0.3)),
        child: Row(
          children: [
            _buildTabBtn(0, 'GRID'),
            _buildTabBtn(1, 'REELS'),
            _buildTabBtn(2, 'VIBES'),
            _buildTabBtn(3, 'TAGGED'),
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
          _buildTabBtn(1, 'REELS'),
          _buildTabBtn(2, 'VIBES'),
          _buildTabBtn(3, 'TAGGED'),
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
            decoration: active ? DoodleDecorations.card(color: DoodleColors.orange, radius: 4) : null,
            child: Text(title, style: DoodleFonts.heading(fontSize: 14, color: active ? DoodleColors.brown : DoodleColors.brown.withValues(alpha: 0.5))),
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
            border: active ? const Border(bottom: BorderSide(color: ProfileColors.cyan, width: 2)) : null,
          ),
          child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: active ? ProfileColors.cyan : ProfileColors.textMuted)),
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
            const Icon(Icons.lock_outline, size: 48, color: ProfileColors.textMuted),
            const SizedBox(height: 16),
            Text('Private Account', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("Follow this user to see their content.", style: GoogleFonts.inter(color: ProfileColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    
    if (_activeTabIndex != 0) {
      // Empty state for Reels, Experiencs, Tagged
      return Container(
        padding: const EdgeInsets.all(60),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ProfileColors.borderLight, width: 2)),
              child: const Icon(Icons.filter_none, color: ProfileColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text('No Content Yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_userPosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(60),
        alignment: Alignment.center,
        child: Text('No posts yet', style: GoogleFonts.inter(color: ProfileColors.textMuted, fontSize: 14)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
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
              child: (img != null && img.isNotEmpty) ? Image(image: provider, fit: BoxFit.cover) : Center(
                child: Text(post['content'] ?? '', maxLines: 2, style: const TextStyle(fontSize: 10, color: Colors.white54), textAlign: TextAlign.center),
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
      width: MediaQuery.of(context).size.width * 0.88 > 380 ? 380 : MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ProfileColors.cyan.withValues(alpha: 0.08), Colors.transparent]),
                border: const Border(bottom: BorderSide(color: ProfileColors.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => neonGradient.createShader(bounds),
                    child: Text('⬡ Dashboard', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: ProfileColors.glass, shape: BoxShape.circle, border: Border.all(color: ProfileColors.gborder)),
                      child: const Icon(Icons.close, size: 18, color: ProfileColors.textSecondary),
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client.from('requests').stream(primaryKey: ['id']),
                builder: (context, reqSnap) {
                  final allReqs = reqSnap.data ?? [];
                  // Counts
                  final followCount = allReqs.where((r) => r['target_id'] == uid && r['target_type'] == 'follow' && r['status'] == 'pending').length;
                  final msgCount = allReqs.where((r) => r['target_id'] == uid && r['target_type'] == 'message' && r['status'] == 'pending').length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── SECTION 1: YOUR ECOSYSTEM ──
                      _buildSectionTitle('🏠 YOUR ECOSYSTEM'),
                      _buildDashItem(Icons.campaign, 'amber', 'Hosted by You', 'Manage participants across your rush-ins, activities & events',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostedByYouScreen()))),
                      _buildDashItem(Icons.how_to_reg, 'teal', 'Joined by You', 'Track your participation status across all categories',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinedByYouScreen()))),
                      _buildDashItem(Icons.person_add_alt_1, 'coral', 'Follow Requests', 'Approve or deny incoming follow requests',
                        badge: followCount > 0 ? '$followCount' : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowRequestsScreen()))),
                      const Divider(color: ProfileColors.borderSubtle, height: 40),

                      // ── SECTION 2: CONTENT MANAGEMENT ──
                      _buildSectionTitle('📦 CONTENT MANAGEMENT'),
                      _buildDashItem(Icons.photo_library, 'teal', 'My Posts', 'Manage, archive or delete posts',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostsScreen()))),
                      _buildDashItem(Icons.bookmark_border, 'violet', 'Saved Collections', 'Posts, places & experiences saved',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedCollectionsScreen()))),
                      _buildDashItem(Icons.star_border, 'amber', 'Reviews & Ratings', 'Manage your reviews across app',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!')))),
                      _buildDashItem(Icons.chat_bubble_outline, 'blue', 'Messages & Chats', 'All conversations & chat groups',
                        badge: msgCount > 0 ? '$msgCount' : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()))),
                      const Divider(color: ProfileColors.borderSubtle, height: 40),

                      // ── SECTION 3: ANALYTICS & INSIGHTS ──
                      _buildSectionTitle('📊 ANALYTICS & INSIGHTS'),
                      _buildDashItem(Icons.bar_chart, 'green', 'Profile Insights', 'Views, reach & engagement stats',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileInsightsScreen()))),
                      _buildDashItem(Icons.trending_up, 'teal', 'Spark Score Analytics', 'Track your Spark score growth',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SparkAnalyticsScreen()))),
                      _buildDashItem(Icons.donut_large, 'amber', 'Activity Summary', 'Weekly & monthly activity report',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivitySummaryScreen()))),
                      const Divider(color: ProfileColors.borderSubtle, height: 40),

                      // ── SECTION 4: QUICK TOOLS ──
                      _buildSectionTitle('🔧 QUICK TOOLS'),
                      _buildDashItem(Icons.block, 'pink', 'Blocked Users', 'Manage blocked accounts',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()))),
                      _buildDashItem(Icons.visibility_off, 'blue', 'Restricted Accounts', 'Silently limit interactions',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!')))),
                      _buildDashItem(Icons.qr_code_2, 'violet', 'QR Code', 'Share your profile via QR',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRCodeScreen()))),
                      _buildDashItem(Icons.share, 'green', 'Invite Friends', 'Invite contacts to join Relaya',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteFriendsScreen()))),
                      const Divider(color: ProfileColors.borderSubtle, height: 40),

                      // ── SECTION 5: SYSTEM ADMINISTRATION ──
                      _buildSectionTitle('⚡ SYSTEM ADMIN'),
                      _buildDashItem(Icons.admin_panel_settings, 'red', 'Super Admin Panel', 'Supreme power over the Relaya ecosystem',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()))),
                      const SizedBox(height: 30),
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

  Widget _buildDashItem(IconData icon, String colorName, String title, String desc, {String? badge, VoidCallback? onTap}) {
    Color getBaseColor() {
      switch(colorName) {
        case 'amber': return ProfileColors.cyan;
        case 'coral': return ProfileColors.pink;
        case 'violet': return ProfileColors.purple;
        case 'blue': return ProfileColors.blue;
        case 'green': return ProfileColors.green;
        case 'pink': return ProfileColors.pink;
        case 'teal': return ProfileColors.teal;
        case 'red': return ProfileColors.red;
        default: return ProfileColors.textMuted;
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
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [c.withValues(alpha:0.2), c.withValues(alpha:0.05)]),
                border: Border.all(color: c.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ProfileColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc, style: GoogleFonts.inter(fontSize: 11, color: ProfileColors.textMuted), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ProfileColors.red.withValues(alpha:0.15), borderRadius: BorderRadius.circular(99)),
                child: Text(badge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ProfileColors.red)),
              ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: ProfileColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) await prefs.setDouble(key, value);
    else if (value is String) await prefs.setString(key, value);
    else if (value is int) await prefs.setInt(key, value);
  }

  void _showBottomSlider({required String title, required String subtitle, required Widget slider, required VoidCallback onSave}) {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : ProfileColors.bgSecondary,
      shape: doodle ? null : const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 24) : GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: ProfileColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : GoogleFonts.inter(fontSize: 13, color: ProfileColors.textMuted)),
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
                  ? DoodleDecorations.card(color: DoodleColors.orange).copyWith(borderRadius: BorderRadius.circular(12))
                  : BoxDecoration(gradient: mainGradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: ProfileColors.cyan.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(child: Text('Save Changes', style: doodle ? DoodleFonts.body(color: DoodleColors.cream, fontSize: 18).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
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
            Text('${tempVal.toInt()} km', style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 26).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: ProfileColors.cyan)),
            SliderTheme(
              data: doodle ? SliderThemeData(
                activeTrackColor: DoodleColors.blue,
                inactiveTrackColor: DoodleColors.paper,
                thumbColor: DoodleColors.orange,
                overlayColor: DoodleColors.orange.withValues(alpha: 0.2),
              ) : SliderTheme.of(context),
              child: Slider(
                value: tempVal,
                min: 1, max: 200, divisions: 199,
                activeColor: doodle ? null : ProfileColors.cyan, inactiveColor: doodle ? null : ProfileColors.cyan.withValues(alpha:0.2),
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
            Text('${tempMin.toInt()} - ${tempMax.toInt()} years old', style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 22).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: ProfileColors.cyan)),
            SliderTheme(
              data: doodle ? SliderThemeData(
                activeTrackColor: DoodleColors.blue,
                inactiveTrackColor: DoodleColors.paper,
                thumbColor: DoodleColors.orange,
                overlayColor: DoodleColors.orange.withValues(alpha: 0.2),
              ) : SliderTheme.of(context),
              child: RangeSlider(
                values: RangeValues(tempMin, tempMax),
                min: 18, max: 99, divisions: 81,
                activeColor: doodle ? null : ProfileColors.cyan, inactiveColor: doodle ? null : ProfileColors.cyan.withValues(alpha:0.2),
                onChanged: (v) => setSheetState(() { tempMin = v.start; tempMax = v.end; }),
              ),
            ),
          ],
        );
      }),
      onSave: () {
        setState(() { _ageMin = tempMin; _ageMax = tempMax; });
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
      {'icon': '📸', 'label': 'Photography', 'c1': 0xFF1A0E00, 'c2': 0xFF78350F},
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
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: ProfileColors.bgSecondary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: ProfileColors.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ProfileColors.textMuted, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  Text('Explore Visibility', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: ProfileColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Choose which sections your profile appears in. Empty = visible everywhere.',
                    style: GoogleFonts.inter(fontSize: 13, color: ProfileColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10, runSpacing: 10,
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: active
                                    ? LinearGradient(colors: [Color(v['c1'] as int), Color(v['c2'] as int)])
                                    : null,
                                color: active ? null : ProfileColors.bgTertiary,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: active ? ProfileColors.cyan.withValues(alpha: 0.5) : ProfileColors.borderSubtle, width: active ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Text(icon, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(label, style: GoogleFonts.inter(color: active ? Colors.white : ProfileColors.textSecondary, fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500))),
                                  if (active) const Icon(Icons.check_circle, color: ProfileColors.cyan, size: 18),
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
                        gradient: const LinearGradient(colors: [ProfileColors.cyan, ProfileColors.purple]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text('Apply', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
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
  void _showBolRoomAnonNameSheet() {
    final ctrl = TextEditingController(text: _bolroomAnonName);
    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ProfileColors.textMuted, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [ProfileColors.purple.withValues(alpha: 0.2), ProfileColors.cyan.withValues(alpha: 0.1)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.theater_comedy, color: ProfileColors.purple, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alias Name', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: ProfileColors.textPrimary)),
              Text('This name will appear in BolRooms only', style: GoogleFonts.inter(fontSize: 12, color: ProfileColors.textMuted)),
            ]),
          ]),
          const SizedBox(height: 24),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'Enter your alias...',
              hintStyle: GoogleFonts.inter(color: ProfileColors.textMuted),
              filled: true,
              fillColor: ProfileColors.glass,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ProfileColors.borderSubtle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ProfileColors.borderSubtle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ProfileColors.cyan, width: 2)),
              counterStyle: GoogleFonts.inter(color: ProfileColors.textMuted, fontSize: 11),
              prefixIcon: const Icon(Icons.alternate_email, color: ProfileColors.cyan, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          // Quick suggestion chips
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final suggestion in ['Shadow', 'Phantom', 'Ghost', 'Ninja', 'Mystic', 'Raven', 'Storm', 'Echo'])
              GestureDetector(
                onTap: () => ctrl.text = suggestion,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ProfileColors.glass,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ProfileColors.borderSubtle),
                  ),
                  child: Text(suggestion, style: GoogleFonts.inter(color: ProfileColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _bolroomAnonName = name);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('bolroom_anon_name', name);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ProfileColors.cyan, ProfileColors.purple]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: ProfileColors.cyan.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Text('Save Alias', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  static const _anonAvatars = [
    {'emoji': '🦊', 'label': 'Fox', 'color': 0xFFFF6B35},
    {'emoji': '🐺', 'label': 'Wolf', 'color': 0xFF7C8DB5},
    {'emoji': '🦅', 'label': 'Eagle', 'color': 0xFF8B6914},
    {'emoji': '🐉', 'label': 'Dragon', 'color': 0xFF4CAF50},
    {'emoji': '🦁', 'label': 'Lion', 'color': 0xFFFF9800},
    {'emoji': '🐯', 'label': 'Tiger', 'color': 0xFFF57C00},
    {'emoji': '🦇', 'label': 'Bat', 'color': 0xFF7B1FA2},
    {'emoji': '🐼', 'label': 'Panda', 'color': 0xFF455A64},
    {'emoji': '🦉', 'label': 'Owl', 'color': 0xFF795548},
    {'emoji': '🐸', 'label': 'Frog', 'color': 0xFF66BB6A},
    {'emoji': '🦄', 'label': 'Unicorn', 'color': 0xFFE040FB},
    {'emoji': '👻', 'label': 'Ghost', 'color': 0xFFB0BEC5},
  ];

  void _showBolRoomAnonAvatarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ProfileColors.textMuted, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [ProfileColors.purple.withValues(alpha: 0.2), ProfileColors.cyan.withValues(alpha: 0.1)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.face, color: ProfileColors.cyan, size: 24),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Choose Avatar', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: ProfileColors.textPrimary)),
                  Text('Pick your anonymous identity', style: GoogleFonts.inter(fontSize: 12, color: ProfileColors.textMuted)),
                ]),
              ]),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
                itemCount: _anonAvatars.length,
                itemBuilder: (_, i) {
                  final av = _anonAvatars[i];
                  final avatarKey = 'anon_${av['label']}';
                  final isSelected = _bolroomAnonAvatar == avatarKey;
                  final color = Color(av['color'] as int);
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() => _bolroomAnonAvatar = avatarKey);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('bolroom_anon_avatar', avatarKey);
                    },
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)]),
                          border: Border.all(color: isSelected ? ProfileColors.cyan : color.withValues(alpha: 0.3), width: isSelected ? 3 : 1.5),
                          boxShadow: isSelected ? [BoxShadow(color: ProfileColors.cyan.withValues(alpha: 0.4), blurRadius: 12)] : [],
                        ),
                        child: Center(child: Text(av['emoji'] as String, style: const TextStyle(fontSize: 26))),
                      ),
                      const SizedBox(height: 4),
                      Text(av['label'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? ProfileColors.cyan : ProfileColors.textMuted)),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 16),
              // "No avatar" option
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _bolroomAnonAvatar = '');
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('bolroom_anon_avatar', '');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: ProfileColors.glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bolroomAnonAvatar.isEmpty ? ProfileColors.cyan : ProfileColors.borderSubtle),
                  ),
                  alignment: Alignment.center,
                  child: Text('Use Default Initial', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _bolroomAnonAvatar.isEmpty ? ProfileColors.cyan : ProfileColors.textSecondary)),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  void _showNavTransitionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Navigation Style', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: ProfileColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Customize how you swipe between pages.', style: GoogleFonts.inter(fontSize: 13, color: ProfileColors.textMuted)),
              const SizedBox(height: 24),
              ...['Slide', 'Fade', 'Scale', '3D Flip'].map((style) {
                final isSelected = _navTransition == style;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _navTransition = style);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('nav_transition', style);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigation set to $style'), backgroundColor: ProfileColors.cyan, duration: const Duration(seconds: 1)));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: ProfileColors.glass,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? ProfileColors.cyan : ProfileColors.borderSubtle, width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(style, style: GoogleFonts.inter(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : ProfileColors.textSecondary)),
                        if (isSelected) const Icon(Icons.check_circle, color: ProfileColors.cyan),
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
      width: MediaQuery.of(context).size.width * 0.88 > 380 ? 380 : MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ProfileColors.purple.withValues(alpha: 0.08), Colors.transparent]),
                border: const Border(bottom: BorderSide(color: ProfileColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: ProfileColors.glass, shape: BoxShape.circle, border: Border.all(color: ProfileColors.gborder)),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: ProfileColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Settings', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: ProfileColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildSectionTitle('Account'),
                  _buildSettingsRow(Icons.person_outline, 'Personal Information', hasArrow: true),
                  _buildSettingsRow(Icons.lock_outline, 'Password & Security', hasArrow: true),
                  _buildSettingsRow(Icons.verified_user_outlined, 'Identity Verification', valueText: 'Verified ✔', valueColor: ProfileColors.green, hasArrow: true),
                  _buildSettingsRow(Icons.link, 'Linked Accounts', hasArrow: true),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Preferences'),
                  _buildSettingsRow(Icons.notifications_none, 'Push Notifications', 
                    toggleValue: _pushNotifications, 
                    onToggle: (v) { setState(() => _pushNotifications = v); _saveSetting('push_notifications', v); }
                  ),
                  _buildSettingsRow(Icons.mail_outline, 'Email Notifications', 
                    toggleValue: _emailNotifications, 
                    onToggle: (v) { setState(() => _emailNotifications = v); _saveSetting('email_notifications', v); }
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeService.themeModeNotifier,
                    builder: (context, mode, _) {
                      return _buildSettingsRow(Icons.dark_mode_outlined, 'Dark Mode', 
                        toggleValue: mode == ThemeMode.dark, 
                        onToggle: (v) => themeService.setTheme(v ? ThemeMode.dark : ThemeMode.light)
                      );
                    }
                  ),
                  _buildSettingsRow(Icons.swipe_outlined, 'Navigation Transition', 
                    valueText: _navTransition, 
                    valueColor: ProfileColors.cyan, 
                    hasArrow: true, 
                    onTap: _showNavTransitionSheet
                  ),
                  // Discovery Location — unified search picker (opens real search sheet)
                  ValueListenableBuilder<String>(
                    valueListenable: locationService.activeLocationNotifier,
                    builder: (context, activeLoc, _) {
                      return _buildSettingsRow(
                        Icons.explore_outlined,
                        'Discovery Location',
                        valueText: activeLoc.isEmpty ? 'Tap to set' : activeLoc,
                        valueColor: const Color(0xFFFF6B00),
                        hasArrow: true,
                        onTap: () => showLocationSearchSheet(context),
                      );
                    }
                  ),
                  _buildSettingsRow(Icons.map_outlined, 'Default Maps App', valueText: _mapsApp, hasArrow: true),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Privacy'),
                  _buildSettingsRow(Icons.privacy_tip_outlined, 'Private Account', 
                    toggleValue: _isPublic == false, 
                    onToggle: (v) async { 
                      setState(() => _isPublic = !v); 
                      if (_myUid.isNotEmpty) await Supabase.instance.client.from('profiles').update({'is_public': !v}).eq('id', _myUid);
                    }
                  ),
                  _buildSettingsRow(Icons.visibility_outlined, 'Activity Status', 
                    toggleValue: true, 
                    onToggle: (v) {} 
                  ),
                  _buildSettingsRow(Icons.block, 'Blocked Accounts', hasArrow: true),
                  _buildSettingsRow(Icons.volume_off_outlined, 'Muted Accounts', hasArrow: true),
                  _buildSettingsRow(Icons.visibility_off_outlined, 'Ghost Mode', 
                    toggleValue: _ghostMode, 
                    onToggle: (v) { setState(() => _ghostMode = v); _saveSetting('ghost_mode', v); }
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Activity Matches'),
                  _buildSettingsRow(Icons.public, 'Global Discovery', 
                    toggleValue: _isGlobal, 
                    onToggle: (v) { setState(() => _isGlobal = v); _saveSetting('is_global', v); }
                  ),
                  if (!_isGlobal)
                    _buildSettingsRow(Icons.radar, 'Match Radius', valueText: '${_matchRadius.toInt()} km', hasArrow: true, onTap: _showMatchRadiusSheet),
                  _buildSettingsRow(Icons.group_outlined, 'Age Preference', valueText: '${_ageMin.toInt()}-${_ageMax.toInt()}', hasArrow: true, onTap: _showAgePrefSheet),
                  _buildSettingsRow(Icons.bolt, 'Spark Notifications', 
                    toggleValue: _sparkNotifications, 
                    onToggle: (v) { setState(() => _sparkNotifications = v); _saveSetting('spark_notifications', v); }
                  ),
                  _buildSettingsRow(Icons.auto_awesome, 'Auto-Match with Spark', 
                    toggleValue: _autoMatchSpark, 
                    onToggle: (v) { setState(() => _autoMatchSpark = v); _saveSetting('auto_match_spark', v); }
                  ),
                  _buildSettingsRow(Icons.explore, 'Explore Visibility', 
                    valueText: _getVibeVisibilitySummary(),
                    valueColor: ProfileColors.cyan,
                    hasArrow: true,
                    onTap: _showVibeVisibilitySheet,
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('BolRoom Identity'),
                  _buildSettingsRow(Icons.theater_comedy, 'Anonymous Mode', 
                    toggleValue: _bolroomAnonymous, 
                    onToggle: (v) async { 
                      setState(() => _bolroomAnonymous = v); 
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('bolroom_anonymous', v);
                    }
                  ),
                  if (_bolroomAnonymous) ...[
                    _buildSettingsRow(Icons.edit, 'Alias Name', 
                      valueText: _bolroomAnonName,
                      valueColor: ProfileColors.cyan,
                      hasArrow: true, 
                      onTap: _showBolRoomAnonNameSheet,
                    ),
                    _buildSettingsRow(Icons.face, 'Avatar', 
                      valueText: _bolroomAnonAvatar.isNotEmpty ? 'Custom' : 'Default',
                      valueColor: ProfileColors.purple,
                      hasArrow: true, 
                      onTap: _showBolRoomAnonAvatarSheet,
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Data & Storage'),
                  _buildSettingsRow(Icons.storage, 'Cache Size', valueText: '45.2 MB', hasArrow: false),
                  _buildSettingsRow(Icons.delete_outline, 'Clear Cache', hasArrow: false, onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared! (Simulated)'), backgroundColor: ProfileColors.green));
                  }),
                  _buildSettingsRow(Icons.high_quality, 'Media Quality', valueText: _mediaQuality, hasArrow: true),
                  _buildSettingsRow(Icons.save_alt, 'Save to Camera Roll', 
                    toggleValue: _saveToCameraRoll, 
                    onToggle: (v) { setState(() => _saveToCameraRoll = v); _saveSetting('save_camera_roll', v); }
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Support & About'),
                  _buildSettingsRow(Icons.help_outline, 'Help Center', hasArrow: true),
                  _buildSettingsRow(Icons.report_problem_outlined, 'Report a Problem', hasArrow: true),
                  _buildSettingsRow(Icons.article_outlined, 'Privacy Policy', hasArrow: true),
                  _buildSettingsRow(Icons.gavel_outlined, 'Terms of Service', hasArrow: true),
                  _buildSettingsRow(Icons.info_outline, 'App Version', valueText: 'v3.2.1', hasArrow: false),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Danger Zone'),
                  _buildSettingsRow(Icons.logout, 'Log Out', isDanger: true, onTap: _onLogout),
                  _buildSettingsRow(Icons.warning_amber_rounded, 'Deactivate Account', isDanger: true, onTap: () {}),
                  _buildSettingsRow(Icons.delete_forever, 'Delete Account', isDanger: true, onTap: () {}),
                  
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
          Container(width: 3, height: 14, decoration: BoxDecoration(color: ProfileColors.cyan, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ProfileColors.textMuted, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title, {String? valueText, Color? valueColor, bool hasArrow = false, bool isDanger = false, bool? toggleValue, ValueChanged<bool>? onToggle, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: ProfileColors.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDanger ? ProfileColors.red.withValues(alpha: 0.15) : ProfileColors.gborder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDanger ? ProfileColors.red : ProfileColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: isDanger ? ProfileColors.red : ProfileColors.textPrimary)),
            ),
            const SizedBox(width: 12),
            if (valueText != null)
              Flexible(
                child: Text(
                  valueText, 
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? ProfileColors.textMuted),
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
                   activeTrackColor: ProfileColors.cyan,
                   inactiveThumbColor: ProfileColors.textMuted,
                   inactiveTrackColor: ProfileColors.bgPrimary,
                 ),
               )
            else if (hasArrow)
               Icon(Icons.arrow_forward_ios, size: 14, color: ProfileColors.textMuted.withValues(alpha:0.5)),
          ],
        ),
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
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    final p = Curves.easeInOut.transform(progress);

    // Orb 1: Cyan top-right
    paint.color = ProfileColors.cyan.withValues(alpha: 0.15);
    canvas.drawCircle(
      Offset(size.width * 0.8 - (p * 40), size.height * 0.2 + (p * 50)),
      120, paint,
    );

    // Orb 2: Purple bottom-left
    paint.color = ProfileColors.purple.withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(size.width * 0.2 + (p * 50), size.height * 0.7 - (p * 40)),
      150, paint,
    );

    // Orb 3: Pink mid-right
    paint.color = ProfileColors.pink.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.6 + (p * 30), size.height * 0.5 + (p * 60)),
      100, paint,
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
  final MapController _mapController = MapController();
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
    _mapController.dispose();
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
            content: const Row(children: [Icon(Icons.location_off, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Please enable location services'))]),
            backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              content: const Row(children: [Icon(Icons.not_listed_location, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permission denied'))]),
              backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _fetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.settings, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permanently denied. Enable in settings.'))]),
            backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(label: 'Settings', textColor: Colors.white, onPressed: () => Geolocator.openAppSettings()),
          ));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));

      if (mounted) {
        setState(() {
          _selectedPoint = LatLng(position.latitude, position.longitude);
          _fetchingGps = false;
        });
        _mapController.move(_selectedPoint, 14.0);
        _reverseGeocode(_selectedPoint);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}')]),
          backgroundColor: ProfileColors.cyan, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('Could not get location: $e'))]),
          backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _searchPlace(val));
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1')}';
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data.map((it) => {
              'name': it['display_name'].toString().split(',').first.trim(),
              'full_name': it['display_name'].toString(),
              'lat': double.parse(it['lat']),
              'lng': double.parse(it['lon']),
            }).toList();
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
    _mapController.move(pt, 14);
  }

  void _onMapTap(TapPosition tapPos, LatLng point) {
    setState(() { _selectedPoint = point; _searchResults = []; });
    _mapController.move(point, _mapController.camera.zoom);
    _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _isResolving = true);
    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${p.latitude}&lon=${p.longitude}&zoom=14&addressdetails=1'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          final address = data['address'] ?? {};
          final landmark = data['name'] ?? address['amenity'] ?? address['building'] ?? address['historic'] ?? address['leisure'];
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
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ProfileColors.borderSubtle))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Location', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Choose where you want to discover.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                  ],
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: ProfileColors.bgCard, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white54, size: 18))),
              ],
            ),
          ),
          
          // Map Canvas
          Expanded(
            child: Stack(
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(_isMapDarkMode ? [
                    -1.0, 0.0, 0.0, 0.0, 255.0,
                    0.0, -1.0, 0.0, 0.0, 255.0,
                    0.0, 0.0, -1.0, 0.0, 255.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ] : [
                    1.0, 0.0, 0.0, 0.0, 0.0,
                    0.0, 1.0, 0.0, 0.0, 0.0,
                    0.0, 0.0, 1.0, 0.0, 0.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ]),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _selectedPoint, initialZoom: 14, onTap: _onMapTap, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all)),
                    children: [
                      TileLayer(userAgentPackageName: 'com.meetra.app', urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'),
                      MarkerLayer(markers: [
                        Marker(point: _selectedPoint, width: 80, height: 80, child: const Icon(Icons.location_on, color: ProfileColors.amber, size: 45, shadows: [Shadow(color: ProfileColors.amber, blurRadius: 15)])),
                      ]),
                    ],
                  ),
                ),
                if (_isMapDarkMode) Container(color: const Color(0xFFFF5C00).withValues(alpha: 0.1)),
                
                // Search Input
                Positioned(
                  top: 16, left: 16, right: 16,
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
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(hintText: 'Search city or landmark...', hintStyle: TextStyle(color: Colors.white54, fontSize: 14), border: InputBorder.none, icon: Icon(Icons.search, color: ProfileColors.amber, size: 20)),
                            ),
                          ),
                        ),
                      ),
                      // Search Results
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: ProfileColors.amber.withValues(alpha: 0.3))),
                          child: ListView.separated(
                            shrinkWrap: true, padding: EdgeInsets.zero, itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (ctx, i) {
                              final r = _searchResults[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined, color: ProfileColors.amber, size: 16),
                                title: Text(r['name'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: Text(r['full_name'], style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  bottom: 24, right: 16,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isMapDarkMode = !_isMapDarkMode),
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
                          child: Icon(_isMapDarkMode ? Icons.wb_sunny : Icons.nightlight_round, color: _isMapDarkMode ? Colors.yellow : ProfileColors.amber, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _fetchLiveGps,
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: ProfileColors.amber, shape: BoxShape.circle, boxShadow: [BoxShadow(color: ProfileColors.amber.withValues(alpha: 0.4), blurRadius: 12)]),
                          child: _fetchingGps ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.my_location, color: Colors.black, size: 22),
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
                      Text('Selected Base', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _isResolving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ProfileColors.amber))
                          : Text(_resolvedName.isEmpty ? 'Tap map' : _resolvedName, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    if (_resolvedName.isEmpty) return;
                    widget.onLocationSelected(_resolvedName, _selectedPoint.latitude, _selectedPoint.longitude);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: _resolvedName.isEmpty ? Colors.white12 : ProfileColors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Confirm', style: GoogleFonts.inter(color: _resolvedName.isEmpty ? Colors.white38 : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
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


