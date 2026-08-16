// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'dart:convert';
import 'package:meetra_app/bolroom/bolroom_dm_chat_screen.dart';
import 'package:meetra_app/bolroom/bolroom_theme.dart';
import 'package:meetra_app/services/notification_service.dart';
import 'package:meetra_app/services/doodle_theme.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meetra_app/widgets/tiltable_hero_section.dart';
import 'bolroom_avatars.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/forward_sheet.dart';

class BolroomProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const BolroomProfileScreen({super.key, this.targetUserId});
  @override
  State<BolroomProfileScreen> createState() => _BolroomProfileScreenState();
}

class _BolroomProfileScreenState extends State<BolroomProfileScreen>
    with WidgetsBindingObserver {
  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purpleGlow = Color(0xFF8A2BE2);
  static const Color textMuted = Color(0xFF8E8B99);

  final _sb = Supabase.instance.client;
  String get _myId => _sb.auth.currentUser?.id ?? '';

  String _anonName = 'Anonymous';
  String _anonBio = '';
  String _auraColorHex = '#8A2BE2';
  String _location = 'Global';
  String? _avatarUrl;
  String? _avatarKey;
  int _roomsHosted = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  // Start as false — renders immediately with defaults, updates in-place
  bool _loading = false;
  bool _uploadingAvatar = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  bool get _isMe => widget.targetUserId == null || widget.targetUserId == _myId;
  String get _targetId => widget.targetUserId ?? _myId;

  @override
  void initState() {
    super.initState();
    // Fire both queries in parallel for maximum speed
    _loadProfile();
    _loadFollowCounts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localLoc = prefs.getString('bolroom_location') ?? 'Global';

      final bp = await _sb
          .from('bolroom_profiles')
          .select('*')
          .eq('id', _targetId)
          .maybeSingle();
      if (bp != null && mounted) {
        final String? avatarKey = bp['avatar_key'] as String?;
        setState(() {
          _anonName = bp['anon_name'] ?? 'Anonymous';
          _anonBio = bp['anon_bio'] ?? '';
          _auraColorHex = bp['aura_color'] ?? '#8A2BE2';
          _avatarUrl = bp['custom_avatar_url'];
          _avatarKey = avatarKey ?? BolroomAvatars.forUser(_targetId).id;
          _location = _isMe ? localLoc : (bp['location'] ?? 'Global');
          _roomsHosted = bp['rooms_hosted'] ?? 0;

          _loading = false;
        });
        // Persist random assignment to DB if needed
        if (avatarKey == null && _isMe) {
          _sb
              .from('bolroom_profiles')
              .update({'avatar_key': _avatarKey})
              .eq('id', _myId)
              .catchError((_) {});
        }
      } else {
        if (_isMe) {
          final assigned = BolroomAvatars.forUser(_myId);
          await _sb.from('bolroom_profiles').upsert({
            'id': _myId,
            'anon_name': 'Shadow_${_myId.substring(0, 4)}',
            'avatar_key': assigned.id,
          });
          _loadProfile();
        } else {
          setState(() => _loading = false); // User doesn't exist
        }
      }

      if (!_isMe) {
        final fCheck = await _sb
            .from('bolroom_follows')
            .select('id')
            .eq('follower_id', _myId)
            .eq('following_id', _targetId)
            .maybeSingle();
        if (mounted) setState(() => _isFollowing = fCheck != null);
      }
    } catch (e) {
      debugPrint('Load profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFollowCounts() async {
    try {
      final followers = await _sb
          .from('bolroom_follows')
          .select('id')
          .eq('following_id', _targetId);
      final following = await _sb
          .from('bolroom_follows')
          .select('id')
          .eq('follower_id', _targetId);
      if (mounted)
        setState(() {
          _followerCount = (followers as List).length;
          _followingCount = (following as List).length;
        });
    } catch (_) {}
  }

  Future<void> _updateProfile(Map<String, dynamic> data) async {
    try {
      if (data.containsKey('location')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bolroom_location', data['location']);
        data.remove('location');
      }
      if (data.isNotEmpty) {
        data['updated_at'] = DateTime.now().toUtc().toIso8601String();
        // Use upsert so if the row doesn't exist yet, it gets created
        await _sb.from('bolroom_profiles').upsert(
          {'id': _myId, ...data},
          onConflict: 'id',
        );
      }
    } catch (e) {
      debugPrint('[BolroomProfile] _updateProfile ERROR: $e');
      rethrow; // Propagate so callers can show error
    }
  }

  String _fmtNum(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  DateTime _lastVoiceMaskRefresh = DateTime(2000);

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    if (_loading)
      return Scaffold(
        backgroundColor: doodle ? DoodleColors.paper : bgColor,
        body: SafeArea(
          child: _buildProfileSkeleton(doodle),
        ),
      );

    return Scaffold(
      backgroundColor: doodle ? DoodleColors.paper : bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
              bottom: 100), // Space for bottom nav from shell
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopBar(doodle),
              const SizedBox(height: 10),
              TiltableHeroSection(
                child: Column(
                  children: [
                    _buildProfileAvatar(doodle),
                    const SizedBox(height: 16),
                    _buildProfileInfo(doodle),
                    const SizedBox(height: 24),
                    _buildStatsRow(doodle),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_isMe)
                _buildEditProfileButton(doodle)
              else
                _buildPublicActionButtons(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: _iconButton(Icons.arrow_back_ios_new_rounded, doodle),
          ),
          if (_isMe)
            GestureDetector(
              onTap: _showOptionsMenu,
              child: _iconButton(Icons.more_horiz, doodle),
            )
          else
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Report/Block menu coming soon.'))),
              child: _iconButton(Icons.more_horiz, doodle),
            ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: doodle
                      ? DoodleColors.brown.withValues(alpha: 0.5)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          _menuTile(
              Icons.auto_awesome, 'Choose Avatar', const Color(0xFF8A2BE2), () {
            Navigator.pop(context);
            _showAvatarOptionsSheet();
          }),
          _menuTile(
              Icons.send_outlined, 'Forward Profile', const Color(0xFFFF6B00),
              () {
            Navigator.pop(context);
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ForwardBottomSheet(
                    contentTitle:
                        _anonName.isNotEmpty ? _anonName : 'This Profile',
                    contentUrl: 'https://meetra.app/profile/$_myId',
                    contentImageUrl: _avatarUrl));
          }),
          _menuTile(
              Icons.palette_outlined, 'Change Aura', const Color(0xFFFFD700),
              () {
            Navigator.pop(context);
            _showAuraChangerSheet();
          }),
          _menuTile(
              Icons.block_outlined, 'Blocked Users', const Color(0xFFFF4655),
              () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No blocked users.')));
          }),
          _menuTile(Icons.logout, 'Sign Out', Colors.redAccent, () async {
            Navigator.pop(context);
            await _sb.auth.signOut();
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _menuTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final doodle = isDoodleMode(context);
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
      title: Text(label,
          style: doodle
              ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 15)
                  .copyWith(fontWeight: FontWeight.bold)
              : GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _showAvatarPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BolroomAvatarPickerSheet(
        userId: _myId,
        currentAvatarKey: _avatarKey,
        onSelected: (key) async {
          setState(() {
            _avatarKey = key;
            _avatarUrl = null; // custom avatar clears photo
          });
          await BolroomAvatars.saveAvatarKey(_myId, key);
          _showToast('Avatar updated! âœ¨');
        },
      ),
    );
  }

  void _showAvatarOptionsSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: doodle
                        ? DoodleColors.brown.withValues(alpha: 0.5)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            Text('Profile Picture',
                style: doodle
                    ? DoodleFonts.heading(
                        color: DoodleColors.brown, fontSize: 20)
                    : const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAvatarActionBtn(Icons.auto_awesome, 'Avatars', purpleGlow,
                    () async {
                  Navigator.pop(sheetContext);
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (mounted) _showAvatarPickerSheet();
                }),
                _buildAvatarActionBtn(
                    Icons.photo_library, 'Gallery', const Color(0xFFFF6B00),
                    () async {
                  Navigator.pop(sheetContext);
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (mounted) _pickAndUploadAvatar(ImageSource.gallery);
                }),
                if (_avatarUrl != null)
                  _buildAvatarActionBtn(
                      Icons.delete_outline, 'Remove', Colors.redAccent,
                      () async {
                    Navigator.pop(sheetContext);
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) _removeAvatar();
                  }),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAvatarActionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    final doodle = isDoodleMode(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: doodle
                  ? DoodleFonts.body(
                          color: DoodleColors.brown.withValues(alpha: 0.8),
                          fontSize: 12)
                      .copyWith(fontWeight: FontWeight.bold)
                  : const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) {
      debugPrint('[Avatar] User cancelled image pick');
      return;
    }

    // Let user crop their avatar
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Picture',
          toolbarColor: cardColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
          backgroundColor: bgColor,
          activeControlsWidgetColor: purpleGlow,
        ),
        IOSUiSettings(
          title: 'Adjust Profile Picture',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) {
      debugPrint('[Avatar] User cancelled crop');
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await croppedFile.readAsBytes();
      debugPrint('[Avatar] Image bytes: ${bytes.lengthInBytes}');

      // Always use .jpg for consistency and smaller size
      final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'bolroom_avatars/${_myId}_$uniqueTimestamp.jpg';

      debugPrint('[Avatar] Uploading to storage path: $path');

      // Upload to Supabase Storage
      await _sb.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      debugPrint('[Avatar] Upload complete');

      final url = _sb.storage.from('avatars').getPublicUrl(path);
      debugPrint('[Avatar] Public URL: $url');

      // Save to database via upsert
      await _updateProfile({'custom_avatar_url': url});
      debugPrint('[Avatar] DB upsert done');

      // Also clear avatar_key so the UI definitely uses the new photo
      // (prevents preset avatar rendering on top of the URL)
      await _sb
          .from('bolroom_profiles')
          .update({'avatar_key': null}).eq('id', _myId);

      // Evict CachedNetworkImage disk cache for old URL
      if (_avatarUrl != null) {
        try {
          await CachedNetworkImage.evictFromCache(_avatarUrl!);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _avatarKey = null; // force photo display, not preset avatar
          _uploadingAvatar = false;
        });
      }
      _showToast('Profile picture updated! ðŸŽ‰');
    } catch (e) {
      debugPrint('[Avatar] *** UPLOAD FAILED: $e');
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _showToast(
            'Upload failed: ${e.toString().substring(0, e.toString().length.clamp(0, 80))}');
      }
    }
  }

  // â”€â”€ Profile Skeleton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Mirrors the EXACT layout of the real profile page so there's zero
  // layout shift when data arrives. Uses a subtle shimmer animation.
  Widget _buildProfileSkeleton(bool doodle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: _SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top bar: back arrow + menu dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _skelBox(44, 44, radius: 22),
                  _skelBox(80, 22, radius: 8),
                  _skelBox(44, 44, radius: 22),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Avatar circle
            _skelBox(140, 140, radius: 70),
            const SizedBox(height: 20),
            // Username
            _skelBox(160, 22, radius: 8),
            const SizedBox(height: 10),
            // Bio line 1
            _skelBox(220, 14, radius: 6),
            const SizedBox(height: 6),
            // Bio line 2
            _skelBox(160, 14, radius: 6),
            const SizedBox(height: 16),
            // Aura badge
            _skelBox(100, 32, radius: 16),
            const SizedBox(height: 28),
            // Stats row: 3 cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _skelBox(100, 72, radius: 16),
                  _skelBox(100, 72, radius: 16),
                  _skelBox(100, 72, radius: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Edit Profile / action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: _skelBox(double.infinity, 52, radius: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skelBox(double w, double h, {double radius = 8}) {
    return Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Future<void> _removeAvatar() async {
    Navigator.pop(context); // Close sheet
    setState(() => _uploadingAvatar = true);
    try {
      // We don't necessarily need to delete the file, just remove the reference
      await _updateProfile({'custom_avatar_url': null});
      if (mounted)
        setState(() {
          _avatarUrl = null;
          _uploadingAvatar = false;
        });
      _showToast('Profile picture removed.');
    } catch (e) {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: cardColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: purpleGlow.withValues(alpha: 0.3))),
    ));
  }

  Widget _iconButton(IconData icon, bool doodle) {
    return Container(
      width: 44,
      height: 44,
      decoration: doodle
          ? DoodleDecorations.card()
          : BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
      child: Icon(icon,
          color: doodle ? DoodleColors.brown : Colors.white, size: 20),
    );
  }

  Widget _buildProfileAvatar(bool doodle) {
    return GestureDetector(
      onTap: _isMe ? _showAvatarOptionsSheet : null,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _uploadingAvatar
              ? Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: cardColor),
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: purpleGlow, strokeWidth: 2)),
                )
              : BolroomAvatarWidget(
                  size: 140,
                  avatarUrl: _avatarUrl,
                  avatarKey: _avatarKey,
                  userId: _targetId,
                  showRing: !doodle,
                  auraOverride: _auraColorHex.isNotEmpty
                      ? Color(int.parse(_auraColorHex.replaceAll('#', '0xFF')))
                      : null,
                ),
          // Edit badge
          if (_isMe)
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: doodle ? DoodleColors.paper : bgColor,
                    shape: BoxShape.circle),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color:
                          doodle ? DoodleColors.brown : const Color(0xFF7B2CBF),
                      shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome,
                      color: doodle ? DoodleColors.cream : Colors.white,
                      size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(bool doodle) {
    int auraLevel = ((_roomsHosted * 2 + _followerCount) ~/ 10) + 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '@$_anonName',
              style: doodle
                  ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 26)
                  : const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.verified,
                color: doodle ? DoodleColors.blue : const Color(0xFF7B2CBF),
                size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _anonBio.isNotEmpty
              ? '"$_anonBio"'
              : '"Whisperer of midnight thoughts. Anonymous since 2024."',
          style: doodle
              ? DoodleFonts.body(
                  color: DoodleColors.brown.withValues(alpha: 0.8),
                  fontSize: 16)
              : const TextStyle(
                  color: textMuted,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Aura Level Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: doodle
              ? BoxDecoration(
                  color: DoodleColors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DoodleColors.orange),
                )
              : BoxDecoration(
                  color: BolroomTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: BolroomTheme.gold.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: BolroomTheme.gold.withValues(alpha: 0.1),
                        blurRadius: 10),
                  ],
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded,
                  color: doodle ? DoodleColors.orange : BolroomTheme.gold,
                  size: 16),
              const SizedBox(width: 6),
              Text(
                'Lv. $auraLevel Aura',
                style: doodle
                    ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 14)
                        .copyWith(fontWeight: FontWeight.bold)
                    : const TextStyle(
                        color: BolroomTheme.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
              ),
            ],
          ),
        )
            .animate()
            .scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildStatsRow(bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            _fmtNum(_followerCount),
            'Followers',
            Icons.people_alt_outlined,
            const [Color(0xFFD433FF), Color(0xFF7B2CBF)],
            doodle,
            onTap: () => _showFollowListSheet('Followers'),
          ),
          _buildStatCard(
            _fmtNum(_followingCount),
            'Following',
            Icons.person_outline,
            const [Color(0xFFFFD700), Color(0xFFFF8C00)],
            doodle,
            onTap: () => _showFollowListSheet('Following'),
          ),
          _buildStatCard(
            _fmtNum(_roomsHosted),
            'Rooms Hosted',
            Icons.local_fire_department_outlined,
            const [Color(0xFFFF6B00), Color(0xFF1E90FF)],
            doodle,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon,
      List<Color> gradientColors, bool doodle,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: doodle
              ? DoodleDecorations.card(color: DoodleColors.paper)
              : BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
          child: Column(
            children: [
              if (doodle)
                Text(value,
                    style: DoodleFonts.heading(
                        color: DoodleColors.brown, fontSize: 24))
              else
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: doodle
                          ? DoodleColors.brown.withValues(alpha: 0.5)
                          : textMuted,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: doodle
                        ? DoodleFonts.body(
                            color: DoodleColors.brown.withValues(alpha: 0.8),
                            fontSize: 12)
                        : const TextStyle(
                            color: textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditProfileButton(bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _showEditProfile,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: doodle
              ? DoodleDecorations.card(color: DoodleColors.paper)
              : BoxDecoration(
                  color: const Color(0xFF1A132F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3B2768)),
                ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_outlined,
                  color: doodle ? DoodleColors.blue : const Color(0xFFB983FF),
                  size: 18),
              const SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: doodle
                    ? DoodleFonts.heading(
                        color: DoodleColors.blue, fontSize: 16)
                    : const TextStyle(
                        color: Color(0xFFB983FF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _toggleFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 50,
                decoration: BoxDecoration(
                  color: _isFollowing ? const Color(0xFF1A132F) : purpleGlow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _isFollowing
                          ? const Color(0xFF3B2768)
                          : Colors.transparent),
                  boxShadow: _isFollowing
                      ? []
                      : [
                          BoxShadow(
                              color: purpleGlow.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 1)
                        ],
                ),
                child: _isFollowLoading
                    ? const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              _isFollowing
                                  ? Icons.person_remove_rounded
                                  : Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isFollowing ? 'Unfollow' : 'Follow',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _navigateToChat,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: const Color(0xFFFF6B00), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Message',
                      style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToChat() async {
    if (_targetId.isEmpty || _myId.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Error: Invalid user session or profile (Missing ID).'),
            backgroundColor: Colors.redAccent));
      return;
    }
    try {
      final existing = await _sb
          .from('bolroom_dm_conversations')
          .select('*')
          .or('and(user1_id.eq.$_myId,user2_id.eq.$_targetId),and(user1_id.eq.$_targetId,user2_id.eq.$_myId)')
          .maybeSingle();

      String convId;
      if (existing != null) {
        convId = existing['id'].toString();
      } else {
        final newConvo = await _sb
            .from('bolroom_dm_conversations')
            .insert({
              'user1_id': _myId,
              'user2_id': _targetId,
            })
            .select()
            .single();
        convId = newConvo['id'].toString();
      }

      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BolroomDmChatScreen(
                    conversationId: convId,
                    partnerId: _targetId,
                    partnerName: _anonName,
                    partnerAvatarKey: _avatarUrl ?? 'default',
                  )));
    } catch (e) {
      debugPrint('Start/Navigate to chat error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open chat: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_targetId.isEmpty || _myId.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Error: Invalid user session or profile (Missing ID).'),
            backgroundColor: Colors.redAccent));
      return;
    }
    if (_isFollowLoading) return;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });
    try {
      if (!_isFollowing) {
        // Previously it was following, now we deleted it
        await _sb
            .from('bolroom_follows')
            .delete()
            .eq('follower_id', _myId)
            .eq('following_id', _targetId);
      } else {
        await _sb
            .from('bolroom_follows')
            .insert({'follower_id': _myId, 'following_id': _targetId});

        // Notify both users
        try {
          final me = await _sb
              .from('bolroom_profiles')
              .select('anon_name')
              .eq('id', _myId)
              .maybeSingle();
          final myName = me?['anon_name'] ?? 'Anonymous';

          await NotificationService.sendNotification(
            userId: _targetId,
            type: NotificationType.message,
            title: 'BolRoom New Follower',
            body: '@$myName started following you in the ecosystem!',
            payload: {'source': 'bolroom', 'follower_id': _myId},
          );
          await NotificationService.sendNotification(
            userId: _myId,
            type: NotificationType.message,
            title: 'BolRoom Following',
            body: 'You are now following @$_anonName!',
            payload: {'source': 'bolroom', 'following_id': _targetId},
          );
        } catch (e) {
          debugPrint('Notification error: $e');
        }
      }
    } catch (e) {
      debugPrint('Follow error: $e');
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _followerCount += _isFollowing ? 1 : -1;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Widget _buildSectionHeader(String title, String action, bool doodle,
      {VoidCallback? onActionTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: doodle
                ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18)
                : const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          GestureDetector(
            onTap: onActionTap,
            child: Row(
              children: [
                Text(
                  action,
                  style: doodle
                      ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 14)
                      : const TextStyle(
                          color: Color(0xFFB983FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                ),
                Icon(Icons.chevron_right,
                    color: doodle ? DoodleColors.blue : const Color(0xFFB983FF),
                    size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAuraChangerSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Shift Aura Signature",
                  style: doodle
                      ? DoodleFonts.heading(
                          color: DoodleColors.brown, fontSize: 18)
                      : const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildColorChanger(
                      const Color(0xFF8A2BE2), '#8A2BE2', setSheetState),
                  _buildColorChanger(
                      const Color(0xFFFF6B00), '#00E5FF', setSheetState),
                  _buildColorChanger(
                      const Color(0xFFFF4655), '#FF4655', setSheetState),
                  _buildColorChanger(
                      const Color(0xFFFFD700), '#FFD700', setSheetState),
                  _buildColorChanger(
                      const Color(0xFF00FF00), '#00FF00', setSheetState),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                  "Changes made here reflect instantly across\nEchoes, Hubs, and DMs.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 12)),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildColorChanger(
      Color color, String hex, StateSetter setSheetState) {
    bool isSelected = _auraColorHex.toUpperCase() == hex.toUpperCase();
    return GestureDetector(
      onTap: () {
        setState(() => _auraColorHex = hex);
        setSheetState(() {});
        _updateProfile({'aura_color': hex});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2)
                ]
              : null,
        ),
      ),
    );
  }

  void _showFollowListSheet(String type) {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _FollowListSheet(
        targetId: _targetId,
        type: type,
        onProfileTap: (uid) {
          Navigator.pop(ctx);
          if (uid != _targetId) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BolroomProfileScreen(targetUserId: uid)));
          }
        },
      ),
    );
  }

  void _showEditProfile() {
    final doodle = isDoodleMode(context);
    final nameCtrl = TextEditingController(text: _anonName);
    final bioCtrl = TextEditingController(text: _anonBio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: doodle
            ? BoxDecoration(
                color: DoodleColors.paper,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: DoodleColors.brown, width: 2))
            : BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor)),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 24),
              Text('Edit Profile',
                  style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 20),
              Text('ANONYMOUS NAME',
                  style: GoogleFonts.inter(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              SizedBox(height: 8),
              TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: cardColor,
                      hintText: 'Enter name...',
                      hintStyle:
                          TextStyle(color: textMuted.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none))),
              SizedBox(height: 16),
              Text('BIO',
                  style: GoogleFonts.inter(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              SizedBox(height: 8),
              TextField(
                  controller: bioCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: cardColor,
                      hintText: 'Tell them about your shadow...',
                      hintStyle:
                          TextStyle(color: textMuted.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none))),
              SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final bio = bioCtrl.text.trim();
                      if (name.isNotEmpty) {
                        await _updateProfile(
                            {'anon_name': name, 'anon_bio': bio});
                        setState(() {
                          _anonName = name;
                          _anonBio = bio;
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: purpleGlow,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0),
                    child: Text('Save Changes',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  )),
            ]),
      ),
    );
  }

  final Map<String, List<String>> _indiaLocations = {
    // 28 States
    'Andhra Pradesh': [
      'Visakhapatnam',
      'Vijayawada',
      'Guntur',
      'Nellore',
      'Kurnool',
      'Tirupati',
      'Kakinada',
      'Kadapa',
      'Anantapur',
      'Rajahmundry',
      'Eluru',
      'Ongole',
      'Machilipatnam',
      'Chittoor'
    ],
    'Arunachal Pradesh': [
      'Itanagar',
      'Tawang',
      'Naharlagun',
      'Pasighat',
      'Ziro',
      'Tezu',
      'Bomdila',
      'Aalo',
      'Roing'
    ],
    'Assam': [
      'Guwahati',
      'Silchar',
      'Dibrugarh',
      'Jorhat',
      'Nagaon',
      'Tinsukia',
      'Tezpur',
      'Bongaigaon',
      'Karimganj',
      'Diphu',
      'Sivasagar',
      'Goalpara',
      'Barpeta',
      'Dhubri'
    ],
    'Bihar': [
      'Patna',
      'Gaya',
      'Bhagalpur',
      'Muzaffarpur',
      'Purnia',
      'Darbhanga',
      'Ara',
      'Begusarai',
      'Katihar',
      'Munger',
      'Chhapra',
      'Saharsa',
      'Hajipur',
      'Sasaram',
      'Bettiah',
      'Motihari'
    ],
    'Chhattisgarh': [
      'Raipur',
      'Bhilai',
      'Bilaspur',
      'Korba',
      'Rajnandgaon',
      'Raigarh',
      'Jagdalpur',
      'Ambikapur',
      'Dhamtari',
      'Mahasamund',
      'Durg',
      'Chirmiri'
    ],
    'Goa': [
      'Panaji',
      'Vasco da Gama',
      'Margao',
      'Mapusa',
      'Ponda',
      'Bicholim',
      'Curchorem',
      'Sanquelim',
      'Cuncolim'
    ],
    'Gujarat': [
      'Ahmedabad',
      'Surat',
      'Vadodara',
      'Rajkot',
      'Bhavnagar',
      'Jamnagar',
      'Junagadh',
      'Gandhinagar',
      'Anand',
      'Navsari',
      'Morbi',
      'Nadiad',
      'Bharuch',
      'Porbandar',
      'Mehsana',
      'Bhuj'
    ],
    'Haryana': [
      'Gurugram',
      'Faridabad',
      'Panipat',
      'Ambala',
      'Rohtak',
      'Hisar',
      'Karnal',
      'Sonipat',
      'Panchkula',
      'Yamunanagar',
      'Bhiwani',
      'Sirsa',
      'Bahadurgarh',
      'Kurukshetra',
      'Jind',
      'Kaithal'
    ],
    'Himachal Pradesh': [
      'Shimla',
      'Dharamshala',
      'Mandi',
      'Solan',
      'Kullu',
      'Palampur',
      'Chamba',
      'Nahan',
      'Una',
      'Bilaspur',
      'Hamirpur',
      'Manali'
    ],
    'Jharkhand': [
      'Ranchi',
      'Jamshedpur',
      'Dhanbad',
      'Bokaro',
      'Deoghar',
      'Hazaribagh',
      'Phusro',
      'Giridih',
      'Ramgarh',
      'Medininagar',
      'Chirkunda',
      'Dumka'
    ],
    'Karnataka': [
      'Bengaluru',
      'Mysuru',
      'Mangaluru',
      'Hubballi',
      'Belagavi',
      'Davangere',
      'Ballari',
      'Kalaburagi',
      'Shivamogga',
      'Tumakuru',
      'Raichur',
      'Bidar',
      'Hospet',
      'Gadag',
      'Hassan',
      'Udupi',
      'Kolar'
    ],
    'Kerala': [
      'Thiruvananthapuram',
      'Kochi',
      'Kozhikode',
      'Thrissur',
      'Kollam',
      'Alappuzha',
      'Palakkad',
      'Kannur',
      'Kottayam',
      'Manjeri',
      'Thalassery',
      'Ponnani',
      'Kasaragod',
      'Pathanamthitta'
    ],
    'Madhya Pradesh': [
      'Bhopal',
      'Indore',
      'Gwalior',
      'Jabalpur',
      'Ujjain',
      'Sagar',
      'Dewas',
      'Satna',
      'Ratlam',
      'Rewa',
      'Murwara',
      'Singrauli',
      'Burhanpur',
      'Khandwa',
      'Morena',
      'Bhind',
      'Chhindwara',
      'Guna'
    ],
    'Maharashtra': [
      'Mumbai',
      'Pune',
      'Nagpur',
      'Nashik',
      'Aurangabad',
      'Solapur',
      'Amravati',
      'Nanded',
      'Kolhapur',
      'Akola',
      'Jalgaon',
      'Latur',
      'Dhule',
      'Ahmednagar',
      'Chandrapur',
      'Parbhani',
      'Thane',
      'Kalyan-Dombivli',
      'Navi Mumbai',
      'Vasai-Virar'
    ],
    'Manipur': [
      'Imphal',
      'Thoubal',
      'Kakching',
      'Churachandpur',
      'Bishnupur',
      'Ukhrul',
      'Jiribam',
      'Senapati'
    ],
    'Meghalaya': [
      'Shillong',
      'Tura',
      'Nongstoin',
      'Jowai',
      'Williamnagar',
      'Baghmara',
      'Resubelpara'
    ],
    'Mizoram': [
      'Aizawl',
      'Lunglei',
      'Saiha',
      'Champhai',
      'Kolasib',
      'Serchhip',
      'Lawngtlai'
    ],
    'Nagaland': [
      'Kohima',
      'Dimapur',
      'Mokokchung',
      'Tuensang',
      'Wokha',
      'Zunheboto',
      'Kiphire',
      'Phek'
    ],
    'Odisha': [
      'Bhubaneswar',
      'Cuttack',
      'Rourkela',
      'Brahmapur',
      'Sambalpur',
      'Puri',
      'Balasore',
      'Bhadrak',
      'Baripada',
      'Jharsuguda',
      'Bargarh',
      'Rayagada',
      'Koraput',
      'Angul'
    ],
    'Punjab': [
      'Ludhiana',
      'Amritsar',
      'Jalandhar',
      'Patiala',
      'Bathinda',
      'Hoshiarpur',
      'Mohali',
      'Batala',
      'Pathankot',
      'Moga',
      'Abohar',
      'Malerkotla',
      'Khanna',
      'Phagwara',
      'Muktsar',
      'Faridkot'
    ],
    'Rajasthan': [
      'Jaipur',
      'Jodhpur',
      'Udaipur',
      'Kota',
      'Bikaner',
      'Ajmer',
      'Bhilwara',
      'Alwar',
      'Bharatpur',
      'Sikar',
      'Pali',
      'Sri Ganganagar',
      'Kishangarh',
      'Baran',
      'Tonk',
      'Hanumangarh',
      'Beawar'
    ],
    'Sikkim': [
      'Gangtok',
      'Namchi',
      'Gyalshing',
      'Mangan',
      'Singtam',
      'Rangpo',
      'Jorethang'
    ],
    'Tamil Nadu': [
      'Chennai',
      'Coimbatore',
      'Madurai',
      'Tiruchirappalli',
      'Salem',
      'Tirunelveli',
      'Tiruppur',
      'Erode',
      'Vellore',
      'Thoothukudi',
      'Dindigul',
      'Thanjavur',
      'Ranipet',
      'Sivakasi',
      'Karur',
      'Ooty',
      'Hosur',
      'Nagercoil',
      'Kanchipuram'
    ],
    'Telangana': [
      'Hyderabad',
      'Warangal',
      'Nizamabad',
      'Karimnagar',
      'Khammam',
      'Ramagundam',
      'Mahbubnagar',
      'Nalgonda',
      'Adilabad',
      'Suryapet',
      'Miryalaguda',
      'Jagtial'
    ],
    'Tripura': [
      'Agartala',
      'Udaipur',
      'Dharmanagar',
      'Kailashahar',
      'Belonia',
      'Khowai',
      'Bishalgarh',
      'Ambassa'
    ],
    'Uttar Pradesh': [
      'Lucknow',
      'Kanpur',
      'Ghaziabad',
      'Agra',
      'Varanasi',
      'Meerut',
      'Prayagraj',
      'Bareilly',
      'Aligarh',
      'Moradabad',
      'Saharanpur',
      'Gorakhpur',
      'Noida',
      'Firozabad',
      'Jhansi',
      'Muzaffarnagar',
      'Mathura',
      'Ayodhya',
      'Rampur',
      'Shahjahanpur'
    ],
    'Uttarakhand': [
      'Dehradun',
      'Haridwar',
      'Roorkee',
      'Haldwani',
      'Rudrapur',
      'Kashipur',
      'Rishikesh',
      'Mussoorie',
      'Nainital',
      'Almora',
      'Pithoragarh'
    ],
    'West Bengal': [
      'Kolkata',
      'Howrah',
      'Darjeeling',
      'Siliguri',
      'Asansol',
      'Durgapur',
      'Bardhaman',
      'English Bazar',
      'Baharampur',
      'Habra',
      'Kharagpur',
      'Shantipur',
      'Dankuni',
      'Haldia',
      'Jalpaiguri',
      'Kalyani',
      'Raiganj'
    ],

    // 8 Union Territories
    'Andaman and Nicobar Islands': [
      'Port Blair',
      'Garacharma',
      'Bambooflat',
      'Prothrapur'
    ],
    'Chandigarh': ['Chandigarh'],
    'Dadra and Nagar Haveli and Daman and Diu': [
      'Daman',
      'Diu',
      'Silvassa',
      'Amli'
    ],
    'Delhi': [
      'New Delhi',
      'North Delhi',
      'South Delhi',
      'East Delhi',
      'West Delhi',
      'Central Delhi',
      'Shahdara',
      'Rohini',
      'Dwarka',
      'Chanakyapuri',
      'Connaught Place'
    ],
    'Jammu and Kashmir': [
      'Srinagar',
      'Jammu',
      'Anantnag',
      'Baramulla',
      'Kathua',
      'Sopore',
      'Bandipora',
      'Poonch',
      'Kupwara',
      'Udhampur',
      'Pulwama'
    ],
    'Ladakh': ['Leh', 'Kargil'],
    'Lakshadweep': ['Kavaratti', 'Minicoy', 'Andrott', 'Amini', 'Agatti'],
    'Puducherry': ['Puducherry', 'Ozhukarai', 'Karaikal', 'Yanam', 'Mahe']
  };

  void _showLocationSheet() {
    final doodle = isDoodleMode(context);
    String searchQuery = '';
    String? selectedState;
    bool isFetching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<String> displayItems = [];

          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            _indiaLocations.forEach((state, cities) {
              if (state.toLowerCase().contains(query) &&
                  !displayItems.contains(state)) displayItems.add(state);
              for (var city in cities) {
                if (city.toLowerCase().contains(query) &&
                    !displayItems.contains(city)) displayItems.add(city);
              }
            });
          } else if (selectedState != null) {
            displayItems = [
              'All of $selectedState',
              ...(_indiaLocations[selectedState] ?? [])
            ];
          } else {
            displayItems = _indiaLocations.keys.toList();
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (selectedState != null && searchQuery.isEmpty)
                      GestureDetector(
                        onTap: () => setSheetState(() => selectedState = null),
                        child:
                            const Icon(Icons.arrow_back, color: Colors.white),
                      )
                    else
                      const Icon(Icons.location_on, color: Color(0xFFFFB347)),
                    Text(
                      selectedState != null && searchQuery.isEmpty
                          ? selectedState!
                          : 'Broadcast Region',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _location = 'Global');
                        _updateProfile({'location': 'Global'});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Global',
                          style: TextStyle(
                              color: textMuted, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Current Location Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Profile Location',
                              style: TextStyle(color: textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_location,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          setSheetState(() => isFetching = true);
                          try {
                            bool serviceEnabled =
                                await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) throw 'Location disabled';
                            LocationPermission permission =
                                await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied)
                                throw 'Permission denied';
                            }
                            final pos = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                    accuracy: LocationAccuracy.low,
                                    timeLimit: Duration(seconds: 10)));
                            final res = await http.get(
                              Uri.parse(
                                  'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&addressdetails=1'),
                              headers: {'User-Agent': 'MeetraApp/1.0'},
                            ).timeout(const Duration(seconds: 8));
                            if (res.statusCode == 200) {
                              final data = jsonDecode(res.body);
                              final address = data['address'] ?? {};
                              final city = address['city'] ??
                                  address['town'] ??
                                  address['village'] ??
                                  address['hamlet'] ??
                                  '';
                              final state = address['state'] ?? '';
                              String locStr = [city, state]
                                  .where((e) => e.toString().trim().isNotEmpty)
                                  .join(', ');
                              if (locStr.isNotEmpty) {
                                setState(() => _location = locStr);
                                await _updateProfile({'location': locStr});
                                if (mounted) Navigator.pop(ctx);
                              }
                            }
                          } catch (e) {
                            debugPrint('Auto-fetch error: $e');
                          }
                          if (mounted) setSheetState(() => isFetching = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFB347).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isFetching
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFFFB347), strokeWidth: 2))
                              : const Row(
                                  children: [
                                    Icon(Icons.my_location,
                                        color: Color(0xFFFFB347), size: 14),
                                    SizedBox(width: 4),
                                    Text('Auto-Fetch',
                                        style: TextStyle(
                                            color: Color(0xFFFFB347),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => setSheetState(() => searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search State or City...',
                    hintStyle: const TextStyle(color: textMuted),
                    filled: true,
                    fillColor: bgColor,
                    prefixIcon: const Icon(Icons.search, color: textMuted),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: displayItems.length,
                    itemBuilder: (ctx, i) {
                      final item = displayItems[i];
                      final isState = _indiaLocations.containsKey(item);
                      final isAll = item.startsWith('All of ');
                      return ListTile(
                        title: Text(item,
                            style: TextStyle(
                                color: isAll
                                    ? const Color(0xFFFFB347)
                                    : Colors.white,
                                fontWeight: isAll
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        trailing: (isState && searchQuery.isEmpty)
                            ? const Icon(Icons.chevron_right, color: textMuted)
                            : null,
                        onTap: () {
                          String finalLoc = item;
                          if (isAll) finalLoc = selectedState!;

                          if (isAll) {
                            setState(() => _location = finalLoc);
                            _updateProfile({'location': finalLoc});
                            Navigator.pop(ctx);
                          } else if (isState && searchQuery.isEmpty) {
                            setSheetState(() => selectedState = item);
                          } else {
                            setState(() => _location = finalLoc);
                            _updateProfile({'location': finalLoc});
                            Navigator.pop(ctx);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FollowListSheet extends StatefulWidget {
  final String targetId;
  final String type; // 'Followers' or 'Following'
  final Function(String) onProfileTap;

  const _FollowListSheet(
      {required this.targetId, required this.type, required this.onProfileTap});

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  Set<String> _myFollowings = {};
  // Start as false — renders immediately with defaults, updates in-place
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final myId = _sb.auth.currentUser?.id ?? '';
      if (myId.isNotEmpty) {
        final myFollowingData = await _sb
            .from('bolroom_follows')
            .select('following_id')
            .eq('follower_id', myId);
        _myFollowings = (myFollowingData as List)
            .map((e) => e['following_id'].toString())
            .toSet();
      }

      final isFollowers = widget.type == 'Followers';
      final matchCol = isFollowers ? 'following_id' : 'follower_id';
      final fetchCol = isFollowers ? 'follower_id' : 'following_id';

      final List<dynamic> rels = await _sb
          .from('bolroom_follows')
          .select(fetchCol)
          .eq(matchCol, widget.targetId);

      if (rels.isEmpty) {
        if (mounted)
          setState(() {
            _loading = false;
          });
        return;
      }

      final ids = rels.map((e) => e[fetchCol].toString()).toList();
      final profiles =
          await _sb.from('bolroom_profiles').select('*').inFilter('id', ids);

      if (mounted)
        setState(() {
          _users = List<Map<String, dynamic>>.from(profiles);
          _loading = false;
        });
    } catch (e) {
      debugPrint('Error fetching ${widget.type}: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollowUser(String uid, String userName) async {
    final myId = _sb.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;

    final isFollowing = _myFollowings.contains(uid);
    setState(() {
      if (isFollowing) {
        _myFollowings.remove(uid);
      } else {
        _myFollowings.add(uid);
      }
    });

    try {
      if (isFollowing) {
        await _sb
            .from('bolroom_follows')
            .delete()
            .eq('follower_id', myId)
            .eq('following_id', uid);
      } else {
        await _sb
            .from('bolroom_follows')
            .insert({'follower_id': myId, 'following_id': uid});
        final me = await _sb
            .from('bolroom_profiles')
            .select('anon_name')
            .eq('id', myId)
            .maybeSingle();
        final myName = me?['anon_name'] ?? 'Anonymous';
        await NotificationService.sendNotification(
          userId: uid,
          type: NotificationType.message,
          title: 'BolRoom New Follower',
          body: '@$myName started following you in the ecosystem!',
          payload: {'source': 'bolroom', 'follower_id': myId},
        );
      }
    } catch (e) {
      setState(() {
        if (isFollowing) {
          _myFollowings.add(uid);
        } else {
          _myFollowings.remove(uid);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(widget.type,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF8A2BE2), strokeWidth: 2))
                  : _users.isEmpty
                      ? Center(
                          child: Text('No ${widget.type.toLowerCase()} yet.',
                              style: const TextStyle(
                                  color: Color(0xFF8E8B99), fontSize: 16)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            final Color aura = Color(int.tryParse(
                                    'FF${(u['aura_color'] ?? '#8A2BE2').replaceFirst('#', '')}') ??
                                0xFF8A2BE2);
                            final uid = u['id']?.toString() ?? '';
                            final isMe =
                                uid == (_sb.auth.currentUser?.id ?? '');
                            final isFollowing = _myFollowings.contains(uid);

                            Widget trailingAction = const SizedBox.shrink();
                            if (!isMe) {
                              trailingAction = GestureDetector(
                                onTap: () => _toggleFollowUser(
                                    uid, u['anon_name'] ?? 'User'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isFollowing
                                        ? Colors.transparent
                                        : const Color(0xFF1E90FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isFollowing
                                            ? Colors.white38
                                            : Colors.transparent),
                                  ),
                                  child: Text(
                                    isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(
                                      color: isFollowing
                                          ? Colors.white
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              leading: GestureDetector(
                                onTap: () => widget.onProfileTap(uid),
                                child: BolroomAvatarWidget(
                                  size: 50,
                                  avatarUrl: u['custom_avatar_url']?.toString(),
                                  avatarKey: u['avatar_key']?.toString(),
                                  userId: uid,
                                  showRing: true,
                                ),
                              ),
                              title: GestureDetector(
                                  onTap: () => widget.onProfileTap(uid),
                                  child: Text(u['anon_name'] ?? 'User',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600))),
                              subtitle: Text(u['location'] ?? 'Global',
                                  style: const TextStyle(
                                      color: Color(0xFF8E8B99), fontSize: 13)),
                              trailing: trailingAction,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------------------
// Shimmer wrapper — sweeps a highlight across children.
// Pure Flutter, no extra packages needed.
// ------------------------------------------------------------------------------
class _SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const _SkeletonShimmer({required this.child});
  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.5, 1.0],
            colors: const [
              Color(0x0DFFFFFF),
              Color(0x33FFFFFF),
              Color(0x0DFFFFFF),
            ],
            transform: _SlidingGradientTransform(slidePercent: 0),
          ).createShader(bounds),
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}
