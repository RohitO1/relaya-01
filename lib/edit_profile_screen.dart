import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_upload_service.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'services/location_service.dart';
import 'utils/constants.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  const EditProfileScreen({super.key, required this.initialProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _sb = Supabase.instance.client;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _locSearchCtrl;
  late TextEditingController _jobTitleCtrl;

  double? _lat;
  double? _lng;
  final MapController _mapCtrl = MapController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  // DOB wheel state
  int _dobDay = 1;
  int _dobMonth = 1;
  int _dobYear = 2000;
  bool _dobPickerExpanded = false;
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  String? _avatarUrl;
  String _gender = '';
  Set<String> _interests = {};
  Set<String> _purposes = {};
  bool _isPublic = true;

  double _heightCm = 170;
  String _smoking = '';
  String _drinking = '';
  String _weed = '';
  String _diet = '';
  String _exercise = '';
  String _education = '';
  String _zodiac = '';
  String _relationshipType = '';
  String _religion = '';
  String _matchGender = '';

  Set<String> _selectedTraits = {};
  Set<String> _selectedLanguages = {};
  Set<String> _selectedVibes = {};

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p['name'] ?? p['full_name'] ?? '');
    _userCtrl = TextEditingController(text: p['username'] ?? '');
    _bioCtrl = TextEditingController(text: p['bio'] ?? '');
    _cityCtrl = TextEditingController(text: p['city'] ?? '');
    _stateCtrl = TextEditingController(text: p['state'] ?? '');
    _dobCtrl = TextEditingController(text: p['dob'] ?? '');
    _locSearchCtrl = TextEditingController(text: p['city'] ?? '');
    _jobTitleCtrl = TextEditingController(text: p['job_title'] ?? '');
    _lat = (p['lat'] as num?)?.toDouble();
    _lng = (p['lng'] as num?)?.toDouble();

    if (_dobCtrl.text.isNotEmpty) {
      try {
        final d = DateTime.parse(_dobCtrl.text);
        _dobYear = d.year;
        _dobMonth = d.month;
        _dobDay = d.day;
      } catch (_) {}
    }
    
    _avatarUrl = p['avatar_url'];
    _gender = p['gender'] ?? '';
    _isPublic = p['is_public'] ?? true;
    _heightCm = (p['height_cm'] as num?)?.toDouble() ?? 170;
    _smoking = p['smoking'] ?? '';
    _drinking = p['drinking'] ?? '';
    _weed = p['weed'] ?? '';
    _diet = p['diet'] ?? '';
    _exercise = p['exercise'] ?? '';
    _education = p['education'] ?? '';
    _zodiac = p['zodiac'] ?? '';
    _relationshipType = p['relationship_type'] ?? '';
    _religion = p['religion'] ?? '';
    _matchGender = p['match_gender'] ?? '';

    if (p['interests'] is List) _interests = Set<String>.from((p['interests'] as List).map((e) => e.toString()));
    if (p['looking_for'] is List) _purposes = Set<String>.from((p['looking_for'] as List).map((e) => e.toString()));
    if (p['personality_traits'] is List) _selectedTraits = Set<String>.from((p['personality_traits'] as List).map((e) => e.toString()));
    if (p['languages'] is List) _selectedLanguages = Set<String>.from((p['languages'] as List).map((e) => e.toString()));
    if (p['visible_vibes'] is List) _selectedVibes = Set<String>.from((p['visible_vibes'] as List).map((e) => e.toString()));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _dobCtrl.dispose();
    _locSearchCtrl.dispose();
    _searchDebounce?.cancel();
    _jobTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final url = await ImageUploadService.pickAndUpload(context: context, folder: 'avatars');
    if (url != null) {
      setState(() => _avatarUrl = url);
    }
  }

  String? _extractColumnFromError(String msg) {
    final start = msg.indexOf("Could not find the '");
    if (start == -1) return null;
    final end = msg.indexOf("' column", start + 20);
    if (end == -1) return null;
    return msg.substring(start + 20, end);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = _sb.auth.currentUser!.id;
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'full_name': _nameCtrl.text.trim(),
        'username': _userCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'district': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'dob': _dobCtrl.text.trim(),
        'job_title': _jobTitleCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'gender': _gender,
        'interests': _interests.toList(),
        'looking_for': _purposes.toList(),
        'height_cm': _heightCm.toInt(),
        'smoking': _smoking,
        'drinking': _drinking,
        'weed': _weed,
        'diet': _diet,
        'exercise': _exercise,
        'education': _education,
        'zodiac': _zodiac,
        'relationship_type': _relationshipType,
        'religion': _religion,
        'match_gender': _matchGender,
        'personality_traits': _selectedTraits.toList(),
        'languages': _selectedLanguages.toList(),
        'visible_vibes': _selectedVibes.toList(),
        'is_public': _isPublic,
      };

      bool success = false;
      int retries = 0;

      while (!success && retries < 15) {
        try {
          await _sb.from('profiles').update(payload).eq('id', uid);
          success = true;
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST204' || e.message.contains('Could not find the') || e.message.contains('column')) {
            final colName = _extractColumnFromError(e.message);
            if (colName != null && payload.containsKey(colName)) {
              payload.remove(colName);
              retries++;
              continue;
            }

            bool removedAny = false;
            final commonCols = [
              'dob', 'languages', 'personality_traits', 'visible_vibes', 
              'zodiac', 'relationship_type', 'religion', 'match_gender'
            ];
            for (final col in commonCols) {
              if (e.message.contains("'$col'") && payload.containsKey(col)) {
                payload.remove(col);
                removedAny = true;
              }
            }
            if (removedAny) {
              retries++;
              continue;
            }
          }
          rethrow;
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _daysInMonth(int month, int year) {
    return DateTime(year, month + 1, 0).day;
  }

  void _commitDob() {
    final maxDay = _daysInMonth(_dobMonth, _dobYear);
    if (_dobDay > maxDay) _dobDay = maxDay;
    _dobCtrl.text = '$_dobYear-${_dobMonth.toString().padLeft(2, '0')}-${_dobDay.toString().padLeft(2, '0')}';
  }

  Widget _buildDobPicker() {
    final now = DateTime.now();
    final maxYear = now.year - 16;
    final years = List.generate(maxYear - 1950 + 1, (i) => 1950 + i);
    final months = List.generate(12, (i) => i + 1);

    const itemH = 52.0;
    const visibleItems = 3;

    return StatefulBuilder(builder: (ctx, setLocal) {
      FixedExtentScrollController dayCtrl2 = FixedExtentScrollController(initialItem: _dobDay - 1);
      FixedExtentScrollController monthCtrl2 = FixedExtentScrollController(initialItem: _dobMonth - 1);
      FixedExtentScrollController yearCtrl2 = FixedExtentScrollController(initialItem: years.indexOf(_dobYear).clamp(0, years.length - 1));

      Widget col(FixedExtentScrollController c, List items, Function(int) onChange, {bool isYear = false}) {
        return Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: c,
            itemExtent: itemH,
            physics: const FixedExtentScrollPhysics(),
            perspective: 0.003,
            diameterRatio: 1.8,
            onSelectedItemChanged: (i) {
              onChange(i);
              setLocal(() {});
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (_, i) {
                if (i < 0 || i >= items.length) return null;
                final sel = c.hasClients && c.selectedItem == i;
                final String label;
                if (isYear) {
                  label = '${items[i]}';
                } else if (items == months) {
                  label = _monthNames[items[i] - 1];
                } else {
                  label = '${items[i]}'.padLeft(2, '0');
                }
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: GoogleFonts.inter(
                      fontSize: sel ? 26 : 20,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w400,
                      color: sel ? Colors.white : Colors.white.withValues(alpha: 0.35),
                    ),
                    child: Text(label),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      }

      final localDays = List.generate(_daysInMonth(_dobMonth, _dobYear), (i) => i + 1);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.25), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 2)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () { setState(() => _dobPickerExpanded = false); },
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                  ),
                  Row(children: [
                    const Icon(Icons.cake_outlined, color: Color(0xFFFF6B00), size: 16),
                    const SizedBox(width: 6),
                    Text('Date of Birth', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _commitDob();
                        _dobPickerExpanded = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF22C55E)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Done', style: GoogleFonts.inter(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: Center(child: Text('DAY', style: GoogleFonts.inter(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)))),
                  Expanded(child: Center(child: Text('MONTH', style: GoogleFonts.inter(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)))),
                  Expanded(child: Center(child: Text('YEAR', style: GoogleFonts.inter(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: itemH * visibleItems,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: itemH,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: const Color(0xFFFF6B00).withValues(alpha: 0.5), width: 1),
                          bottom: BorderSide(color: const Color(0xFFFF6B00).withValues(alpha: 0.5), width: 1),
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 0, left: 0, right: 0, height: itemH * 0.9,
                    child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF0D1117), const Color(0xFF0D1117).withValues(alpha: 0)])))),
                  Positioned(bottom: 0, left: 0, right: 0, height: itemH * 0.9,
                    child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [const Color(0xFF0D1117), const Color(0xFF0D1117).withValues(alpha: 0)])))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        col(dayCtrl2, localDays, (i) { _dobDay = localDays[i]; }),
                        col(monthCtrl2, months, (i) { _dobMonth = months[i]; }, isYear: false),
                        col(yearCtrl2, years, (i) { _dobYear = years[i]; }, isYear: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
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

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0F);
    const cyan = Color(0xFFFF6B00);
    const text2 = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Edit Profile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cyan)))
          else
            TextButton(
              onPressed: _save,
              child: Text('Save', style: GoogleFonts.inter(color: cyan, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cyan, width: 2),
                        image: DecorationImage(
                          image: _buildSafeImage(_avatarUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: cyan, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.black, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            _buildLabel('Full Name'),
            _buildField(_nameCtrl, 'Your full name'),
            const SizedBox(height: 16),

            _buildLabel('Username'),
            _buildField(_userCtrl, 'Username'),
            const SizedBox(height: 16),

            _buildLabel('Bio'),
            _buildField(_bioCtrl, 'Write a short bio...', maxLines: 3),
            const SizedBox(height: 16),

            _buildLabel('Date of Birth'),
            GestureDetector(
              onTap: () => setState(() => _dobPickerExpanded = !_dobPickerExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _dobPickerExpanded ? const Color(0xFFFF6B00) : (_dobCtrl.text.isNotEmpty ? const Color(0xFFFF6B00).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
                    width: _dobPickerExpanded ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: _dobCtrl.text.isNotEmpty ? const Color(0xFFFF6B00) : const Color(0xFF94A3B8), size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _dobCtrl.text.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (() {
                                    try {
                                      final d = DateTime.parse(_dobCtrl.text);
                                      return '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
                                    } catch (e) { return _dobCtrl.text; }
                                  })(),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text('Date of birth', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                              ],
                            )
                          : Text('Select Date of Birth', style: GoogleFonts.inter(color: Colors.white24, fontSize: 16)),
                    ),
                    Icon(
                      _dobPickerExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF94A3B8), size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_dobPickerExpanded) _buildDobPicker(),
            const SizedBox(height: 16),

            _buildLabel('Location'),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
              child: TextField(
                controller: _locSearchCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search city, area, landmark...',
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B00), size: 20),
                  suffixIcon: _locSearchCtrl.text.isNotEmpty
                      ? GestureDetector(onTap: () => setState(() { _locSearchCtrl.clear(); _searchResults = []; }), child: const Icon(Icons.close, color: const Color(0xFF94A3B8), size: 18))
                      : null,
                ),
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) {
                    final r = _searchResults[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 18),
                      title: Text(r['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(r['full_name'] ?? '', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _selectSearchResult(r),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : const LatLng(20.5937, 78.9629),
                    initialZoom: _lat != null && _lng != null ? 14.0 : 4.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _lat = point.latitude;
                        _lng = point.longitude;
                      });
                      _reverseGeocode(point.latitude, point.longitude);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    if (_lat != null && _lng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lat!, _lng!),
                            width: 60, height: 60,
                            child: const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Gender'),
            _buildGenderSelector(),
            const SizedBox(height: 24),

            _buildSection('Demographics & Work', [
              _buildLabel('Job Title'),
              _buildField(_jobTitleCtrl, 'e.g. Software Engineer'),
              const SizedBox(height: 16),
              
              _buildLabel('Height (cm)'),
              Slider(
                value: _heightCm,
                min: 120, max: 220, divisions: 100,
                activeColor: cyan,
                label: '${_heightCm.round()} cm',
                onChanged: (v) => setState(() => _heightCm = v),
              ),
              Center(child: Text('${_heightCm.round()} cm', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              
              _buildLabel('Education'),
              _buildSingleSelectWrap(ProfileConstants.eduLevels, _education, (v) => setState(() => _education = v)),
              const SizedBox(height: 16),

              _buildLabel('Religion'),
              _buildSingleSelectWrap(ProfileConstants.religions, _religion, (v) => setState(() => _religion = v)),
              const SizedBox(height: 16),

              _buildLabel('Zodiac'),
              _buildSingleSelectWrap(ProfileConstants.zodiacSigns, _zodiac, (v) => setState(() => _zodiac = v)),
            ]),

            _buildSection('Lifestyle Habits', [
              _buildLabel('Smoking'),
              _buildSingleSelectWrap(['Never', 'Socially', 'Regularly'], _smoking, (v) => setState(() => _smoking = v)),
              const SizedBox(height: 16),
              
              _buildLabel('Drinking'),
              _buildSingleSelectWrap(['Never', 'Socially', 'Regularly'], _drinking, (v) => setState(() => _drinking = v)),
              const SizedBox(height: 16),
              
              _buildLabel('420 / Weed'),
              _buildSingleSelectWrap(['Never', 'Socially', 'Regularly'], _weed, (v) => setState(() => _weed = v)),
              const SizedBox(height: 16),

              _buildLabel('Diet'),
              _buildSingleSelectWrap(['Everything', 'Vegetarian', 'Vegan', 'Pescatarian', 'Kosher', 'Halal', 'Other'], _diet, (v) => setState(() => _diet = v)),
              const SizedBox(height: 16),

              _buildLabel('Exercise'),
              _buildSingleSelectWrap(['Active', 'Sometimes', 'Never'], _exercise, (v) => setState(() => _exercise = v)),
            ]),

            _buildSection('Preferences', [
              _buildLabel('Looking For (Intent)'),
              _buildMultiSelectWrap(ProfileConstants.purposeOptions, _purposes),
              const SizedBox(height: 16),

              _buildLabel('Relationship Type'),
              _buildSingleSelectWrap(['Monogamy', 'Non-monogamy', 'Open to exploring', 'Prefer not to say'], _relationshipType, (v) => setState(() => _relationshipType = v)),
              const SizedBox(height: 16),

              _buildLabel('Who do you want to meet?'),
              _buildSingleSelectWrap(['Men', 'Women', 'Everyone'], _matchGender, (v) => setState(() => _matchGender = v)),
              const SizedBox(height: 16),

              _buildLabel('Languages Spoken'),
              _buildMultiSelectWrap(ProfileConstants.languages, _selectedLanguages),
            ]),

            _buildSection('Personality & Vibes', [
              _buildLabel('Top Interests'),
              _buildMultiSelectWrap(ProfileConstants.interestCategories.values.expand((x) => x).toList(), _interests),
              const SizedBox(height: 16),

              _buildLabel('Personality Traits'),
              _buildMultiSelectWrap(ProfileConstants.personalityTraits, _selectedTraits),
              const SizedBox(height: 16),

              _buildLabel('Vibes to display'),
              _buildMultiSelectWrap(ProfileConstants.vibeOptions, _selectedVibes),
            ]),


            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Public Profile', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Allow others to find you', style: GoogleFonts.inter(color: text2, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: cyan,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white24),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: ['Male', 'Female', 'Other'].map((g) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _gender = g),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _gender == g ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gender == g ? const Color(0xFFFF6B00) : Colors.white.withValues(alpha: 0.05)),
            ),
            alignment: Alignment.center,
            child: Text(g, style: GoogleFonts.inter(color: _gender == g ? Colors.white : const Color(0xFF94A3B8), fontWeight: _gender == g ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFFF6B00) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? Colors.white : const Color(0xFF94A3B8), fontSize: 13)),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFFFF6B00),
          collapsedIconColor: const Color(0xFF94A3B8),
          title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSelectWrap(List<String> options, String current, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: options.map((opt) => _buildChip(opt, current == opt, () => onSelect(opt))).toList(),
    );
  }

  Widget _buildMultiSelectWrap(List<String> options, Set<String> currentSet) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: options.map((opt) => _buildChip(opt, currentSet.contains(opt), () {
        setState(() {
          if (currentSet.contains(opt)) {
            currentSet.remove(opt);
          } else {
            currentSet.add(opt);
          }
        });
      })).toList(),
    );
  }

  ImageProvider _buildSafeImage(String? url) {
    if (url == null || url.isEmpty) return const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200');
    if (url.startsWith('http')) return NetworkImage(url);
    try {
      final base64Str = url.contains(',') ? url.split(',').last : url;
      return MemoryImage(base64Decode(base64Str));
    } catch (_) {
      return const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200');
    }
  }
}
