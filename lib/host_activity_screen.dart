import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui'; // For ImageFilter and BackdropFilter

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';

// =============================================================================
// HOST ACTIVITY SCREEN - SUPREME EDITION
// A multi-step wizard for creating Rush-Ins and standard activities.
// =============================================================================

enum MapLayerHost {
  street('Street Mode', Icons.map, 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png', Color(0xFF00E5FF), true),
  satellite('Satellite', Icons.satellite_alt, 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', Color(0xFFFF007F), false),
  terrain('Terrain', Icons.terrain, 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', Color(0xFF00E676), false);

  final String label;
  final IconData icon;
  final String tileUrl;
  final Color accent;
  final bool allowsDarkMode; // Only street mode gets the neon inversion
  const MapLayerHost(this.label, this.icon, this.tileUrl, this.accent, this.allowsDarkMode);
}

class HostActivityScreen extends StatefulWidget {
  final LatLng initialLocation;
  final bool initialIsRushIn;
  const HostActivityScreen({super.key, required this.initialLocation, required this.initialIsRushIn});

  @override
  State<HostActivityScreen> createState() => _HostActivityScreenState();
}

class _HostActivityScreenState extends State<HostActivityScreen> with TickerProviderStateMixin {
  // ── CONTROLLERS ──
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _hookCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _pageCtrl = PageController();
  final MapController _mapController = MapController();

  // ── ANIMATION ──
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── STATE ──
  int _currentStep = 0;
  late bool _isRushIn;
  bool _saving = false;
  bool _fetchingGps = false;

  // ── RUSH-IN DATA ──
  final List<String> _selectedVibes = [];
  String _selectedMood = '🔥';
  int _participantLimit = 10;
  int _durationHours = 6;
  double _radiusKm = 5.0;
  bool _isGhostMode = false;
  bool _autoAccept = false;
  bool _inviteOnly = false;
  String _entryType = 'free'; // 'free' or 'paid'

  final String _selectedCategory = 'Music';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  // -- SELLER PACKAGE DATA --
  bool _isSeller = false;
  bool _isPackage = false;
  final _priceCtrl = TextEditingController(text: '0');

  // ── LOCATION ──
  LatLng _pinLocation = const LatLng(0, 0);
  bool _isLightMode = false;
  MapLayerHost _mapLayer = MapLayerHost.street;
  bool _showLayerPicker = false;
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;
  bool _showDropdown = false;

  // ── LOOKUP MAPS ──
  final List<String> _categories = ['Music', 'Fitness', 'Tech', 'Art', 'Gaming', 'Food', 'Social', 'Chill', 'Wild', 'Deep Talks'];
  final List<String> _moods = ['🔥', '🎉', '😎', '🌙', '💀', '🧘', '🎶', '⚡', '🍕', '💬'];
  final Map<String, Map<String, dynamic>> _vibeData = {
    'Music':      {'icon': Icons.music_note, 'color': const Color(0xFFE040FB)},
    'Fitness':    {'icon': Icons.fitness_center, 'color': const Color(0xFF00E676)},
    'Tech':       {'icon': Icons.computer, 'color': const Color(0xFF00E5FF)},
    'Art':        {'icon': Icons.palette, 'color': const Color(0xFFFFAB40)},
    'Gaming':     {'icon': Icons.sports_esports, 'color': const Color(0xFF7C4DFF)},
    'Food':       {'icon': Icons.restaurant, 'color': const Color(0xFFFF5252)},
    'Social':     {'icon': Icons.people, 'color': const Color(0xFF448AFF)},
    'Chill':      {'icon': Icons.self_improvement, 'color': const Color(0xFF69F0AE)},
    'Wild':       {'icon': Icons.whatshot, 'color': const Color(0xFFFF6D00)},
    'Deep Talks': {'icon': Icons.psychology, 'color': const Color(0xFFB388FF)},
  };

  // ── STEPS ──
  List<String> get _stepTitles => _isRushIn
    ? ['IDENTITY', 'VIBES', 'RULES', 'DROP ZONE', 'LAUNCH']
    : ['DETAILS', 'VIBES', 'SCHEDULE', 'RULES', 'LOCATION', 'LAUNCH'];

  @override
  void initState() {
    super.initState();
    _isRushIn = widget.initialIsRushIn;
    _pinLocation = widget.initialLocation;
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _checkSellerStatus();
  }

  Future<void> _checkSellerStatus() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final res = await Supabase.instance.client.from('profiles').select('is_seller').eq('id', uid!).single();
      if (mounted) setState(() => _isSeller = res['is_seller'] == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationNameCtrl.dispose();
    _hookCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    _pageCtrl.dispose();
    _mapController.dispose();
    _pulseCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── GPS ──
  Future<void> _fetchLiveGps() async {
    setState(() => _fetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _fetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.location_off, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Please enable location services in your device settings'))]),
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
              content: const Row(children: [Icon(Icons.not_listed_location, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permission denied. Please allow access.'))]),
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
            content: const Row(children: [Icon(Icons.settings, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permanently denied. Please enable it from app settings.'))]),
            backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(label: 'Open Settings', textColor: Colors.white, onPressed: () => Geolocator.openAppSettings()),
          ));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );

      if (mounted) {
        setState(() {
          _pinLocation = LatLng(position.latitude, position.longitude);
          _fetchingGps = false;
        });
        _mapController.move(_pinLocation, 16.0);
        _reverseGeocode(_pinLocation);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Location pinned: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}')]),
          backgroundColor: const Color(0xFF00E5CC), behavior: SnackBarBehavior.floating,
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

  Future<void> _reverseGeocode(LatLng p) async {
    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${p.latitude}&lon=${p.longitude}&zoom=14&addressdetails=1'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          final address = data['address'] ?? {};
          final landmark = data['name'] ?? address['amenity'] ?? address['building'] ?? address['historic'] ?? address['leisure'];
          final display = landmark ?? (data['display_name'] ?? '');
          
          setState(() {
            _searchCtrl.text = display;
            _locationNameCtrl.text = display;
          });
        }
      }
    } catch (_) {}
  }

  // ── SEARCH ──
  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (val.trim().isNotEmpty) {
        _performSearch(val.trim());
      } else {
        setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() { _searchResults.clear(); _showDropdown = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final encoded = Uri.encodeComponent(query);
      // Use AllOrigins proxy for consistent global search & CORS handling
      final proxyUrl = 'https://api.allorigins.win/raw?url='
          '${Uri.encodeComponent('https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5&addressdetails=1')}';
      
      final res = await http.get(Uri.parse(proxyUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data.map((it) => {
              'display_name': it['display_name'].toString().split(',').first.trim(),
              'full_name': it['display_name'].toString(),
              'lat': double.parse(it['lat']),
              'lon': double.parse(it['lon']),
            }).toList();
            _showDropdown = _searchResults.isNotEmpty;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  void _selectResult(Map<String, dynamic> res) {
    final lat = res['lat'] as double;
    final lon = res['lon'] as double;
    
    setState(() {
      _pinLocation = LatLng(lat, lon);
      _searchResults = [];
      _showDropdown = false;
      _searchCtrl.text = res['display_name'];
      _locationNameCtrl.text = res['display_name'];
    });
    FocusScope.of(context).unfocus();
    _mapController.move(_pinLocation, 16.0);
  }

  // ── DATE / TIME ──
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (c, ch) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), surface: Color(0xFF101015), onSurface: Colors.white)), child: ch!),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (c, ch) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), surface: Color(0xFF101015), onSurface: Colors.white)), child: ch!),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  // ── VALIDATION ──
  bool get _canProceed {
    if (_isRushIn) {
      switch (_currentStep) {
        case 0: return _titleCtrl.text.trim().isNotEmpty && _hookCtrl.text.trim().isNotEmpty;
        case 1: return _selectedVibes.isNotEmpty;
        case 2: return true; // Rules step always valid (has defaults)
        case 3: return _locationNameCtrl.text.trim().isNotEmpty;
        case 4: return true; // Launch preview is always valid
        default: return false;
      }
    } else {
      switch (_currentStep) {
        case 0: return _titleCtrl.text.trim().isNotEmpty && _descCtrl.text.trim().isNotEmpty;
        case 1: return _selectedVibes.isNotEmpty;
        case 2: return _selectedDate != null && _selectedTime != null;
        case 3: return true; 
        case 4: return _locationNameCtrl.text.trim().isNotEmpty;
        case 5: return true;
        default: return false;
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(_currentStep, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(_currentStep, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  // ── SUBMIT ──
  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final now = DateTime.now();
      final dt = _isRushIn
          ? (_selectedTime != null 
              ? DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute) 
              : now)
          : DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);

      final payload = <String, dynamic>{
        'user_id': uid,
        'title': _titleCtrl.text.trim(),
        'description': _isRushIn ? (_noteCtrl.text.trim().isEmpty ? 'Rush-In Activity' : _noteCtrl.text.trim()) : _descCtrl.text.trim(),
        'category': _selectedVibes.join(', '),
        'activity_time': dt.toIso8601String(),
        'lat': _pinLocation.latitude,
        'lng': _pinLocation.longitude,
        'location_name': _locationNameCtrl.text.trim(),
        'district': locationService.activeLocation.split(',').first.trim(),
        'state': locationService.activeLocation.split(',').length > 1 ? locationService.activeLocation.split(',')[1].trim() : '',
        'is_active': true,
        'is_rush_in': _isRushIn,
        'activity_type': _isRushIn ? 'rush_in' : 'event',
        'vibes': _isRushIn ? _selectedVibes : [],
        'hook': _isRushIn ? _hookCtrl.text.trim() : null,
        'participant_limit': _isRushIn ? _participantLimit : 100,
        'is_ghost_mode': _isRushIn ? _isGhostMode : false,
        'mood': _isRushIn ? _selectedMood : null,
        'auto_accept': _isRushIn ? _autoAccept : false,
        'invite_only': _isRushIn ? _inviteOnly : false,
        'entry_type': _isRushIn ? _entryType : 'free',
      };

      if (_isRushIn) {
        payload['expires_at'] = dt.add(Duration(hours: _durationHours)).toIso8601String();
        payload['duration_hours'] = _durationHours;
        payload['radius_km'] = _radiusKm;
      }

      final response = await Supabase.instance.client
          .from('activities')
          .insert(payload)
          .select('id')
          .single();

      final String activityId = response['id'].toString();

      // Trigger nearby notifications
      NotificationService.notifyNearbyActivity(
        creatorId: uid,
        activityId: activityId,
        title: _titleCtrl.text.trim(),
        locationName: _locationNameCtrl.text.trim(),
        lat: _pinLocation.latitude,
        lng: _pinLocation.longitude,
        radiusKm: _isRushIn ? _radiusKm.toDouble() : 50.0,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF101015),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFFF007F).withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: const Color(0xFFFF007F).withValues(alpha: 0.3), blurRadius: 40)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(_isRushIn ? 'RUSH-IN IS LIVE!' : 'ACTIVITY DEPLOYED!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Your signal is now broadcasting.', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () { Navigator.pop(context); Navigator.pop(context, true); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF007F), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text('RETURN TO MAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF007F);
    const purple = Color(0xFF8B5CF6);
    const actPrimary = Color(0xFF00E5FF);
    const actSecondary = Color(0xFF2962FF);
    final accent = _isRushIn ? pink : actPrimary;
    final accentSecondary = _isRushIn ? purple : actSecondary;

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: Stack(
        children: [
          // ── AMBIENT ORBS ──
          Positioned(top: -120, right: -80, child: _ambientOrb(accentSecondary, 350)),
          Positioned(bottom: -80, left: -100, child: _ambientOrb(accent, 300)),

          // ── MAIN CONTENT ──
          SafeArea(
            child: Column(
              children: [
                // ── TOP BAR ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _currentStep == 0 ? () => Navigator.pop(context) : _prevStep,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                          child: Icon(_currentStep == 0 ? Icons.close : Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isRushIn ? 'CREATE RUSH-IN' : 'HOST ACTIVITY', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
                            const SizedBox(height: 4),
                            Text('STEP ${_currentStep + 1} OF ${_stepTitles.length} • ${_stepTitles[_currentStep]}', style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── PROGRESS BAR ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: List.generate(_stepTitles.length, (i) {
                      final isActive = i <= _currentStep;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(right: i < _stepTitles.length - 1 ? 6 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: isActive ? LinearGradient(colors: [accent, accentSecondary]) : null,
                            color: isActive ? null : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ── PAGE VIEW ──
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _isRushIn
                      ? [_rushStep0Identity(accent, accentSecondary), _rushStep1Vibes(accent), _rushStep2Rules(accent, accentSecondary), _rushStep3Location(accent), _rushStep4Launch(accent, accentSecondary)]
                      : [_stdStep0Details(accent), _stdStep1Vibes(accent), _stdStep2Schedule(accent), _stdStep3Rules(accent, accentSecondary), _stdStep4Location(accent), _stdStep5Launch(accent, accentSecondary)],
                  ),
                ),

                // ── BOTTOM NAV ──
                _buildBottomNav(accent, accentSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RUSH-IN STEP 0: IDENTITY
  // ===========================================================================
  Widget _rushStep0Identity(Color accent, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('WHAT\'S HAPPENING?', 'The headline that hooks everyone in.'),
          const SizedBox(height: 16),
          _neonTextField(_titleCtrl, 'E.g., Midnight Rooftop Jam', Icons.electric_bolt, accent),
          const SizedBox(height: 32),

          _neonTextField(_hookCtrl, 'Free drinks if you beat me at pool!', Icons.campaign, secondary, maxLines: 2),
          const SizedBox(height: 32),

          if (_isSeller) ...[
            _sectionHeader('PREMIUM PACKAGE', 'Is this an official commercial event?'),
            const SizedBox(height: 12),
            _ruleToggle(Icons.verified, 'MARK AS PACKAGE', 'List this in the Events marketplace.', _isPackage, (v) => setState(() => _isPackage = v)),
            if (_isPackage) ...[
              const SizedBox(height: 20),
              _sectionHeader('PACKAGE PRICE (₹)', 'Set a price for this experience.'),
              const SizedBox(height: 12),
              _neonTextField(_priceCtrl, '0', Icons.payments, const Color(0xFF10B981), keyboardType: TextInputType.number),
              const SizedBox(height: 32),
            ] else 
              const SizedBox(height: 32),
          ],


          _sectionHeader('SET THE MOOD', 'Pick an emoji that represents the energy.'),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final m = _moods[i];
                final sel = _selectedMood == m;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56, height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? accent : Colors.white.withValues(alpha: 0.06), width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 12)] : [],
                    ),
                    child: Text(m, style: TextStyle(fontSize: sel ? 28 : 22)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          _sectionHeader('EXTRA NOTE (OPTIONAL)', 'Add details only participants will see.'),
          const SizedBox(height: 16),
          _neonTextField(_noteCtrl, 'Bring your own gear. Parking available.', Icons.sticky_note_2_outlined, Colors.white38, maxLines: 3),
        ],
      ),
    );
  }

  // ===========================================================================
  // RUSH-IN STEP 1: VIBES
  // ===========================================================================
  Widget _rushStep1Vibes(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('PICK YOUR VIBES', 'Select all the energy tags that fit this Rush-In.'),
          const SizedBox(height: 8),
          Text('${_selectedVibes.length} selected', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...(_categories.map((cat) {
            final sel = _selectedVibes.contains(cat);
            final vibe = _vibeData[cat]!;
            final clr = vibe['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() { sel ? _selectedVibes.remove(cat) : _selectedVibes.add(cat); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: sel ? clr.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? clr.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.04)),
                  boxShadow: sel ? [BoxShadow(color: clr.withValues(alpha: 0.2), blurRadius: 16)] : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: sel ? clr.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                      child: Icon(vibe['icon'] as IconData, color: sel ? clr : Colors.white38, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(cat.toUpperCase(), style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1))),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: sel
                        ? Icon(Icons.check_circle, key: const ValueKey('check'), color: clr, size: 24)
                        : Container(key: const ValueKey('empty'), width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.1)))),
                    ),
                  ],
                ),
              ),
            );
          })),
        ],
      ),
    );
  }

  // ===========================================================================
  // RUSH-IN STEP 2: RULES
  // ===========================================================================
  Widget _rushStep2Rules(Color accent, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // START TIME (OPTIONAL)
          _sectionHeader('START TIME', 'When does the Rush-In begin? (Default: Now)'),
          const SizedBox(height: 16),
          GestureDetector(onTap: _pickTime, child: _dateTile(Icons.access_time, 'TIME', _selectedTime == null ? 'Starting Now' : _selectedTime!.format(context), accent)),
          const SizedBox(height: 36),

          // CREW LIMIT
          _sectionHeader('CREW LIMIT', 'How many people can join?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [2, 5, 10, 20, 50].map((n) {
              final sel = _participantLimit == n;
              return GestureDetector(
                onTap: () => setState(() => _participantLimit = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56, height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: sel ? LinearGradient(colors: [accent, secondary], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                    color: sel ? null : Colors.white.withValues(alpha: 0.04),
                    boxShadow: sel ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12)] : [],
                  ),
                  child: Text('$n', style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w900, fontSize: sel ? 20 : 15)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),

          // BURNOUT TIMER
          _sectionHeader('BURNOUT TIMER', 'How long will the Rush-In stay live?'),
          const SizedBox(height: 16),
          Row(
            children: [
              {'h': 1, 'label': 'FLASH', 'icon': Icons.flash_on},
              {'h': 6, 'label': 'EVENING', 'icon': Icons.nights_stay},
              {'h': 12, 'label': 'HALF DAY', 'icon': Icons.wb_twilight},
              {'h': 24, 'label': 'FULL DAY', 'icon': Icons.wb_sunny},
            ].map((d) {
              final h = d['h'] as int;
              final sel = _durationHours == h;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _durationHours = h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: sel ? accent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Column(
                      children: [
                        Icon(d['icon'] as IconData, color: sel ? accent : Colors.white38, size: 22),
                        const SizedBox(height: 8),
                        Text('${h}H', style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(d['label'] as String, style: TextStyle(color: sel ? accent : Colors.white30, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),

          // BROADCAST RADIUS
          _sectionHeader('BROADCAST RADIUS', 'How far should your Rush-In signal reach?'),
          const SizedBox(height: 8),
          Text('${_radiusKm.round()} km', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            _radiusKm <= 2 ? 'Hyper-local — only the closest people' : _radiusKm <= 5 ? 'Neighborhood radius — nearby users' : _radiusKm <= 10 ? 'City-wide signal — broad reach' : 'Maximum broadcast — district-wide',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
              thumbColor: Colors.white,
              overlayColor: accent.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 6,
              activeTickMarkColor: accent,
              inactiveTickMarkColor: Colors.white.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: _radiusKm,
              min: 1,
              max: 25,
              divisions: 24,
              onChanged: (v) => setState(() => _radiusKm = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['1km', '5km', '10km', '15km', '25km'].map((l) => Text(l, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold))).toList(),
            ),
          ),
          const SizedBox(height: 36),

          // TOGGLE SWITCHES
          _sectionHeader('ADVANCED SETTINGS', 'Fine-tune your Rush-In behavior.'),
          const SizedBox(height: 16),
          _ruleToggle(Icons.visibility_off, 'GHOST MODE', 'Your identity is hidden on the feed.', _isGhostMode, (v) => setState(() => _isGhostMode = v)),
          const SizedBox(height: 12),
          _ruleToggle(Icons.verified, 'AUTO-ACCEPT', 'Automatically accept the first joiners.', _autoAccept, (v) => setState(() => _autoAccept = v)),
          const SizedBox(height: 12),
          _ruleToggle(Icons.lock_outline, 'INVITE ONLY', 'Only people you share the link with can see it.', _inviteOnly, (v) => setState(() => _inviteOnly = v)),
          const SizedBox(height: 12),

          // ENTRY TYPE
          _sectionHeader('ENTRY TYPE', 'Is your Rush-In free or exclusive?'),
          const SizedBox(height: 16),
          Row(
            children: [
              _entryPill('free', 'FREE ENTRY', Icons.lock_open, accent),
              const SizedBox(width: 12),
              _entryPill('paid', 'EXCLUSIVE', Icons.diamond, secondary),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RUSH-IN STEP 3: DROP ZONE
  // ===========================================================================
  Widget _rushStep3Location(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('THE DROP ZONE', 'Pin your exact location on the map.'),
              Row(children: [
                _mapStyleToggle(accent),
                const SizedBox(width: 8),
                _gpsButton(accent),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          _locationMap(accent),
          const SizedBox(height: 20),
          _neonTextField(_locationNameCtrl, 'Name this spot... (e.g. Rooftop, Gate 3)', Icons.edit_location_alt, accent),
        ],
      ),
    );
  }

  // ===========================================================================
  // RUSH-IN STEP 4: LAUNCH PREVIEW
  // ===========================================================================
  Widget _rushStep4Launch(Color accent, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('PREVIEW YOUR RUSH-IN', 'This is exactly how others will see it on the map.'),
          const SizedBox(height: 24),

          // Preview Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101015),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 30)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, color: accent, size: 8), const SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                      ]),
                    ),
                    const Spacer(),
                    Text('${_durationHours}h', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.access_time, color: Colors.white38, size: 14),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(_selectedMood, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_titleCtrl.text.isEmpty ? 'Your Rush-In Title' : _titleCtrl.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
                  ],
                ),
                if (_hookCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('"${_hookCtrl.text}"', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 14)),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _selectedVibes.map((v) {
                    final clr = (_vibeData[v]?['color'] as Color?) ?? Colors.white24;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: clr.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: clr.withValues(alpha: 0.3))),
                      child: Text(v.toUpperCase(), style: TextStyle(color: clr, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.place, color: accent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_locationNameCtrl.text.isEmpty ? 'Location' : _locationNameCtrl.text, style: const TextStyle(color: Colors.white54, fontSize: 13))),
                    const SizedBox(width: 12),
                    Icon(Icons.people, color: accent, size: 16),
                    const SizedBox(width: 4),
                    Text('$_participantLimit', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(width: 16),
                    Icon(Icons.radar, color: accent, size: 16),
                    const SizedBox(width: 4),
                    Text('${_radiusKm.round()}km', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_isGhostMode) _previewBadge('GHOST', Icons.visibility_off),
                    if (_autoAccept) _previewBadge('AUTO', Icons.verified),
                    if (_inviteOnly) _previewBadge('INVITE', Icons.lock),
                    if (_entryType == 'paid') _previewBadge('EXCLUSIVE', Icons.diamond),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Tap LAUNCH to go live.', style: TextStyle(color: accent.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))),
        ],
      ),
    );
  }

  // ===========================================================================
  // STANDARD ACTIVITY STEPS
  // ===========================================================================
  Widget _stdStep0Details(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('ACTIVITY NAME', 'Give your event a clear title.'),
        const SizedBox(height: 16),
        _neonTextField(_titleCtrl, 'E.g., Weekend Hiking Trip', Icons.event, accent),
        const SizedBox(height: 32),
        _sectionHeader('DESCRIPTION', 'What will you be doing?'),
        const SizedBox(height: 16),
        _neonTextField(_descCtrl, 'Describe the activity in detail...', Icons.description, accent, maxLines: 4),
        const SizedBox(height: 32),
        
        if (_isSeller) ...[
          _sectionHeader('PREMIUM PACKAGE', 'Is this an official commercial event?'),
          const SizedBox(height: 12),
          _ruleToggle(Icons.verified, 'MARK AS PACKAGE', 'List this in the Events marketplace.', _isPackage, (v) => setState(() => _isPackage = v)),
          if (_isPackage) ...[
            const SizedBox(height: 20),
            _sectionHeader('PACKAGE PRICE (₹)', 'Set a price for this experience.'),
            const SizedBox(height: 12),
            _neonTextField(_priceCtrl, '0', Icons.payments, const Color(0xFF10B981), keyboardType: TextInputType.number),
            const SizedBox(height: 32),
          ] else 
            const SizedBox(height: 32),
        ],
      ]),
    );
  }

  Widget _stdStep1Vibes(Color accent) {
    return _rushStep1Vibes(accent);
  }

  Widget _stdStep2Schedule(Color accent) {
    return _stdStep1Schedule(accent);
  }

  Widget _stdStep3Rules(Color accent, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('PARTICIPANT LIMIT', 'How many people can join your event?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [5, 10, 25, 50, 100].map((n) {
              final sel = _participantLimit == n;
              return GestureDetector(
                onTap: () => setState(() => _participantLimit = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 50, height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: sel ? LinearGradient(colors: [accent, secondary]) : null,
                    color: sel ? null : Colors.white.withValues(alpha: 0.04),
                  ),
                  child: Text('$n', style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _sectionHeader('SETTINGS', 'Automate your activity management.'),
          const SizedBox(height: 16),
          _ruleToggle(Icons.verified, 'AUTO-ACCEPT', 'Instantly approve all join requests.', _autoAccept, (v) => setState(() => _autoAccept = v)),
          const SizedBox(height: 12),
          _ruleToggle(Icons.lock_outline, 'INVITE ONLY', 'Only people with the link can request to join.', _inviteOnly, (v) => setState(() => _inviteOnly = v)),
          const SizedBox(height: 32),
          _sectionHeader('ENTRY TYPE', 'Is this event free or paid?'),
          const SizedBox(height: 16),
          Row(
            children: [
              _entryPill('free', 'FREE', Icons.lock_open, accent),
              const SizedBox(width: 12),
              _entryPill('paid', 'PAID/EXCL', Icons.diamond, secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stdStep4Location(Color accent) {
    return _stdStep2Location(accent);
  }

  Widget _stdStep5Launch(Color accent, Color secondary) {
    return _stdStep3Launch(accent, secondary);
  }

  Widget _stdStep1Schedule(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('DATE & TIME', 'When is this happening?'),
        const SizedBox(height: 24),
        GestureDetector(onTap: _pickDate, child: _dateTile(Icons.calendar_today, 'DATE', _selectedDate == null ? 'Tap to select' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}', accent)),
        const SizedBox(height: 16),
        GestureDetector(onTap: _pickTime, child: _dateTile(Icons.access_time, 'TIME', _selectedTime == null ? 'Tap to select' : _selectedTime!.format(context), accent)),
      ]),
    );
  }

  Widget _stdStep2Location(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionHeader('LOCATION', 'Where is it happening?'),
          Row(children: [
            _mapStyleToggle(accent),
            const SizedBox(width: 8),
            _gpsButton(accent),
          ]),
        ]),
        const SizedBox(height: 16),
        _locationMap(accent),
        const SizedBox(height: 20),
        _neonTextField(_locationNameCtrl, 'Name this location...', Icons.edit_location_alt, accent),
      ]),
    );
  }

  Widget _stdStep3Launch(Color accent, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('READY TO PUBLISH', 'Review and launch your activity.'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFF101015), borderRadius: BorderRadius.circular(28), border: Border.all(color: accent.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 20)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_titleCtrl.text.isEmpty ? 'Activity Title' : _titleCtrl.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(_selectedCategory, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            Text(_descCtrl.text.isEmpty ? 'No description.' : _descCtrl.text, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today, color: accent, size: 16), const SizedBox(width: 8),
              Text(_selectedDate == null ? 'No date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}', style: const TextStyle(color: Colors.white54)),
              const SizedBox(width: 20),
              Icon(Icons.access_time, color: accent, size: 16), const SizedBox(width: 8),
              Text(_selectedTime == null ? 'No time' : _selectedTime!.format(context), style: const TextStyle(color: Colors.white54)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.place, color: accent, size: 16), const SizedBox(width: 8),
              Text(_locationNameCtrl.text.isEmpty ? 'No location' : _locationNameCtrl.text, style: const TextStyle(color: Colors.white54)),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ===========================================================================
  // REUSABLE COMPONENTS
  // ===========================================================================

  Widget _ambientOrb(Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 120)]));
  }

  Widget _sectionHeader(String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ]);
  }

  Widget _neonTextField(TextEditingController ctrl, String hint, IconData icon, Color glow, {int maxLines = 1, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          prefixIcon: maxLines == 1 ? Icon(icon, color: glow.withValues(alpha: 0.6), size: 20) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: maxLines == 1 ? 18 : 20),
        ),
      ),
    );
  }


  Widget _ruleToggle(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: value ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? Colors.white : Colors.white38, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: value ? Colors.white : Colors.white60, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: Colors.white30, fontSize: 11)),
          ])),
          Switch(
            value: value, onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _entryPill(String type, String label, IconData icon, Color clr) {
    final sel = _entryType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _entryType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: sel ? clr.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? clr.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? clr : Colors.white38, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
          ]),
        ),
      ),
    );
  }

  Widget _previewBadge(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white38, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ]),
    );
  }

  Widget _gpsButton(Color accent) {
    return GestureDetector(
      onTap: _fetchingGps ? null : _fetchLiveGps,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: _fetchingGps
          ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 3))
          : const Icon(Icons.my_location, color: Color(0xFF0077FF), size: 24),
      ),
    );
  }


  Widget _mapStyleToggle(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _isLightMode = !_isLightMode),
      child: _glassContainer(
        padding: const EdgeInsets.all(10),
        child: Icon(_isLightMode ? Icons.nightlight_round : Icons.wb_sunny, color: _isLightMode ? Colors.blueGrey : Colors.yellow, size: 18),
      ),
    );
  }

  Widget _locationMap(Color accent) {
    final baseUrl = _mapLayer.tileUrl;

    return Container(
      height: 380, // Taller for better search experience
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 25)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Dark mode/Neon inversion logic
            if (!_isLightMode && _mapLayer.allowsDarkMode)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  -1.0, 0.0, 0.0, 0.0, 255.0,
                  0.0, -1.0, 0.0, 0.0, 255.0,
                  0.0, 0.0, -1.0, 0.0, 255.0,
                  0.0, 0.0, 0.0, 1.0, 0.0,
                ]),
                child: _buildFlutterMapWidget(accent, baseUrl),
              )
            else
              _buildFlutterMapWidget(accent, baseUrl),

            // Neon wash overlay
            if (!_isLightMode && _mapLayer.allowsDarkMode)
              Container(color: const Color(0xFF4A00E0).withValues(alpha: 0.15)),

            // Search Bar (Glassmorphic)
            Positioned(
              top: 16, left: 16, right: 64,
              child: _mapSearchField(accent),
            ),

            // Dropdown Overlay
            if (_showDropdown)
              Positioned(
                top: 72, left: 16, right: 64,
                child: _mapSearchResults(accent),
              ),

            // Theme Toggle (Floating Top-Right)
            Positioned(
              top: 16, right: 16,
              child: _mapStyleToggle(accent),
            ),

            // Layer Picker Popup
            if (_showLayerPicker)
              Positioned(
                bottom: 72, left: 16,
                child: _buildLayerPickerPopup(accent),
              ),

            // Layer FAB (Floating Bottom-Left)
            Positioned(
              bottom: 16, left: 16,
              child: _buildLayerFab(accent),
            ),

            // GPS Pin (Floating Bottom-Right)
            Positioned(
              bottom: 16, right: 16,
              child: _gpsButton(accent),
            ),

            // Action Guide
            Positioned(
              top: 76, left: 0, right: 0,
              child: Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                    child: const Text('Move map to pinpoint exactly', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ),

            // 🎯 Fixed Center Crosshair
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.center_focus_strong, color: accent, size: 32, shadows: [Shadow(color: accent, blurRadius: 15)]),
                    const SizedBox(height: 24), // Offset for the icon's visual center vs the tip of a pin if we had one
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFlutterMapWidget(Color accent, String baseUrl) {
    return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _pinLocation, 
          initialZoom: 15.0, 
          onTap: (_, pt) { setState(() => _pinLocation = pt); _reverseGeocode(pt); },
          onPositionChanged: (pos, hasGesture) {
            if (hasGesture) {
              setState(() => _pinLocation = pos.center);
              _reverseGeocode(pos.center); 
            }
          },
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        ),

        children: [
          TileLayer(userAgentPackageName: 'com.meetra.app', urlTemplate: baseUrl, subdomains: const ['a', 'b', 'c', 'd']),
          MarkerLayer(markers: [
            Marker(
              point: _pinLocation, 
              width: 60, height: 60, 
              child: AnimatedBuilder(
                animation: _pulseAnim, 
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: 40 * _pulseAnim.value, height: 40 * _pulseAnim.value, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.3))),
                    Icon(Icons.location_on, color: accent, size: 40, shadows: [Shadow(color: accent, blurRadius: 15)]),
                  ],
                ),
              ),
            ),
          ]),
        ],
      );
  }

  Widget _mapSearchField(Color accent) {
    return _glassContainer(
      height: 48,
      borderRadius: BorderRadius.circular(20),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search locations...',
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: accent.withValues(alpha: 0.6), size: 18),
          suffixIcon: _isSearching ? Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: accent)) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _mapSearchResults(Color accent) {
    return _glassContainer(
      maxHeight: 200,
      borderRadius: BorderRadius.circular(20),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (ctx, i) {
          final res = _searchResults[i];
          return ListTile(
            dense: true,
            leading: Icon(Icons.location_on, color: accent, size: 18),
            title: Text(res['display_name'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(res['full_name'], style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _selectResult(res),
          );
        },
      ),
    );
  }

  Widget _buildLayerFab(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showLayerPicker = !_showLayerPicker),
      child: _glassContainer(
        width: 45, height: 45,
        child: Icon(_mapLayer.icon, color: accent, size: 20),
      ),
    );
  }

  Widget _buildLayerPickerPopup(Color accent) {
    return _glassContainer(
      width: 180,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: MapLayerHost.values.map((layer) {
          final sel = _mapLayer == layer;
          return InkWell(
            onTap: () => setState(() { _mapLayer = layer; _showLayerPicker = false; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? layer.accent.withValues(alpha: 0.15) : Colors.transparent,
                border: Border(left: BorderSide(color: sel ? layer.accent : Colors.transparent, width: 3)),
              ),
              child: Row(
                children: [
                  Icon(layer.icon, color: sel ? layer.accent : Colors.white60, size: 16),
                  const SizedBox(width: 12),
                  Expanded(child: Text(layer.label, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
                  if (sel) Icon(Icons.check_circle, color: layer.accent, size: 16),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _glassContainer({required Widget child, double? width, double? height, double? maxHeight, BorderRadius? borderRadius, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width, height: height,
          constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight) : null,
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF101015).withValues(alpha: 0.7),
            borderRadius: borderRadius ?? BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _dateTile(IconData icon, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent, size: 20)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _buildBottomNav(Color accent, Color secondary) {
    final isLast = _currentStep == _stepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => GestureDetector(
          onTap: isLast
            ? (_saving ? null : _submit)
            : (_canProceed ? _nextStep : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 64,
            decoration: BoxDecoration(
              gradient: (isLast || _canProceed) ? LinearGradient(colors: [accent, secondary]) : null,
              color: (isLast || _canProceed) ? null : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(32),
              boxShadow: (isLast || _canProceed)
                ? [BoxShadow(color: accent.withValues(alpha: 0.3 * (isLast ? _pulseAnim.value : 1)), blurRadius: 25, offset: const Offset(0, 8))]
                : [],
            ),
            child: Center(
              child: _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isLast ? Icons.rocket_launch : Icons.arrow_forward, color: (isLast || _canProceed) ? Colors.white : Colors.white30, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isLast ? (_isRushIn ? 'LAUNCH RUSH-IN' : 'PUBLISH ACTIVITY') : 'CONTINUE',
                        style: TextStyle(color: (isLast || _canProceed) ? Colors.white : Colors.white30, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
