import 'dart:ui' as ui;
import 'vibe_artwork.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';

// ignore_for_file: avoid_print, unused_local_variable, unused_element, unused_field, use_build_context_synchronously, unused_element_parameter, prefer_final_fields
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
// import 'experience_screen.dart'; // Disabled as per user instruction
import 'chat_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import 'services/profile_completion_service.dart';
import 'host_activity_screen.dart';
import 'services/location_service.dart';
import 'push_notification_manager.dart';
import 'rush_in_consumer_detail_view.dart';
import 'admin_dashboard_screen.dart';
import 'notifications_screen.dart';
import 'services/notification_service.dart';
import 'widgets/touch_scale.dart';
import 'spark_screen.dart';
import 'services/theme_service.dart';
import 'services/nearby_agent.dart';
import 'splash_screen.dart';
import 'widgets/app_header_actions.dart';
import 'package:app_links/app_links.dart';
import 'chatroom_live_screen.dart';
import 'widgets/location_picker_sheet.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tkcdzuthjrxpfczqathy.supabase.co',
    anonKey: 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj',
  );

  // Initialize services
  await themeService.init();
  await locationService.init();

  runApp(const MeetraApp());

  // Initialize push notification settings safely in background
  PushNotificationManager().initialize();
}

class MeetraApp extends StatefulWidget {
  const MeetraApp({super.key});

  @override
  State<MeetraApp> createState() => _MeetraAppState();
}

class _MeetraAppState extends State<MeetraApp> {
  bool _showSplash = true;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'meetra' && uri.host == 'orbit') {
        final roomId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (roomId != null) {
          final res = await Supabase.instance.client.from('chatrooms').select('*').eq('id', roomId).maybeSingle();
          if (res != null && navigatorKey.currentContext != null) {
            BolRoomManager.openRoom(
              navigatorKey.currentContext!,
              roomId: res['id'].toString(),
              roomName: res['name'] ?? 'Untitled',
              topic: res['topic'] ?? 'General',
              hostId: res['host_id']?.toString() ?? '',
              hostName: res['host_name'] ?? 'Host',
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService.themeModeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Meetra Neon',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            primaryColor: const Color(0xFFFF5C00),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5C00),
              secondary: Color(0xFFFF6B00),
              surface: Colors.white,
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)
                .apply(
                    bodyColor: const Color(0xFF1E293B),
                    displayColor: const Color(0xFF0F172A)),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF050508),
            primaryColor: const Color(0xFFFF6B00),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF6B00),
              secondary: Color(0xFFFF5C00),
              surface: Color(0xFF0D0D12),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
                .apply(bodyColor: Colors.white, displayColor: Colors.white),
          ),
          home: _showSplash
            ? SplashScreen(
                onComplete: () {
                  if (mounted) setState(() => _showSplash = false);
                },
              )
            : StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = snapshot.hasData ? snapshot.data!.session : null;
              if (session != null) {
                // User is logged in - check if onboarding is complete
                return FutureBuilder<Map<String, dynamic>?>(
                  future: Supabase.instance.client
                      .from('profiles')
                      .select('onboarding_complete')
                      .eq('id', session.user.id)
                      .maybeSingle(),
                  builder: (context, profileSnap) {
                    if (profileSnap.connectionState ==
                        ConnectionState.waiting) {
                      return Scaffold(
                        backgroundColor: const Color(0xFF050508),
                        body: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/meetra_icon.png',
                                width: 80,
                                height: 80,
                              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                               .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms, 
curve: Curves.easeInOut),
                            ],
                          ),
                        ),
                      );
                    }

                    final profile = profileSnap.data;
                    final onboardingDone = profile != null &&
                        profile['onboarding_complete'] == true;

                    if (!onboardingDone) {
                      return Scaffold(
                        backgroundColor: Colors.black,
                        body: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: const OnboardingScreen(),
                          ),
                        ),
                      );
                    }

                    return Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: const MainDashboard(),
                        ),
                      ),
                    );
                  },
                );
              }
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: const AuthScreen(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}


// ----------------------------------------------------
// NEON WIDGETS
// ----------------------------------------------------
class NeonCard extends StatelessWidget {
  final Widget child;
  final double blurRadius;
  final double spreadRadius;
  final Color shadowColor;
  final Color bgColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;

  const NeonCard({
    super.key,
    required this.child,
    this.blurRadius = 15.0,
    this.spreadRadius = 1.0,
    this.shadowColor = const Color(0xFFFF6B00),
    this.bgColor = const Color(0xFF101015),
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.08),
            spreadRadius: spreadRadius,
            blurRadius: blurRadius,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class Animated3DButton extends StatefulWidget {
  final VoidCallback onPressed;
  const Animated3DButton({super.key, required this.onPressed});

  @override
  State<Animated3DButton> createState() => _Animated3DButtonState();
}

class _Animated3DButtonState extends State<Animated3DButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
        scale: _scaleAnimation,
        child: TouchScale(
            onTap: widget.onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C00), Color(0xFFFF6B00)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 2)),
                  ]),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Create Rush-In',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )));
  }
}

// ----------------------------------------------------
// MAIN DASHBOARD & NEON NAV BAR
// ----------------------------------------------------
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainDashboardState>();
    if (state != null) {
      state._onSelectTab(index);
    }
  }

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  final List<int> _navigationHistory = [];
  static const int _maxHistory = 10;
  bool _goingForward = true;
  String _navTransition = 'Slide';
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _loadNavPref();
    _startPresenceHeartbeat();
    // Start the AI nearby agent after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NearbyAgent.instance.start(context, radiusKm: 15.0);
    });
  }

  void _startPresenceHeartbeat() {
    _updatePresence();
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) => _updatePresence());
  }

  Future<void> _updatePresence() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final currentCity = locationService.activeDistrict.isNotEmpty ? locationService.activeDistrict : 'Unknown';
        await Supabase.instance.client.from('profiles').update({
          'city': currentCity,
        }).eq('id', uid);
      }
    } catch (_) {}
  }

  Future<void> _loadNavPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _navTransition = prefs.getString('nav_transition') ?? 'Slide';
      });
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    NearbyAgent.instance.stop();
    super.dispose();
  }

  void _onSelectTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    // Reload preference just in case it was changed
    _loadNavPref();
    setState(() {
      _goingForward = index > _currentIndex;
      _navigationHistory.add(_currentIndex);
      if (_navigationHistory.length > _maxHistory) {
        _navigationHistory.removeAt(0);
      }
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_navigationHistory.isNotEmpty) {
          setState(() {
            _currentIndex = _navigationHistory.removeLast();
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -300) {
                  // Swipe left -> Next tab
                  if (_currentIndex < 4) _onSelectTab(_currentIndex + 1);
                } else if (details.primaryVelocity! > 300) {
                  // Swipe right -> Prev tab
                  if (_currentIndex > 0) _onSelectTab(_currentIndex - 1);
                }
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: 80 + bottomSafeArea),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    switch (_navTransition) {
                      case 'Fade':
                        return FadeTransition(opacity: animation, child: child);
                      case 'Scale':
                        return ScaleTransition(scale: animation, child: child);
                      case '3D Flip':
                        final rotate = Tween(begin: 3.14, end: 0.0).animate(animation);
                        return AnimatedBuilder(
                          animation: rotate,
                          builder: (context, ch) {
                            // Ensure the old child fades out so they don't overlap weirdly
                            final isUnder = (ValueKey(_currentIndex) != child.key);
                            var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                            tilt *= isUnder ? -1.0 : 1.0;
                            final value = isUnder ? math.min(rotate.value, 1.57) : rotate.value;
                            return Transform(
                              transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                              alignment: Alignment.center,
                              child: ch,
                            );
                          },
                          child: child,
                        );
                      case 'Slide':
                      default:
                        final slideOffset = _goingForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
                        final slide = Tween(begin: slideOffset, end: Offset.zero).animate(animation);
                        return SlideTransition(position: slide, child: child);
                    }
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentIndex),
                    child: _getScreenByIndex(_currentIndex),
                  ),
                ),
              ),
            ),

            // ── Flat Bottom Nav Bar ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(bottom: bottomSafeArea),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0A0F),
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFF2A1F3D),
                      width: 1.0,
                    ),
                  ),
                ),
                child: SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      // Home
                      _buildNavItem(Icons.home_outlined, Icons.home_rounded, 0),
                      // Explore
                      _buildNavItem(Icons.explore_outlined, Icons.explore_rounded, 1),
                      // Center Spark button
                      _buildCenterSparkButton(),
                      // Messages
                      _buildNavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 3),
                      // Profile
                      _buildNavItem(Icons.person_outline_rounded, Icons.person_rounded, 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the elevated center Spark (lightning) button with ringed glow
  Widget _buildCenterSparkButton() {
    final bool isSelected = _currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onSelectTab(2),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Dark outer ring
                color: const Color(0xFF1A1A1F),
                border: Border.all(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                  width: 2.0,
                ),
                boxShadow: [
                  // Outer orange glow
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: isSelected ? 0.5 : 0.25),
                    blurRadius: isSelected ? 28 : 18,
                    spreadRadius: isSelected ? 3 : 1,
                  ),
                ],
              ),
              // Inner gradient circle with gap
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF6B00),
                        Color(0xFFFF3060),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, int index) {
    bool isSelected = _currentIndex == index;
    Color color = isSelected ? Colors.white : const Color(0xFF8E8E93);
    return Expanded(
      child: GestureDetector(
        onTap: () => _onSelectTab(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              color: color,
              size: 28, // Slightly larger to compensate for removed text
            ),
          ],
        ),
      ),
    );
  }

  Widget _getScreenByIndex(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return ExploreScreen(onCreateTap: () => _showCreateRushInSheet(context));
      case 2:
        return SparkScreen(
          onBack: () => _onSelectTab(0),
        );
      case 3:
        // Replaced ExperienceScreen with ChatScreen
        return const ChatScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  // CREATE RUSH-IN BOTTOM SHEET (Image 4)
  void _showCreateRushInSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          // Stable state for the bottom sheet
          bool isSheetMapDark = true;
          final mapSheetCtrl = MapController();
          final sheetSearchCtrl = TextEditingController();
          List<dynamic> sheetSearchResults = [];

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF08080C),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Create Rush-In',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. What\'s the vibe?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildVibeChip(Icons.whatshot, 'Party',
                                isSelected: true),
                            _buildVibeChip(Icons.fitness_center, 'Workout'),
                            _buildVibeChip(Icons.restaurant, 'Foodie'),
                            _buildVibeChip(Icons.sports_esports, 'Gaming'),
                            _buildVibeChip(Icons.movie, 'Cinema'),
                            _buildVibeChip(Icons.menu_book, 'Study'),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text('2. Add a hook',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: const Color(0xFF101015),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10)),
                          child: const TextField(
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  'e.g. 5v5 Basketball at Sunset Park! ??',
                              hintStyle: TextStyle(
                                  color: Colors.white38, fontSize: 14),
                              icon: Icon(Icons.sort, color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Participant Limit',
                                style: TextStyle(color: Colors.white70)),
                            Row(
                              children: [
                                IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Color(0xFFFF5C00)),
                                    onPressed: () {}),
                                const Text('12',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: Color(0xFFFF5C00)),
                                    onPressed: () {}),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text('3. How long?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTimePill('1 hr'),
                            _buildTimePill('3 hrs', isSelected: true),
                            _buildTimePill('6 hrs'),
                            _buildTimePill('12 hrs'),
                            _buildTimePill('24 hrs'),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('4. Set Location',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                      color:
                                          Colors.green.withValues(alpha: 0.5))),
                              child: const Text('Auto-detect: ON',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        StatefulBuilder(
                          builder: (context, setSheetState) {
                            // Local helper for search
                            Future<void> performSheetSearch(String q) async {
                              final encoded = Uri.encodeComponent(q);
                              final proxyUrl =
                                  'https://api.allorigins.win/raw?url='
                                  '${Uri.encodeComponent('https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5&addressdetails=1')}';
                              try {
                                final res = await http.get(Uri.parse(proxyUrl));
                                if (res.statusCode == 200) {
                                  final data = jsonDecode(res.body) as List;
                                  setSheetState(() {
                                    sheetSearchResults = data
                                        .map((it) => {
                                              'display_name': it['display_name']
                                                  .toString()
                                                  .split(',')
                                                  .first
                                                  .trim(),
                                              'full_name':
                                                  it['display_name'].toString(),
                                              'lat': double.parse(it['lat']),
                                              'lon': double.parse(it['lon']),
                                            })
                                        .toList();
                                  });
                                }
                              } catch (_) {}
                            }

                            return Container(
                              height: 320, // Taller map for better interaction
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.white12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black45, blurRadius: 20)
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Stack(
                                  children: [
                                    // Map with Theme Inversion
                                    ColorFiltered(
                                      colorFilter:
                                          ColorFilter.matrix(isSheetMapDark
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
                                      child: FlutterMap(
                                        mapController: mapSheetCtrl,
                                        options: const MapOptions(
                                          initialCenter:
                                              LatLng(28.6139, 77.2090),
                                          initialZoom: 14.0,
                                          interactionOptions:
                                              InteractionOptions(
                                                  flags: InteractiveFlag.all),
                                        ),
                                        children: [
                                          TileLayer(
                                            userAgentPackageName:
                                                'com.meetra.app',
                                            urlTemplate:
                                                'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                                          )
                                        ],
                                      ),
                                    ),

                                    // Neon Wash
                                    if (isSheetMapDark)
                                      Container(
                                          color: const Color(0xFFFF5C00)
                                              .withValues(alpha: 0.15)),

                                    // Glassmorphic Search Bar
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      right: 54,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: BackdropFilter(
                                          filter: ui.ImageFilter.blur(
                                              sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            height: 40,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                    color: Colors.white10)),
                                            child: TextField(
                                              controller: sheetSearchCtrl,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                              onChanged: (v) {
                                                if (v.length > 2) {
                                                  performSheetSearch(v);
                                                }
                                              },
                                              decoration: const InputDecoration(
                                                hintText: 'Search location...',
                                                hintStyle: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12),
                                                border: InputBorder.none,
                                                icon: Icon(Icons.search,
                                                    color: Colors.white54,
                                                    size: 16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // My Location Button
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () async {
                                          try {
                                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                            if (!serviceEnabled) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                  content: const Row(children: [Icon(Icons.location_off, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Please enable location services'))]),
                                                  backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ));
                                              }
                                              return;
                                            }
                                            LocationPermission perm = await Geolocator.checkPermission();
                                            if (perm == LocationPermission.denied) {
                                              perm = await Geolocator.requestPermission();
                                              if (perm == LocationPermission.denied) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                    content: const Row(children: [Icon(Icons.not_listed_location, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permission denied'))]),
                                                    backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ));
                                                }
                                                return;
                                              }
                                            }
                                            if (perm == LocationPermission.deniedForever) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                  content: const Row(children: [Icon(Icons.settings, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permanently denied. Enable in settings.'))]),
                                                  backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  action: SnackBarAction(label: 'Settings', textColor: Colors.white, onPressed: () => Geolocator.openAppSettings()),
                                                ));
                                              }
                                              return;
                                            }
                                            final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
                                            mapSheetCtrl.move(LatLng(pos.latitude, pos.longitude), 15);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}')]),
                                                backgroundColor: const Color(0xFFFF6B00), behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 3),
                                              ));
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('Could not get location: $e'))]),
                                                backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ));
                                            }
                                          }
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFFF6B00),
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.4), blurRadius: 8)]),
                                          child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),

                                    // Theme Toggle
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () => setSheetState(() =>
                                            isSheetMapDark = !isSheetMapDark),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle),
                                          child: Icon(
                                              isSheetMapDark
                                                  ? Icons.wb_sunny
                                                  : Icons.nightlight_round,
                                              color: isSheetMapDark
                                                  ? Colors.yellow
                                                  : Colors.blueGrey,
                                              size: 18),
                                        ),
                                      ),
                                    ),

                                    // Search Results Dropdown
                                    if (sheetSearchResults.isNotEmpty)
                                      Positioned(
                                        top: 56,
                                        left: 12,
                                        right: 54,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                              maxHeight: 120),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF101015),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.white12)),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount:
                                                sheetSearchResults.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(
                                                    color: Colors.white10,
                                                    height: 1),
                                            itemBuilder: (ctx, i) {
                                              final r = sheetSearchResults[i];
                                              return ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                    Icons.location_on,
                                                    color: Color(0xFFFF6B00),
                                                    size: 14),
                                                title: Text(r['display_name'],
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12)),
                                                onTap: () {
                                                  mapSheetCtrl.move(
                                                      LatLng(
                                                          r['lat'], r['lon']),
                                                      15);
                                                  setSheetState(() {
                                                    sheetSearchResults = [];
                                                    sheetSearchCtrl.text =
                                                        r['display_name'];
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                    // Center Marker
                                    IgnorePointer(
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFF5C00),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: const Text('Drop Zone',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white)),
                                            ),
                                            const Icon(Icons.location_on,
                                                color: Colors.white, size: 30),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        NeonCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.visibility_off,
                                        color: Colors.white54, size: 20),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Ghost Mode',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            'Hide exact pin until I approve guests',
                                            style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                    value: true,
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: const Color(0xFFFF5C00),
                                    onChanged: (val) {})
                              ],
                            )),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3A67),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Blast Rush-In ?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        });
  }

  Widget _buildVibeChip(IconData icon, String label,
      {bool isSelected = false}) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF8A00) : const Color(0xFF101015),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: isSelected ? Colors.white : const Color(0xFFFF5C00)),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTimePill(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF101015),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.black : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 13)),
    );
  }
}

// ----------------------------------------------------
// 0. DISCOVER SCREEN
// ----------------------------------------------------
// ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
// DISCOVER SCREEN ï¿½ Interest Picker ? Profile Swiping ? Feed
// ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
enum _DiscoverView { interests, profiles }

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  _DiscoverView _view = _DiscoverView.interests;
  String _selectedInterest = '';
  int _profileIdx = 0;
  bool _isPremium = false; // Controls if knocking profiles are legible

  // Sorting & Filtering
  double _filterDistance = 100.0; // max distance in km (100 = Anywhere)
  String _selectedLocation = 'Near Me';
  final List<String> _locations = ['Near Me', 'NYC', 'LA', 'Miami', 'Chicago'];

  // -- Random Profile Deck (main page) --
  List<Map<String, dynamic>> _randomProfiles = [];
  bool _loadingRandom = false;
  int _randomIdx = 0;
  double _randomDragX = 0;
  double _randomDragY = 0;
  bool _randomDragging = false;

  // Location data
  double? _myLat;
  double? _myLng;

  late AnimationController _bgController;

  // -- Tinder Swipe Engine --
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;
  bool _showMatchOverlay = false;
  Map<String, dynamic>? _matchedProfile;
  late AnimationController _swipeController;
  late AnimationController _heartPopController;
  bool _showHeartPop = false;

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _swipeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _heartPopController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _loadDiscoveryPreferences();
    _initLocation();
    _fetchDynamicVibeStats();
    _loadRandomProfiles();
    
    // Listen to location changes
    locationService.activeLocationNotifier.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    // Clear all cached data so it reloads with the new location
    setState(() {
      _randomProfiles = [];
      _randomIdx = 0;
      _loadingRandom = false;
      _interestProfiles.clear();
      _aiMatches = [];
      _loadingMatches = false;
    });

    // Re-init location to fetch new coordinates, then refresh everything
    _initLocation().then((_) {
      _fetchDynamicVibeStats();
      _loadRandomProfiles();
      _loadAiMatches();

      // If viewing an interest, reload those profiles too
      if (_view == _DiscoverView.profiles && _selectedInterest.isNotEmpty) {
        _loadProfilesForInterest(_selectedInterest);
      }
    });
  }

  Future<void> _loadDiscoveryPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _filterDistance = prefs.getDouble('discovery_radius') ?? 100.0;
      });
    }
  }

  Future<void> _initLocation() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    // STEP 1: Always prioritize the global LocationService coordinates
    if (locationService.activeLat != null && locationService.activeLng != null) {
      if (mounted) {
        setState(() {
          _myLat = locationService.activeLat;
          _myLng = locationService.activeLng;
        });
      }
      return;
    }

    // STEP 2: Fall back to reading from Supabase profile
    try {
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('lat, lng, city')
          .eq('id', uid)
          .maybeSingle();

      if (mounted && myProfile != null) {
        final dbLat = double.tryParse(myProfile['lat']?.toString() ?? '');
        final dbLng = double.tryParse(myProfile['lng']?.toString() ?? '');
        if (dbLat != null && dbLng != null) {
          setState(() {
            _myLat = dbLat;
            _myLng = dbLng;
          });
          // Also seed LocationService so all screens get this baseline
          if (locationService.activeLat == null) {
            locationService.setLocation(
              myProfile['city']?.toString() ?? 'My Location',
              lat: dbLat,
              lng: dbLng,
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    locationService.activeLocationNotifier.removeListener(_onLocationChanged);
    _bgController.dispose();
    _swipeController.dispose();
    _heartPopController.dispose();
    super.dispose();
  }

  // -- Interest categories (Matching Prototype) --------------------------------
  List<Map<String, dynamic>> _interests = [
    {
      'label': 'Study',
      'icon': Icons.menu_book,
      'c1': 0xFF0F0C29,
      'c2': 0xFF302B63,
      'tagline': 'Deep focus',
      'active': 128,
      'activity': 'studying now',
      'users': ['S', 'R', 'P'],
      'userColors': [0xFFFF7E40, 0xFF06B6D4, 0xFFFF3D00],
      'extra': 12,
    },
    {
      'label': 'Fitness',
      'icon': Icons.fitness_center,
      'c1': 0xFF1A0000,
      'c2': 0xFF7F1D1D,
      'tagline': 'Grind ï¿½ Glow',
      'active': 96,
      'activity': 'grinding now',
      'users': ['K', 'M', 'V'],
      'userColors': [0xFF10B981, 0xFFFF7E40, 0xFFF59E0B],
      'extra': 9,
    },
    {
      'label': 'Music',
      'icon': Icons.music_note,
      'c1': 0xFF150020,
      'c2': 0xFF5B21B6,
      'tagline': 'Feel every beat',
      'active': 214,
      'activity': 'vibing now',
      'users': ['A', 'N'],
      'userColors': [0xFFFF3D00, 0xFF3B82F6],
      'extra': 21,
    },
    {
      'label': 'Startup',
      'icon': Icons.rocket_launch,
      'c1': 0xFF030C1A,
      'c2': 0xFF1E3A8A,
      'tagline': 'Build ï¿½ Ship',
      'active': 73,
      'activity': 'building now',
      'users': ['R', 'S'],
      'userColors': [0xFFEF4444, 0xFF3B82F6],
      'extra': 7,
    },
    {
      'label': 'Travel',
      'icon': Icons.flight_takeoff,
      'c1': 0xFF022C22,
      'c2': 0xFF064E3B,
      'tagline': 'Wander ï¿½ Explore',
      'active': 142,
      'activity': 'exploring now',
      'users': ['J', 'L'],
      'userColors': [0xFF10B981, 0xFF6366F1],
      'extra': 14,
    },
    {
      'label': 'Gaming',
      'icon': Icons.sports_esports,
      'c1': 0xFF0D0028,
      'c2': 0xFF3B0764,
      'tagline': 'Play ï¿½ Win',
      'active': 187,
      'activity': 'playing now',
      'users': ['X', 'G'],
      'userColors': [0xFFFF7E40, 0xFF06B6D4],
      'extra': 18,
    },
    {
      'label': 'Photography',
      'icon': Icons.camera_alt,
      'c1': 0xFF1A0E00,
      'c2': 0xFF78350F,
      'tagline': 'Capture moments',
      'active': 89,
      'activity': 'shooting now',
      'users': ['L', 'P'],
      'userColors': [0xFFF59E0B, 0xFFFF3D00],
      'extra': 8,
    },
    {
      'label': 'Cooking',
      'icon': Icons.restaurant,
      'c1': 0xFF1A0500,
      'c2': 0xFF7C2D12,
      'tagline': 'Flip ï¿½ Feast',
      'active': 61,
      'activity': 'cooking now',
      'users': ['C', 'D'],
      'userColors': [0xFFEF4444, 0xFF10B981],
      'extra': 6,
    },
    {
      'label': 'Perform',
      'icon': Icons.mic,
      'c1': 0xFF022C22,
      'c2': 0xFF065F46,
      'tagline': 'Stage ï¿½ Spotlight',
      'active': 53,
      'activity': 'performing now',
      'users': ['M', 'F'],
      'userColors': [0xFF10B981, 0xFFFF7E40],
      'extra': 5,
    },
    {
      'label': 'Tech & AI',
      'icon': Icons.smart_toy,
      'c1': 0xFF001A25,
      'c2': 0xFF082F49,
      'tagline': 'Build tomorrow',
      'active': 112,
      'activity': 'building now',
      'users': ['A', 'K'],
      'userColors': [0xFF06B6D4, 0xFFFF7E40],
      'extra': 11,
    },
    {
      'label': 'Dating',
      'icon': Icons.favorite,
      'c1': 0xFF2D0018,
      'c2': 0xFF831843,
      'tagline': 'Find your spark',
      'active': 248,
      'activity': 'finding love now',
      'users': ['S', 'R', 'N', 'V'],
      'userColors': [0xFFFF3D00, 0xFFFF7E40, 0xFF06B6D4, 0xFFF59E0B],
      'extra': 24,
      'wide': true,
    },
  ];

  Future<void> _fetchDynamicVibeStats() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url, interests, visible_vibes');

      if (response.isEmpty) return;

      final Map<String, List<String>> vibeAvatars = {};
      final Map<String, int> vibeCounts = {};

      for (final profile in response) {
        final rawInterests = profile['interests'];
        if (rawInterests == null) continue;

        // Parse visible_vibes — empty means visible everywhere
        List<String> visibleVibes = [];
        final rawVibes = profile['visible_vibes'];
        if (rawVibes is List) {
          visibleVibes = rawVibes.map((e) => e.toString()).toList();
        }

        // Parse PG array string {A,B,C} or List depending on representation
        List<String> userInterests = [];
        if (rawInterests is List) {
          userInterests = rawInterests.map((e) => e.toString()).toList();
        } else if (rawInterests is String) {
          userInterests = rawInterests
              .replaceAll('{', '')
              .replaceAll('}', '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        final String avatar = profile['avatar_url']?.toString() ?? '';

        for (final interest in userInterests) {
          final label = interest;

          // Only count if visible_vibes is empty (visible everywhere) 
          // or contains this specific vibe label (case-insensitive)
          if (visibleVibes.isNotEmpty) {
            final isVisible = visibleVibes.any(
              (v) => v.trim().toLowerCase() == label.trim().toLowerCase()
            );
            if (!isVisible) continue;
          }

          vibeCounts[label] = (vibeCounts[label] ?? 0) + 1;

          if (avatar.isNotEmpty) {
            vibeAvatars.putIfAbsent(label, () => []);
            if (vibeAvatars[label]!.length < 3) {
              vibeAvatars[label]!.add(avatar);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          for (int i = 0; i < _interests.length; i++) {
            final label =
                (_interests[i]['label'] as String).trim().toLowerCase();
            // Match case-insensitively
            final matchingKey = vibeCounts.keys.firstWhere(
              (k) => k.trim().toLowerCase() == label,
              orElse: () => '',
            );

            if (matchingKey.isNotEmpty) {
              _interests[i]['active'] = vibeCounts[matchingKey];
              if (vibeAvatars.containsKey(matchingKey)) {
                _interests[i]['users'] = vibeAvatars[matchingKey];
                final remaining =
                    vibeCounts[matchingKey]! - vibeAvatars[matchingKey]!.length;
                _interests[i]['extra'] = remaining.clamp(0, 999);
              } else {
                _interests[i]['users'] = [];
                _interests[i]['extra'] = vibeCounts[matchingKey];
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching vibe stats: $e');
    }
  }

  // -- Tinder-style interest matching from Supabase --
  final Map<String, List<Map<String, dynamic>>> _interestProfiles = {};
  bool _loadingInterest = false;
  final Set<String> _skippedProfiles = {};

  List<Map<String, dynamic>> _profilesFor(String interest) {
    final cached = _interestProfiles[interest] ?? [];
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return cached.where((p) {
      final pid = p['id']?.toString() ?? '';
      return pid != uid && !_skippedProfiles.contains(pid);
    }).toList();
  }

  Future<void> _loadProfilesForInterest(String interest) async {
    if (_interestProfiles.containsKey(interest)) return;
    setState(() => _loadingInterest = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      double radiusKm = prefs.getDouble('discovery_radius') ?? 100.0;
      bool isGlobal = prefs.getBool('is_global') ?? false;

      // If global toggle is on, or radius >= 201km (legacy fallback), treat as 'Global' (50000km)
      if (isGlobal || radiusKm >= 201.0) radiusKm = 50000.0;

      // Use the coordinates from LocationService (or fallbacks)
      final useLat = locationService.activeLat ?? _myLat ?? 25.4484;
      final useLng = locationService.activeLng ?? _myLng ?? 78.5685;

      // Call the high-precision PostGIS RPC
      final data =
          await Supabase.instance.client.rpc('get_nearby_profiles', params: {
        'user_lat': useLat,
        'user_lng': useLng,
        'radius_km': radiusKm,
        'filter_interest': interest,
      });

      final profiles = (data as List).map((p) {
        return {
          'id': p['id'],
          'name': p['name'] ?? p['full_name'] ?? 'User',
          'age': p['age'] ?? 22,
          'avatar': p['avatar_url'] ??
              'https://picsum.photos/seed/${p['id']}/400/500',
          'bio': p['bio'] ?? '',
          'city': p['city'] ?? '',
          'lat': p['lat'],
          'lng': p['lng'],
          'gender': p['gender'] ?? '',
          'interests': (p['interests'] as List?)?.cast<String>() ?? [],
          'personality': p['personality'] ?? '',
          'looking_for': (p['looking_for'] as List?)?.cast<String>() ?? [],
          'availability': (p['availability'] as List?)?.cast<String>() ?? [],
          'height_cm': p['height_cm'],
          'smoking': p['smoking'] ?? '',
          'drinking': p['drinking'] ?? '',
          'weed': p['weed'] ?? '',
          'diet': p['diet'] ?? '',
          'exercise': p['exercise'] ?? '',
          'education': p['education'] ?? '',
          'job_title': p['job_title'] ?? '',
          'zodiac': p['zodiac'] ?? '',
          'relationship_type': p['relationship_type'] ?? '',
          'religion': p['religion'] ?? '',
          'match_gender': p['match_gender'] ?? '',
          'personality_traits': (p['personality_traits'] as List?)?.cast<String>() ?? [],
          'visible_vibes': (p['visible_vibes'] as List?)?.cast<String>() ?? [],
        };
      }).toList();

      // Filter by visible_vibes: only show profiles that opted into this vibe
      // Empty visible_vibes = visible everywhere (backward compat)
      profiles.retainWhere((p) {
        final vibes = p['visible_vibes'] as List<String>;
        if (vibes.isEmpty) return true; // empty = visible everywhere
        return vibes.any((v) => v.trim().toLowerCase() == interest.trim().toLowerCase());
      });

      profiles.shuffle();

      if (mounted) {
        setState(() {
          _interestProfiles[interest] = profiles;
          _loadingInterest = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load profiles for $interest: $e');
      if (mounted) {
        setState(() {
          _interestProfiles[interest] = [];
          _loadingInterest = false;
        });
      }
    }
  }

  // -- Random Profile Loading (for main page deck) -------------------------------
  Future<void> _loadRandomProfiles() async {
    if (_loadingRandom) return;
    setState(() => _loadingRandom = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        setState(() => _loadingRandom = false);
        return;
      }

      // Load my profile for distance calculations
      final me = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (me != null) _myProfile = me;

      // Get active city from locationService or from profile
      final activeCity = locationService.activeLocation.isNotEmpty
          ? locationService.activeLocation.toLowerCase()
          : (me?['city']?.toString().toLowerCase() ?? '');

      // Get efficient bounding box for queries
      final bounds = await locationService.getBoundingBoxAsync();
      
      var query = Supabase.instance.client.from('profiles').select().neq('id', uid);
      
      if (bounds != null) {
        query = query
          .gte('lat', bounds['minLat']!)
          .lte('lat', bounds['maxLat']!)
          .gte('lng', bounds['minLng']!)
          .lte('lng', bounds['maxLng']!);
      }

      final data = await query.limit(100);

      final profiles = (data as List).map((p) {
        return {
          'id': p['id'],
          'name': p['name'] ?? p['full_name'] ?? 'User',
          'age': p['age'] ?? 22,
          'avatar': p['avatar_url'] ??
              'https://picsum.photos/seed/${p['id']}/400/500',
          'bio': p['bio'] ?? '',
          'city': p['city'] ?? '',
          'lat': p['lat'],
          'lng': p['lng'],
          'gender': p['gender'] ?? '',
          'interests': (p['interests'] as List?)?.cast<String>() ?? [],
          'personality': p['personality'] ?? '',
          'looking_for': (p['looking_for'] as List?)?.cast<String>() ?? [],
          'availability': (p['availability'] as List?)?.cast<String>() ?? [],
          // New Onboarding Fields
          'height_cm': p['height_cm'],
          'smoking': p['smoking'] ?? '',
          'drinking': p['drinking'] ?? '',
          'weed': p['weed'] ?? '',
          'diet': p['diet'] ?? '',
          'exercise': p['exercise'] ?? '',
          'education': p['education'] ?? '',
          'job_title': p['job_title'] ?? '',
          'zodiac': p['zodiac'] ?? '',
          'relationship_type': p['relationship_type'] ?? '',
          'religion': p['religion'] ?? '',
          'match_gender': p['match_gender'] ?? '',
          'personality_traits': (p['personality_traits'] as List?)?.cast<String>() ?? [],
        };
      }).toList();

      // Precise Circular Radius Filtering (Post-Bounding Box)
      final prefs = await SharedPreferences.getInstance();
      double radiusKm = prefs.getDouble('discovery_radius') ?? 100.0;
      bool isGlobal = prefs.getBool('is_global') ?? false;
      if (!isGlobal && radiusKm < 201.0 && _myLat != null && _myLng != null) {
        profiles.retainWhere((p) {
          final pLat = double.tryParse(p['lat']?.toString() ?? '');
          final pLng = double.tryParse(p['lng']?.toString() ?? '');
          if (pLat == null || pLng == null) return false;
          final dist = _getDistance(_myLat!, _myLng!, pLat, pLng);
          return dist <= radiusKm;
        });
      }

      // Filter by city: show people from the same city first
      List<Map<String, dynamic>> cityFiltered;
      if (activeCity.isNotEmpty) {
        final sameCity = profiles.where((p) =>
            (p['city'] as String).toLowerCase().contains(activeCity) ||
            activeCity.contains((p['city'] as String).toLowerCase())).toList();
        if (sameCity.length >= 3) {
          cityFiltered = sameCity;
        } else {
          // Not enough profiles in this city, include nearby ones too
          cityFiltered = profiles;
        }
      } else {
        cityFiltered = profiles;
      }
      cityFiltered.shuffle();

      if (mounted) {
        setState(() {
          _randomProfiles = cityFiltered;
          _randomIdx = 0;
          _loadingRandom = false;
        });
      }
    } catch (e) {
      debugPrint('loadRandomProfiles error: $e');
      if (mounted) setState(() => _loadingRandom = false);
    }
  }

  void _onRandomSwipeRight(Map<String, dynamic> p) {
    _onSwipeRight(p);
    setState(() {
      _randomIdx++;
      _randomDragX = 0;
      _randomDragY = 0;
      _randomDragging = false;
    });
  }

  void _onRandomSwipeLeft(Map<String, dynamic> p) {
    HapticFeedback.lightImpact();
    setState(() {
      _randomIdx++;
      _randomDragX = 0;
      _randomDragY = 0;
      _randomDragging = false;
    });
  }

  void _onRandomSwipeComplete(Map<String, dynamic> p) {
    if (_randomDragX > 120) {
      _onRandomSwipeRight(p);
    } else if (_randomDragX < -120) {
      _onRandomSwipeLeft(p);
    } else {
      setState(() {
        _randomDragX = 0;
        _randomDragY = 0;
        _randomDragging = false;
      });
    }
  }

  // -- Navigation helpers --
  void _selectInterest(String interest) {
    setState(() {
      _selectedInterest = interest;
      _profileIdx = 0;

      _view = _DiscoverView.profiles;
    });
    _initLocation(); // Ensure baseline lat/lng is fresh before loading profiles
    _loadProfilesForInterest(interest);
  }

  void _nextProfile() {
    final total = _profilesFor(_selectedInterest).length;
    if (_profileIdx < total) {
      // Add current profile to skipped set so it doesn't reappear
      final profiles = _profilesFor(_selectedInterest);
      if (_profileIdx < profiles.length) {
        _skippedProfiles.add(profiles[_profileIdx]['id']?.toString() ?? '');
      }
    }
    setState(() {
      _profileIdx = 0;
    }); // Always reset to 0 since skipped profiles are filtered out
  }

  // -- BUILD --
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(anim),
              child: child)),
      child: switch (_view) {
        _DiscoverView.interests => _buildInterestPicker(),
        _DiscoverView.profiles => _buildProfileView(),
      },
    );
  }

  // --------------------------------------------------------------------
  // SUB-VIEW 1: Interest Picker (HOME PAGE)
  // --------------------------------------------------------------------
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Late Night Vibes';
  }

  IconData get _greetingIcon {
    final hour = DateTime.now().hour;
    if (hour < 6) return Icons.bedtime;
    if (hour < 12) return Icons.wb_sunny;
    if (hour < 17) return Icons.wb_cloudy;
    if (hour < 21) return Icons.nights_stay;
    return Icons.bedtime;
  }

  // -- AI Matching Engine ------------------------------------------------------
  List<Map<String, dynamic>> _aiMatches = [];
  bool _loadingMatches = false;
  Map<String, dynamic>? _myProfile;

  Future<void> _loadAiMatches() async {
    if (_loadingMatches) return;
    setState(() => _loadingMatches = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        setState(() => _loadingMatches = false);
        return;
      }

      // Load my profile
      final me = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (me == null) {
        setState(() => _loadingMatches = false);
        return;
      }
      _myProfile = me;

      final myInterests = List<String>.from((me['interests'] as List?) ?? []);
      final myPersonality = (me['personality'] as String?) ?? '';
      final myLookingFor =
          List<String>.from((me['looking_for'] as List?) ?? []);
      final myAvailability =
          List<String>.from((me['availability'] as List?) ?? []);
      final myLat = double.tryParse(me['lat']?.toString() ?? '');
      final myLng = double.tryParse(me['lng']?.toString() ?? '');

      // Get active city for filtering
      final activeCity = locationService.activeLocation.isNotEmpty
          ? locationService.activeLocation.toLowerCase()
          : (me['city']?.toString().toLowerCase() ?? '');

      // Load all other profiles
      final others = await Supabase.instance.client
          .from('profiles')
          .select()
          .neq('id', uid)
          .limit(100);

      final List<Map<String, dynamic>> scored = [];
      for (final p in (others as List)) {
        final theirInterests =
            List<String>.from((p['interests'] as List?) ?? []);
        final theirPersonality = (p['personality'] as String?) ?? '';
        final theirLookingFor =
            List<String>.from((p['looking_for'] as List?) ?? []);
        final theirAvailability =
            List<String>.from((p['availability'] as List?) ?? []);
        final theirLat = double.tryParse(p['lat']?.toString() ?? '');
        final theirLng = double.tryParse(p['lng']?.toString() ?? '');

        // Skip profiles with no interests
        if (theirInterests.isEmpty) continue;

        // Compute score
        final interestScore = _jaccard(myInterests, theirInterests);
        final personalityScore =
            (myPersonality.isNotEmpty && myPersonality == theirPersonality)
                ? 1.0
                : 0.0;
        final lookingForScore = _jaccard(myLookingFor, theirLookingFor);
        final availabilityScore = _jaccard(myAvailability, theirAvailability);
        double proximityScore = 0.5; // default mid
        if (myLat != null &&
            myLng != null &&
            theirLat != null &&
            theirLng != null) {
          final dist = _haversine(myLat, myLng, theirLat, theirLng);
          proximityScore = dist < 5
              ? 1.0
              : dist < 20
                  ? 0.8
                  : dist < 50
                      ? 0.6
                      : dist < 100
                          ? 0.4
                          : 0.2;
        }

        final total = (interestScore * 0.40) +
            (personalityScore * 0.15) +
            (lookingForScore * 0.20) +
            (availabilityScore * 0.15) +
            (proximityScore * 0.10);
        final pct = (total * 100).clamp(5, 98).round();

        // Build "why" description
        final shared =
            myInterests.where((i) => theirInterests.contains(i)).toList();
        String why = '';
        if (shared.isNotEmpty) {
          why =
              '${shared.length} shared interest${shared.length > 1 ? 's' : ''}';
          if (shared.length <= 2) why += ' (${shared.join(", ")})';
        }
        if (myPersonality.isNotEmpty && myPersonality == theirPersonality) {
          why += why.isNotEmpty ? ' ï¿½ Same vibe' : 'Same personality';
        }
        final sharedLF =
            myLookingFor.where((l) => theirLookingFor.contains(l)).toList();
        if (sharedLF.isNotEmpty) {
          why += why.isNotEmpty ? ' ï¿½ Similar goals' : 'Similar goals';
        }
        if (why.isEmpty) why = 'Nearby & available';

        scored.add({
          'id': p['id'],
          'name': p['name'] ?? p['full_name'] ?? 'User',
          'avatar':
              p['avatar_url'] ?? 'https://picsum.photos/seed/${p['id']}/200',
          'city': p['city'] ?? '',
          'pct': pct,
          'why': why,
          'lat': p['lat'],
          'lng': p['lng'],
          'interests': theirInterests,
          'bio': p['bio'] ?? '',
          'age': p['age'] ?? 22,
          'gender': p['gender'] ?? '',
          'personality': theirPersonality,
          'looking_for': theirLookingFor,
          'availability': theirAvailability,
          'height_cm': p['height_cm'],
          'smoking': p['smoking'] ?? '',
          'drinking': p['drinking'] ?? '',
          'weed': p['weed'] ?? '',
          'diet': p['diet'] ?? '',
          'exercise': p['exercise'] ?? '',
          'education': p['education'] ?? '',
          'job_title': p['job_title'] ?? '',
          'zodiac': p['zodiac'] ?? '',
          'relationship_type': p['relationship_type'] ?? '',
          'religion': p['religion'] ?? '',
          'match_gender': p['match_gender'] ?? '',
          'personality_traits': (p['personality_traits'] as List?)?.cast<String>() ?? [],
        });
      }

      scored.sort((a, b) => (b['pct'] as int).compareTo(a['pct'] as int));

      // Filter by active city — prefer same-city matches
      List<Map<String, dynamic>> finalMatches;
      if (activeCity.isNotEmpty) {
        final sameCity = scored.where((m) {
          final c = (m['city'] as String).toLowerCase();
          return c.contains(activeCity) || activeCity.contains(c);
        }).toList();
        finalMatches = sameCity.length >= 3 ? sameCity : scored;
      } else {
        finalMatches = scored;
      }

      if (mounted) {
        setState(() {
          _aiMatches = finalMatches;
          _loadingMatches = false;
        });
      }
    } catch (e) {
      debugPrint('AI Matching error: $e');
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  double _jaccard(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    final setA = a.toSet();
    final setB = b.toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0 : intersection / union;
  }

  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Radius of the earth in km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final d = r * c;
    return d; // Distance in km
  }

  // AI scoring continues to use high-precision proximity logic
  double _haversine(double lat1, double lon1, double lat2, double lon2) =>
      _getDistance(lat1, lon1, lat2, lon2);

  void _showMatchDetail(Map<String, dynamic> m) {
    final pct = m['pct'] as int;
    final hue = pct > 75
        ? 160.0
        : pct > 50
            ? 45.0
            : 0.0;
    final ringColor = HSLColor.fromAHSL(1, hue, 0.8, 0.55).toColor();
    final interests = List<String>.from(m['interests'] ?? []);
    final myInterests =
        List<String>.from((_myProfile?['interests'] as List?) ?? []);
    final shared = myInterests.where((i) => interests.contains(i)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D12),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            // Avatar + Percentage
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [
                      ringColor,
                      ringColor.withValues(alpha: 0.15),
                      ringColor
                    ]),
                  ),
                ),
                CircleAvatar(
                    radius: 44,
                    backgroundImage:
                        _buildSafeImageProvider(m['avatar'] as String),
                    backgroundColor: const Color(0xFF1A1A2E)),
                Positioned(
                  bottom: 0,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: ringColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: ringColor.withValues(alpha: 0.5),
                              blurRadius: 8)
                        ]),
                    child: Text('$pct%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(m['name'] as String,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 22)),
            const SizedBox(height: 4),
            Text(m['city'] as String,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            if ((m['bio'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(m['bio'] as String,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.black54,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            // Match Breakdown
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ringColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ringColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: ringColor, size: 16),
                      const SizedBox(width: 8),
                      Text('Why you match',
                          style: TextStyle(
                              color: ringColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (shared.isNotEmpty)
                    _matchRow(Icons.interests,
                        'Shared interests: ${shared.join(", ")}', ringColor),
                  // SHOW DISTANCE GAP IN AI MATCH
                  _matchRow(Icons.near_me,
                      'Distance Gap: ${_getDisplayDistance(m)} km', ringColor),
                  if (m['personality'] == (_myProfile?['personality'] ?? ''))
                    _matchRow(Icons.psychology, 'Both ${m['personality']}s',
                        ringColor),
                  if ((m['looking_for'] as List?)?.any((l) =>
                      ((_myProfile?['looking_for'] as List?) ?? [])
                          .contains(l)) ?? false)
                    _matchRow(Icons.handshake, 'Similar goals', ringColor),
                  if ((m['availability'] as List?)?.any((a) =>
                      ((_myProfile?['availability'] as List?) ?? [])
                          .contains(a)) ?? false)
                    _matchRow(
                        Icons.schedule, 'Available at same times', ringColor),
                ],
              ),
            ),
            if (m['zodiac']?.toString().isNotEmpty == true || m['education']?.toString().isNotEmpty == true || m['job_title']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.person_search, color: Colors.white70, size: 16), SizedBox(width: 8), Text('More about them', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14))]),
                    const SizedBox(height: 12),
                    if (m['zodiac']?.toString().isNotEmpty == true) _matchRow(Icons.nights_stay, 'Zodiac: ${m['zodiac']}', Colors.purpleAccent),
                    if (m['education']?.toString().isNotEmpty == true) _matchRow(Icons.school, 'Education: ${m['education']}', Colors.blueAccent),
                    if (m['job_title']?.toString().isNotEmpty == true) _matchRow(Icons.work, 'Job: ${m['job_title']}', Colors.orangeAccent),
                    if (m['drinking']?.toString().isNotEmpty == true && m['drinking'] != 'No') _matchRow(Icons.local_bar, 'Drinks: ${m['drinking']}', Colors.pinkAccent),
                    if (m['smoking']?.toString().isNotEmpty == true && m['smoking'] != 'No') _matchRow(Icons.smoking_rooms, 'Smokes: ${m['smoking']}', Colors.grey),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Interests chips
            if (interests.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests.map((i) {
                  final isShared = shared.contains(i);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isShared
                          ? ringColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isShared
                              ? ringColor.withValues(alpha: 0.5)
                              : Colors.white10),
                    ),
                    child: Text(i,
                        style: TextStyle(
                            color: isShared ? ringColor : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            // Action button - Knock or Message (if already matched)
            FutureBuilder<bool>(
              future: () async {
                final uid = Supabase.instance.client.auth.currentUser?.id;
                if (uid == null) return false;
                // Check if mutual knock exists
                final myKnock = await Supabase.instance.client
                    .from('requests').select('id')
                    .eq('sender_id', uid).eq('target_id', m['id']).eq('target_type', 'profile').maybeSingle();
                final theirKnock = await Supabase.instance.client
                    .from('requests').select('id')
                    .eq('sender_id', m['id']).eq('target_id', uid).eq('target_type', 'profile').maybeSingle();
                return myKnock != null && theirKnock != null;
              }(),
              builder: (context, snap) {
                final isMutual = snap.data == true;
                return Row(
                  children: [
                    if (isMutual) ...[
                      // Mutual match — show Send Message
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                targetUserId: m['id'] as String,
                                name: m['name'] as String,
                                avatarUrl: (m['avatar'] ?? m['avatar_url'] ?? 'https://picsum.photos/seed/${m['id']}/200') as String,
                                isUnlocked: true,
                              ),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 8)],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Send Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Not mutual — show Knock button only
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            ProfileCompletionService.requireCompleteProfile(context, onComplete: () async {
                            final uid = Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) return;
                            try {
                              // Check if already knocked
                              final existing = await Supabase.instance.client
                                  .from('requests').select('id')
                                  .eq('sender_id', uid).eq('target_id', m['id']).eq('target_type', 'profile').maybeSingle();
                              if (existing != null) {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('You already knocked this person! Wait for them to knock back 🚪'),
                                    backgroundColor: Color(0xFFF59E0B),
                                  ));
                                }
                                return;
                              }

                              await Supabase.instance.client.from('requests').insert({
                                'sender_id': uid,
                                'target_id': m['id'],
                                'target_type': 'profile',
                                'status': 'pending',
                              });

                              // Check if they already knocked us → mutual match!
                              final theirKnock = await Supabase.instance.client
                                  .from('requests').select('id')
                                  .eq('sender_id', m['id']).eq('target_id', uid).eq('target_type', 'profile').maybeSingle();

                              if (theirKnock != null) {
                                // Mutual match! Auto-approve both
                                await Supabase.instance.client.from('requests').update({'status': 'approved'})
                                    .match({'target_type': 'profile'})
                                    .or('and(sender_id.eq.$uid,target_id.eq.${m['id']}),and(sender_id.eq.${m['id']},target_id.eq.$uid)');
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _matchedProfile = m;
                                    _showMatchOverlay = true;
                                  });
                                }
                              } else {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Knock sent to ${m['name']}! 🚪'),
                                    backgroundColor: const Color(0xFFFF7E40),
                                  ));
                                }
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Failed: $e'),
                                    backgroundColor: const Color(0xFFE11D48)));
                              }
                            }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF7E40), Color(0xFFFF3D00)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: const Color(0xFFFF7E40).withValues(alpha: 0.3), blurRadius: 8)],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.waving_hand, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Knock 🚪', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // -- Match detail row helper
  Widget _matchRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  // -- Artwork dispatcher ------------------------------------------------------
  Widget _getVibeArtwork(String label) {
    final l = label.trim().toLowerCase();
    switch (l) {
      case 'study':
        return const StudyArtwork();
      case 'fitness':
        return const FitnessArtwork();
      case 'music':
        return const MusicArtwork();
      case 'startup':
        return const StartupArtwork();
      case 'travel':
        return const TravelArtwork();
      case 'gaming':
        return const GamingArtwork();
      case 'photography':
        return const PhotoArtwork();
      case 'cooking':
        return const CookingArtwork();
      case 'perform':
        return const ArtArtwork();
      case 'tech & ai':
        return const TechArtwork();
      case 'dating':
        return const DatingArtwork();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInterestPicker() {
    final nearbyCount = 50 + math.Random().nextInt(15);
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
          ),
        ),
        SafeArea(
          key: const ValueKey('interests'),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // EXPLORE title matched to other main headers
                      Expanded(
                        child: Text(
                          'EXPLORE',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.0,
                            height: 1.0,
                          ),
                        ),
                      ),
                      // Action buttons
                      const AppHeaderActions(),
                    ],
                  ),
                ),
              ),
              // â”€â”€ Active nearby pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2B22),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color:
                              const Color(0xFF38D9A9).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF22C55E), shape: BoxShape.circle),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.6, 1.6),
                            duration: 900.ms),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$nearbyCount people',
                                style: const TextStyle(
                                    color: Color(0xFF38D9A9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800),
                              ),
                              const TextSpan(
                                text: ' active nearby',
                                style: TextStyle(
                                    color: Color(0xFF38D9A9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.location_on,
                            color: Color(0xFF38D9A9), size: 18),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms)
                      .slideX(begin: -0.05, end: 0),
                ),
              ),
              // â”€â”€ People Nearby â€” Random Swipe Deck â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF38D9A9), Color(0xFF4361EE)]),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.people_alt,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('People Nearby',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_loadingRandom)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF38D9A9)))
                      else
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _randomProfiles = [];
                              _randomIdx = 0;
                            });
                            _loadRandomProfiles();
                          },
                          child: const Icon(Icons.refresh_rounded,
                              color: Colors.white38, size: 22),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 340,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _loadingRandom
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF38D9A9)))
                      : _randomIdx >= _randomProfiles.length
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline,
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      size: 60),
                                  const SizedBox(height: 12),
                                  const Text('No more profiles nearby',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 14)),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _randomProfiles = [];
                                        _randomIdx = 0;
                                      });
                                      _loadRandomProfiles();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Color(0xFF38D9A9),
                                          Color(0xFF4361EE)
                                        ]),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text('Refresh',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildRandomDeck(),
                ).animate().fadeIn(delay: 200.ms),
              ),
              // Pick Your Vibe header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pick Your Vibe',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () => _selectInterest('Explore All'),
                        child: const Text('See All ï¿½',
                            style: TextStyle(
                                color: Color(0xFF38D9A9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              // Vibe Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.78),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final nonWide =
                          _interests.where((v) => v['wide'] != true).toList();
                      if (index >= nonWide.length) return null;
                      final v = nonWide[index];
                      return _VibeCard(
                        label: v['label'] as String,
                        icon: v['icon'] as IconData,
                        tagline: v['tagline'] as String,
                        c1: Color(v['c1'] as int),
                        c2: Color(v['c2'] as int),
                        activeCount: v['active'] as int,
                        activity: v['activity'] as String? ?? 'active now',
                        users: (v['users'] as List).cast<String>(),
                        userColors: (v['userColors'] as List).cast<int>(),
                        extra: v['extra'] as int? ?? 0,
                        artwork: _getVibeArtwork(v['label'] as String),
                        onTap: () => _selectInterest(v['label'] as String),
                      );
                    },
                    childCount:
                        _interests.where((v) => v['wide'] != true).length,
                  ),
                ),
              ),
              // Dating wide card
              SliverToBoxAdapter(
                child: Builder(builder: (context) {
                  final dating = _interests.firstWhere(
                      (v) => v['label'] == 'Dating',
                      orElse: () => {});
                  if (dating.isEmpty) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    child: _VibeCard(
                      label: 'Dating',
                      icon: dating['icon'] as IconData,
                      tagline: dating['tagline'] as String,
                      c1: Color(dating['c1'] as int),
                      c2: Color(dating['c2'] as int),
                      activeCount: dating['active'] as int,
                      activity:
                          dating['activity'] as String? ?? 'finding love now',
                      users: (dating['users'] as List).cast<String>(),
                      userColors: (dating['userColors'] as List).cast<int>(),
                      extra: dating['extra'] as int? ?? 0,
                      artwork: _getVibeArtwork('Dating'),
                      onTap: () => _selectInterest('Dating'),
                      isWide: true,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRandomDeck() {
    final profiles = _randomProfiles;
    if (_randomIdx >= profiles.length) return const SizedBox.shrink();
    final current = profiles[_randomIdx];
    final hasNext = _randomIdx + 1 < profiles.length;
    final hasNextNext = _randomIdx + 2 < profiles.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Third card (furthest back)
        if (hasNextNext)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Transform.scale(
                scale: 0.88,
                child: Opacity(
                  opacity: 0.2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: const Color(0xFF1A1A2E),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Second card (behind)
        if (hasNext)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Transform.scale(
                scale: 0.94,
                child: Opacity(
                  opacity: 0.4,
                  child: _buildDeckCard(profiles[_randomIdx + 1], isBg: true),
                ),
              ),
            ),
          ),

        // Main swipeable card
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (_) => setState(() => _randomDragging = true),
            onPanUpdate: (d) => setState(() {
              _randomDragX += d.delta.dx;
              _randomDragY += d.delta.dy;
            }),
            onPanEnd: (_) => _onRandomSwipeComplete(current),
            onTap: () => _showFullProfile(current),
            child: AnimatedContainer(
              duration: _randomDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()
                ..setTranslationRaw(_randomDragX, _randomDragY * 0.3, 0.0)
                ..rotateZ(_randomDragX * 0.0008),
              transformAlignment: Alignment.center,
              child: Stack(
                children: [
                  _buildDeckCard(current, isBg: false),

                  // KNOCK overlay (right swipe)
                  if (_randomDragX > 40)
                    Positioned(
                      top: 60,
                      left: 30,
                      child: Transform.rotate(
                        angle: -0.3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF10B981), width: 3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('KNOCK ðŸšª',
                              style: TextStyle(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  shadows: [
                                    Shadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 15)
                                  ])),
                        ),
                      ),
                    ),

                  // PASS overlay (left swipe)
                  if (_randomDragX < -40)
                    Positioned(
                      top: 60,
                      right: 30,
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFEF4444), width: 3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('PASS âœ•',
                              style: TextStyle(
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  shadows: [
                                    Shadow(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 15)
                                  ])),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCard(Map<String, dynamic> p, {required bool isBg}) {
    final name = p['name'] ?? 'User';
    final age = p['age'] ?? 22;
    final interests = (p['interests'] as List?)?.cast<String>() ?? [];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withValues(alpha: isBg ? 0.05 : 0.12)),
        boxShadow: [
          BoxShadow(
              color:
                  const Color(0xFFFF6B00).withValues(alpha: isBg ? 0.05 : 0.15),
              blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildSafeImage(p['avatar'],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF1a1a2e))),
            // Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.95)
                    ],
                  ),
                ),
              ),
            ),
            // Info
            Positioned(
              bottom: 16,
              left: 18,
              right: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$name, ',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('$age',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                              color: Colors.white70)),
                    ],
                  ),
                  if (p['city'] != null && p['city'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFFFF6B00), size: 12),
                      const SizedBox(width: 3),
                      Text(p['city'].toString(),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: interests
                        .take(3)
                        .map<Widget>((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFF6B00)),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchShimmer() {
    return Container(
      width: 165,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds);
  }

  Widget _buildMatchCard(Map<String, dynamic> m) {
    final initial = (m['name'] as String? ?? '?').isNotEmpty
        ? (m['name'] as String)[0].toUpperCase()
        : '?';
    final pct = m['pct'] as int? ?? 0;
    final why = m['why'] as String? ?? 'Similar vibe';
    final city = m['city'] as String? ?? '';
    final avatarUrl = m['avatar'] as String? ?? '';

    // Ring color based on pct: gold >= 60, red < 50, amber in between
    final ringColor = pct >= 60
        ? const Color(0xFFD4AF37)
        : pct >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFE11D48);

    final tagColor = pct >= 60
        ? const Color(0xFF78350F)
        : pct >= 50
            ? const Color(0xFF92400E)
            : const Color(0xFF7F1D1D);

    return GestureDetector(
      onTap: () => _showMatchDetail(m),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111122),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Avatar with colored ring and % badge
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Outer ring
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        ringColor,
                        ringColor.withValues(alpha: 0.2),
                        ringColor
                      ],
                    ),
                  ),
                ),
                // White gap
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF111122)),
                ),
                // Avatar
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFFF5C00),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? _buildSafeImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 24))
                      : null,
                ),
                // % badge at bottom of avatar
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: ringColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('$pct%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(m['name'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 3),
            // City
            if (city.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11.5)),
              ),
            const Spacer(),
            // Coloured tag at bottom
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(why,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 80.ms).scale(begin: const Offset(0.96, 0.96)),
    );
  }

  ImageProvider _buildSafeImageProvider(String url) {
    if (url.startsWith('data:image')) {
      final b64 = url.split(',').last;
      return MemoryImage(base64Decode(b64));
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return const NetworkImage('https://picsum.photos/200');
  }

  String _getInterestTagline(String label) {
    final i =
        _interests.firstWhere((e) => e['label'] == label, orElse: () => {});
    return i['tagline']?.toString() ?? 'Explore the vibe';
  }

  String _getVibeCount(String label) {
    final i =
        _interests.firstWhere((e) => e['label'] == label, orElse: () => {});
    return '${i['active'] ?? 0}';
  }

  void _onSwipeRight(Map<String, dynamic> p) async {
    ProfileCompletionService.requireCompleteProfile(context, onComplete: () async {
    HapticFeedback.mediumImpact();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await Supabase.instance.client.from('requests').insert({
        'sender_id': uid,
        'target_id': p['id'],
        'target_type': 'profile',
        'status': 'pending',
      });

      // Notify the target user that they've been knocked on
      NotificationService.sendNotification(
        userId: p['id'].toString(),
        type: NotificationType.match,
        title: 'Someone is knocking! ??',
        body: 'A profile nearby is interested in connecting.',
        payload: {'sender_id': uid},
      );

      // Check for mutual knock (MATCH!)
      final mutual = await Supabase.instance.client
          .from('requests')
          .select()
          .eq('sender_id', p['id'])
          .eq('target_id', uid)
          .eq('target_type', 'profile')
          .maybeSingle();

      if (mutual != null && mounted) {
        // Auto-approve both requests for mutual match
        await Supabase.instance.client.from('requests').update({
          'status': 'approved'
        }).match({'target_type': 'profile'}).or(
            'and(sender_id.eq.$uid,target_id.eq.${p['id']}),and(sender_id.eq.${p['id']},target_id.eq.$uid)');

        setState(() {
          _matchedProfile = p;
          _showMatchOverlay = true;
        });

        // Trigger notifications for both users
        NotificationService.sendNotification(
          userId: uid,
          type: NotificationType.match,
          title: 'New Match! ??',
          body: 'You and ${p['name']} knocked each other!',
          payload: {'sender_id': p['id']},
        );
        NotificationService.sendNotification(
          userId: p['id'].toString(),
          type: NotificationType.match,
          title: 'New Match! ??',
          body: 'Someone you knocked just knocked back!',
          payload: {'sender_id': uid},
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Knocked ${p['name']}! ??'),
            backgroundColor: const Color(0xFFFF8A00),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Knocked! ??'),
              backgroundColor: Color(0xFFFF8A00),
              duration: Duration(seconds: 1)),
        );
      }
    }
    _nextProfile();
    });
  }

  void _onSwipeLeft(Map<String, dynamic> p) {
    HapticFeedback.lightImpact();
    _nextProfile();
  }

  void _onSwipeComplete(Map<String, dynamic> p) {
    if (_dragX > 120) {
      _onSwipeRight(p);
    } else if (_dragX < -120) {
      _onSwipeLeft(p);
    }
    setState(() {
      _dragX = 0;
      _dragY = 0;
      _isDragging = false;
    });
  }

  Widget _buildProfileView() {
    final profiles = _profilesFor(_selectedInterest);
    final outOfProfiles = _profileIdx >= profiles.length;

    return Stack(
      children: [
        SafeArea(
          key: const ValueKey('profiles'),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => _view = _DiscoverView.interests),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFFFF6B00).withValues(alpha: 0.4)),
                      ),
                      child: Text(_selectedInterest,
                          style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle),
                        child: Icon(Icons.tune,
                            color: _filterDistance < 100
                                ? const Color(0xFFFF6B00)
                                : Colors.white70,
                            size: 16),
                      ),
                    ),
                    const Spacer(),
                    Text('${profiles.length} profiles',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),

              // Horizontal Scrollable Location Filters (Near Me, NYC, LA, Miami, Chicago) with white borders
              SizedBox(
                height: 46,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: _locations.length,
                  itemBuilder: (context, idx) {
                    final loc = _locations[idx];
                    final isSelected = _selectedLocation == loc;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedLocation = loc;
                        });
                        if (loc == 'Near Me') {
                          _filterDistance = 100.0;
                          _loadProfilesForInterest(_selectedInterest);
                        } else {
                          _filterDistance = 25.0; // Simulate filters for selected city
                          _loadProfilesForInterest(_selectedInterest);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFF6B00) : Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFF6B00) : Colors.white,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            loc,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Swipeable Card Area
              Expanded(
                child: _loadingInterest
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFFFF6B00)))
                    : outOfProfiles
                        ? _buildEmptyProfiles()
                        : _buildSwipeStack(profiles),
              ),

              // Bottom Horizontal Interest Category/Vibe Row with Icons
              Container(
                height: 76,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                  ),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _bottomVibeIcon('Music', Icons.music_note, const Color(0xFFFF7E40)),
                    _bottomVibeIcon('Art', Icons.palette, const Color(0xFFD946EF)),
                    _bottomVibeIcon('Fitness', Icons.fitness_center, const Color(0xFFEF4444)),
                    _bottomVibeIcon('Food', Icons.restaurant, const Color(0xFFF97316)),
                    _bottomVibeIcon('Travel', Icons.flight, const Color(0xFF06B6D4)),
                    _bottomVibeIcon('Gaming', Icons.sports_esports, const Color(0xFF10B981)),
                    _bottomVibeIcon('Tech & AI', Icons.memory, const Color(0xFF6366F1)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Match Overlay
        if (_showMatchOverlay && _matchedProfile != null) _buildMatchOverlay(),
      ],
    );
  }

  Widget _bottomVibeIcon(String label, IconData icon, Color color) {
    final isSelected = _selectedInterest == label;
    return GestureDetector(
      onTap: () => _selectInterest(label),
      child: Container(
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: isSelected ? color : Colors.white70, size: 16),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white54,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeStack(List<Map<String, dynamic>> profiles) {
    final current = profiles[_profileIdx];
    final hasNext = _profileIdx + 1 < profiles.length;
    final hasNextNext = _profileIdx + 2 < profiles.length;

    return Stack(
      children: [
        // Third card
        if (hasNextNext)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 40, right: 40, top: 32, bottom: 95),
              child: Transform.scale(
                scale: 0.90,
                alignment: Alignment.bottomCenter,
                child: _buildProfileCard(profiles[_profileIdx + 2],
                    isBackground: true),
              ),
            ),
          ),

        // Second card
        if (hasNext)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 24, bottom: 95),
              child: Transform.scale(
                scale: 0.95,
                alignment: Alignment.bottomCenter,
                child: _buildProfileCard(profiles[_profileIdx + 1],
                    isBackground: true),
              ),
            ),
          ),

        // Main swipeable card
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 95),
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (d) {
                setState(() {
                  _dragX += d.delta.dx;
                  _dragY += d.delta.dy;
                });
              },
              onPanEnd: (_) => _onSwipeComplete(current),
              child: AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                transform: Matrix4.identity()
                  ..setTranslationRaw(_dragX, _dragY * 0.3, 0.0)
                  ..rotateZ(_dragX * 0.0008),
                transformAlignment: Alignment.center,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: _buildProfileCard(current, isBackground: false),
                    ),

                    // KNOCK overlay
                    Positioned(
                      top: 40,
                      left: 40,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Opacity(
                          opacity: (_dragX / 150).clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFFF6B00), width: 4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'KNOCK',
                              style: TextStyle(
                                color: Color(0xFFFF6B00),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // PASS overlay
                    Positioned(
                      top: 40,
                      right: 40,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Opacity(
                          opacity: (-_dragX / 150).clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFEF4444), width: 4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PASS',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom action buttons: 3 circular buttons (X, star, heart) centered perfectly
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pass Button (X dismiss, circular outline)
              GestureDetector(
                onTap: () => _onSwipeLeft(current),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 24),
              // Super Knock (Star)
              GestureDetector(
                onTap: () {
                  ProfileCompletionService.requireCompleteProfile(context, onComplete: () async {
                    HapticFeedback.heavyImpact();
                    final uid = Supabase.instance.client.auth.currentUser?.id;
                    if (uid == null) return;
                    try {
                      await Supabase.instance.client.from('requests').insert({
                        'sender_id': uid,
                        'target_id': current['id'],
                        'target_type': 'profile',
                        'status': 'pending',
                        'message': 'Super Knock! ⭐',
                      });
                    } catch (_) {}
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Super Knocked ${current['name']}! ⭐'),
                            backgroundColor: const Color(0xFFFF7E40),
                            duration: const Duration(seconds: 1)),
                      );
                    }
                    _nextProfile();
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFF6B00), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                          blurRadius: 10)
                    ],
                  ),
                  child: const Icon(Icons.star, color: Color(0xFFFF6B00), size: 24),
                ),
              ),
              const SizedBox(width: 24),
              // Knock Button (Heart)
              GestureDetector(
                onTap: () => _onSwipeRight(current),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFFF6B00).withValues(alpha: 0.35),
                          blurRadius: 14)
                    ],
                  ),
                  child: const Icon(Icons.favorite,
                      color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> p,
      {required bool isBackground}) {
    return GestureDetector(
      onTap: () => _showFullProfile(p),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF6B00)
                    .withValues(alpha: isBackground ? 0.05 : 0.15),
                blurRadius: 24),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildSafeImage(p['avatar'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF1a1a2e))),
              // Bottom gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 320,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.95)
                      ],
                    ),
                  ),
                ),
              ),
              // Info
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${p['name'] ?? 'User'}, ',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('${p['age'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w300,
                                color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFFFF6B00), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_getDisplayDistance(p)} miles · ${p['city'] ?? 'Brooklyn, NY'}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(p['bio'] ?? '',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    // Orange-outlined interest tags inside card
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ((p['interests'] as List?) ?? [])
                          .take(3)
                          .map<Widget>((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B00),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  t.toString(),
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchOverlay() {
    final p = _matchedProfile!;
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sparkling header
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(colors: [
                Color(0xFFFF6B00),
                Color(0xFFFF7E40),
                Color(0xFFFF3D00)
              ]).createShader(bounds),
              child: const Text("It's a Match! ??",
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(height: 12),
            Text('You and ${p['name']} knocked each other!',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),
            // Avatars row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFF6B00), width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                          blurRadius: 20)
                    ],
                  ),
                  child: ClipOval(
                      child: _buildSafeImage(
                          _myProfile?['avatar_url'] ??
                              'https://picsum.photos/seed/me/200',
                          fit: BoxFit.cover)),
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF3D00).withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.favorite,
                      color: Color(0xFFFF3D00), size: 28),
                ),
                const SizedBox(width: 24),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFF7E40), width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF7E40).withValues(alpha: 0.4),
                          blurRadius: 20)
                    ],
                  ),
                  child: ClipOval(
                      child: _buildSafeImage(
                          p['avatar'] ??
                              'https://picsum.photos/seed/${p['id']}/200',
                          fit: BoxFit.cover)),
                ),
              ],
            ),
            const SizedBox(height: 50),
            // Send Message CTA
            GestureDetector(
              onTap: () {
                // Navigate directly to the chat BEFORE clearing overlay state to avoid flickering or tab resets
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        targetUserId: p['id']?.toString() ?? '',
                        name: p['name'] ?? 'User',
                        avatarUrl: p['avatar'] ??
                            'https://picsum.photos/seed/${p['id']}/200',
                        isUnlocked: true, // Mutual match unlocks chat
                      ),
                    )).then((_) {
                  // Clear overlay when coming back if still needed
                  if (mounted) {
                    setState(() {
                      _showMatchOverlay = false;
                      _matchedProfile = null;
                    });
                  }
                });
                // Also clear immediately so the overlay disappears while navigating
                setState(() {
                  _showMatchOverlay = false;
                  _matchedProfile = null;
                });
              },
              child: Container(
                width: 260,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                        blurRadius: 16)
                  ],
                ),
                child: const Center(
                    child: Text('Send a Message',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17))),
              ),
            ),
            const SizedBox(height: 16),
            // Keep Swiping
            GestureDetector(
              onTap: () => setState(() {
                _showMatchOverlay = false;
                _matchedProfile = null;
              }),
              child: Container(
                width: 260,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(
                    child: Text('Keep Swiping',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w600,
                            fontSize: 15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProfiles() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              color: Colors.white.withValues(alpha: 0.15), size: 80),
          const SizedBox(height: 16),
          const Text('No more profiles',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Check back later for new people!',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _view = _DiscoverView.interests),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF38D9A9), Color(0xFF4361EE)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Explore Vibes',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayDistance(Map<String, dynamic> p) {
    double? tLat;
    double? tLng;

    // 1. Use target's stored coordinates
    final targetLatRaw = p['lat'];
    final targetLngRaw = p['lng'];
    if (targetLatRaw != null && targetLngRaw != null) {
      tLat = double.tryParse(targetLatRaw.toString());
      tLng = double.tryParse(targetLngRaw.toString());
    }

    // 2. Use the user's actual profile location or live GPS (ignore search city spoofing)
    final myProfileLat = double.tryParse(_myProfile?['lat']?.toString() ?? '');
    final myProfileLng = double.tryParse(_myProfile?['lng']?.toString() ?? '');
    
    final mLat = myProfileLat ?? _myLat;
    final mLng = myProfileLng ?? _myLng;

    if (tLat == null || tLng == null || mLat == null || mLng == null) {
      return '?';
    }

    final km = _getDistance(mLat, mLng, tLat, tLng);
    if (km < 1.0) return '< 1';
    return km.toStringAsFixed(1);
  }

  // -- Full Profile Detail ----------------------------------------------------------
  void _showFullProfile(Map<String, dynamic> p) {
    final TextEditingController complimentCtrl = TextEditingController();
    bool isSendingCompliment = false;
    bool complimentSent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.95,
        builder: (_, scroll) => Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D12),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CosmicBackgroundPainter(0.5),
                      ),
                    ),
                    ListView(
                      controller: scroll,
                      padding: EdgeInsets.zero,
                      children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  // Large Photo
                  Container(
                    height: 420,
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image:
                          (p['avatar'] != null && p['avatar'].toString().isNotEmpty)
                              ? DecorationImage(
                                  image: _buildSafeImageProvider(p['avatar']),
                                  fit: BoxFit.cover)
                              : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${p['name'] ?? 'User'}, ',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('${p['age'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70)),
                      ],
                    ),
                  ),

                  // About Me
                  if ((p['bio']?.toString().isNotEmpty ?? false) || (p['about']?.toString().isNotEmpty ?? false))
                    _buildProfileSection('About me', Icons.format_quote_rounded, [
                      Text(p['bio'] ?? p['about'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                    ]),

                  // Essentials
                  _buildProfileSection('Essentials', Icons.assignment_outlined, [
                    _buildDetailRow(Icons.location_on_outlined, '${_getDisplayDistance(p)} km away'),
                    if (p['height_cm'] != null && p['height_cm'] > 0)
                      _buildDetailRow(Icons.height, '${p['height_cm']} cm'),
                    if (p['gender'] != null && p['gender'].toString().isNotEmpty)
                      _buildDetailRow(Icons.person_outline, p['gender']),
                    if (p['match_gender'] != null && p['match_gender'].toString().isNotEmpty)
                      _buildDetailRow(Icons.search, 'Looking for ${p['match_gender']}'),
                  ]),

                  // Personality Prompt
                  if ((p['personality_traits'] as List?)?.isNotEmpty ?? false)
                    _buildProfileSection('My personality', Icons.psychology_outlined, [
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: (p['personality_traits'] as List).map<Widget>((t) => _buildPill(t.toString(), isHighlight: true)).toList(),
                      )
                    ]),

                  // Lifestyle
                  if (_hasLifestyle(p))
                    _buildProfileSection('Lifestyle', Icons.local_cafe_outlined, [
                      if (p['drinking'] != null && p['drinking'].toString().isNotEmpty)
                        _buildDetailRow(Icons.wine_bar_outlined, p['drinking'], subtitle: 'Drinking'),
                      if (p['smoking'] != null && p['smoking'].toString().isNotEmpty)
                        _buildDetailRow(Icons.smoking_rooms_outlined, p['smoking'], subtitle: 'Smoking'),
                      if (p['weed'] != null && p['weed'].toString().isNotEmpty)
                        _buildDetailRow(Icons.grass_outlined, p['weed'], subtitle: 'Cannabis'),
                      if (p['exercise'] != null && p['exercise'].toString().isNotEmpty)
                        _buildDetailRow(Icons.fitness_center_outlined, p['exercise'], subtitle: 'Workout'),
                      if (p['diet'] != null && p['diet'].toString().isNotEmpty)
                        _buildDetailRow(Icons.restaurant_outlined, p['diet'], subtitle: 'Diet'),
                    ]),

                  // More about me
                  if (_hasMoreAboutMe(p))
                    _buildProfileSection('More about me', Icons.info_outline, [
                      if (p['education'] != null && p['education'].toString().isNotEmpty)
                        _buildDetailRow(Icons.school_outlined, p['education'], subtitle: 'Education'),
                      if (p['job_title'] != null && p['job_title'].toString().isNotEmpty)
                        _buildDetailRow(Icons.work_outline, p['job_title'], subtitle: 'Work'),
                      if (p['zodiac'] != null && p['zodiac'].toString().isNotEmpty)
                        _buildDetailRow(Icons.auto_awesome_outlined, p['zodiac'], subtitle: 'Zodiac'),
                      if (p['religion'] != null && p['religion'].toString().isNotEmpty)
                        _buildDetailRow(Icons.church_outlined, p['religion'], subtitle: 'Religion'),
                      if (p['relationship_type'] != null && p['relationship_type'].toString().isNotEmpty)
                        _buildDetailRow(Icons.favorite_border, p['relationship_type'], subtitle: 'Looking for'),
                    ]),

                  // Interests
                  if ((p['interests'] as List?)?.isNotEmpty ?? false)
                    _buildProfileSection('Interests', Icons.grid_view_rounded, [
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: (p['interests'] as List).map<Widget>((t) => _buildPill(t.toString(), isInterest: true)).toList(),
                      )
                    ]),

                  // Compliment Form
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(' Send a Compliment',
                            style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
                            ],
                          ),
                          child: complimentSent 
                          ? const Center(
                              child: Column(
                                children: [
                                  SizedBox(height: 16),
                                  Icon(Icons.favorite, color: Color(0xFFFF3D00), size: 40),
                                  SizedBox(height: 12),
                                  Text('Compliment Sent!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  SizedBox(height: 8),
                                  Text('They will see it in their messages.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  SizedBox(height: 16),
                                ],
                              ),
                            )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: complimentCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Say something nice...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: isSendingCompliment ? null : () async {
                                  if (complimentCtrl.text.trim().isEmpty) return;
                                  setSheetState(() => isSendingCompliment = true);
                                  try {
                                    final myUid = Supabase.instance.client.auth.currentUser?.id;
                                    final targetId = p['user_id']?.toString() ?? p['id']?.toString();
                                    if (myUid != null && targetId != null) {
                                      await Supabase.instance.client.from('messages').insert({
                                        'sender_id': myUid,
                                        'receiver_id': targetId,
                                        'text': '💌 Compliment: ${complimentCtrl.text.trim()}',
                                        'is_image': false,
                                        'created_at': DateTime.now().toUtc().toIso8601String(),
                                      });
                                      setSheetState(() {
                                        complimentSent = true;
                                        isSendingCompliment = false;
                                      });
                                    } else {
                                      setSheetState(() => isSendingCompliment = false);
                                    }
                                  } catch (e) {
                                    setSheetState(() => isSendingCompliment = false);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFFF3D00), Color(0xFFFF7E40)]),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFFFF3D00).withValues(alpha: 0.3), blurRadius: 8),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: isSendingCompliment
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Send Compliment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildActionButton('Share ${p['name'] ?? 'Profile'}', Colors.white, () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Profile link copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFF22C55E),
                          ));
                        }),
                        const SizedBox(height: 8),
                        _buildActionButton('Block ${p['name'] ?? 'User'}', Colors.white70, () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${p['name'] ?? 'User'} blocked. They will no longer appear in your feed.'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }),
                        const SizedBox(height: 8),
                        _buildActionButton('Report ${p['name'] ?? 'User'}', Colors.redAccent, () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Report submitted. Our team will review this profile.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.redAccent,
                          ));
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120), // padding for floating pass/knock buttons
                ],
              ),
                  ],
                ),
              ),
            ),

            // Floating Knock / Pass Buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF0D0D12),
                      const Color(0xFF0D0D12).withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_randomProfiles.contains(p)) {
                            _onRandomSwipeLeft(p);
                          } else {
                            _onSwipeLeft(p);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
                            ],
                          ),
                          child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close, color: Colors.white54, size: 20),
                                  SizedBox(width: 8),
                                  Text('Pass',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                ],
                              )),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_randomProfiles.contains(p)) {
                            _onRandomSwipeRight(p);
                          } else {
                            _onSwipeRight(p);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFF6B00),
                                Color(0xFF3B82F6)
                              ]),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6))
                              ]),
                          child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.waving_hand, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text('Knock',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                ],
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  bool _hasLifestyle(Map<String, dynamic> p) {
    return (p['drinking']?.toString().isNotEmpty ?? false) ||
           (p['smoking']?.toString().isNotEmpty ?? false) ||
           (p['weed']?.toString().isNotEmpty ?? false) ||
           (p['exercise']?.toString().isNotEmpty ?? false) ||
           (p['diet']?.toString().isNotEmpty ?? false);
  }

  bool _hasMoreAboutMe(Map<String, dynamic> p) {
    return (p['education']?.toString().isNotEmpty ?? false) ||
           (p['job_title']?.toString().isNotEmpty ?? false) ||
           (p['zodiac']?.toString().isNotEmpty ?? false) ||
           (p['religion']?.toString().isNotEmpty ?? false) ||
           (p['relationship_type']?.toString().isNotEmpty ?? false);
  }

  Widget _buildProfileSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF6B00), size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {String? subtitle}) {
    Color iconColor = Colors.white54;
    if (icon == Icons.location_on_outlined) {
      iconColor = const Color(0xFFFF6B00);
    } else if (icon == Icons.height) { iconColor = const Color(0xFFFACC15); }
    else if (icon == Icons.person_outline) { iconColor = const Color(0xFFFF3D00); }
    else if (icon == Icons.search) { iconColor = const Color(0xFF3B82F6); }
    else if (icon == Icons.wine_bar_outlined) { iconColor = const Color(0xFFEF4444); }
    else if (icon == Icons.smoking_rooms_outlined) { iconColor = const Color(0xFF9CA3AF); }
    else if (icon == Icons.grass_outlined) { iconColor = const Color(0xFF10B981); }
    else if (icon == Icons.fitness_center_outlined) { iconColor = const Color(0xFFF97316); }
    else if (icon == Icons.restaurant_outlined) { iconColor = const Color(0xFFEAB308); }
    else if (icon == Icons.school_outlined) { iconColor = const Color(0xFFFF7E40); }
    else if (icon == Icons.work_outline) { iconColor = const Color(0xFF06B6D4); }
    else if (icon == Icons.auto_awesome_outlined) { iconColor = const Color(0xFFD946EF); }
    else if (icon == Icons.church_outlined) { iconColor = const Color(0xFF38D9A9); }
    else if (icon == Icons.favorite_border) { iconColor = const Color(0xFFF43F5E); }
    else { iconColor = const Color(0xFFFF6B00); }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: subtitle != null ? CrossAxisAlignment.center : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, {bool isHighlight = false, bool isInterest = false, bool isSmall = false}) {
    Color pillColor = isHighlight ? const Color(0xFF38D9A9) : Colors.white70;
    Color bgColor = isHighlight ? const Color(0xFF38D9A9).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05);
    Color borderColor = isHighlight ? const Color(0xFF38D9A9).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08);
    IconData? icon;

    if (isInterest) {
      final lower = text.toLowerCase();
      if (lower.contains('study')) { icon = Icons.menu_book; pillColor = const Color(0xFF3B82F6); }
      else if (lower.contains('fit') || lower.contains('gym')) { icon = Icons.fitness_center; pillColor = const Color(0xFFEF4444); }
      else if (lower.contains('music')) { icon = Icons.music_note; pillColor = const Color(0xFFFF7E40); }
      else if (lower.contains('start') || lower.contains('busin')) { icon = Icons.rocket_launch; pillColor = const Color(0xFFF59E0B); }
      else if (lower.contains('travel')) { icon = Icons.flight; pillColor = const Color(0xFF06B6D4); }
      else if (lower.contains('game') || lower.contains('gaming')) { icon = Icons.sports_esports; pillColor = const Color(0xFF10B981); }
      else if (lower.contains('photo')) { icon = Icons.camera_alt; pillColor = const Color(0xFFFF3D00); }
      else if (lower.contains('cook') || lower.contains('food')) { icon = Icons.restaurant; pillColor = const Color(0xFFF97316); }
      else if (lower.contains('art') || lower.contains('paint')) { icon = Icons.palette; pillColor = const Color(0xFFD946EF); }
      else if (lower.contains('tech') || lower.contains('code')) { icon = Icons.memory; pillColor = const Color(0xFF6366F1); }
      else if (lower.contains('dance')) { icon = Icons.nightlife; pillColor = const Color(0xFFEAB308); }
      else if (lower.contains('read') || lower.contains('book')) { icon = Icons.auto_stories; pillColor = const Color(0xFF14B8A6); }
      else { icon = Icons.local_fire_department; pillColor = const Color(0xFFFF6B00); }
      
      bgColor = pillColor.withValues(alpha: 0.15);
      borderColor = pillColor.withValues(alpha: 0.4);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 14, 
        vertical: isSmall ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isSmall ? 12 : 20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: pillColor, size: isSmall ? 12 : 14),
            SizedBox(width: isSmall ? 4 : 6),
          ],
          Text(text, style: TextStyle(
            color: pillColor,
            fontSize: isSmall ? 11 : 13,
            fontWeight: isHighlight || isInterest ? FontWeight.w600 : FontWeight.w500,
          )),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0D0D12),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter & Sort',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _profileIdx = 0;
                            });
                          },
                          child: const Text('Apply',
                              style: TextStyle(
                                  color: Color(0xFFFF6B00),
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Distance Limit',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(
                          _filterDistance >= 100
                              ? 'Anywhere'
                              : '${_filterDistance.toInt()} km',
                          style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                      value: _filterDistance,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: const Color(0xFFFF6B00),
                      inactiveColor: Colors.white10,
                      onChanged: (v) {
                        setModalState(() => _filterDistance = v);
                        setState(() => _filterDistance = v);
                      }),
                  const SizedBox(height: 10),
                ],
              ),
            );
          });
        });
  }

  // -- Notifications & Premium --------------------------------------------------
  void _showNotifications() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _showIncomingKnock() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D0D12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Incoming Knock! ??',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      'https://picsum.photos/seed/secretknocker/300/300',
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Blur logic for non-premium
                  if (!_isPremium)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                              color: Colors.black.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                  if (!_isPremium)
                    const Icon(Icons.lock, color: Colors.white70, size: 48),
                ],
              ),
              const SizedBox(height: 24),
              if (_isPremium) ...[
                const Text('Alex, 22',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 8),
                const Text(
                    'Loves Coffee, Startup & Travel.\nLook like a match?',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Center(
                              child: Text('Pass',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Connection accepted! ??'),
                                  backgroundColor: Color(0xFFFF8A00)));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFF6B00),
                                Color(0xFFFF8A00)
                              ]),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Center(
                              child: Text('Let In ??',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text('Identity Hidden',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                const Text(
                    'Get Meetra Premium to instantly see who is knocking at your door.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    // Toggle Premium mock
                    setState(() => _isPremium = true);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Meetra Premium Activated! ?'),
                        backgroundColor: Color(0xFFFF7E40)));
                    _showIncomingKnock(); // re-open popup now that premium is active
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFFF7E40)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFFE11D48).withValues(alpha: 0.4),
                            blurRadius: 16)
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Unlock Premium',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Maybe Later',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// (MarketplaceScreen was replaced by ExperienceScreen module)

// ----------------------------------------------------
// 2. EXPLORE SCREEN — "Active / Inactive" Ecosystem
// ----------------------------------------------------
class ExploreScreen extends StatefulWidget {
  final VoidCallback onCreateTap;
  const ExploreScreen({super.key, required this.onCreateTap});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with TickerProviderStateMixin {
  final _currentUid = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = true;

  List<Map<String, dynamic>> _activeUsers = [];
  List<Map<String, dynamic>> _inactiveUsers = [];

  // Activities mapping for the "What's the move?" picker
  static const List<Map<String, dynamic>> _activities = [
    {'label': 'COFFEE', 'emoji': '☕', 'msg': "hang for coffee?"},
    {'label': 'FOOD', 'emoji': '🍕', 'msg': "hang for food?"},
    {'label': 'BIRYANI', 'emoji': '🍛', 'msg': "hang for biryani?"},
    {'label': 'BEER', 'emoji': '🍺', 'msg': "hang for a beer?"},
    {'label': 'CHAI', 'emoji': '🍵', 'msg': "hang for chai?"},
    {'label': 'STREET', 'emoji': '🌮', 'msg': "hang for street food?"},
    {'label': 'DRINKS', 'emoji': '🍸', 'msg': "hang for drinks?"},
    {'label': 'SUTTA', 'emoji': '🚬', 'msg': "hang for sutta?"},
    {'label': 'SHOPPING', 'emoji': '🛍️', 'msg': "hang for shopping?"},
    {'label': 'MOVIES', 'emoji': '🍿', 'msg': "hang for a movie?"},
    {'label': 'GAMING', 'emoji': '🎮', 'msg': "hang for gaming?"},
    {'label': 'CHILL', 'emoji': '🎶', 'msg': "just hang?"},
  ];

  static const List<Map<String, dynamic>> _times = [
    {'id': 'now', 'label': 'NOW', 'icon': '⚡'},
    {'id': '30m', 'label': '+30 MIN', 'icon': '🕐'},
    {'id': '1h', 'label': '+1 HR', 'icon': '⏰'},
    {'id': '6pm', 'label': '6 PM', 'icon': '🌇'},
  ];

  StreamSubscription<List<Map<String, dynamic>>>? _profilesSubscription;

  @override
  void initState() {
    super.initState();
    _checkFreshUser();
    _loadProfiles();
    locationService.activeLocationNotifier.addListener(_loadProfiles);
  }

  Future<void> _checkFreshUser() async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client.from('profiles').select('explore_first_visited_at, visibility').eq('id', uid).maybeSingle();
      if (res != null && res['explore_first_visited_at'] == null) {
         await Supabase.instance.client.from('profiles').update({
            'explore_first_visited_at': DateTime.now().toUtc().toIso8601String(),
            'visibility': 'inactive',
            'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
         }).eq('id', uid);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _profilesSubscription?.cancel();
    locationService.activeLocationNotifier.removeListener(_loadProfiles);
    super.dispose();
  }

  void _loadProfiles() {
    if (_currentUid == null) { setState(() => _isLoading = false); return; }
    
    final activeDistrict = locationService.activeDistrict.isNotEmpty ? locationService.activeDistrict : 'Unknown';

    _profilesSubscription?.cancel();
    
    if (activeDistrict == 'Unknown') {
       if (mounted) setState(() { _activeUsers = []; _inactiveUsers = []; _isLoading = false; });
       return;
    }

    setState(() => _isLoading = true);

    _profilesSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .listen((data) {
      final now = DateTime.now().toUtc();
      final List<Map<String, dynamic>> act = [], inact = [];

      final searchCity = activeDistrict.toLowerCase().trim();
      final centerLat = locationService.activeLat ?? 0;
      final centerLng = locationService.activeLng ?? 0;

      for (final p in data) {
        if (p['id'] == _currentUid) continue;

        final dbCity = (p['city']?.toString() ?? '').toLowerCase().trim();
        
        bool isNearby = false;
        if (searchCity.isNotEmpty && dbCity.contains(searchCity)) {
          isNearby = true;
        } else if (centerLat != 0 && centerLng != 0 && p['lat'] != null && p['lng'] != null) {
          final profileLat = double.tryParse(p['lat'].toString()) ?? 0;
          final profileLng = double.tryParse(p['lng'].toString()) ?? 0;
          if (locationService.calculateDistanceInKm(centerLat, centerLng, profileLat, profileLng) <= 50) {
            isNearby = true;
          }
        }

        if (!isNearby) continue;

        final visibility = p['visibility']?.toString() ?? 'inactive';
        
        final profile = {
          'id': p['id'], 'name': p['name'] ?? p['full_name'] ?? 'User',
          'age': p['age'] ?? 22, 'avatar_url': p['avatar_url'] ?? '',
          'bio': p['bio'] ?? '', 'city': p['city'] ?? '',
          'distance_km': p['distance_km'] ?? 0,
          'visibility_updated_at': p['visibility_updated_at'] ?? p['updated_at'] ?? '',
          'visibility': visibility,
          'explore_status': p['explore_status'] ?? '',
        };
        
        if (visibility == 'active') { act.add(profile); }
        else { inact.add(profile); }
      }

      act.sort((a, b) => (b['visibility_updated_at']?.toString() ?? '').compareTo(a['visibility_updated_at']?.toString() ?? ''));
      inact.sort((a, b) => (b['visibility_updated_at']?.toString() ?? '').compareTo(a['visibility_updated_at']?.toString() ?? ''));

      if (mounted) setState(() { _activeUsers = act; _inactiveUsers = inact; _isLoading = false; });
    }, onError: (e) {
      debugPrint('ExploreScreen stream error: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _refreshProfiles() async {
    _loadProfiles();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _showVisibilitySettings(BuildContext context) async {
    final uid = _currentUid;
    if (uid == null) return;
    
    String currentVisibility = 'inactive';
    String currentStatus = '';
    try {
      final res = await Supabase.instance.client.from('profiles').select('visibility, explore_status').eq('id', uid).maybeSingle();
      if (res != null) {
        if (res['visibility'] == 'active') {
          currentVisibility = 'active';
        }
        currentStatus = res['explore_status']?.toString() ?? '';
      }
    } catch (_) {}

    if (!context.mounted) return;
    
    final controller = TextEditingController(text: currentStatus);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isVisible = currentVisibility == 'active';
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: 450,
              decoration: BoxDecoration(
                color: const Color(0xFF131313).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 24),
                        Text('Explore Settings', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(isVisible ? 'You are Active' : 'You are Inactive', style: GoogleFonts.inter(color: isVisible ? const Color(0xFF17C964) : Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  if (currentVisibility == 'active') return;
                                  setSheetState(() => currentVisibility = 'active');
                                  final currentCity = locationService.activeDistrict.isNotEmpty ? locationService.activeDistrict : 'Unknown';
                                  await Supabase.instance.client.from('profiles').update({
                                    'visibility': 'active',
                                    'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
                                    'city': currentCity,
                                  }).eq('id', uid);
                                },
                                child: AnimatedContainer(
                                  duration: 200.ms,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isVisible ? const Color(0xFF17C964).withValues(alpha: 0.1) : const Color(0xFF1C1C1C),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isVisible ? const Color(0xFF17C964) : Colors.transparent, width: 2),
                                  ),
                                  child: Center(child: Text('Active', style: GoogleFonts.inter(color: isVisible ? Colors.white : Colors.white54, fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  if (currentVisibility == 'inactive') return;
                                  setSheetState(() => currentVisibility = 'inactive');
                                  final currentCity = locationService.activeDistrict.isNotEmpty ? locationService.activeDistrict : 'Unknown';
                                  await Supabase.instance.client.from('profiles').update({
                                    'visibility': 'inactive',
                                    'visibility_updated_at': DateTime.now().toUtc().toIso8601String(),
                                    'city': currentCity,
                                  }).eq('id', uid);
                                },
                                child: AnimatedContainer(
                                  duration: 200.ms,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: !isVisible ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1C1C1C),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: !isVisible ? Colors.white54 : Colors.transparent, width: 2),
                                  ),
                                  child: Center(child: Text('Inactive', style: GoogleFonts.inter(color: !isVisible ? Colors.white : Colors.white54, fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('YOUR VIEW', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: TextField(
                            controller: controller,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            decoration: InputDecoration(
                              hintText: 'what are you exploring here?',
                              hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            final statusText = controller.text.trim();
                            try {
                              await Supabase.instance.client.from('profiles').update({
                                'explore_status': statusText,
                              }).eq('id', uid);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Settings saved!'), backgroundColor: Color(0xFF17C964)),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error saving settings: $e');
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity, height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF17C964),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF17C964).withValues(alpha: 0.3),
                                  blurRadius: 20, offset: const Offset(0, 8)
                                )
                              ]
                            ),
                            child: Center(
                              child: Text('Save Settings', style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  void _showProfileDetailOverlay(Map<String, dynamic> profile) {
    final name = profile['name'] ?? 'User';
    final avatarUrl = profile['avatar_url']?.toString() ?? '';
    final status = profile['explore_status']?.toString().isNotEmpty == true 
        ? profile['explore_status'].toString() 
        : 'Just exploring around!';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF131313).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Circle Avatar
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF17C964), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17C964).withValues(alpha: 0.25),
                        blurRadius: 25, spreadRadius: 4
                      )
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: avatarUrl.isNotEmpty 
                          ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) 
                          : null,
                      color: const Color(0xFF2A2A2A),
                    ),
                    child: avatarUrl.isEmpty 
                        ? const Icon(Icons.person, color: Colors.white54, size: 55) 
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Name
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5
                  ),
                ),
                const SizedBox(height: 24),
                
                // "Why I am here" Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Why I am here',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF17C964), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '"$status"',
                        style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 15, height: 1.4, fontStyle: FontStyle.italic
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Pulsing Green Hangout Button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showWhatsTheMoveSheet(profile);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF17C964),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF17C964).withValues(alpha: 0.35),
                              blurRadius: 20, spreadRadius: 2
                            )
                          ],
                        ),
                        child: const Icon(Icons.forum_rounded, color: Colors.black, size: 28),
                      ).animate(onPlay: (c) => c.repeat()).scale(
                        begin: const Offset(1, 1), end: const Offset(1.05, 1.05),
                        duration: 1200.ms, curve: Curves.easeInOut
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'HANG OUT',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF17C964), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWhatsTheMoveSheet(Map<String, dynamic> profile) {
    final name = (profile['name'] ?? 'User').toString().split(' ')[0];
    final avatarUrl = profile['avatar_url']?.toString() ?? '';
    final profileId = profile['id']?.toString() ?? '';

    int? selectedActivityIdx;
    String selectedTimeId = 'now';
    bool showConfirmation = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // --- STEP 2: CONFIRMATION SCREEN ---
          if (showConfirmation && selectedActivityIdx != null) {
            final activity = _activities[selectedActivityIdx!];
            final timeObj = _times.firstWhere((t) => t['id'] == selectedTimeId);
            final timeStr = selectedTimeId == 'now' ? 'right now' : (timeObj['label'] as String).toLowerCase();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: BoxDecoration(
                color: const Color(0xFF131313).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('READY', style: GoogleFonts.inter(color: const Color(0xFFF5A524), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 16)),
                          Text('SEND', style: GoogleFonts.inter(color: const Color(0xFFF5A524), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        ],
                      ),
                      const Spacer(flex: 2),
                      SizedBox(
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                                BoxShadow(color: const Color(0xFF17C964).withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 20)
                              ]),
                            ),
                            Text(activity['emoji'] as String, style: const TextStyle(fontSize: 80))
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .slideY(begin: 0, end: -0.1, duration: 1500.ms, curve: Curves.easeInOut)
                              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1500.ms),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(activity['msg'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 16),
                      Text(timeStr, style: GoogleFonts.inter(color: const Color(0xFFF5A524), fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('to ', style: GoogleFonts.inter(color: Colors.white54, fontSize: 16)),
                          Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(flex: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              // Delete any existing hangout request between these two users to avoid clashes
                              try {
                                await Supabase.instance.client
                                    .from('requests')
                                    .delete()
                                    .eq('target_type', 'hangout')
                                    .or('and(sender_id.eq.$_currentUid,target_id.eq.$profileId),and(sender_id.eq.$profileId,target_id.eq.$_currentUid)');
                              } catch (_) {}

                              // Insert the premium Hangout invite message
                              await Supabase.instance.client.from('messages').insert({
                                'sender_id': _currentUid,
                                'receiver_id': profileId,
                                'text': '⚡HANGOUT_INVITE|${activity["emoji"]}|${activity["msg"]}|$timeStr',
                                'is_image': false,
                              });

                              // Insert a pending hangout request in requests table
                              await Supabase.instance.client.from('requests').insert({
                                'sender_id': _currentUid,
                                'target_id': profileId,
                                'target_type': 'hangout',
                                'status': 'pending',
                              });

                              // Send push/system notification about the premium hangout invite
                              try {
                                await NotificationService.sendNotification(
                                  userId: profileId,
                                  type: NotificationType.message,
                                  title: '⚡ New Hangout Invite!',
                                  body: 'Invited you to hang out for: ${activity["msg"]}',
                                  payload: {'sender_id': _currentUid},
                                );
                              } catch (err) {
                                debugPrint('Hangout notification failed: $err');
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Sent to $name!'), backgroundColor: const Color(0xFF17C964)));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Failed: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity, height: 60,
                            decoration: BoxDecoration(color: const Color(0xFF17C964), borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: const Color(0xFF17C964).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('send to $name', style: GoogleFonts.inter(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_outward_rounded, color: Colors.black, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => setSheetState(() => showConfirmation = false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 16),
                            const SizedBox(width: 4),
                            Text('change', style: GoogleFonts.inter(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          }

          // --- STEP 1: ACTIVITY PICKER ---
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFF131313).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 14, backgroundColor: const Color(0xFF2A2A2A),
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        ),
                        const SizedBox(width: 10),
                        Text('hang with ', style: GoogleFonts.inter(color: Colors.white70, fontSize: 15)),
                        Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("what's the ", style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        Text("move?", style: GoogleFonts.inter(color: const Color(0xFF17C964), fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('ACTIVITIES', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
                        ),
                        itemCount: _activities.length,
                        itemBuilder: (context, i) {
                          final act = _activities[i];
                          final isSelected = selectedActivityIdx == i;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedActivityIdx = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF17C964).withValues(alpha: 0.1) : const Color(0xFF1C1C1C),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? const Color(0xFF17C964) : Colors.transparent, width: 1.5),
                                boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF17C964).withValues(alpha: 0.2), blurRadius: 10)] : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(act['emoji'] as String, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(height: 8),
                                  Text(act['label'] as String, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('WHEN?', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: _times.map((t) {
                          final isSelected = selectedTimeId == t['id'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => selectedTimeId = t['id'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF17C964).withValues(alpha: 0.1) : const Color(0xFF1C1C1C),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? const Color(0xFF17C964) : Colors.transparent, width: 2),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(t['icon'] as String, style: const TextStyle(fontSize: 24)),
                                    const SizedBox(height: 8),
                                    Text(t['label'] as String, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: GestureDetector(
                        onTap: () {
                          if (selectedActivityIdx != null) {
                            setSheetState(() => showConfirmation = true);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity, height: 56,
                          decoration: BoxDecoration(
                            color: selectedActivityIdx != null ? Colors.white : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: selectedActivityIdx != null ? [BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))] : [],
                          ),
                          child: Center(
                            child: Text(
                              selectedActivityIdx != null ? 'continue ↑' : 'select an activity',
                              style: GoogleFonts.inter(
                                color: selectedActivityIdx != null ? Colors.black : Colors.white38,
                                fontSize: 16, fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF17C964),
              backgroundColor: const Color(0xFF2A2A2A),
              onRefresh: _refreshProfiles,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // Top Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // App Title / Brand
                          Text(
                            'EXPLORE',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.0,
                              height: 1.0,
                            ),
                          ),
                          
                          // Glassmorphism Location Pill
                          ValueListenableBuilder<String>(
                            valueListenable: locationService.activeDistrictNotifier,
                            builder: (_, loc, __) {
                              final displayLoc = loc.isNotEmpty ? loc : 'Nearby';
                              return GestureDetector(
                                onTap: () => showLocationSearchSheet(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.my_location, color: Color(0xFF17C964), size: 14),
                                      const SizedBox(width: 8),
                                      Text('Active in $displayLoc', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          // Settings Icon
                          GestureDetector(
                            onTap: () => _showVisibilitySettings(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Icon(Icons.settings, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isLoading)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF17C964), strokeWidth: 2)))
                  else if (_activeUsers.isEmpty && _inactiveUsers.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Icon(Icons.radar_rounded, color: Color(0xFF17C964), size: 48),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2000.ms),
                            const SizedBox(height: 24),
                            Text('No one around right now', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('Try exploring a different city', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Active Users
                    _sectionHeader('Active', _activeUsers.length, const Color(0xFF17C964)),
                    _profileGrid(_activeUsers, isActive: true),
                    
                    // Inactive Users
                    _sectionHeader('Inactive', _inactiveUsers.length, Colors.white38),
                    _profileGrid(_inactiveUsers, isActive: false),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    if (count == 0) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(title, style: GoogleFonts.inter(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(width: 8),
            Text('$count users', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _profileGrid(List<Map<String, dynamic>> profiles, {required bool isActive}) {
    if (profiles.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 24, childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _profileCard(profiles[i], isActive: isActive)
            .animate(key: ValueKey('${isActive ? "act" : "inact"}_${profiles[i]['id']}'))
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutQuart),
          childCount: profiles.length,
        ),
      ),
    );
  }

  Widget _profileCard(Map<String, dynamic> profile, {required bool isActive}) {
    final name = (profile['name'] ?? 'User').toString().split(' ')[0];
    final avatarUrl = profile['avatar_url']?.toString() ?? '';
    final streak = ((name.length * 7) % 50) + 1; 

    return GestureDetector(
      onTap: isActive ? () => _showProfileDetailOverlay(profile) : null,
      child: Column(
        children: [
          // Dynamic Avatar Stlying
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Pulsating border for Active, dull border for Inactive
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? const Color(0xFF17C964) : Colors.white24,
                    width: isActive ? 3 : 2,
                  ),
                  boxShadow: isActive ? [BoxShadow(color: const Color(0xFF17C964).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)] : [],
                ),
                child: Container(
                  margin: const EdgeInsets.all(2), // Gap between glowing border and image
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                    color: const Color(0xFF2A2A2A),
                  ),
                  child: avatarUrl.isEmpty ? const Center(child: Icon(Icons.person, color: Colors.white54, size: 30)) : null,
                ),
              ),
              
              // Status Indicator Sticker
              if (isActive)
                Positioned(
                  bottom: 0, right: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF17C964),
                      border: Border.all(color: const Color(0xFF0F121B), width: 2.5),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 14),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Name with opacity depending on state
          Text(name, 
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : Colors.white54, 
              fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500
            ), 
            maxLines: 1, overflow: TextOverflow.ellipsis
          ),
          
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              profile['explore_status']?.toString().isNotEmpty == true 
                  ? '"${profile['explore_status']}"'
                  : '$streak 🔥',
              style: GoogleFonts.inter(
                color: isActive ? Colors.white70 : Colors.white38, 
                fontSize: 10,
                fontStyle: profile['explore_status']?.toString().isNotEmpty == true ? FontStyle.italic : FontStyle.normal
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
    );
  }
}






// ----------------------------------------------------
// MAP LAYER TYPES
// ----------------------------------------------------
enum _MapLayer { street, satellite, terrain, cycling, humanitarian }

extension _MapLayerX on _MapLayer {
  String get label => const {
        _MapLayer.street: 'Street',
        _MapLayer.satellite: 'Satellite',
        _MapLayer.terrain: 'Terrain',
        _MapLayer.cycling: 'Cycling',
        _MapLayer.humanitarian: 'Aid Map',
      }[this]!;

  IconData get icon => const {
        _MapLayer.street: Icons.map_outlined,
        _MapLayer.satellite: Icons.satellite_alt,
        _MapLayer.terrain: Icons.terrain,
        _MapLayer.cycling: Icons.directions_bike,
        _MapLayer.humanitarian: Icons.volunteer_activism,
      }[this]!;

  Color get accent => const {
        _MapLayer.street: Color(0xFFFF6B00),
        _MapLayer.satellite: Color(0xFF4CAF50),
        _MapLayer.terrain: Color(0xFF8BC34A),
        _MapLayer.cycling: Color(0xFFFF9800),
        _MapLayer.humanitarian: Color(0xFFE91E63),
      }[this]!;

  String get tileUrl {
    switch (this) {
      case _MapLayer.street:
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case _MapLayer.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapLayer.terrain:
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      case _MapLayer.cycling:
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case _MapLayer.humanitarian:
        return 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
    }
  }

  // String? get overlayUrl => null;

  // Satellite imagery already looks dark ï¿½ no need to invert it
  bool get allowsDarkMode => this == _MapLayer.street;
}

// ----------------------------------------------------
// 3. ACTIVITY HUB SCREEN (Map & Inbox Toggle)
// ----------------------------------------------------
class ActivityHubScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ActivityHubScreen({super.key, this.onBack});

  @override
  State<ActivityHubScreen> createState() => _ActivityHubScreenState();
}

class _ActivityHubScreenState extends State<ActivityHubScreen> {
  bool _isMapView = false;
  bool _isMapDarkMode = true;
  bool _isFetchingLocation = false;
  bool _showLayerPicker = false;
  Map<String, dynamic>? _selectedMapActivity; // ? controls the layer popup
  _MapLayer _mapLayer = _MapLayer.street;
  LatLng? _myLocation;
  double? _myHeading;
  StreamSubscription<Position>? _locationSubscription;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _showDropdown = false;
  Timer? _debounce;

  final List<Map<String, dynamic>> _searchResults = [];
  late final Stream<List<Map<String, dynamic>>> _activityStream;
  List<dynamic> _hiddenRushIns = [];
  List<dynamic> _requestedRushInIds = [];
  List<dynamic> _approvedRushInIds = [];
  // bool _isLoadingDiscoveryState = false;

  @override
  void initState() {
    super.initState();
    _activityStream = Supabase.instance.client
        .from('activities')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);

    _refreshDiscoveryState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('lat, lng')
          .eq('id', uid)
          .maybeSingle();

      if (mounted && profile != null) {
        final lat = double.tryParse(profile['lat']?.toString() ?? '');
        final lng = double.tryParse(profile['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _myLocation = LatLng(lat, lng);
          });
          // Move map after a short delay so the widget has been built
          try {
            _mapController.move(LatLng(lat, lng), 14.0);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshDiscoveryState() async {
    // setState(() => _isLoadingDiscoveryState = true);
    await Future.wait([
      _fetchHiddenFeed(),
      _fetchRequestedIds(),
    ]);
    // if (mounted) setState(() => _isLoadingDiscoveryState = false);
  }

  Future<void> _fetchHiddenFeed() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('hidden_feed')
          .select('rush_in_id')
          .eq('user_id', uid);

      if (mounted) {
        setState(() {
          _hiddenRushIns =
              (response as List).map((e) => e['rush_in_id']).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching hidden feed: $e');
    }
  }

  Future<void> _fetchRequestedIds() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('requests')
          .select('target_id, status')
          .eq('sender_id', uid)
          .eq('target_type', 'activity');

      if (mounted) {
        setState(() {
          _requestedRushInIds =
              (response as List).map((e) => e['target_id'].toString()).toList();
          _approvedRushInIds = (response as List)
              .where((e) => e['status'] == 'approved')
              .map((e) => e['target_id'].toString())
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching requested IDs: $e');
    }
  }

  /*
  Future<void> _hideRushIn(String activityId) async {
    setState(() => _hiddenRushIns.add(activityId)); // Optimistic UI
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('hidden_feed').insert({
        'user_id': uid,
        'rush_in_id': activityId,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rush-In deleted from your feed.'), backgroundColor: Colors.white24));
    } catch (e) {
      debugPrint('Failed to sync hidden feed: $e'); // Silent fallback 
    }
  }
  */

  @override
  void dispose() {
    _debounce?.cancel();
    // Cancel the geolocation watch so we stop consuming GPS
    if (_locationSubscription != null) {
      _locationSubscription!.cancel();
    }
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // -- LIVE Nominatim search via CORS-safe proxy -------------------------
  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults.clear();
        _showDropdown = false;
      });
      return;
    }
    final encoded = Uri.encodeComponent(query);
    // Use allorigins proxy to satisfy Chrome CORS policy
    final proxyUrl = 'https://api.allorigins.win/raw?url='
        '${Uri.encodeComponent('https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=6&addressdetails=1')}';
    try {
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final parsed = data
            .map<Map<String, dynamic>>((item) => {
                  'name':
                      item['display_name'].toString().split(',').first.trim(),
                  'full_name': item['display_name'].toString(),
                  'lat': double.parse(item['lat'].toString()),
                  'lng': double.parse(item['lon'].toString()),
                })
            .toList();
        setState(() {
          _searchResults
            ..clear()
            ..addAll(parsed);
          _showDropdown = parsed.isNotEmpty;
        });
      }
    } catch (_) {/* network error ï¿½ silently ignore */}
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _fetchSuggestions(val));
  }

  // -- Browser Geolocation ï¿½ continuous watchPosition ------------------------
  void _startLocationTracking() async {
    // Already tracking - just re-center the map
    if (_myLocation != null && _locationSubscription != null) {
      _mapController.move(_myLocation!, 15.0);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    setState(() => _isFetchingLocation = true);

    bool firstFix = true;
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final lat = position.latitude;
      final lng = position.longitude;
      final heading = position.heading;

      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _myLocation = LatLng(lat, lng);
          if (heading != 0) _myHeading = heading;
        });
        // Only fly to location on first fix
        if (firstFix) {
          firstFix = false;
          _mapController.move(LatLng(lat, lng), 15.0);
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $error')),
        );
      }
    });
  }

  /*
  Future<void> _submitJoinRequest(Map<String, dynamic> act) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final existing = await Supabase.instance.client
          .from('requests')
          .select()
          .eq('sender_id', uid)
          .eq('target_id', act['id'])
          .maybeSingle();

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already requested to join!'), backgroundColor: Colors.amber));
        return;
      }

      await Supabase.instance.client.from('requests').insert({
        'sender_id': uid,
        'target_id': act['id'],
        'target_type': 'activity',
        'status': 'pending',
        'message': 'I want to join your Rush-In!'
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Request Sent! ðŸ’‹'), backgroundColor: Color(0xFFFF6B00)));
      Navigator.pop(context); // Close bottom sheet
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }
  */

  void _openDetailView(Map<String, dynamic> act) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RushInConsumerDetailView(
              activity: act,
              onInteraction: () => _refreshDiscoveryState(),
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 18),
                  onPressed: () => widget.onBack?.call(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Text('Activity',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Icon(Icons.tune, color: Colors.white, size: 24),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live Near You',
                      style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  GestureDetector(
                    onTap: () => setState(() => _isMapView = !_isMapView),
                    child: Text(_isMapView ? 'See List' : 'See Map',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              )),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _activityStream,
                builder: (context, snapshot) {
                  final acts = snapshot.data ?? [];
                  // Filter out non-RushIns and expired ones
                  final currentUid =
                      Supabase.instance.client.auth.currentUser?.id;
                  final liveActs = acts.where((act) {
                    if (act['is_active'] != true) return false;
                    if (act['user_id'] == currentUid) return false;
                    // Rush-Ins belong ONLY to the Rush-In Live section
                    if (act['is_rush_in'] == true &&
                        !_approvedRushInIds.contains(act['id'].toString())) {
                      return false;
                    }
                    // Prevent seeing hidden items
                    if (_hiddenRushIns.contains(act['id'].toString())) {
                      return false;
                    }
                    // Prevent seeing already-requested items
                    if (_requestedRushInIds.contains(act['id'].toString()) &&
                        !_approvedRushInIds.contains(act['id'].toString())) {
                      return false;
                    }
                    return true;
                  }).toList();

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isMapView
                        ? _buildMapView(liveActs)
                        : _buildListView(liveActs),
                  );
                }),
          )
        ],
      )),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> liveActivities) {
    final listActs =
        liveActivities.where((act) => act['is_rush_in'] != true).toList();
    return Stack(
      children: [
        ListView(
          key: const ValueKey('list_view'),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            ...listActs.map((act) => _buildMapLiveCard(act)),
            if (listActs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text('No events or Rush-Ins nearby right now.',
                        style: TextStyle(color: Colors.white54))),
              ),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings,
                        color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Admin Access',
                        style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
        Positioned(
          bottom: 110,
          right: 24,
          child: GestureDetector(
            onTap: () {
              final loc = _myLocation ?? const LatLng(28.6139, 77.2090);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HostActivityScreen(
                      initialLocation: loc, initialIsRushIn: false)));
            },
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)]),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView(List<Map<String, dynamic>> liveActivities) {
    return Container(
      key: const ValueKey('map_view'),
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border:
            Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
              blurRadius: 20)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(children: [
          // Dark mode overlay ï¿½ only when allowed by layer type
          if (_isMapDarkMode && _mapLayer.allowsDarkMode)
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
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
              ]),
              child: _buildFlutterMap(liveActivities),
            )
          else
            _buildFlutterMap(liveActivities),

          // Neon hue wash ï¿½ dark street mode only
          if (_isMapDarkMode && _mapLayer.allowsDarkMode)
            IgnorePointer(
                child: Container(
                    color: const Color(0xFFFF5C00).withValues(alpha: 0.2))),

          // Search Bar Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 64,
            child: _buildSearchBar(),
          ),

          // Dropdown Overlay
          if (_showDropdown)
            Positioned(
              top: 66,
              left: 16,
              right: 64,
              child: _buildSearchDropdown(),
            ),

          // Light/Dark Theme Toggle
          Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                  onTap: () => setState(() => _isMapDarkMode = !_isMapDarkMode),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(
                        _isMapDarkMode
                            ? Icons.wb_sunny
                            : Icons.nightlight_round,
                        color: _isMapDarkMode ? Colors.yellow : Colors.blueGrey,
                        size: 20),
                  ))),

          // My Location Button ï¿½ bottom-right, mirrors layer FAB on bottom-left
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: _startLocationTracking,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: _isFetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location,
                        color: Colors.white, size: 24),
              ),
            ),
          ),

          // Layer picker popup (appears above the FAB when open)
          if (_showLayerPicker)
            Positioned(
              bottom: 72,
              left: 16,
              child: _buildLayerPickerPopup(),
            ),

          // Layer FAB ï¿½ always visible in bottom-left
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildLayerFab(),
          ),
        ]),
      ),
    );
  }

  Widget _buildFlutterMap(List<Map<String, dynamic>> liveActivities) {
    // Build markers ONLY for Standard Activities on the map
    final activityMarkers =
        liveActivities.map((act) => _buildActivityMarker(act)).toList();

    // Live-location marker (pulsing dot ? arrow)
    final popupMarkers = _selectedMapActivity != null
        ? [
            Marker(
              point: LatLng(
                _selectedMapActivity!['lat'] as double? ??
                    _selectedMapActivity!['latitude'] as double? ??
                    40.7128,
                _selectedMapActivity!['lng'] as double? ??
                    _selectedMapActivity!['longitude'] as double? ??
                    -74.0060,
              ),
              width: 250,
              height: 250,
              alignment: Alignment.topCenter,
              child: _buildMapPopupCard(_selectedMapActivity!),
            )
          ]
        : <Marker>[];

    final locationMarkers = _myLocation != null
        ? [
            Marker(
              point: _myLocation!,
              width: 60,
              height: 60,
              child: _MyLocationMarker(heading: _myHeading),
            )
          ]
        : <Marker>[];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
          initialCenter: _myLocation ?? const LatLng(40.7128, -74.0060),
          initialZoom: 14.0,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.all)),
      children: [
        TileLayer(
            userAgentPackageName: 'com.meetra.app',
            urlTemplate: _mapLayer.tileUrl),
        MarkerLayer(
            markers: [...activityMarkers, ...locationMarkers, ...popupMarkers]),
      ],
    );
  }

  // ï¿½ Layer FAB: small icon in bottom-left, shows active layer icon ï¿½
  Widget _buildLayerFab() {
    return GestureDetector(
      onTap: () => setState(() => _showLayerPicker = !_showLayerPicker),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _showLayerPicker
              ? _mapLayer.accent.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(
            color: _showLayerPicker ? _mapLayer.accent : Colors.white38,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _mapLayer.accent
                  .withValues(alpha: _showLayerPicker ? 0.5 : 0.2),
              blurRadius: _showLayerPicker ? 16 : 6,
            )
          ],
        ),
        child: Icon(_mapLayer.icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ï¿½ Layer picker popup list ï¿½
  Widget _buildLayerPickerPopup() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.layers, color: Colors.white54, size: 14),
                    SizedBox(width: 6),
                    Text('Map Type',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              ..._MapLayer.values.map((layer) {
                final selected = _mapLayer == layer;
                return InkWell(
                  onTap: () => setState(() {
                    _mapLayer = layer;
                    _showLayerPicker = false;
                  }),
                  borderRadius:
                      selected ? BorderRadius.zero : BorderRadius.circular(0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? layer.accent.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: selected
                          ? Border(
                              left: BorderSide(color: layer.accent, width: 3))
                          : const Border(
                              left: BorderSide(
                                  color: Colors.transparent, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? layer.accent.withValues(alpha: 0.3)
                                : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(layer.icon,
                              color: selected ? layer.accent : Colors.white60,
                              size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            layer.label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle,
                              color: layer.accent, size: 16),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search locations...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.white54, size: 18),
                  ),
                ))));
  }

  Widget _buildSearchDropdown() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: const Color(0xFF101015).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12)
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final loc = _searchResults[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on,
                color: Color(0xFFFF6B00), size: 18),
            title: Text(loc['name'],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(loc['full_name'],
                style: const TextStyle(color: Colors.white38, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            onTap: () {
              _searchController.text = loc['name'];
              setState(() {
                _searchResults.clear();
                _showDropdown = false;
              });
              _mapController.move(LatLng(loc['lat'], loc['lng']), 14.0);
            },
          );
        },
      ),
    );
  }

  Marker _buildActivityMarker(Map<String, dynamic> act) {
    final isRushIn = act['is_rush_in'] == true;
    final lat = act['lat'] as double? ?? act['latitude'] as double? ?? 40.7128;
    final lng =
        act['lng'] as double? ?? act['longitude'] as double? ?? -74.0060;
    // final accent = isRushIn ? const Color(0xFFFF6B00) : const Color(0xFFB388FF);

    return Marker(
      point: LatLng(lat, lng),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMapActivity = act;
          });
          _mapController.move(LatLng(lat, lng), 15.0);
        },
        child: isRushIn
            ? _SparkingRushInMarker(userId: act['user_id']?.toString())
            : _StandardActivityMarker(
                color: const Color(0xFFFF6B00),
                icon: Icons.event,
                userId: act['user_id']?.toString()),
      ),
    );
  }

  /*
  Marker _buildAvatarMarker(LatLng pos, String imgUrl) {
    return Marker(
      point: pos,
      width: 50,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFF6B00), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.8), 
              blurRadius: 10
            )
          ],
          image: DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover),
        ),
      ),
    );
  }
  */

  Widget _buildMapPopupCard(Map<String, dynamic> act) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF65666A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final hostId = act['user_id']?.toString() ?? '';
                      if (hostId.isNotEmpty) {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(userId: hostId)));
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                              'https://picsum.photos/seed/${act['user_id']}/100'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  act['host_name'] ??
                                      ('User ${act['user_id']?.toString().substring(0, 4) ?? ''}'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white)),
                              const Text('is hosting',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text((act['category'] ?? 'EVENT').toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFFFF4081),
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(
                      act['hook'] ?? act['title'] ?? 'Anyone up a musical war.',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => _openDetailView(act),
                      child: const Text('View Details',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  )
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _selectedMapActivity = null),
                child: const Icon(Icons.close, color: Colors.white30, size: 16),
              ),
            )
          ],
        ),
        CustomPaint(
          size: const Size(16, 12),
          painter: _TrianglePainter(color: const Color(0xFF65666A)),
        )
      ],
    );
  }

  /// Returns a relative time label for an activity (e.g. "Tomorrow", "In 5 days", "2 days ago")
  String _relativeTimeLabel(Map<String, dynamic> act) {
    final raw =
        act['event_date'] as String? ?? act['created_at'] as String? ?? '';
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) {
        final days = diff.inDays.abs();
        if (days == 0) return 'Today';
        if (days == 1) return '1 day ago';
        return '$days days ago';
      } else {
        final days = diff.inDays;
        if (days == 0) return 'Today';
        if (days == 1) return 'Tomorrow';
        return 'In $days days';
      }
    } catch (_) {
      return '';
    }
  }

  /// Category metadata: label, icon, pill-color, border-color
  Map<String, dynamic> _categoryMeta(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'sports':
        return {
          'label': 'SPORTS',
          'icon': Icons.sports_soccer,
          'pill': const Color(0xFFE53935),
          'border': const Color(0xFFE53935)
        };
      case 'art':
        return {
          'label': 'ART',
          'icon': Icons.palette,
          'pill': const Color(0xFFF59E0B),
          'border': const Color(0xFFF59E0B)
        };
      case 'tech':
        return {
          'label': 'TECH',
          'icon': Icons.code,
          'pill': const Color(0xFF10B981),
          'border': const Color(0xFF10B981)
        };
      case 'music':
        return {
          'label': 'MUSIC',
          'icon': Icons.music_note,
          'pill': const Color(0xFFFF7E40),
          'border': const Color(0xFFFF7E40)
        };
      case 'food':
        return {
          'label': 'FOOD',
          'icon': Icons.restaurant,
          'pill': const Color(0xFFFF7043),
          'border': const Color(0xFFFF7043)
        };
      case 'social':
        return {
          'label': 'SOCIAL',
          'icon': Icons.people,
          'pill': const Color(0xFF06B6D4),
          'border': const Color(0xFF06B6D4)
        };
      default:
        return {
          'label': 'EVENT',
          'icon': Icons.event,
          'pill': const Color(0xFF6366F1),
          'border': const Color(0xFF6366F1)
        };
    }
  }

  Widget _buildMapLiveCard(Map<String, dynamic> act) {
    final title = act['title'] ?? 'Activity';
    final description = act['description'] ?? act['hook'] ?? '';
    final locationName = act['location_name'] ?? act['venue'] ?? 'Nearby';
    final category = act['category'] as String?;
    final meta = _categoryMeta(category);
    final borderColor = meta['border'] as Color;
    final pillColor = meta['pill'] as Color;
    final catLabel = meta['label'] as String;
    final catIcon = meta['icon'] as IconData;
    final timeLabel = _relativeTimeLabel(act);
    final isPast = timeLabel.contains('ago');

    // Date / time display
    final rawDate =
        act['event_date'] as String? ?? act['created_at'] as String? ?? '';
    String dateStr = '';
    String timeStr = '';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        dateStr = '${_monthAbbr(dt.month)} ${dt.day}, ${dt.year}';
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        timeStr = '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
      } catch (_) {}
    }

    // Host info
    final hostName =
        act['host_name'] as String? ?? act['user_name'] as String? ?? 'Host';
    final hostAvatar =
        act['host_avatar'] as String? ?? act['avatar_url'] as String? ?? '';
    final hostId = act['user_id']?.toString() ?? '';
    final lat = double.tryParse(act['lat']?.toString() ?? '');
    final lng = double.tryParse(act['lng']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _openDetailView(act),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent border
                Container(width: 4, color: borderColor),
                // Card body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: category pill + time badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: pillColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: pillColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(catIcon, color: pillColor, size: 11),
                                    const SizedBox(width: 5),
                                    Text(catLabel,
                                        style: TextStyle(
                                            color: pillColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5)),
                                  ]),
                            ),
                            if (timeLabel.isNotEmpty)
                              Row(children: [
                                Icon(isPast ? Icons.history : Icons.access_time,
                                    size: 12,
                                    color: isPast
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(timeLabel,
                                    style: TextStyle(
                                        color: isPast
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF10B981),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Title
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17)),
                        const SizedBox(height: 6),
                        // Description
                        if (description.isNotEmpty)
                          Text(description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12.5,
                                  height: 1.4)),
                        const Divider(color: Colors.white12, height: 22),
                        // Date / time / location row
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            if (dateStr.isNotEmpty)
                              _infoChip(Icons.calendar_today_outlined, dateStr,
                                  const Color(0xFFFBBF24)),
                            if (timeStr.isNotEmpty)
                              _infoChip(Icons.access_time, timeStr,
                                  const Color(0xFF60A5FA)),
                            GestureDetector(
                              onTap: lat != null && lng != null
                                  ? () =>
                                      _openLocationOnMap(lat, lng, locationName)
                                  : null,
                              child: _infoChip(Icons.location_on_outlined,
                                  locationName, const Color(0xFFF87171),
                                  underline: lat != null && lng != null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Host info
                        GestureDetector(
                          onTap: hostId.isNotEmpty
                              ? () => _viewHostProfile(hostId)
                              : null,
                          child: Row(children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: const Color(0xFFFF5C00),
                              backgroundImage: hostAvatar.isNotEmpty
                                  ? _buildSafeImageProvider(hostAvatar)
                                  : null,
                              child: hostAvatar.isEmpty
                                  ? Text(
                                      hostName.isNotEmpty
                                          ? hostName[0].toUpperCase()
                                          : 'H',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text('Hosted by ',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                            Text(hostName,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*
  Widget _buildRecentInboxCard(String title, String desc, String time, String imgUrl, {Widget? actionBtn}) {
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: const Color(0xFF101015),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
       ),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Container(
             width: 48,
             height: 48,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               image: DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover),
             ),
             child: const Align(
               alignment: Alignment.bottomLeft,
               child: Icon(Icons.circle, color: Colors.green, size: 12),
             ),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                     Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                   ],
                 ),
                 const SizedBox(height: 6),
                 Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
               ],
             )
           ),
           if (actionBtn != null) ...[
              const SizedBox(width: 12),
              Align(alignment: Alignment.centerRight, child: actionBtn),
           ]
         ],
       )
     );
  }
  */

  /// Small info chip used in activity/rush-in card footer
  Widget _infoChip(IconData icon, String label, Color color,
      {bool underline = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11.5,
                decoration:
                    underline ? TextDecoration.underline : TextDecoration.none,
                decorationColor: color)),
      ],
    );
  }

  /// Opens Google Maps or an in-app map for a precise location
  void _openLocationOnMap(double lat, double lng, String label) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _SinglePinMapScreen(lat: lat, lng: lng, label: label)));
  }

  /// Opens the host's profile screen
  void _viewHostProfile(String hostId) {
    if (hostId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: hostId)));
  }

  /// Month abbreviation helper
  String _monthAbbr(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}

// ---------------------------------------------------------------------------
// SINGLE PIN MAP SCREEN - Shows precise location of an activity/rush-in
// ---------------------------------------------------------------------------
class _SinglePinMapScreen extends StatelessWidget {
  final double lat;
  final double lng;
  final String label;
  const _SinglePinMapScreen(
      {required this.lat, required this.lng, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        title: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 16.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 50,
                height: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.location_on,
                        color: Color(0xFFFF6B00), size: 30),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandardActivityMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? userId;
  const _StandardActivityMarker(
      {required this.color, required this.icon, this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)
            ],
          ),
          child: CircleAvatar(
            radius: 14,
            backgroundImage: userId != null
                ? NetworkImage('https://picsum.photos/seed/$userId/100')
                : null,
            backgroundColor: Colors.grey[900],
            child: userId == null
                ? Icon(icon, color: Colors.white, size: 12)
                : null,
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: color),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingRushInMarker extends StatefulWidget {
  final Color color;
  final String? userId;
  const _PulsingRushInMarker({required this.color, this.userId});
  @override
  State<_PulsingRushInMarker> createState() => _PulsingRushInMarkerState();
}

class _PulsingRushInMarkerState extends State<_PulsingRushInMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30 + (25 * _ctrl.value),
            height: 30 + (25 * _ctrl.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.15 * (1 - _ctrl.value)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 15 * _ctrl.value)
              ],
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: widget.userId != null
                  ? NetworkImage(
                      'https://picsum.photos/seed/${widget.userId}/100')
                  : null,
              backgroundColor: Colors.black,
              child: widget.userId == null
                  ? const Icon(Icons.bolt, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 4. PROFILE SCREEN BACKGROUND
// ----------------------------------------------------

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// LIVE LOCATION MARKER  â€“  pulsing dot + rotating arrow
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MyLocationMarker extends StatefulWidget {
  final double? heading; // null or NaN = stationary (show dot)
  const _MyLocationMarker({this.heading});

  @override
  State<_MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<_MyLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _ring;

  static const _blue = Color(0xFF2979FF);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _ring = Tween<double>(begin: 0.6, end: 2.4)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _hasHeading => widget.heading != null && !(widget.heading!.isNaN);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        // Opacity fades out as ring expands
        final ringOpacity = (1.0 - (_ring.value - 0.6) / 1.8).clamp(0.0, 0.5);
        return Stack(
          alignment: Alignment.center,
          children: [
            // â”€â”€ Expanding pulse ring â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Transform.scale(
              scale: _ring.value,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withValues(alpha: ringOpacity),
                ),
              ),
            ),

            // â”€â”€ Accuracy halo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _blue.withValues(alpha: 0.15),
                border:
                    Border.all(color: _blue.withValues(alpha: 0.3), width: 1),
              ),
            ),

            // â”€â”€ Core: dot when stationary, arrow when moving â”€â”€â”€â”€â”€â”€
            if (_hasHeading)
              Transform.rotate(
                // heading is clockwise from North; Flutter rotate is clockwise too
                angle: (widget.heading! * 3.14159265 / 180.0),
                child: const Icon(
                  Icons.navigation,
                  color: _blue,
                  size: 30,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              )
            else
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withValues(alpha: 0.7), blurRadius: 8),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// --------------------------------------------------------------------
// CUSTOM BACKGROUND PAINTER
// --------------------------------------------------------------------
class CosmicBackgroundPainter extends CustomPainter {
  final double animationValue;

  CosmicBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF030305));

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Orb 1 (Cyan)
    final dx1 =
        size.width * (0.2 + 0.3 * math.sin(animationValue * math.pi * 2));
    final dy1 =
        size.height * (0.3 + 0.2 * math.cos(animationValue * math.pi * 2));
    paint.color = const Color(0xFFFF6B00).withValues(alpha: 0.15);
    canvas.drawCircle(Offset(dx1, dy1), 150, paint);

    // Orb 2 (Purple)
    final dx2 = size.width *
        (0.8 + 0.2 * math.cos(animationValue * math.pi * 2 + math.pi));
    final dy2 = size.height *
        (0.7 + 0.3 * math.sin(animationValue * math.pi * 2 + math.pi));
    paint.color = const Color(0xFFFF7E40).withValues(alpha: 0.15);
    canvas.drawCircle(Offset(dx2, dy2), 200, paint);

    // Orb 3 (Pink)
    final dx3 =
        size.width * (0.5 + 0.4 * math.sin(animationValue * math.pi * 4));
    final dy3 =
        size.height * (0.1 + 0.1 * math.cos(animationValue * math.pi * 2));
    paint.color = const Color(0xFFFF3D00).withValues(alpha: 0.10);
    canvas.drawCircle(Offset(dx3, dy3), 120, paint);
  }

  @override
  bool shouldRepaint(covariant CosmicBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _SparkingRushInMarker extends StatefulWidget {
  final String? userId;
  const _SparkingRushInMarker({this.userId});
  @override
  State<_SparkingRushInMarker> createState() => _SparkingRushInMarkerState();
}

class _SparkingRushInMarkerState extends State<_SparkingRushInMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 35 + (20 * _ctrl.value),
                  height: 35 + (20 * _ctrl.value),
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF4081)
                            .withValues(alpha: 0.3 * (1 - _ctrl.value)),
                        blurRadius: 20,
                        spreadRadius: 10),
                    BoxShadow(
                        color: Colors.amberAccent
                            .withValues(alpha: 0.4 * (1 - _ctrl.value)),
                        blurRadius: 40,
                        spreadRadius: 5),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101015),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF4081).withValues(alpha: 0.6),
                          blurRadius: 15)
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: widget.userId != null
                        ? NetworkImage(
                            'https://picsum.photos/seed/${widget.userId}/100')
                        : null,
                    backgroundColor: const Color(0xFF101015),
                    child: widget.userId == null
                        ? const Icon(Icons.bolt,
                            color: Colors.amberAccent, size: 18)
                        : null,
                  ),
                ),
                const Positioned(
                  bottom: -5,
                  child: Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFFFF4081), size: 16),
                )
              ],
            ));
  }
}

// -- Image helpers for Base64 bypass --
Widget _buildSafeImage(String url,
    {double? width,
    double? height,
    BoxFit? fit,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder}) {
  if (url.startsWith('data:image')) {
    final b64 = url.split(',').last;
    return Image.memory(base64Decode(b64),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder ?? (_, __, ___) => const SizedBox.shrink());
  }
  return Image.network(url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder ?? (_, __, ___) => const SizedBox.shrink());
}

ImageProvider _buildSafeImageProvider(String url) {
  if (url.startsWith('data:image')) {
    final b64 = url.split(',').last;
    return MemoryImage(base64Decode(b64));
  }
  return NetworkImage(url);
}

// ---------------------------------------------------------------------------
// SELLER APPLICATION SCREEN
// ---------------------------------------------------------------------------

class SellerApplicationScreen extends StatefulWidget {
  const SellerApplicationScreen({super.key});

  @override
  State<SellerApplicationScreen> createState() =>
      _SellerApplicationScreenState();
}

class _SellerApplicationScreenState extends State<SellerApplicationScreen> {
  final _businessNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = 'Food & Beverage';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Food & Beverage',
    'Concerts & Music',
    'Tours & Travel',
    'Standup & Comedy',
    'Fitness & Health',
    'Tech & Learning'
  ];

  Future<void> _submitApplication() async {
    if (_businessNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your business name')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      // Using the requests table with a specialized target_id for Admin routing
      await Supabase.instance.client.from('requests').insert({
        'sender_id': uid,
        'target_id': '00000000-0000-0000-0000-000000000000', // Admin System ID
        'target_type': 'seller_application',
        'status': 'pending',
        'payload': {
          'business_name': _businessNameCtrl.text,
          'description': _descCtrl.text,
          'category': _selectedCategory,
          'applied_at': DateTime.now().toIso8601String(),
        }
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF12121E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Application Submitted',
                style: TextStyle(color: Colors.white)),
            content: const Text(
                'Our verification team will review your business documentation and update your account within 24-48 hours.',
                style: TextStyle(color: Colors.white54)),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Got it!',
                      style: TextStyle(color: Color(0xFFFF6B00)))),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('SELLER AUTHORIZATION',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start your business on Meetra',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Apply to become a verified seller to list premium packages and events in the marketplace.',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 32),
            _buildFieldLabel('BUSINESS OR TRADING NAME'),
            _buildTextField(
                _businessNameCtrl, 'e.g. Skyline Tours or The Comedy Club'),
            const SizedBox(height: 20),
            _buildFieldLabel('EXPERIENCE CATEGORY'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1A1A2E),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildFieldLabel('BUSINESS DESCRIPTION'),
            _buildTextField(_descCtrl,
                'Tell us what you plan to sell and your experience level...',
                maxLines: 4),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitApplication,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('SUBMIT APPLICATION',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String tagline;
  final Color c1;
  final Color c2;
  final int activeCount;
  final String activity;
  final List<String> users; // Can be initials or avatar URLs
  final List<int> userColors;
  final int extra;
  final Widget artwork;
  final VoidCallback onTap;
  final bool isWide;

  const _VibeCard({
    required this.label,
    this.icon,
    required this.tagline,
    required this.c1,
    required this.c2,
    required this.activeCount,
    this.activity = 'active now',
    this.users = const [],
    this.userColors = const [],
    this.extra = 0,
    required this.artwork,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isWide ? 140 : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1, c2],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: c1.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Background Artwork (Optimized)
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.1,
                  child: artwork,
                ),
              ),

              // 2. Glassy Overlay (Optimized - No BackdropFilter used here for speed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        const Color(0xFF0D0D1A).withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon,
                              color: Colors.white.withValues(alpha: 0.9), size: 16),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Avatar Row & Activity
                    Row(
                      children: [
                        // Avatars
                        if (users.isNotEmpty || extra > 0)
                          SizedBox(
                            width:
                                (users.length + (extra > 0 ? 1 : 0)) * 18.0 + 4,
                            height: 24,
                            child: Stack(
                              children: [
                                for (int i = 0; i < users.length; i++)
                                  Positioned(
                                    left: i * 16.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0D0D1A),
                                            width: 1.5),
                                      ),
                                      child: CircleAvatar(
                                        radius: 11,
                                        backgroundColor: userColors.length > i
                                            ? Color(userColors[i])
                                            : Colors.white12,
                                        backgroundImage: users[i]
                                                    .startsWith('http') ||
                                                users[i].contains('data:image')
                                            ? _buildSafeImageProvider(users[i])
                                            : null,
                                        child: (users[i].startsWith('http') ||
                                                users[i].contains('data:image'))
                                            ? null
                                            : Text(
                                                users[i].isNotEmpty
                                                    ? users[i][0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w900),
                                              ),
                                      ),
                                    ),
                                  ),
                                if (extra > 0)
                                  Positioned(
                                    left: users.length * 16.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0D0D1A),
                                            width: 1.5),
                                      ),
                                      child: CircleAvatar(
                                        radius: 11,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.15),
                                        child: Text(
                                          '+$extra',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            activity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF38D9A9),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. Active Pill
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38D9A9),
                          shape: BoxShape.circle,
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.5, 1.5),
                          ),
                      const SizedBox(width: 5),
                      Text(
                        activeCount > 1000
                            ? '${(activeCount / 1000).toStringAsFixed(1)}k'
                            : '$activeCount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

