// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'image_upload_service.dart';
import 'feature_guide_screen.dart';
import 'main.dart';
import 'services/location_service.dart';


// ─────────────────────────────────────────────────────────────────
// PREMIUM ONBOARDING SCREEN — 6-step cinematic profile setup
// Inspired by Hinge / Bumble / Tinder best practices
// ─────────────────────────────────────────────────────────────────

const _bg    = Color(0xFF000000);
const _card  = Color(0xFF131318);
const _card2 = Color(0xFF1A1A22);
const _orange = Color(0xFFFF6B00);
const _amber  = Color(0xFFFF9F0A);
const _green  = Color(0xFF22C55E);
const _txt   = Color(0xFFF1F5F9);
const _txt2  = Color(0xFF94A3B8);
const _muted = Color(0xFF64748B);
const _gb    = Color(0x14FFFFFF);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  static const int _totalSteps = 6;
  bool _saving = false;
  final PageController _pageCtrl = PageController();
  late AnimationController _pulseCtrl;
  late AnimationController _orbCtrl;

  // ── Step 1: Identity ──
  String? _photoUrl;
  final _nameCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _usernameAvailable = false;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // ── Step 2: DOB & Bio ──
  int _dobDay = 1, _dobMonth = 1, _dobYear = 2000;
  bool _dobSet = false;
  final _bioCtrl = TextEditingController();
  static const _monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  // ── Step 3: Gender ──
  String _gender = '';

  // ── Step 4: Interests ──
  final Set<String> _selectedInterests = {};
  static const int _maxInterests = 7;

  static const _interestGroups = {
    '🎵 Music':    ['Pop','Hip-Hop','Rock','Jazz','EDM','Classical','Indie','R&B','Bollywood','K-Pop'],
    '🎮 Gaming':   ['Mobile Games','PC Gaming','Console','Esports','RPGs','FPS','Casual Games'],
    '✈️ Travel':   ['Backpacking','Beach','Mountains','City Trips','Solo Travel','Luxury Travel'],
    '🍕 Food':     ['Street Food','Cooking','Baking','Cafes','Fine Dining','Veganism','Sushi','Desserts'],
    '📸 Creative': ['Photography','Drawing','Writing','Design','Music Production','Film Making'],
    '🏋️ Fitness':  ['Gym','Yoga','Running','Cycling','Cricket','Football','Basketball','Dance'],
    '💻 Tech':     ['Coding','AI & ML','Gadgets','Startups','Blockchain','Gaming Tech'],
    '📚 Learning': ['Books','Podcasts','Online Courses','Philosophy','History','Science'],
    '🎬 Culture':  ['Movies','Series','Anime','Theatre','Stand-Up Comedy','Art Galleries'],
    '🌿 Outdoors': ['Hiking','Camping','Nature Walks','Bird Watching','Adventure Sports'],
  };

  // ── Step 5: Personality Vibes ──
  final Set<String> _selectedVibes = {};
  static const int _maxVibes = 4;

  static const _vibes = [
    ('🌙 Night Owl',     'nightowl'),
    ('☀️ Early Bird',    'earlybird'),
    ('⚡ Spontaneous',   'spontaneous'),
    ('🎯 Goal-Oriented', 'goaldirected'),
    ('🎭 Creative Soul', 'creative'),
    ('🤝 Social Butterfly','social'),
    ('🧘 Calm & Chill',  'calm'),
    ('🔥 Ambitious',     'ambitious'),
    ('😂 Funny & Witty', 'funny'),
    ('💡 Deep Thinker',  'deepthink'),
    ('🎉 Party Person',  'partyperson'),
    ('📖 Homebody',      'homebody'),
    ('🌍 Adventurous',   'adventurous'),
    ('💪 Fitness Buff',  'fitness'),
    ('🎨 Artsy',         'artsy'),
    ('🤓 Intellectual',  'intellectual'),
  ];

  // ── Step 6: Location ──
  double? _lat, _lng;
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final MapController _mapCtrl = MapController();
  final _locSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  bool _detectingLocation = false;

  // ── DOB wheel state ──
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _orbCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    final now = DateTime.now();
    _dobDay = 1; _dobMonth = 1; _dobYear = now.year - 20;
    final yearList = _yearList;
    _dayCtrl   = FixedExtentScrollController(initialItem: 0);
    _monthCtrl = FixedExtentScrollController(initialItem: 0);
    _yearCtrl  = FixedExtentScrollController(initialItem: yearList.indexOf(_dobYear).clamp(0, yearList.length - 1));
  }

  List<int> get _yearList {
    final maxYear = DateTime.now().year - 16;
    return List.generate(maxYear - 1950 + 1, (i) => 1950 + i);
  }

  int _daysInMonth(int m, int y) => DateTime(y, m + 1, 0).day;

  String get _dobString {
    if (!_dobSet) return '';
    return '$_dobYear-${_dobMonth.toString().padLeft(2,'0')}-${_dobDay.toString().padLeft(2,'0')}';
  }

  String get _dobDisplay {
    if (!_dobSet) return 'Select Date of Birth';
    return '${_monthNames[_dobMonth - 1]} $_dobDay, $_dobYear';
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _usernameDebounce?.cancel();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _locSearchCtrl.dispose();
    _searchDebounce?.cancel();
    _pageCtrl.dispose();
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Step validation ──────────────────────────────────────────────
  bool get _canProceed {
    switch (_step) {
      case 0:
        final bool isNameValid = _nameCtrl.text.trim().length >= 2;
        final bool isUsernameValid = _usernameCtrl.text.trim().length >= 3 && _usernameAvailable;
        final bool isPasswordValid = _passwordCtrl.text.length >= 6 && _passwordCtrl.text == _confirmPasswordCtrl.text;
        return isNameValid && isUsernameValid && isPasswordValid;
      case 1: return _dobSet;
      case 2: return _gender.isNotEmpty;
      case 3: return _selectedInterests.length >= 3;
      case 4: return _selectedVibes.isNotEmpty;
      case 5: return _lat != null && _lng != null;
      default: return true;
    }
  }

  void _nextStep() {
    if (!_canProceed) {
      _showNudge();
      return;
    }
    if (_step < _totalSteps - 1) {
      HapticFeedback.selectionClick();
      setState(() => _step++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    } else {
      _completeOnboarding();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      HapticFeedback.selectionClick();
      setState(() => _step--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    }
  }

  void _showNudge() {
    final msgs = [
      'Please enter your name, username, and a valid password.',
      'Pick your birthday to continue.',
      'Select your gender to continue.',
      'Pick at least 3 interests to continue.',
      'Choose at least 1 vibe that describes you.',
      'Please pin your location to continue.',
    ];
    if (msgs[_step].isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msgs[_step], style: const TextStyle(color: Colors.white)),
      backgroundColor: _orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Username check ───────────────────────────────────────────────
  void _checkUsername(String val) {
    _usernameDebounce?.cancel();
    final clean = val.toLowerCase().trim();
    if (clean.length < 3) {
      setState(() { _usernameAvailable = false; _checkingUsername = false; });
      return;
    }
    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final res = await Supabase.instance.client
            .from('profiles').select('id').eq('username', clean).maybeSingle();
        if (mounted) setState(() { _usernameAvailable = res == null; _checkingUsername = false; });
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  // ── Photo upload ─────────────────────────────────────────────────
  Future<void> _handlePhotoUpload() async {
    final url = await ImageUploadService.pickAndUpload(context: context, folder: 'avatars');
    if (url != null && mounted) setState(() => _photoUrl = url);
  }

  // ── Location search ──────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) { if (mounted) setState(() => _searchResults = []); return; }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await locationService.searchLocations(q);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  void _selectResult(Map<String, dynamic> r) {
    final lat = (r['lat'] as num).toDouble();
    final lng = (r['lng'] as num).toDouble();
    final name = r['name']?.toString() ?? '';
    final full = r['full_name']?.toString() ?? '';
    setState(() {
      _lat = lat; _lng = lng;
      _cityCtrl.text = name;
      _stateCtrl.text = full.split(',').length > 1 ? full.split(',')[1].trim() : '';
      _locSearchCtrl.text = name;
      _searchResults = [];
    });
    _mapCtrl.move(LatLng(lat, lng), 14.0);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1';
      final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'RelayaApp/1.0'});
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        final addr = data['address'] ?? {};
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
        final state = addr['state'] ?? '';
        setState(() { _cityCtrl.text = city; _stateCtrl.text = state; _locSearchCtrl.text = city; });
      }
    } catch (_) {}
  }

  Future<void> _detectMyLocation() async {
    setState(() => _detectingLocation = true);
    try {
      bool svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) throw Exception('Location services disabled');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) throw Exception('Permission denied forever');
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 14.0);
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not detect: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  // ── Complete onboarding ──────────────────────────────────────────
  Future<void> _completeOnboarding() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final locationName = [_cityCtrl.text.trim(), _stateCtrl.text.trim()].where((s) => s.isNotEmpty).join(', ');
      final cleanUsername = _usernameCtrl.text.trim().toLowerCase();
      final finalUsername = cleanUsername.isNotEmpty && _usernameAvailable
          ? cleanUsername
          : 'user_${uid.substring(0, 8)}';

      if (_passwordCtrl.text.trim().isNotEmpty && _passwordCtrl.text == _confirmPasswordCtrl.text) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              email: '$finalUsername@relaya.app',
              password: _passwordCtrl.text.trim(),
            ),
          );
        } catch (e) {
          debugPrint('Auth updateUser failed (email/password setup): $e');
        }
      }

      final payload = <String, dynamic>{
        'id': uid,
        'name': _nameCtrl.text.trim(),
        'full_name': _nameCtrl.text.trim(),
        'username': finalUsername,
        'gender': _gender,
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'district': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'lat': _lat ?? 0,
        'lng': _lng ?? 0,
        'avatar_url': _photoUrl ?? '',
        'onboarding_complete': true,
        'is_public': true,
      };

      if (_dobSet) payload['dob'] = _dobString;
      if (_selectedInterests.isNotEmpty) payload['interests'] = _selectedInterests.toList();
      if (_selectedVibes.isNotEmpty) payload['personality_traits'] = _selectedVibes.toList();

      // Try to save all fields; gracefully degrade if schema lacks optional columns
      try {
        await Supabase.instance.client.from('profiles').upsert(payload, onConflict: 'id');
      } on PostgrestException catch (e) {
        // Retry with only core fields if optional columns don't exist yet
        debugPrint('Full upsert failed ($e), retrying with core fields...');
        await Supabase.instance.client.from('profiles').upsert({
          'id': uid,
          'name': _nameCtrl.text.trim(),
          'full_name': _nameCtrl.text.trim(),
          'username': finalUsername,
          'gender': _gender,
          'city': _cityCtrl.text.trim(),
          'lat': _lat ?? 0,
          'lng': _lng ?? 0,
          'avatar_url': _photoUrl ?? '',
          'onboarding_complete': true,
        }, onConflict: 'id');
      }

      if (_lat != null && _lng != null) {
        locationService.setLocation(locationName.isNotEmpty ? locationName : _cityCtrl.text, lat: _lat, lng: _lng);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('matchRadius', 25.0);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => FeatureGuideScreen(
              onComplete: (guideCtx) {
                Navigator.of(guideCtx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainDashboard()),
                  (route) => false,
                );
              },
            ),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final stepTitles = [
      'Create your identity',
      'Your birthday & bio',
      'How do you identify?',
      'What do you love?',
      'Your vibe',
      'Where are you?',
    ];
    final stepSubtitles = [
      'Set up your public profile',
      'Help us personalise your experience',
      'This helps us tailor your feed',
      'Pick up to 7 interests',
      'Pick up to 4 words that describe you',
      'Find people & events near you',
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Ambient background orbs
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, __) {
              final t = _orbCtrl.value;
              return Stack(children: [
                Positioned(
                  top: -60 + 30 * math.sin(t * math.pi),
                  right: -80,
                  child: _orb(350, _orange.withValues(alpha: 0.15)),
                ),
                Positioned(
                  bottom: 80 + 20 * math.cos(t * math.pi),
                  left: -60,
                  child: _orb(300, _amber.withValues(alpha: 0.12)),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ]);
            },
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      if (_step > 0)
                        GestureDetector(
                          onTap: _prevStep,
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _gb)),
                            child: const Icon(Icons.arrow_back_ios_new, color: _txt2, size: 16),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                      const Spacer(),
                      Text(
                        '${_step + 1} / $_totalSteps',
                        style: GoogleFonts.inter(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // ── Progress bar ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuint,
                      height: 6,
                      width: MediaQuery.of(context).size.width * ((_step + 1) / _totalSteps),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_orange, _amber]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: _orange.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Step header ──────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stepTitles[_step], style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: _txt, height: 1.1)),
                        const SizedBox(height: 6),
                        Text(stepSubtitles[_step], style: GoogleFonts.inter(fontSize: 13, color: _muted)),
                      ],
                    ),
                  ),
                ),

                // ── Page content ─────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _step0Identity(),
                      _step1BioAndDob(),
                      _step2Gender(),
                      _step3Interests(),
                      _step4Vibes(),
                      _step5Location(),
                    ],
                  ),
                ),

                // ── Bottom CTA ───────────────────────────────────
                _buildBottomCta(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])),
  );

  Widget _buildBottomCta() {
    final isLast = _step == _totalSteps - 1;
    final canGo  = _canProceed;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: GestureDetector(
        onTap: _saving ? null : _nextStep,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: canGo && !_saving
                ? const LinearGradient(colors: [_orange, _amber])
                : null,
            color: !canGo || _saving ? Colors.white.withValues(alpha: 0.07) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: canGo && !_saving ? [BoxShadow(color: _orange.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))] : null,
          ),
          child: Center(
            child: _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                        color: canGo ? Colors.black : _muted, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      isLast ? "Let's Go!" : 'Continue',
                      style: GoogleFonts.inter(color: canGo ? Colors.black : _muted, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 0 — Identity: Photo, Name, Username
  // ════════════════════════════════════════════════════════════════
  Widget _step0Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: <Widget>[
          // Photo picker
          GestureDetector(
            onTap: _handlePhotoUpload,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) {
                final glow = _photoUrl == null ? _pulseCtrl.value * 0.08 + 0.02 : 0.0;
                return Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _card2,
                    border: Border.all(color: _photoUrl != null ? _orange : Colors.white.withValues(alpha: 0.15), width: 2.5),
                    boxShadow: _photoUrl == null ? [BoxShadow(color: _orange.withValues(alpha: glow), blurRadius: 24, spreadRadius: 4)] : null,
                  ),
                  child: _photoUrl != null
                      ? ClipOval(child: Image(image: _buildSafeImage(_photoUrl), fit: BoxFit.cover, width: 110, height: 110))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_a_photo_rounded, color: _orange, size: 28),
                          const SizedBox(height: 6),
                          Text('Add Photo', style: GoogleFonts.inter(color: _orange, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('Profile photo', style: GoogleFonts.inter(color: _muted, fontSize: 11)),
          const SizedBox(height: 28),
          _inputField('Your first name *', _nameCtrl, Icons.person_outline, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          _usernameField(),
          const SizedBox(height: 14),
          _passwordFields(),
        ].animate(interval: 50.ms).fade(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }

  Widget _passwordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gb),
          ),
          child: TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(color: _txt, fontSize: 16),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              icon: Icon(Icons.lock_outline, color: _muted, size: 22),
              border: InputBorder.none,
              hintText: 'Create a Password (min. 6 chars)',
              hintStyle: GoogleFonts.inter(color: _txt2),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: _muted),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ),
        if (_passwordCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _confirmPasswordCtrl.text.isEmpty
                    ? _gb
                    : (_passwordCtrl.text == _confirmPasswordCtrl.text ? _green : Colors.red),
              ),
            ),
            child: TextField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscurePassword,
              style: GoogleFonts.inter(color: _txt, fontSize: 16),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                icon: Icon(Icons.lock_outline, color: _muted, size: 22),
                border: InputBorder.none,
                hintText: 'Confirm Password',
                hintStyle: GoogleFonts.inter(color: _txt2),
              ),
            ),
          ),
          if (_passwordCtrl.text.isNotEmpty && _confirmPasswordCtrl.text.isNotEmpty && _passwordCtrl.text != _confirmPasswordCtrl.text)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Text('Passwords do not match', style: GoogleFonts.inter(color: Colors.red, fontSize: 12)),
            )
        ],
      ],
    );
  }

  Widget _usernameField() {
    final val = _usernameCtrl.text.trim();
    Color borderColor = _gb;
    IconData? trailingIcon;
    Color? trailingColor;
    if (val.length >= 3) {
      if (_checkingUsername) {
        borderColor = _gb;
      } else if (_usernameAvailable) {
        borderColor = _green;
        trailingIcon = Icons.check_circle;
        trailingColor = _green;
      } else {
        borderColor = Colors.red;
        trailingIcon = Icons.cancel;
        trailingColor = Colors.red;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderColor == _gb ? 1 : 1.5),
          ),
          child: TextField(
            controller: _usernameCtrl,
            style: GoogleFonts.inter(color: _txt, fontSize: 15),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\.]'))],
            decoration: InputDecoration(
              hintText: '@username',
              hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
              prefixIcon: const Icon(Icons.alternate_email, color: _orange, size: 20),
              suffixIcon: _checkingUsername
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: _orange)))
                  : trailingIcon != null ? Icon(trailingIcon, color: trailingColor, size: 20) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (v) { setState(() {}); _checkUsername(v); },
          ),
        ),
        if (val.length >= 3 && !_checkingUsername && !_usernameAvailable)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text('Username taken. Try another.', style: GoogleFonts.inter(color: Colors.red, fontSize: 11)),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 1 — Birthday & Bio
  // ════════════════════════════════════════════════════════════════
  Widget _step1BioAndDob() {
    final yearList = _yearList;
    final days     = List.generate(_daysInMonth(_dobMonth, _dobYear), (i) => i + 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // DOB header
          Row(children: [
            const Icon(Icons.cake_outlined, color: _orange, size: 18),
            const SizedBox(width: 8),
            Text('Date of Birth', style: GoogleFonts.inter(color: _txt, fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            if (_dobSet)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(_dobDisplay, style: GoogleFonts.inter(color: _orange, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 12),
          // Drum-roll date picker
          Container(
            height: 180,
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _orange.withValues(alpha: 0.2))),
            child: Stack(
              children: [
                // selection indicator
                Center(
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _orange.withValues(alpha: 0.4), width: 1.5),
                      color: _orange.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Day
                      Expanded(child: _drumWheel(
                        controller: _dayCtrl,
                        items: days,
                        label: (v) => v.toString().padLeft(2,'0'),
                        onChanged: (i) { _dobDay = days[i]; _dobSet = true; setState((){}); },
                      )),
                      // Month
                      Expanded(child: _drumWheel(
                        controller: _monthCtrl,
                        items: List.generate(12, (i) => i + 1),
                        label: (v) => _monthNames[v - 1],
                        onChanged: (i) { _dobMonth = i + 1; _dobSet = true; setState((){}); },
                      )),
                      // Year
                      Expanded(child: _drumWheel(
                        controller: _yearCtrl,
                        items: yearList,
                        label: (v) => v.toString(),
                        onChanged: (i) { _dobYear = yearList[i]; _dobSet = true; setState((){}); },
                      )),
                    ],
                  ),
                ),
                // top/bottom fades
                Positioned(top: 0, left: 0, right: 0, height: 60,
                  child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_card, _card.withValues(alpha: 0)])))),
                Positioned(bottom: 0, left: 0, right: 0, height: 60,
                  child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [_card, _card.withValues(alpha: 0)])))),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Bio
          Row(children: [
            const Icon(Icons.edit_outlined, color: _orange, size: 18),
            const SizedBox(width: 8),
            Text('Short Bio', style: GoogleFonts.inter(color: _txt, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 6),
            Text('(optional)', style: GoogleFonts.inter(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
            child: TextField(
              controller: _bioCtrl,
              maxLines: 3,
              maxLength: 120,
              style: GoogleFonts.inter(color: _txt, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. "Music lover, explorer, always up for an adventure ✨"',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.inter(color: _muted, fontSize: 11),
              ),
            ),
          ),
        ].animate(interval: 50.ms).fade(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }

  Widget _drumWheel({
    required FixedExtentScrollController controller,
    required List<int> items,
    required String Function(int) label,
    required void Function(int) onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 50,
      perspective: 0.003,
      diameterRatio: 1.8,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: items.length,
        builder: (_, i) {
          if (i < 0 || i >= items.length) return null;
          final sel = controller.hasClients && controller.selectedItem == i;
          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: GoogleFonts.inter(
                fontSize: sel ? 22 : 16,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w400,
                color: sel ? _txt : Colors.white.withValues(alpha: 0.3),
              ),
              child: Text(label(items[i])),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 2 — Gender
  // ════════════════════════════════════════════════════════════════
  Widget _step2Gender() {
    final options = [
      ('Man',       Icons.face_rounded,       const Color(0xFF3B82F6)),
      ('Woman',     Icons.face_3_rounded,      const Color(0xFFEC4899)),
      ('Non-Binary',Icons.person_2_rounded,    const Color(0xFF8B5CF6)),
      ('Prefer not to say', Icons.remove_circle_outline, _muted),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: <Widget>[
          Row(children: [
            Expanded(child: _genderCard(options[0])),
            const SizedBox(width: 14),
            Expanded(child: _genderCard(options[1])),
          ]),
          const SizedBox(height: 14),
          _genderTile(options[2]),
          const SizedBox(height: 10),
          _genderTile(options[3]),
        ].animate(interval: 50.ms).fade(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }

  Widget _genderCard((String, IconData, Color) opt) {
    final sel = _gender == opt.$1;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _gender = opt.$1); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: sel ? opt.$3.withValues(alpha: 0.12) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? opt.$3 : _gb, width: sel ? 2 : 1),
          boxShadow: sel ? [BoxShadow(color: opt.$3.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0,4))] : null,
        ),
        child: Column(children: [
          Icon(opt.$2, size: 52, color: sel ? opt.$3 : _muted),
          const SizedBox(height: 12),
          Text(opt.$1, style: GoogleFonts.inter(color: sel ? opt.$3 : _txt, fontSize: 16, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          if (sel) ...[const SizedBox(height: 6), Icon(Icons.check_circle, color: opt.$3, size: 18)],
        ]),
      ),
    );
  }

  Widget _genderTile((String, IconData, Color) opt) {
    final sel = _gender == opt.$1;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _gender = opt.$1); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: sel ? opt.$3.withValues(alpha: 0.10) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? opt.$3 : _gb, width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(opt.$2, color: sel ? opt.$3 : _muted, size: 22),
          const SizedBox(width: 16),
          Text(opt.$1, style: GoogleFonts.inter(color: sel ? opt.$3 : _txt, fontSize: 15, fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
          const Spacer(),
          if (sel) Icon(Icons.check_circle_rounded, color: opt.$3, size: 20),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 3 — Interests
  // ════════════════════════════════════════════════════════════════
  Widget _step3Interests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _gb)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.interests_outlined, color: _orange, size: 16),
              const SizedBox(width: 6),
              Text('${_selectedInterests.length} / $_maxInterests selected',
                  style: GoogleFonts.inter(color: _selectedInterests.length >= 3 ? _orange : _muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 18),
          ..._interestGroups.entries.map((entry) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.key, style: GoogleFonts.inter(color: _txt2, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: entry.value.map((tag) {
                final sel = _selectedInterests.contains(tag);
                final maxed = _selectedInterests.length >= _maxInterests && !sel;
                return GestureDetector(
                  onTap: maxed ? null : () {
                    HapticFeedback.selectionClick();
                    setState(() { if (sel) _selectedInterests.remove(tag); else _selectedInterests.add(tag); });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _orange.withValues(alpha: 0.15) : _card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: sel ? _orange : Colors.white.withValues(alpha: maxed ? 0.03 : 0.1), width: sel ? 1.5 : 1),
                    ),
                    child: Text(tag, style: GoogleFonts.inter(color: sel ? _orange : maxed ? _muted : _txt2, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),
            ]);
          }),
        ].animate(interval: 50.ms).fade(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 4 — Personality Vibes
  // ════════════════════════════════════════════════════════════════
  Widget _step4Vibes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _gb)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${_selectedVibes.length} / $_maxVibes selected',
                  style: GoogleFonts.inter(color: _selectedVibes.isNotEmpty ? _orange : _muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: _vibes.map((v) {
              final (label, key) = v;
              final sel = _selectedVibes.contains(key);
              final maxed = _selectedVibes.length >= _maxVibes && !sel;
              return GestureDetector(
                onTap: maxed ? null : () {
                  HapticFeedback.selectionClick();
                  setState(() { if (sel) _selectedVibes.remove(key); else _selectedVibes.add(key); });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? _amber.withValues(alpha: 0.15) : _card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: sel ? _amber : Colors.white.withValues(alpha: maxed ? 0.04 : 0.12),
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel ? [BoxShadow(color: _amber.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0,3))] : null,
                  ),
                  child: Text(label, style: GoogleFonts.inter(color: sel ? _amber : maxed ? _muted : _txt, fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ].animate(interval: 50.ms).fade(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 5 — Location
  // ════════════════════════════════════════════════════════════════
  Widget _step5Location() {
    final pinLat = _lat ?? 20.5937;
    final pinLng = _lng ?? 78.9629;
    final hasPin = _lat != null && _lng != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: <Widget>[
          // Detect button
          GestureDetector(
            onTap: _detectingLocation ? null : _detectMyLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _detectingLocation
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _orange, strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, color: _orange, size: 18),
                const SizedBox(width: 10),
                Text(_detectingLocation ? 'Detecting...' : 'Use my current location',
                    style: GoogleFonts.inter(color: _orange, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // Search bar
          Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
            child: TextField(
              controller: _locSearchCtrl,
              style: GoogleFonts.inter(color: _txt, fontSize: 14),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search city, area, landmark...',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.search, color: _orange, size: 20),
                suffixIcon: _locSearchCtrl.text.isNotEmpty
                    ? GestureDetector(onTap: () => setState(() { _locSearchCtrl.clear(); _searchResults = []; }), child: const Icon(Icons.close, color: _muted, size: 18))
                    : null,
              ),
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _gb)),
              child: ListView.builder(
                shrinkWrap: true, padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final r = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: _orange, size: 18),
                    title: Text(r['name'] ?? '', style: GoogleFonts.inter(color: _txt, fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(r['full_name'] ?? '', style: GoogleFonts.inter(color: _muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectResult(r),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),

          // Map
          if (hasPin || _cityCtrl.text.isEmpty)
            Container(
              height: 230,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _orange.withValues(alpha: 0.25))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: LatLng(pinLat, pinLng),
                    initialZoom: hasPin ? 13.0 : 4.0,
                    onTap: (_, point) {
                      setState(() { _lat = point.latitude; _lng = point.longitude; });
                      _reverseGeocode(point.latitude, point.longitude);
                    },
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png', userAgentPackageName: 'com.meetra.app'),
                    if (hasPin)
                      MarkerLayer(markers: [Marker(
                        point: LatLng(pinLat, pinLng), width: 44, height: 44,
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _orange.withValues(alpha: 0.15), border: Border.all(color: _orange, width: 2)),
                          child: const Icon(Icons.location_pin, color: _orange, size: 28),
                        ),
                      )]),
                  ],
                ),
              ),
            ),

          // City display
          if (_cityCtrl.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _green.withValues(alpha: 0.25))),
              child: Row(children: [
                const Icon(Icons.location_on, color: _green, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  [_cityCtrl.text, _stateCtrl.text].where((s) => s.isNotEmpty).join(', '),
                  style: GoogleFonts.inter(color: _txt, fontSize: 14, fontWeight: FontWeight.w600),
                )),
                const Icon(Icons.check_circle, color: _green, size: 18),
              ]),
            ),

          const SizedBox(height: 8),
          Text('Tap the map to pin your location. It is required to find events near you.',
              style: GoogleFonts.inter(color: _orange, fontSize: 11), textAlign: TextAlign.center),
        ].animate(interval: 50.ms).fade(duration: 500.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0),
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────
  Widget _inputField(String hint, TextEditingController ctrl, IconData icon, {void Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.inter(color: _txt, fontSize: 15),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
          prefixIcon: Icon(icon, color: _orange, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  ImageProvider _buildSafeImage(String? url) {
    if (url == null || url.isEmpty) return const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200');
    if (url.startsWith('http')) return NetworkImage(url);
    try {
      return MemoryImage(base64Decode(url.contains(',') ? url.split(',').last : url));
    } catch (_) {
      return const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200');
    }
  }
}
