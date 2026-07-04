import 'dart:ui'; // Required for ImageFilter and Blur
import 'dart:async'; // Required for Timer
import 'dart:convert'; // Required for jsonDecode

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_upload_service.dart';
import 'services/theme_service.dart';
import 'services/location_service.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/rush_in_history_sheet.dart';
import 'services/doodle_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;

  // ── Why are you here ──
  final List<Map<String, dynamic>> _purposeOptions = [
    {'icon': Icons.people_outline, 'label': 'Make friends'},
    {'icon': Icons.school_outlined, 'label': 'Study partners'},
    {'icon': Icons.fitness_center, 'label': 'Workout buddies'},
    {'icon': Icons.group_outlined, 'label': 'Find companions'},
    {'icon': Icons.celebration_outlined, 'label': 'Attend events'},
    {'icon': Icons.support_agent, 'label': 'Professional help'},
    {'icon': Icons.favorite_outline, 'label': 'Date / romance'},
    {'icon': Icons.handshake_outlined, 'label': 'Networking'},
  ];
  List<String> _selectedPurposes = [];

  // ── Your Vibe (interests) ──
  final List<Map<String, dynamic>> _vibeOptions = [
    {'icon': Icons.menu_book, 'label': 'Study'},
    {'icon': Icons.fitness_center, 'label': 'Fitness'},
    {'icon': Icons.music_note, 'label': 'Music'},
    {'icon': Icons.rocket_launch, 'label': 'Startup'},
    {'icon': Icons.flight, 'label': 'Travel'},
    {'icon': Icons.sports_esports, 'label': 'Gaming'},
    {'icon': Icons.camera_alt, 'label': 'Photography'},
    {'icon': Icons.restaurant, 'label': 'Cooking'},
    {'icon': Icons.palette, 'label': 'Art'},
    {'icon': Icons.memory, 'label': 'Tech'},
    {'icon': Icons.nightlife, 'label': 'Dancing'},
    {'icon': Icons.auto_stories, 'label': 'Reading'},
  ];
  List<String> _selectedVibes = [];

  // ── Discovery Settings (stored locally via SharedPreferences) ──
  double _distanceRadius = 50;
  bool _isGlobal = false;
  RangeValues _ageRange = const RangeValues(18, 40);
  bool _showMe = true;

  // ── About Me ──
  final TextEditingController _bioController = TextEditingController();
  
  // ── Navigation Transition ──
  String _navTransition = 'Slide';
  
  // ── Account Settings ──
  bool _isPublic = true;

  // ── Profile fields from DB ──
  // ignore: unused_field
  String _name = '';
  // ignore: unused_field
  int _age = 0;
  // ignore: unused_field
  String _gender = '';
  // ignore: unused_field
  String _personality = '';
  // ── Location ──
  String _activeLocation = '';
  List<Map<String, dynamic>> _savedLocations = [];

  // ── Photos ──
  String _avatarUrl = '';
  final List<String> _galleryUrls = ['', '', '', '', '', ''];

  // ── Trust & Safety ──
  final bool _isVerified = false;
  final bool _isLinked = false;

  // ── Activity Dashboard ──
  int _activityCount = 0;
  int _connectionCount = 0;

  // ── Notification Settings ──
  Map<String, dynamic> _notifSettings = {
    'matches': true,
    'nearby_activities': true,
    'approvals': true,
    'messages': true,
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  ImageProvider _safeImageProvider(String url) {
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(url);
  }

  List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      return raw.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _loadAll() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) { if (mounted) setState(() => _loading = false); return; }

      // 1. Load profile from Supabase
      final data = await Supabase.instance.client.from('profiles').select().eq('id', uid).maybeSingle();
      final prefs = await SharedPreferences.getInstance();

      // 3. Load activity count
      int actCount = 0;
      int connCount = 0;
      try {
        final acts = await Supabase.instance.client.from('activities').select('id').eq('user_id', uid);
        actCount = (acts as List).length;
      } catch (_) {}
      try {
        final conns = await Supabase.instance.client.from('requests').select('id').eq('target_id', uid).eq('status', 'approved');
        connCount = (conns as List).length;
      } catch (_) {}

      if (mounted && data != null) {
        setState(() {
          _bioController.text = data['bio'] ?? '';
          _activeLocation = data['city'] ?? '';
          _avatarUrl = data['avatar_url'] ?? '';
          _name = data['name'] ?? data['full_name'] ?? '';
          _age = data['age'] ?? 0;
          _gender = data['gender'] ?? '';
          _personality = data['personality'] ?? '';
          _isPublic = data['is_public'] ?? true;
          _selectedVibes = _parseList(data['interests']);
          _selectedPurposes = _parseList(data['looking_for']);
          
          if (data['notification_settings'] != null) {
            _notifSettings = Map<String, dynamic>.from(data['notification_settings']);
          }

          // Local preferences
          _navTransition = prefs.getString('nav_transition') ?? 'Slide';
          _distanceRadius = prefs.getDouble('discovery_radius') ?? 50;
          _isGlobal = prefs.getBool('is_global') ?? false;
          _ageRange = RangeValues(
            prefs.getDouble('age_range_min') ?? 18,
            prefs.getDouble('age_range_max') ?? 40,
          );
          _showMe = prefs.getBool('show_me') ?? true;

          // Saved locations from local storage
          final locJson = prefs.getString('saved_locations');
          if (locJson != null) {
            try {
              final decoded = jsonDecode(locJson);
              if (decoded is List) {
                _savedLocations = decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
              }
            } catch (_) {}
          }
          if (_activeLocation.isNotEmpty && !_savedLocations.any((l) => l['name'] == _activeLocation)) {
            _savedLocations.insert(0, {'name': _activeLocation, 'lat': 0.0, 'lng': 0.0});
          }

          final galleryRaw = prefs.getStringList('gallery_urls');
          if (galleryRaw != null && galleryRaw.isNotEmpty) {
            for (int i = 0; i < galleryRaw.length && i < 6; i++) {
              _galleryUrls[i] = galleryRaw[i];
            }
          }

          _activityCount = actCount;
          _connectionCount = connCount;
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Settings load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfileToDb({double? lat, double? lng}) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final map = {
        'bio': _bioController.text.trim(),
        'interests': _selectedVibes,
        'looking_for': _selectedPurposes,
        'city': _activeLocation,
        'notification_settings': _notifSettings,
      };
      if (lat != null) map['lat'] = lat;
      if (lng != null) map['lng'] = lng;

      await Supabase.instance.client.from('profiles').update(map).eq('id', uid);
    } catch (e) {
      debugPrint('DB save error: $e');
    }
  }

  Future<void> _saveLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nav_transition', _navTransition);
    await prefs.setDouble('discovery_radius', _distanceRadius);
    await prefs.setBool('is_global', _isGlobal);
    await prefs.setDouble('age_range_min', _ageRange.start);
    await prefs.setDouble('age_range_max', _ageRange.end);
    await prefs.setBool('show_me', _showMe);
    await prefs.setString('saved_locations', jsonEncode(_savedLocations));
    await prefs.setStringList('gallery_urls', _galleryUrls);
  }

  Future<void> _saveAll() async {
    final lat = locationService.activeLat;
    final lng = locationService.activeLng;
    await _saveProfileToDb(lat: lat, lng: lng);
    await _saveLocalPreferences();
    locationService.setLocation(_activeLocation, lat: lat, lng: lng);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text('All preferences saved!')]),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }



  void _showAddLocationDialog() {
    // Listen for location changes AFTER sheet closes
    void onChanged() {
      final loc = locationService.activeLocation;
      final lat = locationService.activeLat;
      final lng = locationService.activeLng;
      if (loc.isNotEmpty && mounted) {
        setState(() {
          _activeLocation = loc;
          if (!_savedLocations.any((l) => l['name'] == loc)) {
            _savedLocations.insert(0, {'name': loc, 'lat': lat ?? 0.0, 'lng': lng ?? 0.0});
          }
        });
        _saveProfileToDb(lat: lat, lng: lng);
        _saveLocalPreferences();
      }
      locationService.coordinatesUpdateNotifier.removeListener(onChanged);
    }
    locationService.coordinatesUpdateNotifier.addListener(onChanged);
    showLocationSearchSheet(context);
  }

  void _showUpgradeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFFF6B00), width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond, color: Color(0xFFFF6B00), size: 48),
            const SizedBox(height: 16),
            const Text('Relaya Elite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 8),
            const Text('Unlock premium features', style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            _upgradeFeatureRow(Icons.visibility_off, 'Browse Anonymously', 'See profiles without being seen'),
            _upgradeFeatureRow(Icons.bolt, 'Unlimited Rush-Ins', 'No cooldown between Rush-Ins'),
            _upgradeFeatureRow(Icons.location_on, 'Global Discovery', 'Match with people anywhere in the world'),
            _upgradeFeatureRow(Icons.verified, 'Priority Verification', 'Get verified faster with priority queue'),
            _upgradeFeatureRow(Icons.favorite, 'See Who Likes You', 'See who sent you join requests'),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elite upgrade coming soon!'), backgroundColor: Color(0xFFFF7E40))); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF7E40)]), borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text('Upgrade — Coming Soon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _upgradeFeatureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B00), size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    final textP = doodle ? DoodleColors.textPrimary : Colors.white;
    final textM = doodle ? DoodleColors.textMuted : Colors.white38;

    if (_loading) {
      return Scaffold(
        backgroundColor: doodle ? DoodleColors.cream : const Color(0xFF050508),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_ios, size: 18, color: textP), onPressed: () => Navigator.pop(context))),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
      );
    }

    return Scaffold(
      backgroundColor: doodle ? DoodleColors.cream : const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: textP, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('Settings', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════
            // 0. APPEARANCE (NEW - TOP)
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              borderColor: const Color(0xFFFACC15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Text('Appearance ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('✨', style: TextStyle(fontSize: 18))]),
                  Text('Customize your visual experience.', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38, fontSize: 11)),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeService.themeModeNotifier,
                    builder: (context, mode, child) {
                      final isDark = mode == ThemeMode.dark;
                      return Row(
                        children: [
                          Expanded(
                            child: _buildThemeButton(
                              icon: Icons.wb_sunny_outlined,
                              label: 'Day',
                              isSelected: !isDark,
                              onTap: () => themeService.setTheme(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildThemeButton(
                              icon: Icons.nightlight_round_outlined,
                              label: 'Night',
                              isSelected: isDark,
                              onTap: () => themeService.setTheme(ThemeMode.dark),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 0.5. NAVIGATION (NEW STANDALONE)
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              borderColor: const Color(0xFF06B6D4), // Cyan
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Text('Navigation ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('🧭', style: TextStyle(fontSize: 18))]),
                  Text('Customize how you swipe between pages.', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38, fontSize: 11)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101015) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _navTransition,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B202D) : Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
                        items: ['Slide', 'Fade', 'Scale', '3D Flip'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() => _navTransition = newValue);
                            _saveLocalPreferences();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigation set to $newValue'), backgroundColor: const Color(0xFF06B6D4), duration: const Duration(seconds: 1)));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 1. ACCOUNT PLAN
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: doodle ? DoodleColors.paper : const Color(0xFF101015), borderRadius: BorderRadius.circular(14), border: Border.all(color: doodle ? DoodleColors.cardBorder : Colors.transparent)),
                    child: Row(
                      children: [
                        Icon(Icons.account_circle_outlined, color: textM, size: 28),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Standard', style: TextStyle(color: textP, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Free Account', style: TextStyle(color: textM, fontSize: 11)),
                        ]),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: doodle ? DoodleColors.amber : const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('Active', style: TextStyle(color: doodle ? DoodleColors.brown : const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showUpgradeSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(colors: [const Color(0xFFFF6B00).withValues(alpha: 0.15), const Color(0xFFFF7E40).withValues(alpha: 0.15)]),
                        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.diamond, color: Color(0xFFFF6B00), size: 16),
                          SizedBox(width: 8),
                          Text('Upgrade to Elite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFF6B00))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 2. ACTIVITY & HISTORY
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activity & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildTrustRow(Icons.history, 'Rush-In History', 'View All',
                      const Color(0xFF3B82F6),
                      onTap: () {
                        final currentUid = Supabase.instance.client.auth.currentUser?.id;
                        if (currentUid != null) {
                          showRushInHistorySheet(context, currentUid);
                        }
                      }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 3. TRUST & SAFETY
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trust & Safety', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildTrustRow(Icons.verified_user, 'Identity Verified', _isVerified ? 'Verified' : 'Pending',
                      _isVerified ? const Color(0xFF10B981) : Colors.amber,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Verification is reviewed by our team. It may take up to 24 hours.'),
                          backgroundColor: Color(0xFFFF8A00),
                        ));
                      }),
                  const Divider(color: Colors.white10, height: 24),
                  _buildTrustRow(Icons.link_off, 'Linked Account', _isLinked ? 'Linked' : 'Not Linked',
                      _isLinked ? const Color(0xFF10B981) : Colors.white54,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Account linking (Google, Apple) coming soon!'),
                          backgroundColor: Color(0xFFFF8A00),
                        ));
                      }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 3. LOCATION — search-based, PAN India
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              borderColor: const Color(0xFFFF6B00),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF3B82F6)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.explore, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Discovery Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        Text('Filter all feeds by location', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Active location display
                  ValueListenableBuilder<String>(
                    valueListenable: locationService.activeLocationNotifier,
                    builder: (context, activeLoc, _) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: activeLoc.isEmpty ? 0.1 : 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            activeLoc.isEmpty ? Icons.location_off_outlined : Icons.my_location,
                            color: activeLoc.isEmpty ? Colors.white24 : const Color(0xFFFF6B00),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeLoc.isEmpty ? 'No location set' : activeLoc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: activeLoc.isEmpty ? textM : textP,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (activeLoc.isNotEmpty)
                                  const Text('Active · Feeds filtered to this area', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (activeLoc.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Change Location button — opens real search sheet
                  GestureDetector(
                    onTap: _showAddLocationDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF3B82F6)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Search Any City or District', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Works for any district in India', style: TextStyle(color: Colors.white24, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // ═══════════════════════════════════════════════
            // 4. PRIVACY
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              borderColor: const Color(0xFFE11D48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Public Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textP)),
                          const SizedBox(height: 4),
                          Text('When off, only followers will see your posts.', style: TextStyle(color: textM, fontSize: 11)),
                        ],
                      ),
                      Switch(
                        value: _isPublic,
                        activeThumbColor: const Color(0xFFFF6B00),
                        onChanged: (val) async {
                          setState(() => _isPublic = val);
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid != null) {
                            final messenger = ScaffoldMessenger.of(context);
                            await Supabase.instance.client.from('profiles').update({'is_public': val}).eq('id', uid);
                            messenger.showSnackBar(SnackBar(content: Text(val ? 'Account is now public' : 'Account is now private')));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 5. DISCOVERY SETTINGS
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              borderColor: const Color(0xFFFF6B00),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Discovery Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Control who you see.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 20),

                  // Show Me toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show Me on Meetra', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Switch(
                      value: _showMe,
                      onChanged: (v) { setState(() => _showMe = v); _saveLocalPreferences(); },
                      activeThumbColor: const Color(0xFFFF6B00),
                      activeTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                    ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),

                  // Global Discovery Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Global Discovery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Switch(
                        value: _isGlobal,
                        onChanged: (v) { setState(() => _isGlobal = v); _saveLocalPreferences(); },
                        activeThumbColor: const Color(0xFFFF6B00),
                        activeTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  if (!_isGlobal) ...[
                    const Divider(color: Colors.white10, height: 16),
                    Text('Distance Radius: ${_distanceRadius.round()} km', style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.w600, fontSize: 13)),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFFF6B00),
                        inactiveTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                        thumbColor: const Color(0xFFFF6B00),
                        overlayColor: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(value: _distanceRadius, min: 1, max: 200, onChanged: (v) => setState(() => _distanceRadius = v), onChangeEnd: (_) => _saveLocalPreferences()),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()}', style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.w600, fontSize: 13)),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFFFF6B00),
                      inactiveTrackColor: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                      thumbColor: const Color(0xFFFF6B00),
                      overlayColor: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: RangeSlider(values: _ageRange, min: 18, max: 65, onChanged: (v) => setState(() => _ageRange = v), onChangeEnd: (_) => _saveLocalPreferences()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 5. NOTIFICATION SETTINGS
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              borderColor: const Color(0xFFFF7E40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Row(children: [Text('Notifications ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('🔔', style: TextStyle(fontSize: 18))]),
                   const Text('Control how you receive alerts.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                   const SizedBox(height: 20),
                   _buildNotificationToggle('Matches & Knocks', 'Notify when someone knocks back', 'matches'),
                   const Divider(color: Colors.white10, height: 24),
                   _buildNotificationToggle('Nearby Activities', 'Alert when new Rush-Ins start nearby', 'nearby_activities'),
                   const Divider(color: Colors.white10, height: 24),
                   _buildNotificationToggle('Approvals & Rejections', 'Status updates for your join requests', 'approvals'),
                   const Divider(color: Colors.white10, height: 24),
                   _buildNotificationToggle('Messages', 'New chat and message alerts', 'messages'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 6. ABOUT ME
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('About Me', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    GestureDetector(
                      onTap: () async { await _saveProfileToDb(); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bio saved!'), backgroundColor: Color(0xFF10B981))); }, // ignore: use_build_context_synchronously
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.4))),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.save_outlined, color: Color(0xFFFF6B00), size: 14),
                          SizedBox(width: 6),
                          Text('Save', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 300,
                    style: TextStyle(color: doodle ? DoodleColors.textPrimary : Colors.white70, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Write something about yourself...',
                      hintStyle: TextStyle(color: doodle ? DoodleColors.textMuted : Colors.white24),
                      filled: true,
                      fillColor: doodle ? DoodleColors.paper : const Color(0xFF101015),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: doodle ? BorderSide(color: DoodleColors.cardBorder) : BorderSide.none),
                      counterStyle: TextStyle(color: doodle ? DoodleColors.textMuted : Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 6. MY PHOTOS
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('The first photo is your primary profile picture.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final url = await ImageUploadService.pickAndUpload(context: context, folder: 'avatars');
                      if (url != null && mounted) {
                        setState(() => _avatarUrl = url);
                        await ImageUploadService.updateProfileAvatar(url);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primary photo updated!'), backgroundColor: Color(0xFF10B981))); // ignore: use_build_context_synchronously
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _avatarUrl.isNotEmpty
                          ? Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Image(image: _safeImageProvider(_avatarUrl), height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 220, width: double.infinity, color: doodle ? DoodleColors.paper : const Color(0xFF101015), child: Center(child: Icon(Icons.broken_image, color: doodle ? DoodleColors.textMuted : Colors.white24, size: 40)))),
                                Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                                ),
                              ],
                            )
                          : Container(height: 220, width: double.infinity, decoration: BoxDecoration(color: doodle ? DoodleColors.paper : const Color(0xFF101015), border: Border.all(color: doodle ? DoodleColors.cardBorder : Colors.transparent), borderRadius: BorderRadius.circular(16)), child: Center(child: Icon(Icons.add_a_photo, color: doodle ? DoodleColors.textMuted : Colors.white24, size: 40))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10,
                    children: List.generate(6, (i) => GestureDetector(
                      onTap: () async {
                        final url = await ImageUploadService.pickAndUpload(context: context, folder: 'gallery');
                        if (url != null && mounted) {
                          setState(() => _galleryUrls[i] = url);
                          _saveLocalPreferences();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(color: doodle ? DoodleColors.paper : const Color(0xFF101015), borderRadius: BorderRadius.circular(12), border: Border.all(color: doodle ? DoodleColors.cardBorder : Colors.white10)),
                        child: _galleryUrls[i].isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image(image: _safeImageProvider(_galleryUrls[i]), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()))
                            : const Center(child: Icon(Icons.add, color: Color(0xFFFF6B00), size: 24)),
                      ),
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 7. ACTIVITY DASHBOARD
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activity Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Your social stats at a glance.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(Icons.event, 'Activities', '$_activityCount', const Color(0xFFFF6B00)),
                      Container(width: 1, height: 50, color: Colors.white10),
                      _buildStatColumn(Icons.people, 'Connections', '$_connectionCount', const Color(0xFFFF7E40)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 8. WHY ARE YOU HERE?
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Text('Why are you here? ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('💡', style: TextStyle(fontSize: 18))]),
                  const Text('This helps us match you with the right people', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 16),
                  ..._purposeOptions.map((opt) {
                    final isSelected = _selectedPurposes.contains(opt['label']);
                    return GestureDetector(
                      onTap: () => setState(() { isSelected ? _selectedPurposes.remove(opt['label']) : _selectedPurposes.add(opt['label']); }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? (doodle ? DoodleColors.amber : const Color(0xFFFF6B00).withValues(alpha: 0.08)) : (doodle ? DoodleColors.paper : const Color(0xFF101015)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSelected ? (doodle ? DoodleColors.brown : const Color(0xFFFF6B00).withValues(alpha: 0.4)) : (doodle ? DoodleColors.cardBorder : Colors.white10)),
                        ),
                        child: Row(children: [
                          Icon(opt['icon'] as IconData, color: isSelected ? const Color(0xFFFF6B00) : Colors.white54, size: 22),
                          const SizedBox(width: 14),
                          Text(opt['label'] as String, style: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : Colors.white70, fontWeight: FontWeight.w500, fontSize: 14)),
                          const Spacer(),
                          if (isSelected) const Icon(Icons.check_circle, color: Color(0xFFFF6B00), size: 18),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 9. YOUR VIBE
            // ═══════════════════════════════════════════════
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Text('Your Vibe ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('🎯', style: TextStyle(fontSize: 18))]),
                  Text('Pick at least 2 interests (max 6)', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _vibeOptions.map((opt) {
                      final isSelected = _selectedVibes.contains(opt['label']);
                      return GestureDetector(
                        onTap: () => setState(() { isSelected ? _selectedVibes.remove(opt['label']) : (_selectedVibes.length < 6 ? _selectedVibes.add(opt['label']) : null); }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? (doodle ? DoodleColors.amber : const Color(0xFFFF6B00).withValues(alpha: 0.12)) : (doodle ? DoodleColors.paper : const Color(0xFF101015)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? (doodle ? DoodleColors.brown : const Color(0xFFFF6B00).withValues(alpha: 0.5)) : (doodle ? DoodleColors.cardBorder : Colors.white12)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(opt['icon'] as IconData, color: isSelected ? const Color(0xFFFF6B00) : Colors.white54, size: 16),
                            const SizedBox(width: 8),
                            Text(opt['label'] as String, style: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text('${_selectedVibes.length}/6 selected', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SAVE ALL
            GestureDetector(
              onTap: _saveAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: const Center(child: Text('Save All Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
            ),

            const SizedBox(height: 20),

            // SIGN OUT
            GestureDetector(
              onTap: _handleSignOut,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
                ),
                child: const Center(child: Text('Sign Out', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 14))),
              ),
            ),

            const SizedBox(height: 20),

            // DELETE ACCOUNT
            GestureDetector(
              onTap: () {
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF0A0A0F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('This action is permanent and cannot be undone. All your data will be lost.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                    TextButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please contact support to delete your account.'), backgroundColor: Color(0xFFE11D48))); },
                      child: const Text('Delete', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold))),
                  ],
                ));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                ),
                child: const Center(child: Text('Delete Account', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of Meetra?', style: TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  // ── Helpers ──

  Widget _buildSectionCard({required Widget child, Color? borderColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final doodle = isDoodleMode(context);

    if (doodle) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: DoodleDecorations.card(color: DoodleColors.paper, borderColor: borderColor ?? DoodleColors.brown),
        child: child,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor?.withValues(alpha: 0.3) ?? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))),
        boxShadow: [
          if (borderColor != null) BoxShadow(color: borderColor.withValues(alpha: 0.08), blurRadius: 20),
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildNotificationToggle(String title, String subtitle, String key) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: _notifSettings[key] ?? true,
          onChanged: (v) {
            setState(() => _notifSettings[key] = v);
            _saveProfileToDb();
          },
          activeThumbColor: const Color(0xFFFF7E40),
        ),
      ],
    );
  }

  Widget _buildTrustRow(IconData icon, String label, String status, Color statusColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: statusColor, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withValues(alpha: 0.4))),
          child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
        ),
      ]),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _buildThemeButton({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDarkNow = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? (label == 'Day' ? Colors.amber.withValues(alpha: 0.1) : const Color(0xFFFF8A00).withValues(alpha: 0.1))
              : (isDarkNow ? const Color(0xFF101015) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? (label == 'Day' ? Colors.amber : const Color(0xFFFF8A00))
                : (isDarkNow ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected 
                ? (label == 'Day' ? Colors.amber : const Color(0xFFFF8A00))
                : (isDarkNow ? Colors.white38 : Colors.black38), size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              color: isSelected 
                  ? (label == 'Day' ? Colors.amber : const Color(0xFFFF8A00))
                  : (isDarkNow ? Colors.white38 : Colors.black38),
            )),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// ADD LOCATION DIALOG — with integrated FlutterMap + search
// ═══════════════════════════════════════════════════════════════════
class AddLocationDialog extends StatefulWidget {
  final Function(String name, double lat, double lng) onLocationAdded;
  const AddLocationDialog({super.key, required this.onLocationAdded});

  @override
  State<AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  LatLng _selectedPoint = const LatLng(25.4358, 78.5685);
  String _resolvedName = '';
  bool _isResolving = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  bool _isMapDarkMode = true; // Added for theme shift

  @override
  void initState() {
    super.initState();
    _reverseGeocode(_selectedPoint);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMapDarkMode = !isDoodleMode(context);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isResolving = true);
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1&zoom=10';
      final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'MeetraApp/1.0'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final addr = data['address'] ?? {};
        final district = addr['state_district'] ?? addr['county'] ?? addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
        final state = addr['state'] ?? '';
        final name = [district, state].where((s) => s.isNotEmpty).join(', ');
        if (mounted) setState(() { _resolvedName = name.isNotEmpty ? name : (data['display_name'] ?? 'Unknown'); _isResolving = false; });
      } else {
        if (mounted) setState(() { _resolvedName = 'Could not resolve'; _isResolving = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _resolvedName = 'Network error'; _isResolving = false; });
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().length < 3) { setState(() => _searchResults = []); return; }
    try {
      final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5';
      final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'MeetraApp/1.0'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _searchResults = data.map<Map<String, dynamic>>((e) => {
              'name': e['display_name']?.split(',').first.trim() ?? '',
              'full_name': e['display_name'] ?? '',
              'lat': double.tryParse(e['lat']?.toString() ?? '') ?? 0.0,
              'lng': double.tryParse(e['lon']?.toString() ?? '') ?? 0.0,
            }).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _searchPlace(val));
  }

  void _onMapTap(TapPosition tapPos, LatLng point) {
    setState(() { _selectedPoint = point; _searchResults = []; });
    _mapController.move(point, _mapController.camera.zoom);
    _reverseGeocode(point);
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final pt = LatLng(result['lat'], result['lng']);
    setState(() { _selectedPoint = pt; _searchResults = []; _searchCtrl.text = ''; });
    _mapController.move(pt, 12);
    _reverseGeocode(pt);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Select Home Base', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('Set your city for accurate discovery', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
              ]),
              const SizedBox(height: 20),
              
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Map with Theme Shifter
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
                          options: MapOptions(initialCenter: _selectedPoint, initialZoom: 12, onTap: _onMapTap, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all)),
                          children: [
                            TileLayer(userAgentPackageName: 'com.meetra.app', urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'),
                            MarkerLayer(markers: [
                              Marker(point: _selectedPoint, width: 60, height: 60, child: const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 45, shadows: [Shadow(color: Color(0xFFFF6B00), blurRadius: 15)])),
                            ]),
                          ],
                        ),
                      ),

                      // Dark Wash
                      if (_isMapDarkMode) Container(color: const Color(0xFFFF5C00).withValues(alpha: 0.1)),

                      // Glassmorphic Search
                      Positioned(
                        top: 16, left: 16, right: 64,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: _onSearchChanged,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(hintText: 'Search city...', hintStyle: TextStyle(color: Colors.white38, fontSize: 13), border: InputBorder.none, icon: Icon(Icons.search, color: Color(0xFFFF6B00), size: 18)),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Day/Night Shifter
                      Positioned(
                        top: 16, right: 16,
                        child: GestureDetector(
                          onTap: () => setState(() => _isMapDarkMode = !_isMapDarkMode),
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
                            child: Icon(_isMapDarkMode ? Icons.wb_sunny : Icons.nightlight_round, color: _isMapDarkMode ? Colors.yellow : Colors.blueGrey, size: 20),
                          ),
                        ),
                      ),

                      // Search Results
                      if (_searchResults.isNotEmpty)
                        Positioned(
                          top: 72, left: 16, right: 64,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3))),
                                child: ListView.separated(
                                  shrinkWrap: true, padding: EdgeInsets.zero, itemCount: _searchResults.length,
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                  itemBuilder: (ctx, i) {
                                    final r = _searchResults[i];
                                    return ListTile(
                                      dense: true, leading: const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 16),
                                      title: Text(r['name'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      subtitle: Text(r['full_name'], style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onTap: () => _selectSearchResult(r),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Resolution Result
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.map_outlined, color: Color(0xFFFF6B00), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isResolving
                        ? const LinearProgressIndicator(backgroundColor: Colors.white10, color: Color(0xFFFF6B00))
                        : Text(_resolvedName.isEmpty ? 'Tap map to select' : _resolvedName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ]),
              ),
              
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white54))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_resolvedName.isEmpty || _resolvedName == 'Could not resolve' || _resolvedName == 'Network error') return;
                      widget.onLocationAdded(_resolvedName, _selectedPoint.latitude, _selectedPoint.longitude);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 54, alignment: Alignment.center,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)])),
                      child: const Text('Add Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
