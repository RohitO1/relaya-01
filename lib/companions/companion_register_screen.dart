import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../image_upload_service.dart';
class CompanionRegisterScreen extends StatefulWidget {
  final String? editId;
  const CompanionRegisterScreen({super.key, this.editId});

  @override
  State<CompanionRegisterScreen> createState() => _CompanionRegisterScreenState();
}

class _CompanionRegisterScreenState extends State<CompanionRegisterScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;
  bool _loading = false;
  static const int _totalSteps = 7;

  // Step 1: Basic Info
  final _displayNameCtrl = TextEditingController();
  final _bioShortCtrl = TextEditingController();
  final _bioLongCtrl = TextEditingController();

  // Step 2: Photos
  final List<String> _photos = [];
  bool _uploadingPhoto = false;

  // Step 3: Session Types
  bool _isVirtualEnabled = false;
  double _virtualRate = 0;
  int _virtualMinDuration = 30;
  int _virtualMaxDuration = 120;

  bool _isPhysicalEnabled = false;
  double _physicalRate = 0;
  int _physicalMinDuration = 60;
  int _travelRadiusKm = 10;
  String _meetLocationPreference = 'public_only';

  // Step 4: Availability
  // Day 0 = Monday, Day 6 = Sunday. For simplicity, storing active days here, actual timeblocks would need deeper UI.
  final Set<int> _activeDays = {}; 
  int _advanceNoticeHours = 24;
  int _maxSessionsPerDay = 3;

  // Step 5: Tags
  final _allTags = [
    'Conversation', 'Language Practice', 'Gaming', 'Fitness', 'Dining', 
    'Exploring', 'Study Buddy', 'Event Plus-One', 'Music', 'Art'
  ];
  final Set<String> _selectedTags = {};

  // Step 6: Languages & Location
  final _allLanguages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Urdu'];
  final Set<String> _selectedLanguages = {};
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();

  // Step 7: Review & Submit (Code of Conduct)
  bool _agreedToConduct = false;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client.from('companion_profiles').select().eq('id', widget.editId!).single();
      _displayNameCtrl.text = data['display_name'] ?? '';
      _bioShortCtrl.text = data['bio_short'] ?? '';
      _bioLongCtrl.text = data['bio_long'] ?? '';
      _photos.addAll((data['photos'] as List?)?.map((e) => e.toString()).toList() ?? []);
      _isVirtualEnabled = data['is_virtual_enabled'] ?? false;
      _virtualRate = (data['virtual_rate_per_hour'] ?? 0).toDouble();
      _virtualMinDuration = data['virtual_min_duration_minutes'] ?? 30;
      _virtualMaxDuration = data['virtual_max_duration_minutes'] ?? 120;
      _isPhysicalEnabled = data['is_physical_enabled'] ?? false;
      _physicalRate = (data['physical_rate_per_hour'] ?? 0).toDouble();
      _physicalMinDuration = data['physical_min_duration_minutes'] ?? 60;
      _travelRadiusKm = data['travel_radius_km'] ?? 10;
      _meetLocationPreference = data['meet_location_preference'] ?? 'public_only';
      _advanceNoticeHours = data['advance_notice_hours'] ?? 24;
      _maxSessionsPerDay = data['max_sessions_per_day'] ?? 3;
      _selectedTags.addAll((data['tags'] as List?)?.map((e) => e.toString()).toList() ?? []);
      _selectedLanguages.addAll((data['languages'] as List?)?.map((e) => e.toString()).toList() ?? []);
      _cityCtrl.text = data['city'] ?? '';
      _regionCtrl.text = data['region'] ?? '';
      _agreedToConduct = true;
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioShortCtrl.dispose();
    _bioLongCtrl.dispose();
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _displayNameCtrl.text.isNotEmpty && _bioShortCtrl.text.isNotEmpty;
      case 1: return _photos.isNotEmpty;
      case 2: return _isVirtualEnabled || _isPhysicalEnabled;
      case 3: return _activeDays.isNotEmpty;
      case 4: return _selectedTags.isNotEmpty;
      case 5: return _selectedLanguages.isNotEmpty && _cityCtrl.text.isNotEmpty;
      case 6: return _agreedToConduct;
      default: return true;
    }
  }

  void _nextStep() {
    if (!_canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete required fields'), backgroundColor: Color(0xFFE11D48)));
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final data = {
        'user_id': uid,
        'display_name': _displayNameCtrl.text.trim(),
        'bio_short': _bioShortCtrl.text.trim(),
        'bio_long': _bioLongCtrl.text.trim(),
        'photos': _photos,
        'is_virtual_enabled': _isVirtualEnabled,
        'virtual_rate_per_hour': _virtualRate,
        'virtual_min_duration_minutes': _virtualMinDuration,
        'virtual_max_duration_minutes': _virtualMaxDuration,
        'is_physical_enabled': _isPhysicalEnabled,
        'physical_rate_per_hour': _physicalRate,
        'physical_min_duration_minutes': _physicalMinDuration,
        'travel_radius_km': _travelRadiusKm,
        'meet_location_preference': _meetLocationPreference,
        'advance_notice_hours': _advanceNoticeHours,
        'max_sessions_per_day': _maxSessionsPerDay,
        'tags': _selectedTags.toList(),
        'languages': _selectedLanguages.toList(),
        'city': _cityCtrl.text.trim(),
        'region': _regionCtrl.text.trim(),
        'status': 'PENDING',
      };

      if (widget.editId != null) {
        await Supabase.instance.client.from('companion_profiles').update(data).eq('id', widget.editId!);
      } else {
        await Supabase.instance.client.from('companion_profiles').insert(data);
        
        // Also insert availability (simplified for now)
        for (var day in _activeDays) {
          await Supabase.instance.client.from('companion_availability').insert({
            'companion_id': (await Supabase.instance.client.from('companion_profiles').select('id').eq('user_id', uid).single())['id'],
            'day_of_week': day,
            'start_time_utc': '00:00:00',
            'end_time_utc': '23:59:59',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Submitted! Pending Review.'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 6 photos allowed')));
      return;
    }
    setState(() => _uploadingPhoto = true);
    try {
      final url = await ImageUploadService.pickAndUpload(context: context, folder: 'companion_photos');
      if (url != null && mounted) {
        setState(() => _photos.add(url));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, {int maxLines = 1, int? maxLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF050508), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prevStep),
        title: Text('Step ${_step + 1} of $_totalSteps', style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _totalSteps, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7E40))),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Step 1: Basic Info
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Basic Info', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      _buildTextField(_displayNameCtrl, 'Display Name', 'e.g. Alex (No real names)'),
                      _buildTextField(_bioShortCtrl, 'Short Bio (Appears on cards)', 'Max 300 characters...', maxLines: 3, maxLength: 300),
                      _buildTextField(_bioLongCtrl, 'About Me (Full profile)', 'Max 1000 characters...', maxLines: 6, maxLength: 1000),
                    ],
                  ),
                  // Step 2: Photos
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Photos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text('First photo is your primary picture.', style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: [
                          ..._photos.asMap().entries.map((e) => Stack(
                            children: [
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(e.value), fit: BoxFit.cover)),
                              ),
                              Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => setState(() => _photos.removeAt(e.key)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                              if (e.key == 0) Positioned(bottom: 4, left: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: const Text('Primary', style: TextStyle(fontSize: 10, color: Colors.white)))),
                            ]
                          )),
                          if (_photos.length < 6)
                            GestureDetector(
                              onTap: _addPhoto,
                              child: Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24, style: BorderStyle.solid)),
                                child: _uploadingPhoto ? const Center(child: CircularProgressIndicator()) : const Icon(Icons.add_a_photo, color: Colors.white54),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Step 3: Session Types
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Session Types', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      SwitchListTile(
                        title: const Text('Virtual Sessions', style: TextStyle(color: Colors.white)),
                        value: _isVirtualEnabled,
                        onChanged: (v) => setState(() => _isVirtualEnabled = v),
                        activeTrackColor: const Color(0xFFFF7E40).withValues(alpha: 0.5),
                        activeThumbColor: const Color(0xFFFF7E40),
                      ),
                      if (_isVirtualEnabled) ...[
                        const Padding(padding: EdgeInsets.only(top: 16), child: Text('Hourly Rate (₹)', style: TextStyle(color: Colors.white70))),
                        Slider(value: _virtualRate, min: 0, max: 5000, divisions: 100, label: '₹${_virtualRate.toInt()}', onChanged: (v) => setState(() => _virtualRate = v)),
                        // Add min/max duration dropdowns ideally here
                      ],
                      const Divider(color: Colors.white12, height: 40),
                      SwitchListTile(
                        title: const Text('Physical Sessions', style: TextStyle(color: Colors.white)),
                        value: _isPhysicalEnabled,
                        onChanged: (v) => setState(() => _isPhysicalEnabled = v),
                        activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                        activeThumbColor: const Color(0xFF10B981),
                      ),
                      if (_isPhysicalEnabled) ...[
                        const Padding(padding: EdgeInsets.only(top: 16), child: Text('Hourly Rate (₹)', style: TextStyle(color: Colors.white70))),
                        Slider(value: _physicalRate, min: 0, max: 10000, divisions: 100, label: '₹${_physicalRate.toInt()}', onChanged: (v) => setState(() => _physicalRate = v)),
                        const Padding(padding: EdgeInsets.only(top: 16), child: Text('Travel Radius (km)', style: TextStyle(color: Colors.white70))),
                        Slider(value: _travelRadiusKm.toDouble(), min: 1, max: 100, divisions: 99, label: '${_travelRadiusKm}km', onChanged: (v) => setState(() => _travelRadiusKm = v.toInt())),
                      ],
                    ],
                  ),
                  // Step 4: Availability
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Availability', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      const Text('Active Days', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].asMap().entries.map((e) {
                          final selected = _activeDays.contains(e.key);
                          return FilterChip(
                            label: Text(e.value),
                            selected: selected,
                            onSelected: (v) => setState(() { v ? _activeDays.add(e.key) : _activeDays.remove(e.key); }),
                            selectedColor: const Color(0xFFFF7E40).withValues(alpha: 0.3),
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text('Advance Notice Required', style: TextStyle(color: Colors.white70)),
                      DropdownButton<int>(
                        value: _advanceNoticeHours,
                        dropdownColor: const Color(0xFF15151A),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: [1, 3, 12, 24, 48].map((e) => DropdownMenuItem(value: e, child: Text('$e Hours'))).toList(),
                        onChanged: (v) => setState(() => _advanceNoticeHours = v!),
                      ),
                      const SizedBox(height: 24),
                      const Text('Max Sessions Per Day', style: TextStyle(color: Colors.white70)),
                      DropdownButton<int>(
                        value: _maxSessionsPerDay,
                        dropdownColor: const Color(0xFF15151A),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: [1, 2, 3, 4, 5, 10].map((e) => DropdownMenuItem(value: e, child: Text(e == 10 ? 'Unlimited' : '$e Sessions'))).toList(),
                        onChanged: (v) => setState(() => _maxSessionsPerDay = v!),
                      ),
                    ],
                  ),
                  // Step 5: Tags
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Interests & Tags', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _allTags.map((t) {
                          final selected = _selectedTags.contains(t);
                          return FilterChip(
                            label: Text(t),
                            selected: selected,
                            onSelected: (v) => setState(() { v ? _selectedTags.add(t) : _selectedTags.remove(t); }),
                            selectedColor: const Color(0xFFFF7E40).withValues(alpha: 0.3),
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  // Step 6: Languages & Location
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Languages & Location', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      const Text('Languages', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _allLanguages.map((l) {
                          final selected = _selectedLanguages.contains(l);
                          return FilterChip(
                            label: Text(l),
                            selected: selected,
                            onSelected: (v) => setState(() { v ? _selectedLanguages.add(l) : _selectedLanguages.remove(l); }),
                            selectedColor: const Color(0xFFFF7E40).withValues(alpha: 0.3),
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(_cityCtrl, 'City', 'e.g. Mumbai'),
                      _buildTextField(_regionCtrl, 'Region/State', 'e.g. Maharashtra'),
                    ],
                  ),
                  // Step 7: Submit
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Review & Submit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      CheckboxListTile(
                        title: const Text('I agree to the Companion Code of Conduct', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('I will be respectful, punctual, and adhere to community guidelines.', style: TextStyle(color: Colors.white54)),
                        value: _agreedToConduct,
                        onChanged: (v) => setState(() => _agreedToConduct = v ?? false),
                        activeColor: const Color(0xFFFF7E40),
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 24),
                      const Text('Your application will be reviewed. ID verification is required before you appear in search results.', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _saving ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7E40),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(_step == _totalSteps - 1 ? 'Submit Application' : 'Continue', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
