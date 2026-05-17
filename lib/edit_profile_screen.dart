import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_upload_service.dart';

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
  
  String? _avatarUrl;
  String _gender = '';
  Set<String> _interests = {};
  Set<String> _purposes = {};
  bool _isPublic = true;

  final List<String> _vibeOptions = [
    'Music', 'Tech', 'Fitness', 'Study', 'Art', 'Travel', 'Food', 'Sports', 'Photography', 'Dance', 'Gaming', 'Reading'
  ];
  
  final List<String> _purposeOptions = [
    'Meet New People', 'Find Activity Partners', 'Professional Networking', 'Study Groups', 'Travel Companions', 'Gaming Squad'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p['name'] ?? p['full_name'] ?? '');
    _userCtrl = TextEditingController(text: p['username'] ?? '');
    _bioCtrl = TextEditingController(text: p['bio'] ?? '');
    _cityCtrl = TextEditingController(text: p['city'] ?? '');
    _avatarUrl = p['avatar_url'];
    _gender = p['gender'] ?? '';
    _isPublic = p['is_public'] ?? true;
    
    if (p['interests'] is List) {
      _interests = Set<String>.from((p['interests'] as List).map((e) => e.toString()));
    }
    if (p['looking_for'] is List) {
      _purposes = Set<String>.from((p['looking_for'] as List).map((e) => e.toString()));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final url = await ImageUploadService.pickAndUpload(context: context, folder: 'avatars');
    if (url != null) {
      setState(() => _avatarUrl = url);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = _sb.auth.currentUser!.id;
      await _sb.from('profiles').update({
        'name': _nameCtrl.text.trim(),
        'full_name': _nameCtrl.text.trim(),
        'username': _userCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'avatar_url': _avatarUrl,
        'gender': _gender,
        'interests': _interests.toList(),
        'looking_for': _purposes.toList(),
        'is_public': _isPublic,
      }).eq('id', uid);

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

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0F);
    const cyan = Color(0xFF00E5CC);
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

            _buildLabel('Location'),
            _buildField(_cityCtrl, 'City, State'),
            const SizedBox(height: 16),

            _buildLabel('Gender'),
            _buildGenderSelector(),
            const SizedBox(height: 24),

            _buildLabel('Vibes (Interests)'),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _vibeOptions.map((v) => _buildChip(v, _interests.contains(v), () {
                setState(() {
                  if (_interests.contains(v)) {
                    _interests.remove(v);
                  } else {
                    _interests.add(v);
                  }
                });
              })).toList(),
            ),
            const SizedBox(height: 24),

            _buildLabel('Looking For'),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _purposeOptions.map((p) => _buildChip(p, _purposes.contains(p), () {
                setState(() {
                  if (_purposes.contains(p)) {
                    _purposes.remove(p);
                  } else {
                    _purposes.add(p);
                  }
                });
              })).toList(),
            ),
            const SizedBox(height: 24),

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
              color: _gender == g ? const Color(0xFF00E5CC).withValues(alpha: 0.1) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gender == g ? const Color(0xFF00E5CC) : Colors.white.withValues(alpha: 0.05)),
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
          color: selected ? const Color(0xFF00E5CC).withValues(alpha: 0.1) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF00E5CC) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? Colors.white : const Color(0xFF94A3B8), fontSize: 13)),
      ),
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
