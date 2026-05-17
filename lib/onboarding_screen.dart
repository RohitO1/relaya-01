// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'image_upload_service.dart';
import 'feature_guide_screen.dart';
import 'main.dart';
import 'services/location_service.dart';

// ─────────────────────────────────────────────────────────────────
// PREMIUM ONBOARDING SCREEN — 16-step ultra-detailed profile setup
// ─────────────────────────────────────────────────────────────────

const _bg = Color(0xFF000000);
const _card = Color(0xFF1A1F2E);
const _cyan = Color(0xFF00E5CC);
const _pink = Color(0xFFFF007F);
const _green = Color(0xFF22C55E);
const _txt = Color(0xFFF1F5F9);
const _txt2 = Color(0xFF94A3B8);
const _muted = Color(0xFF64748B);
const _gb = Color(0x14FFFFFF);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final int _totalSteps = 17;
  bool _saving = false;
  final PageController _pageCtrl = PageController();

  // Basic Info
  String? _photoUrl;
  final _displayNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String _gender = '';
  
  // Location
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  final MapController _mapCtrl = MapController();
  final TextEditingController _locSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  double _radiusKm = 25.0;
  bool _detectingLocation = false;
  bool _isMapLight = false;

  // Demographics / Lifestyle
  double _heightCm = 170;
  String _smoking = '';
  String _drinking = '';
  String _weed = '';
  String _diet = '';
  String _exercise = '';
  String _education = '';
  final String _jobTitle = '';
  String _zodiac = '';
  String _relationshipType = '';
  String _religion = '';
  String _matchGender = '';
  
  // Personality & Interests
  final Set<String> _selectedTraits = {};
  final Set<String> _selectedInterests = {};
  final Set<String> _selectedVibes = {};
  
  // Preferences
  final _langCtrl = TextEditingController();
  bool _pushNotif = true;
  bool _privateProfile = false;

  // --- DATA LISTS ---
  static const _personalityTraits = ['Active Listener', 'Adventurous', 'Affectionate', 'Ambitious', 'Animal lover', 'Assertive', 'Bookworm', 'Brunch Lover', 'Carefree', 'Charismatic', 'Cheerful', 'Competitive', 'Confident', 'Conservative', 'Creative', 'Cultural', 'Empathetic', 'ENFJ', 'ENFP', 'ENTJ', 'ENTP', 'Entrepreneurial', 'ESFJ', 'ESFP', 'ESTJ', 'ESTP', 'Extroverted', 'Family-oriented', 'Fashionable', 'Funny', 'Generous', 'Germaphobe', 'Good with Kids', 'INFJ', 'INFP', 'Intelligent', 'INTJ', 'INTP', 'Introverted', 'ISFJ', 'ISFP', 'ISTJ', 'ISTP', 'Liberal', 'Nerdy', 'Night owl', 'Open-minded', 'Outdoorsy', 'Patient', 'Playful', 'Positive', 'Respectful', 'Romantic', 'Self-aware', 'Shopaholic', 'Spontaneous', 'Thoughtful'];

  static const _interestCategories = {
    'Arts & Culture': ['Acting', 'Anime', 'Art galleries', 'Board games', 'Creative writing', 'Design', 'DIY', 'Fashion', 'Film & Cinema', 'Filmmaking', 'Knitting', 'Learning languages', 'Live music', 'Museums', 'Painting', 'Photography', 'Playing music', 'Pottery', 'Reading', 'Sewing', 'Standup comedy', 'Theatre', 'Travel', 'TV shows'],
    'Community': ['Activism', 'Family time', 'Politics', 'Spending time with friends', 'Volunteering'],
    'Food & Drink': ['Baking', 'Bubble tea', 'Cake decorating', 'Chocolate', 'Coffee', 'Cooking', 'Eating out', 'Fish & chips', 'Healthy eating', 'Junk food', 'Meat lover', 'Pescatarian', 'Pizza', 'Sushi', 'Vegan', 'Vegetarian'],
    'Outdoors': ['Bird watching', 'Camping', 'Fishing', 'Gardening', 'Hiking', 'Nature walks', 'Scuba diving'],
    'Sport': ['American football', 'Archery', 'Badminton', 'Baseball', 'Basketball', 'Boxing', 'Calisthenics', 'Cricket', 'Cycling', 'Dancing', 'Fencing', 'Figure skating', 'Football', 'Golf', 'Gym', 'Gymnastics', 'Horse Riding', 'Ice hockey', 'Mixed Martial arts', 'Motorsports', 'Pilates', 'Rock climbing', 'Rollerblading', 'Rowing', 'Rugby', 'Running', 'Sailing', 'Skateboarding', 'Skiing', 'Snowboarding', 'Surfing', 'Swimming', 'Tennis', 'Volleyball', 'Yoga'],
    'Technology': ['Animation', 'Blogging', 'Coding', 'Content creation', 'Digital art', 'Influencer', 'Live streaming', 'Tech', 'Video games']
  };

  static const _zodiacSigns = ['♈ Aries', '♉ Taurus', '♊ Gemini', '♋ Cancer', '♌ Leo', '♍ Virgo', '♎ Libra', '♏ Scorpio', '♐ Sagittarius', '♑ Capricorn', '♒ Aquarius', '♓ Pisces'];
  static const _religions = ['Agnostic', 'Atheist', 'Buddhist', 'Catholic', 'Christian', 'Hindu', 'Jewish', 'Muslim', 'Sikh', 'Spiritual', 'Other', 'Prefer not to say'];
  static const _eduLevels = ['High School', 'Trade/Tech School', 'In College', 'Undergraduate Degree', 'In Grad School', 'Graduate Degree', 'Prefer not to say'];
  
  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _dobCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _locSearchCtrl.dispose();
    _langCtrl.dispose();
    _pageCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _totalSteps - 1) {
      HapticFeedback.selectionClick();
      setState(() => _step++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _completeOnboarding();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      HapticFeedback.selectionClick();
      setState(() => _step--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  Future<void> _handlePhotoUpload() async {
    final url = await ImageUploadService.pickAndUpload(context: context, folder: 'avatars');
    if (url != null && mounted) setState(() => _photoUrl = url);
  }

  Future<void> _completeOnboarding() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final locationName = [_cityCtrl.text.trim(), _stateCtrl.text.trim()].where((s) => s.isNotEmpty).join(', ');

      await Supabase.instance.client.from('profiles').upsert({
        'id': uid,
        'name': _displayNameCtrl.text.trim(),
        'full_name': _displayNameCtrl.text.trim(),
        'gender': _gender,
        'city': _cityCtrl.text.trim(),
        'district': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'lat': _lat ?? 0,
        'lng': _lng ?? 0,
        'avatar_url': _photoUrl ?? 'https://picsum.photos/seed/$uid/200',
        'bio': _bioCtrl.text.trim(),
        'height_cm': _heightCm.toInt(),
        'smoking': _smoking,
        'drinking': _drinking,
        'weed': _weed,
        'diet': _diet,
        'exercise': _exercise,
        'education': _education,
        'job_title': _jobTitle,
        'zodiac': _zodiac,
        'relationship_type': _relationshipType,
        'religion': _religion,
        'match_gender': _matchGender,
        'personality_traits': _selectedTraits.toList(),
        'interests': _selectedInterests.toList(),
        'visible_vibes': _selectedVibes.toList(),
        'is_public': !_privateProfile,
        'onboarding_complete': true,
      }, onConflict: 'id');

      if (_lat != null && _lng != null) {
        locationService.setLocation(locationName.isNotEmpty ? locationName : _cityCtrl.text, lat: _lat, lng: _lng);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('matchRadius', _radiusKm);

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: List.generate(_totalSteps, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 2 : 0),
                      decoration: BoxDecoration(
                        color: active ? _cyan : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: active && i == _step ? [BoxShadow(color: _cyan.withValues(alpha: 0.5), blurRadius: 4)] : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _s0BasicInfo(),
                  _s1Gender(),
                  _s2Location(),
                  _s3Height(),
                  _s4Lifestyle(),
                  _s5Diet(),
                  _s6Exercise(),
                  _s7Education(),
                  _s8Job(),
                  _s9Zodiac(),
                  _s10Relationship(),
                  _s11Religion(),
                  _s12MatchOrientation(),
                  _s13Personality(),
                  _s14Interests(),
                  _s15Preferences(),
                  _s16VibeVisibility(),
                ],
              ),
            ),

            // Bottom Nav
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [_bg, _bg.withValues(alpha: 0)]),
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: GestureDetector(
                        onTap: _prevStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gb)),
                          child: const Icon(Icons.arrow_back, color: _txt2),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _saving ? null : _nextStep,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_cyan, _green]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _cyan.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Center(
                          child: _saving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text(_step == _totalSteps - 1 ? 'Complete' : 'Continue', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────
  Widget _header(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _txt)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _muted, height: 1.5)),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _doodleIcon(IconData icon, Color color) {
    return Container(
      width: 120, height: 120,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(icon, size: 60, color: color),
    );
  }

  Widget _optionTile(String label, String value, String current, ValueChanged<String> onSelect, {IconData? icon}) {
    final sel = value == current;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: sel ? _cyan.withValues(alpha: 0.1) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? _cyan : _gb, width: sel ? 2 : 1),
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: sel ? _cyan : _muted, size: 20), const SizedBox(width: 16)],
            Expanded(child: Text(label, style: GoogleFonts.inter(color: sel ? _cyan : _txt, fontSize: 16, fontWeight: sel ? FontWeight.w600 : FontWeight.w500))),
            if (sel) const Icon(Icons.check_circle, color: _cyan, size: 22),
          ],
        ),
      ),
    );
  }

  // ── STEPS ────────────────────────────────────────────────────────────

  Widget _s0BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Let's get to know you", "Add a photo and your basic details"),
          GestureDetector(
            onTap: _handlePhotoUpload,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: _card,
                border: Border.all(color: _photoUrl != null ? _cyan : _gb, width: 2),
              ),
              child: _photoUrl != null
                  ? ClipOval(child: Image.network(_photoUrl!, fit: BoxFit.cover))
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: _muted, size: 30), SizedBox(height: 8), Text('Add Photo', style: TextStyle(color: _cyan, fontSize: 12))]),
            ),
          ),
          const SizedBox(height: 30),
          _inputField('First Name', _displayNameCtrl, Icons.person),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 365*16)));
              if (d != null) setState(() => _dobCtrl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
            },
            child: AbsorbPointer(child: _inputField('Date of Birth (YYYY-MM-DD)', _dobCtrl, Icons.calendar_today)),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController ctrl, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gb)),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.inter(color: _txt),
        decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: _muted), prefixIcon: Icon(icon, color: _cyan), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 18)),
      ),
    );
  }

  Widget _s1Gender() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Are you a man or a woman?", "This helps us tailor your experience"),
          Row(
            children: [
              Expanded(child: _genderCard('Man', Icons.face, _gender, (v) => setState(() => _gender = v))),
              const SizedBox(width: 16),
              Expanded(child: _genderCard('Woman', Icons.face_3, _gender, (v) => setState(() => _gender = v))),
            ],
          ),
          const SizedBox(height: 16),
          _optionTile('Non-Binary', 'Non-Binary', _gender, (v) => setState(() => _gender = v)),
        ],
      ),
    );
  }

  Widget _genderCard(String label, IconData icon, String current, ValueChanged<String> onSelect) {
    final sel = label == current;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: sel ? _cyan.withValues(alpha: 0.1) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _cyan : _gb, width: sel ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 60, color: sel ? _cyan : _muted),
            const SizedBox(height: 16),
            Text(label, style: GoogleFonts.inter(color: sel ? _cyan : _txt, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await locationService.searchLocations(query);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = (result['lat'] as num).toDouble();
    final lng = (result['lng'] as num).toDouble();
    final name = result['name']?.toString() ?? '';
    final fullName = result['full_name']?.toString() ?? '';
    setState(() {
      _lat = lat;
      _lng = lng;
      _cityCtrl.text = name;
      _stateCtrl.text = fullName.split(',').length > 1 ? fullName.split(',')[1].trim() : '';
      _locSearchCtrl.text = name;
      _searchResults = [];
    });
    _mapCtrl.move(LatLng(lat, lng), 14.0);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1';
      final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'MeetraApp/1.0'});
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        final addr = data['address'] ?? {};
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
        final state = addr['state'] ?? '';
        setState(() {
          _cityCtrl.text = city;
          _stateCtrl.text = state;
          _locSearchCtrl.text = city;
        });
      }
    } catch (_) {}
  }

  Widget _s2Location() {
    final pinLat = _lat ?? 20.5937;
    final pinLng = _lng ?? 78.9629;
    final hasPin = _lat != null && _lng != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Where are you?", "Find people & events nearby"),
          _doodleIcon(Icons.location_city, _cyan),
          
          // ── Search Bar ──
          Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gb)),
            child: TextField(
              controller: _locSearchCtrl,
              style: GoogleFonts.inter(color: _txt, fontSize: 14),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search city, area, landmark...',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.search, color: _cyan, size: 20),
                suffixIcon: _locSearchCtrl.text.isNotEmpty
                    ? GestureDetector(onTap: () => setState(() { _locSearchCtrl.clear(); _searchResults = []; }), child: const Icon(Icons.close, color: _muted, size: 18))
                    : null,
              ),
            ),
          ),

          // ── Search Results ──
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _gb)),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final r = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: _cyan, size: 18),
                    title: Text(r['name'] ?? '', style: GoogleFonts.inter(color: _txt, fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(r['full_name'] ?? '', style: GoogleFonts.inter(color: _muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectSearchResult(r),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // ── Interactive Map ──
          Container(
            height: 220,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _cyan.withValues(alpha: 0.3))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: LatLng(pinLat, pinLng),
                      initialZoom: hasPin ? 14.0 : 4.5,
                      onTap: (_, point) {
                        setState(() { _lat = point.latitude; _lng = point.longitude; });
                        _reverseGeocode(point.latitude, point.longitude);
                      },
                    ),
                    children: [
                      TileLayer(urlTemplate: _isMapLight ? 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png' : 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png', userAgentPackageName: 'com.meetra.app'),
                      if (hasPin)
                        MarkerLayer(markers: [Marker(point: LatLng(pinLat, pinLng), width: 40, height: 40, child: const Icon(Icons.location_pin, color: _cyan, size: 36))]),
                    ],
                  ),
                  Positioned(
                    bottom: 10, right: 10,
                    child: GestureDetector(
                      onTap: _detectingLocation ? null : () async {
                        setState(() => _detectingLocation = true);
                        try {
                          // 1. Check if location services are enabled
                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) {
                            if (mounted) {
                              setState(() => _detectingLocation = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(children: [
                                    Icon(Icons.location_off, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Please enable location services in your device settings')),
                                  ]),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                            return;
                          }

                          // 2. Check & request permission
                          LocationPermission permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied) {
                              if (mounted) {
                                setState(() => _detectingLocation = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(children: [
                                      Icon(Icons.not_listed_location, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('Location permission denied. Please allow access to use this feature.')),
                                    ]),
                                    backgroundColor: Colors.orange.shade800,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          if (permission == LocationPermission.deniedForever) {
                            if (mounted) {
                              setState(() => _detectingLocation = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(children: [
                                    Icon(Icons.settings, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Location permanently denied. Please enable it from app settings.')),
                                  ]),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  action: SnackBarAction(
                                    label: 'Open Settings',
                                    textColor: Colors.white,
                                    onPressed: () => Geolocator.openAppSettings(),
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          // 3. Get precise location with high accuracy
                          final pos = await Geolocator.getCurrentPosition(
                            locationSettings: const LocationSettings(
                              accuracy: LocationAccuracy.high,
                              timeLimit: Duration(seconds: 15),
                            ),
                          );
                          setState(() { _lat = pos.latitude; _lng = pos.longitude; });
                          _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15.0);
                          await _reverseGeocode(pos.latitude, pos.longitude);
                          if (mounted) {
                            setState(() => _detectingLocation = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Location pinned: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}')),
                                ]),
                                backgroundColor: _cyan,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _detectingLocation = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.error_outline, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Could not get location: $e')),
                                ]),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF1A1F2E).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cyan.withValues(alpha: 0.3))),
                        child: _detectingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)) : const Icon(Icons.my_location, color: _cyan, size: 20),
                      ),
                    ),
                  ),
                  if (hasPin)
                    Positioned(
                      top: 10, left: 10, right: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF1A1F2E).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10), border: Border.all(color: _cyan.withValues(alpha: 0.2))),
                        child: Text(_cityCtrl.text.isNotEmpty ? _cityCtrl.text : '${pinLat.toStringAsFixed(4)}, ${pinLng.toStringAsFixed(4)}', style: GoogleFonts.inter(color: _cyan, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  // Dark/Light Mode Toggle
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _isMapLight = !_isMapLight),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF1A1F2E).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cyan.withValues(alpha: 0.3))),
                        child: Icon(_isMapLight ? Icons.nightlight_round : Icons.wb_sunny, color: _isMapLight ? Colors.blueGrey : Colors.yellow, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ── Radius Slider ──
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discovery Radius', style: GoogleFonts.inter(color: _txt2)), Text('${_radiusKm.round()} km', style: GoogleFonts.inter(color: _cyan, fontWeight: FontWeight.bold))]),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: _cyan, thumbColor: _cyan, overlayColor: _cyan.withValues(alpha: 0.15)),
            child: Slider(value: _radiusKm, min: 5, max: 100, onChanged: (v) => setState(() => _radiusKm = v)),
          ),
        ],
      ),
    );
  }

  Widget _s3Height() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("How tall are you?", "Just for the stats!"),
          _doodleIcon(Icons.height, _pink),
          Text('${_heightCm.toInt()} cm', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: _cyan)),
          const SizedBox(height: 30),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: _cyan, thumbColor: Colors.white, overlayColor: _cyan.withValues(alpha: 0.2), trackHeight: 8),
            child: Slider(value: _heightCm, min: 120, max: 220, onChanged: (v) => setState(() => _heightCm = v)),
          ),
        ],
      ),
    );
  }

  Widget _s4Lifestyle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Lifestyle choices", "Let's align your vibes"),
          _lifestyleSection('Smoking 🚬', _smoking, ['Never', 'Sometimes', 'Regularly'], (v) => setState(() => _smoking = v)),
          _lifestyleSection('Drinking 🍷', _drinking, ['Never', 'Socially', 'Regularly'], (v) => setState(() => _drinking = v)),
          _lifestyleSection('Weed 🌿', _weed, ['Never', 'Sometimes', 'Regularly'], (v) => setState(() => _weed = v)),
        ],
      ),
    );
  }

  Widget _lifestyleSection(String title, String current, List<String> options, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(color: _txt, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: options.map((o) => Expanded(
          child: GestureDetector(
            onTap: () => onSelect(o),
            child: Container(
              margin: const EdgeInsets.only(right: 8, bottom: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: current == o ? _cyan.withValues(alpha: 0.2) : _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: current == o ? _cyan : _gb)),
              alignment: Alignment.center,
              child: Text(o, style: GoogleFonts.inter(color: current == o ? _cyan : _txt2, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        )).toList()),
      ],
    );
  }

  Widget _s5Diet() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Diet Preferences", "Food brings people together"),
          _doodleIcon(Icons.restaurant, _green),
          ...['Vegetarian', 'Non-Vegetarian', 'Eggetarian', 'Vegan', 'Pescatarian'].map((o) => _optionTile(o, o, _diet, (v) => setState(() => _diet = v))),
        ],
      ),
    );
  }

  Widget _s6Exercise() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Do you exercise?", "Fitness matches are the best"),
          _doodleIcon(Icons.fitness_center, _cyan),
          ...['Everyday', 'Sometimes', 'Rarely', 'Never'].map((o) => _optionTile(o, o, _exercise, (v) => setState(() => _exercise = v))),
        ],
      ),
    );
  }

  Widget _s7Education() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Education", "What's your academic background?"),
          _doodleIcon(Icons.school, _pink),
          ..._eduLevels.map((o) => _optionTile(o, o, _education, (v) => setState(() => _education = v))),
        ],
      ),
    );
  }

  final _jobTitleCtrl = TextEditingController();

  Widget _s8Job() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("What do you do?", "Your profession or industry"),
          _doodleIcon(Icons.work, _cyan),
          _inputField('e.g. Software Engineer, Designer', _jobTitleCtrl, Icons.badge),
        ],
      ),
    );
  }
  
  Widget _s9Zodiac() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Zodiac Sign", "Written in the stars"),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _zodiacSigns.map((z) {
              final sel = _zodiac == z;
              return GestureDetector(
                onTap: () => setState(() => _zodiac = z),
                child: Container(
                  width: (MediaQuery.of(context).size.width - 60) / 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: sel ? _cyan.withValues(alpha: 0.1) : _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? _cyan : _gb)),
                  alignment: Alignment.center,
                  child: Text(z, style: GoogleFonts.inter(color: sel ? _cyan : _txt, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _s10Relationship() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("What are you looking for?", "Relationship intentions"),
          _doodleIcon(Icons.favorite, _pink),
          ...['Long-term partner', 'Short-term', 'Casual', 'Just friends', 'Not sure yet'].map((o) => _optionTile(o, o, _relationshipType, (v) => setState(() => _relationshipType = v))),
        ],
      ),
    );
  }

  Widget _s11Religion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Religion", "Your spiritual background"),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _religions.map((r) {
              final sel = _religion == r;
              return GestureDetector(
                onTap: () => setState(() => _religion = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: sel ? _cyan.withValues(alpha: 0.1) : _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? _cyan : _gb)),
                  child: Text(r, style: GoogleFonts.inter(color: sel ? _cyan : _txt)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _s12MatchOrientation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Who do you want to meet?", "Your preference for matches"),
          _doodleIcon(Icons.people, _cyan),
          ...['Men', 'Women', 'Everyone'].map((o) => _optionTile(o, o, _matchGender, (v) => setState(() => _matchGender = v))),
        ],
      ),
    );
  }

  Widget _s13Personality() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Your Personality", "Select up to 5 traits"),
          Text('${_selectedTraits.length}/5 selected', style: GoogleFonts.inter(color: _cyan, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _personalityTraits.map((t) {
              final sel = _selectedTraits.contains(t);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedTraits.remove(t);
                  } else if (_selectedTraits.length < 5) _selectedTraits.add(t);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: sel ? _cyan : _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? _cyan : _gb)),
                  child: Text(t, style: GoogleFonts.inter(color: sel ? Colors.black : _txt, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _s14Interests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header("Your Interests", "Select up to 15 interests"),
          Center(child: Text('${_selectedInterests.length}/15 selected', style: GoogleFonts.inter(color: _cyan, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          ..._interestCategories.entries.map((cat) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(cat.key, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _txt))),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: cat.value.map((i) {
                    final sel = _selectedInterests.contains(i);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) {
                          _selectedInterests.remove(i);
                        } else if (_selectedInterests.length < 15) _selectedInterests.add(i);
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: sel ? _pink.withValues(alpha: 0.2) : _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? _pink : _gb)),
                        child: Text(i, style: GoogleFonts.inter(color: sel ? _pink : _txt2, fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _s15Preferences() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header("Almost done! 🎉", "Final touches"),
          _inputField('Write a short bio...', _bioCtrl, Icons.edit),
          const SizedBox(height: 24),
          _toggleRow('Push Notifications', _pushNotif, (v) => setState(() => _pushNotif = v)),
          _toggleRow('Private Profile', _privateProfile, (v) => setState(() => _privateProfile = v)),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool val, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gb)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: _txt, fontSize: 16)),
          Switch(value: val, onChanged: onChanged, activeThumbColor: _cyan, trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _cyan.withValues(alpha: 0.3) : _gb)),
        ],
      ),
    );
  }

  Widget _s16VibeVisibility() {
    const vibes = [
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _header('Where should people find you?', 'Choose sections to appear in on Explore'),
          const SizedBox(height: 8),
          Text('People browsing these vibes will see your profile.\nSelect all that apply — you can edit anytime from Settings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _txt2, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: vibes.map((v) {
              final label = v['label'] as String;
              final icon = v['icon'] as String;
              final active = _selectedVibes.contains(label);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (active) {
                      _selectedVibes.remove(label);
                    } else {
                      _selectedVibes.add(label);
                    }
                  });
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 72) / 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(colors: [Color(v['c1'] as int), Color(v['c2'] as int)])
                        : null,
                    color: active ? null : _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: active ? _cyan.withValues(alpha: 0.5) : _gb, width: active ? 2 : 1),
                    boxShadow: active ? [BoxShadow(color: _cyan.withValues(alpha: 0.15), blurRadius: 12)] : null,
                  ),
                  child: Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(label,
                          style: GoogleFonts.inter(
                            color: active ? Colors.white : _txt2,
                            fontSize: 14,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (active)
                        const Icon(Icons.check_circle, color: _cyan, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                if (_selectedVibes.length == vibes.length) {
                  _selectedVibes.clear();
                } else {
                  _selectedVibes.addAll(vibes.map((v) => v['label'] as String));
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gb),
              ),
              child: Text(
                _selectedVibes.length == vibes.length ? 'Deselect All' : 'Select All',
                style: GoogleFonts.inter(color: _cyan, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


