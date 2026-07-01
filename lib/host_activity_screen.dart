import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui'; // For ImageFilter and BackdropFilter

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/doodle_theme.dart';

// =============================================================================
// HOST ACTIVITY SCREEN - SUPREME EDITION
// A multi-step wizard for creating Rush-Ins and standard activities.
// =============================================================================

enum MapLayerHost {
  street('Street Mode', Icons.map, 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png', Color(0xFFFF6B00), true),
  satellite('Satellite', Icons.satellite_alt, 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', Color(0xFFFF007F), false),
  terrain('Terrain', Icons.terrain, 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', Color(0xFF4ADE80), false);

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
  bool _isRushIn = true;
  bool _saving = false;
  bool _fetchingGps = false;
  String? _uploadedImageUrl;
  bool _isUploadingBanner = false;

  // ── RUSH-IN DATA ──
  final List<String> _selectedVibes = [];
  String _selectedMood = '🔥';
  int _participantLimit = 10;
  int _durationHours = 6;
  double _radiusKm = 5.0;
  bool _isGhostMode = false;

  final String _selectedCategory = 'Music';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // ── AI SUGGESTIONS ──
  final List<Map<String, dynamic>> _defaultAiSuggestions = [
    {
      'title': 'Midnight Coffee Run',
      'tags': ['Coffee', 'Late Night', 'Chill'],
      'desc': 'Anyone up for a quick coffee run to the nearest 24/7 cafe? Need a caffeine boost.',
    },
    {
      'title': 'Weekend Turf Cricket',
      'tags': ['Sports', 'Cricket', 'Active'],
      'desc': 'Looking for a few more players for a 6-a-side box cricket match this weekend.',
    },
    {
      'title': 'Rooftop Pizza Party',
      'tags': ['Food', 'Party', 'Music'],
      'desc': 'Ordering some pizzas and playing music on the rooftop. Everyone is welcome to join.',
    },
    {
      'title': 'Early Morning Cycling',
      'tags': ['Fitness', 'Morning', 'Explore'],
      'desc': 'Planning a 15km cycle ride around the city at dawn. Great way to start the day!',
    },
    {
      'title': 'Casual Board Games',
      'tags': ['Games', 'Indoor', 'Fun'],
      'desc': 'Hosting a casual board game evening. I have Monopoly and Catan, bring your favorites!',
    },
  ];

  List<Map<String, dynamic>> _filteredAiSuggestions = [];


  static const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  void _filterAiSuggestions(String query) {
    if (_aiDebounce?.isActive ?? false) _aiDebounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _filteredAiSuggestions = List.from(_defaultAiSuggestions);
        _isGeneratingSuggestions = false;
      });
      return;
    }

    // Immediately clear stale suggestions & show loading
    setState(() {
      _filteredAiSuggestions = [];
      _isGeneratingSuggestions = true;
    });

    _aiDebounce = Timer(const Duration(milliseconds: 400), () => _callGeminiApi(query));
  }

  Future<void> _callGeminiApi(String query, {int attempt = 1}) async {
    if (!mounted) return;
    if (_geminiApiKey.isEmpty) {
      debugPrint('[AI] Gemini API key not configured via --dart-define=GEMINI_API_KEY=...');
      if (mounted) setState(() => _isGeneratingSuggestions = false);
      return;
    }
    const maxAttempts = 3;
    debugPrint('[AI] Attempt $attempt for query: "$query"');

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey',
      );

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': 'Generate 5 fun social activity ideas for the topic "$query". '
                    'Return a JSON object: {"suggestions":[{"title":"...","tags":["tag1","tag2"],"desc":"..."}]}'
              }
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.9,
        },
      });

      debugPrint('[AI] Sending request to Gemini...');
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: requestBody);
      debugPrint('[AI] Response status: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 429 && attempt < maxAttempts) {
        // Rate limited — wait and retry
        final waitSec = attempt * 2;
        debugPrint('[AI] Rate limited (429). Retrying in ${waitSec}s...');
        await Future.delayed(Duration(seconds: waitSec));
        if (mounted) await _callGeminiApi(query, attempt: attempt + 1);
        return;
      }

      if (response.statusCode == 200) {
        debugPrint('[AI] Success! Parsing response...');
        final body = jsonDecode(response.body);

        String? text;
        try {
          text = body['candidates'][0]['content']['parts'][0]['text'] as String?;
        } catch (e) {
          debugPrint('[AI] Failed to extract text from response: $e');
          debugPrint('[AI] Full response body: ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');
        }

        if (text != null && text.isNotEmpty) {
          debugPrint('[AI] Raw text (first 300 chars): ${text.substring(0, (text.length > 300 ? 300 : text.length))}');

          // Strip markdown backticks if present
          String cleaned = text.trim();
          if (cleaned.startsWith('```')) {
            final firstNl = cleaned.indexOf('\n');
            final lastBt = cleaned.lastIndexOf('```');
            if (firstNl != -1 && lastBt > firstNl) {
              cleaned = cleaned.substring(firstNl + 1, lastBt).trim();
            }
          }

          final parsed = jsonDecode(cleaned);
          if (parsed is Map && parsed.containsKey('suggestions')) {
            final list = parsed['suggestions'] as List;
            debugPrint('[AI] Parsed ${list.length} suggestions');
            if (mounted) {
              setState(() {
                _filteredAiSuggestions = list.map<Map<String, dynamic>>((e) {
                  return {
                    'title': e['title']?.toString() ?? '',
                    'tags': List<String>.from((e['tags'] as List?) ?? []),
                    'desc': e['desc']?.toString() ?? '',
                  };
                }).where((s) => (s['title'] as String).isNotEmpty).toList();
                _isGeneratingSuggestions = false;
              });
              return;
            }
          } else {
            debugPrint('[AI] Response JSON does not contain "suggestions" key. Keys: ${parsed is Map ? parsed.keys.toList() : "not a map"}');
          }
        }
      } else {
        debugPrint('[AI] API error ${response.statusCode}: ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');
      }
    } catch (e, stack) {
      debugPrint('[AI] Exception: $e');
      debugPrint('[AI] Stack: $stack');
    }

    if (mounted) {
      setState(() => _isGeneratingSuggestions = false);
    }
  }
  
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
  Timer? _geocodeDebounce;
  Timer? _aiDebounce;
  bool _isGeneratingSuggestions = false;
  bool _isSearching = false;
  bool _showDropdown = false;

  void _debounceReverseGeocode(LatLng target) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _pinLocation = target;
        });
      }
      _reverseGeocode(target);
    });
  }

  Future<void> _pickAndUploadBannerImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (file == null) return;

      setState(() {
        _isUploadingBanner = true;
      });

      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), 'jpg');
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'banners/$uid-$timestamp.$ext';

      try {
        await Supabase.instance.client.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
        final url = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
        if (mounted) {
          setState(() {
            _uploadedImageUrl = url;
            _isUploadingBanner = false;
          });
        }
      } catch (e) {
        final b64 = base64Encode(bytes);
        if (mounted) {
          setState(() {
            _uploadedImageUrl = 'data:image/jpeg;base64,$b64';
            _isUploadingBanner = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  // ── LOOKUP MAPS ──
  final List<String> _categories = ['Outdoor', 'Sports', 'Music', 'Food', 'Study', 'Gaming', 'Fitness'];
  final List<String> _moods = ['🔥', '🎉', '😎', '🌙', '💀', '🧘', '🎶', '⚡', '🍕', '💬'];
  final Map<String, Map<String, dynamic>> _vibeData = {
    'Outdoor':    {'icon': Icons.park, 'color': const Color(0xFF4ADE80)},
    'Sports':     {'icon': Icons.sports_soccer, 'color': const Color(0xFFFFAB40)},
    'Music':      {'icon': Icons.music_note, 'color': const Color(0xFFE040FB)},
    'Food':       {'icon': Icons.restaurant, 'color': const Color(0xFFFF5252)},
    'Study':      {'icon': Icons.menu_book, 'color': const Color(0xFF448AFF)},
    'Gaming':     {'icon': Icons.sports_esports, 'color': const Color(0xFF7C4DFF)},
    'Fitness':    {'icon': Icons.fitness_center, 'color': const Color(0xFF69F0AE)},
  };

  // ── STEPS ──
  List<String> get _stepTitles => ['DETAILS', 'LOCATION', 'LAUNCH'];

  @override
  void initState() {
    super.initState();
    _isRushIn = true;
    _filteredAiSuggestions = List.from(_defaultAiSuggestions);
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
    _geocodeDebounce?.cancel();
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
          backgroundColor: const Color(0xFFFF6B00), behavior: SnackBarBehavior.floating,
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


  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (c, ch) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF6B00), surface: Color(0xFF101015), onSurface: Colors.white)), child: ch!),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  // ── VALIDATION ──
  bool get _canProceed {
    if (_isRushIn) {
      switch (_currentStep) {
        case 0: return _titleCtrl.text.trim().isNotEmpty && _noteCtrl.text.trim().isNotEmpty;
        case 1: return _locationNameCtrl.text.trim().isNotEmpty;
        case 2: return true; // Launch preview is always valid
        default: return false;
      }
    } return false;
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated. Please log in.');
      }
      final uid = user.id;
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
        'activity_time': dt.toUtc().toIso8601String(),
        'lat': _pinLocation.latitude,
        'lng': _pinLocation.longitude,
        'location_name': _locationNameCtrl.text.trim(),
        'district': locationService.activeDistrict,
        'state': locationService.activeState,
        'is_active': true,
        'is_rush_in': _isRushIn,
        'activity_type': _isRushIn ? 'rush_in' : 'event',
        'vibes': _isRushIn ? _selectedVibes : [],
        'hook': _isRushIn ? _hookCtrl.text.trim() : null,
        'participant_limit': _isRushIn ? _participantLimit : 100,
        'is_ghost_mode': _isRushIn ? _isGhostMode : false,
        'is_ghost': _isRushIn ? _isGhostMode : false,
        'auto_accept': false,
        'invite_only': false,
        'entry_type': 'free',
      };

      if (_isRushIn) {
        payload['expires_at'] = dt.add(Duration(hours: _durationHours)).toUtc().toIso8601String();
        payload['duration_hours'] = _durationHours;
        payload['radius_km'] = _radiusKm;
      }

      String activityId;
      final safeKeys = ['user_id', 'title', 'description', 'category', 'activity_time', 'lat', 'lng', 'location_name', 'district', 'state', 'is_active'];
      final safePayload = <String, dynamic>{};
      String extraData = '';
      
      if (_uploadedImageUrl != null) {
        extraData += '\n[image_url:$_uploadedImageUrl]';
      }
      
      for (final key in payload.keys) {
        if (safeKeys.contains(key)) {
          safePayload[key] = payload[key];
        } else {
          if (payload[key] != null) {
            extraData += '\n[$key:${payload[key]}]';
          }
        }
      }
      
      safePayload['description'] = '${safePayload['description'] ?? ''}$extraData';
      
      final response = await Supabase.instance.client
          .from('activities')
          .insert(safePayload)
          .select('id')
          .single();
      activityId = response['id'].toString();

      String hostName = 'Someone';
      try {
        final profileRes = await Supabase.instance.client
            .from('profiles')
            .select('name')
            .eq('id', uid)
            .maybeSingle();
        if (profileRes != null && profileRes['name'] != null) {
          hostName = profileRes['name'].toString();
        } else {
          final profileRes2 = await Supabase.instance.client
              .from('profiles')
              .select('full_name')
              .eq('id', uid)
              .maybeSingle();
          if (profileRes2 != null && profileRes2['full_name'] != null) {
            hostName = profileRes2['full_name'].toString();
          }
        }
      } catch (_) {
        try {
          final profileRes2 = await Supabase.instance.client
              .from('profiles')
              .select('full_name')
              .eq('id', uid)
              .maybeSingle();
          if (profileRes2 != null && profileRes2['full_name'] != null) {
            hostName = profileRes2['full_name'].toString();
          }
        } catch (_) {}
      }

      // Trigger nearby notifications
      NotificationService.notifyNearbyActivity(
        creatorId: uid,
        activityId: activityId,
        title: _titleCtrl.text.trim(),
        locationName: _locationNameCtrl.text.trim(),
        hostName: hostName,
        lat: _pinLocation.latitude,
        lng: _pinLocation.longitude,
        isRushIn: _isRushIn,
        activityCity: locationService.activeDistrict,
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
                    gradient: const LinearGradient(colors: [Color(0xFFFF007F), Color(0xFFFF7E40)]),
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
    const pink = Color(0xFFFF6B00); // Updated to Orange
    const purple = Color(0xFFFF9F0A); // Updated to Amber/Orange
    const actPrimary = Color(0xFFFF6B00);
    const actSecondary = Color(0xFF2962FF);
    final accent = _isRushIn ? pink : actPrimary;
    final accentSecondary = _isRushIn ? purple : actSecondary;

    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : const Color(0xFF050508),
      body: Stack(
        children: [
          // ── MAP BACKGROUND (FULL SCREEN) ──
          if (_currentStep == 1)
            Positioned.fill(
              child: _locationMap(Colors.blue),
            ),

          // ── AMBIENT ORBS ──
          if (_currentStep != 1) Positioned(top: -120, right: -80, child: _ambientOrb(accentSecondary, 350)),
          if (_currentStep != 1) Positioned(bottom: -80, left: -100, child: _ambientOrb(accent, 300)),

          // ── MAIN CONTENT ──
          SafeArea(
            child: Column(
              children: [
                // ── TOP BAR ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Builder(
                    builder: (context) {
                      final bool isMapLight = _currentStep == 1 ? _isLightMode : isDoodleMode(context);
                      final Color topIconColor = isMapLight ? DoodleColors.textPrimary : Colors.white;
                      final Color topSubColor = isMapLight ? DoodleColors.textPrimary.withValues(alpha: 0.6) : Colors.white38;
                      final Color topIconBg = isMapLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);
                      
                      return Row(
                        children: [
                          GestureDetector(
                            onTap: _currentStep == 0 ? () => Navigator.pop(context) : _prevStep,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: topIconBg, borderRadius: BorderRadius.circular(14)),
                              child: Icon(_currentStep == 0 ? Icons.close : Icons.arrow_back_ios_new, color: topIconColor, size: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isRushIn ? 'CREATE RUSH-IN' : 'HOST ACTIVITY', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
                                const SizedBox(height: 4),
                                Text('STEP ${_currentStep + 1} OF ${_stepTitles.length} • ${_stepTitles[_currentStep]}', style: TextStyle(color: topSubColor, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
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
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: _currentStep == 1,
                        child: PageView(
                          controller: _pageCtrl,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [_rushStep0Identity(accent, accentSecondary), const SizedBox(), _rushStep4Launch(accent, accentSecondary)],
                        ),
                      ),
                      if (_currentStep == 1)
                        Positioned.fill(
                          child: _rushStep3Overlay(accent),
                        ),
                    ],
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
          _sectionHeader('WHAT\'S YOUR PLAN?', 'Search for ideas or write your own headline.'),
          const SizedBox(height: 16),
          _neonTextField(_titleCtrl, 'Search ideas... (e.g. cricket)', Icons.auto_awesome, accent, onChanged: _filterAiSuggestions),
          
          if (_isGeneratingSuggestions) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(accent)),
                ),
                const SizedBox(width: 10),
                Text('AI is brainstorming...', style: TextStyle(color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDoodleMode(context) ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF16161A).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDoodleMode(context) ? DoodleColors.sketchLine.withValues(alpha: 0.2) : Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 150,
                          height: 12,
                          decoration: BoxDecoration(color: isDoodleMode(context) ? Colors.black12 : Colors.white10, borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 10,
                              decoration: BoxDecoration(color: accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(5)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 40,
                              height: 10,
                              decoration: BoxDecoration(color: accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ] else if (_filteredAiSuggestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text('AI suggestions for you', style: TextStyle(color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredAiSuggestions.take(5).length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final sug = _filteredAiSuggestions[i];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _titleCtrl.text = sug['title'];
                      _noteCtrl.text = sug['desc'];
                      _filterAiSuggestions(sug['title']);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDoodleMode(context) ? Colors.white : const Color(0xFF16161A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDoodleMode(context) ? DoodleColors.sketchLine : Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.auto_awesome, color: accent, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sug['title'], style: TextStyle(color: isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Row(
                                children: (sug['tags'] as List).map<Widget>((t) => Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(t, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: isDoodleMode(context) ? Colors.black26 : Colors.white24, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
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

          _sectionHeader('DESCRIPTION (REQUIRED)', 'Tell people what you want to do.'),
          const SizedBox(height: 16),
          _neonTextField(_noteCtrl, 'Pack a picnic, bring a frisbee, maybe some cricket gear? Park hang out.', Icons.sticky_note_2_outlined, Colors.white38, maxLines: 3),
          const SizedBox(height: 32),
          _buildBannerImageSection(accent),
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
        ],
      ),
    );
  }

  // ===========================================================================
  // RUSH-IN STEP 3: DROP ZONE
  // ===========================================================================
  Widget _rushStep3Overlay(Color accent) {
    return Stack(
      children: [
        // Top Header
        Positioned(
          top: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: _sectionHeader('THE DROP ZONE', 'Pin your exact location on the map.', forceLight: _isLightMode),
          ),
        ),
        
        // Search Bar
        Positioned(
          top: 80, left: 16, right: 64,
          child: _mapSearchField(accent),
        ),
        // Dropdown Overlay
        if (_showDropdown)
          Positioned(
            top: 136, left: 16, right: 64,
            child: _mapSearchResults(accent),
          ),
        
        // Theme Toggle (Top-Right of search bar area)
        Positioned(
          top: 80, right: 16,
          child: _mapStyleToggle(accent),
        ),

        // Action Guide
        Positioned(
          top: 140, left: 0, right: 0,
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
                const SizedBox(height: 24), // Offset for visual center
              ],
            ),
          ),
        ),

        // Layer Picker Popup
        if (_showLayerPicker)
          Positioned(
            bottom: 140, left: 16,
            child: _buildLayerPickerPopup(accent),
          ),

        // Layer FAB (Floating Bottom-Left)
        Positioned(
          bottom: 80, left: 16,
          child: _buildLayerFab(accent),
        ),

        // GPS Pin (Floating Bottom-Right)
        Positioned(
          bottom: 80, right: 16,
          child: _gpsButton(accent),
        ),

        // Bottom Text Field
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: _neonTextField(_locationNameCtrl, 'Name this spot... (e.g. Rooftop, Gate 3)', Icons.edit_location_alt, accent, forceLight: _isLightMode),
          ),
        ),
      ],
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
          _buildLaunchPreviewCard(accent, secondary),
          const SizedBox(height: 24),
          Center(child: Text('Tap LAUNCH to go live.', style: TextStyle(color: accent.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))),
        ],
      ),
    );
  }

  // ===========================================================================
  // STANDARD ACTIVITY STEPS
  // ===========================================================================
  Widget _buildBannerImageSection(Color accent) {
    final List<Map<String, String>> presets = [
      {'name': 'Music', 'url': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&auto=format&fit=crop'},
      {'name': 'Cafe', 'url': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&auto=format&fit=crop'},
      {'name': 'Sports', 'url': 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=800&auto=format&fit=crop'},
      {'name': 'Nature', 'url': 'https://images.unsplash.com/photo-1533240332313-0db49b439ad3?w=800&auto=format&fit=crop'},
      {'name': 'Tech', 'url': 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&auto=format&fit=crop'},
      {'name': 'Party', 'url': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&auto=format&fit=crop'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('EVENT BANNER IMAGE', 'Select a preset premium banner or upload directly from your gallery.'),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = _uploadedImageUrl == preset['url'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _uploadedImageUrl = preset['url'];
                  });
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? accent : Colors.white10,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          preset['url']!,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: isSelected ? Colors.black26 : Colors.black45,
                        ),
                        Center(
                          child: Text(
                            preset['name']!.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: accent,
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
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
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isUploadingBanner ? null : _pickAndUploadBannerImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isUploadingBanner)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 2,
                    ),
                  )
                else ...[
                  Icon(Icons.photo_library, color: accent.withValues(alpha: 0.8), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'UPLOAD FROM GALLERY',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 16,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _uploadedImageUrl!.startsWith('data:')
                  ? Image.memory(
                      base64Decode(_uploadedImageUrl!.split(',').last),
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      _uploadedImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white.withValues(alpha: 0.02),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.white24),
                              SizedBox(width: 8),
                              Text('Failed to load image', style: TextStyle(color: Colors.white24, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLaunchPreviewCard(Color accent, Color secondary) {
    final bannerUrl = _uploadedImageUrl;
    final isLight = isDoodleMode(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF101015),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: -5,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image Section
          if (bannerUrl != null && bannerUrl.isNotEmpty)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  bannerUrl.startsWith('data:')
                      ? Image.memory(
                          base64Decode(bannerUrl.split(',').last),
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                        ),
                  // Sleek gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  // Active indicator pill
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: accent, size: 8),
                          const SizedBox(width: 6),
                          Text(
                            _isRushIn ? 'LIVE RUSH-IN' : 'UPCOMING',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isRushIn)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${_durationHours}H LIVE',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleCtrl.text.isEmpty ? 'Untitled Event' : _titleCtrl.text,
                            style: GoogleFonts.inter(
                              color: isLight ? DoodleColors.textPrimary : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRushIn
                                ? _selectedVibes.join(' • ').toUpperCase()
                                : _selectedCategory.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isRushIn && _descCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _descCtrl.text,
                    style: GoogleFonts.inter(
                      color: isLight ? DoodleColors.textPrimary.withValues(alpha: 0.8) : Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                Divider(color: isLight ? DoodleColors.sketchLine : Colors.white10, height: 1),
                const SizedBox(height: 16),

                // Info Rows
                _infoRow(Icons.place, 'Location', _locationNameCtrl.text.isEmpty ? 'Drop Zone Pinned' : _locationNameCtrl.text, accent),
                if (!_isRushIn) ...[
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.calendar_today,
                    'Date & Time',
                    '${_selectedDate?.day}/${_selectedDate?.month}/${_selectedDate?.year} at ${_selectedTime?.format(context) ?? ""}',
                    accent,
                  ),
                ],
                const SizedBox(height: 10),
                _infoRow(
                  Icons.people,
                  'Max Crew',
                  '$_participantLimit People',
                  accent,
                ),
                if (_isRushIn) ...[
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.radar,
                    'Broadcast Radius',
                    '${_radiusKm.round()} km radius',
                    accent,
                  ),
                ],

                // Badge status pills
                if (_isGhostMode || _isPackage) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      if (_isGhostMode) _previewBadge('GHOST', Icons.visibility_off),
                      if (_isPackage) _previewBadge('EXCLUSIVE', Icons.diamond),
                    ],
                  )
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color accent) {
    final isLight = isDoodleMode(context);
    return Row(
      children: [
        Icon(icon, color: accent.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.inter(color: isLight ? DoodleColors.textPrimary.withValues(alpha: 0.5) : Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(color: isLight ? DoodleColors.textPrimary : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // REUSABLE COMPONENTS
  // ===========================================================================

  Widget _ambientOrb(Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 120)]));
  }

  Widget _sectionHeader(String title, String sub, {bool? forceLight}) {
    final isLight = forceLight ?? isDoodleMode(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: isLight ? DoodleColors.textPrimary : Colors.white, fontWeight: FontWeight.w900, fontSize: isLight ? 20 : 18, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(sub, style: TextStyle(color: isLight ? DoodleColors.textPrimary.withValues(alpha: 0.6) : Colors.white38, fontSize: isLight ? 13 : 12)),
    ]);
  }

  Widget _neonTextField(TextEditingController ctrl, String hint, IconData icon, Color glow, {int maxLines = 1, TextInputType? keyboardType, bool? forceLight, ValueChanged<String>? onChanged}) {
    final isLight = forceLight ?? isDoodleMode(context);
    final bg = isLight ? Colors.white : Colors.white.withValues(alpha: 0.03);
    final border = isLight ? DoodleColors.sketchLine : Colors.white.withValues(alpha: 0.06);
    final txt = isLight ? DoodleColors.textPrimary : Colors.white;
    final hintClr = isLight ? DoodleColors.textPrimary.withValues(alpha: 0.5) : Colors.white24;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: txt, fontSize: isLight ? 16 : 15, fontWeight: isLight ? FontWeight.w500 : FontWeight.normal),
        onChanged: (v) {
          if (onChanged != null) onChanged(v);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintClr, fontSize: isLight ? 15 : 14),
          prefixIcon: maxLines == 1 ? Icon(icon, color: isLight ? DoodleColors.textPrimary.withValues(alpha: 0.6) : glow.withValues(alpha: 0.6), size: isLight ? 22 : 20) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: maxLines == 1 ? 18 : 20),
        ),
      ),
    );
  }


  Widget _ruleToggle(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) {
    final isLight = isDoodleMode(context);
    final bg = isLight ? Colors.white : (value ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02));
    final border = isLight ? DoodleColors.sketchLine : (value ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04));
    final txt = isLight ? DoodleColors.textPrimary : (value ? Colors.white : Colors.white60);
    final subTxt = isLight ? DoodleColors.textPrimary.withValues(alpha: 0.6) : Colors.white30;
    final icnClr = isLight ? DoodleColors.textPrimary : (value ? Colors.white : Colors.white38);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: icnClr, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: subTxt, fontSize: 11)),
          ])),
          Switch(
            value: value, onChanged: onChanged,
            activeThumbColor: isLight ? Colors.white : Colors.white,
            activeTrackColor: isLight ? DoodleColors.blue : Colors.white.withValues(alpha: 0.3),
            inactiveThumbColor: isLight ? Colors.white : Colors.white38,
            inactiveTrackColor: isLight ? DoodleColors.sketchLine : Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }


  Widget _previewBadge(String label, IconData icon) {
    final isLight = isDoodleMode(context);
    final bg = isLight ? DoodleColors.cream : Colors.white.withValues(alpha: 0.05);
    final txt = isLight ? DoodleColors.textPrimary.withValues(alpha: 0.5) : Colors.white38;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: txt, size: 12),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: txt, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
          ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Color(0xFFFF6B00), strokeWidth: 3))
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

    if (!_isLightMode && _mapLayer.allowsDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1.0, 0.0, 0.0, 0.0, 255.0,
          0.0, -1.0, 0.0, 0.0, 255.0,
          0.0, 0.0, -1.0, 0.0, 255.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]),
        child: _buildFlutterMapWidget(accent, baseUrl),
      );
    }
    return _buildFlutterMapWidget(accent, baseUrl);
  }


  Widget _buildFlutterMapWidget(Color accent, String baseUrl) {
    return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _pinLocation, 
          initialZoom: 15.0, 
          onTap: (_, pt) { 
            _mapController.move(pt, _mapController.camera.zoom);
            setState(() => _pinLocation = pt); 
            _debounceReverseGeocode(pt); 
          },
          onPositionChanged: (pos, hasGesture) {
            if (hasGesture) {
              _pinLocation = pos.center; // Update coordinate in memory to prevent janky gesture resets
              _debounceReverseGeocode(pos.center); 
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
    final isLight = _currentStep == 3 ? _isLightMode : isDoodleMode(context);
    final disabledBg = isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04);
    final disabledText = isLight ? Colors.black38 : Colors.white30;

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
              color: (isLast || _canProceed) ? null : disabledBg,
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
                      Icon(isLast ? Icons.rocket_launch : Icons.arrow_forward, color: (isLast || _canProceed) ? Colors.white : disabledText, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isLast ? (_isRushIn ? 'LAUNCH RUSH-IN' : 'PUBLISH ACTIVITY') : 'CONTINUE',
                        style: TextStyle(color: (isLast || _canProceed) ? Colors.white : disabledText, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
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
