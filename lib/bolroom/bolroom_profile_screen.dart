// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:meetra_app/bolroom/bolroom_dm_chat_screen.dart';
import 'package:meetra_app/bolroom/bolroom_theme.dart';
import 'package:meetra_app/services/notification_service.dart';
import 'package:meetra_app/services/doodle_theme.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meetra_app/services/voice_mask_service.dart';
import 'package:meetra_app/widgets/tiltable_hero_section.dart';
import 'package:meetra_app/bolroom/bolroom_avatars.dart';

class BolroomProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const BolroomProfileScreen({super.key, this.targetUserId});
  @override
  State<BolroomProfileScreen> createState() => _BolroomProfileScreenState();
}

class _BolroomProfileScreenState extends State<BolroomProfileScreen> with WidgetsBindingObserver {
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
  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isRecordingTest = false;
  bool _isPlayingTest = false;
  bool _hasRecording = false;
  Timer? _testTimer;
  int _testSecondsLeft = 0;
  StreamSubscription<Uint8List>? _pcmSub;
  final List<int> _recordedBytes = [];
  RealtimeChannel? _profileChannel;

  bool get _isMe => widget.targetUserId == null || widget.targetUserId == _myId;
  String get _targetId => widget.targetUserId ?? _myId;

  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  final _voiceMaskService = VoiceMaskService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _loadProfile();
    _loadFollowCounts();
    _subscribeProfileRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isMe) {
      _refreshVoiceMaskState();
    }
  }

  // Timestamp of last LOCAL user action - realtime updates within 1.5 s are ignored
  // to prevent the DB-write roundtrip from flipping the toggle back.
  DateTime _localActionTime = DateTime(2000);
  bool get _isWithinLocalActionDebounce =>
      DateTime.now().difference(_localActionTime).inMilliseconds < 5000;

  /// Re-read just the voice mask fields from DB so we stay synced
  /// with changes made from the live voice room.
  Future<void> _refreshVoiceMaskState() async {
    if (!_isMe) return;
    if (_isWithinLocalActionDebounce) return; // user just acted - skip
    try {
      final bp = await _sb.from('bolroom_profiles')
          .select('voice_mask_enabled, voice_mask_preset, voice_pitch, voice_formant')
          .eq('id', _myId)
          .maybeSingle();
      if (bp != null && mounted && !_isWithinLocalActionDebounce) {
        final dbEnabled = bp['voice_mask_enabled'] == true;
        final dbPreset = (bp['voice_mask_preset'] ?? 'ghost').toString();
        final dbPitch = (bp['voice_pitch'] ?? 0.5).toDouble();
        final dbFormant = (bp['voice_formant'] ?? 0.0).toDouble();
        if (dbEnabled != _voiceMaskEnabled || dbPreset != _voiceMaskPreset || dbPitch != _voicePitch) {
          setState(() {
            _voiceMaskEnabled = dbEnabled;
            _voiceMaskPreset = dbPreset;
            _voicePitch = dbPitch;
            _voiceFormant = dbFormant;
            _isEditingVoiceMask = false;
          });
        }
      }
    } catch (_) {}
  }

  void _subscribeProfileRealtime() {
    if (!_isMe) return;
    _profileChannel = _sb.channel('bp_profile_voicemask_$_myId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'bolroom_profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: _myId,
      ),
      callback: (payload) {
        if (!mounted) return;
        // Ignore realtime echoes within 1.5 s of a local user action
        if (_isWithinLocalActionDebounce) return;
        final row = payload.newRecord;
        final dbEnabled = row.containsKey('voice_mask_enabled') ? row['voice_mask_enabled'] == true : _voiceMaskEnabled;
        final dbPreset = row.containsKey('voice_mask_preset') && row['voice_mask_preset'] != null ? row['voice_mask_preset'].toString() : _voiceMaskPreset;
        final dbPitch = row.containsKey('voice_pitch') && row['voice_pitch'] != null ? (row['voice_pitch']).toDouble() : _voicePitch;
        final dbFormant = row.containsKey('voice_formant') && row['voice_formant'] != null ? (row['voice_formant']).toDouble() : _voiceFormant;
        if (dbEnabled != _voiceMaskEnabled || dbPreset != _voiceMaskPreset || dbPitch != _voicePitch) {
          setState(() {
            _voiceMaskEnabled = dbEnabled;
            _voiceMaskPreset = dbPreset;
            _voicePitch = dbPitch;
            _voiceFormant = dbFormant;
            _isEditingVoiceMask = false;
          });
        }
      },
    );
    _profileChannel!.subscribe();
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    WidgetsBinding.instance.removeObserver(this);
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _testTimer?.cancel();
    if (_isRecordingTest) {
      VoiceMaskService.instance.stopMasking();
    }
    super.dispose();
  }

  Uint8List _buildWavHeader(int dataLength) {
    int sampleRate = 44100;
    int channels = 1;
    int byteRate = sampleRate * channels * 2;
    int blockAlign = channels * 2;
    int bitsPerSample = 16;
    
    var header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46); // "RIFF"
    header.setUint32(4, 36 + dataLength, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45); // "WAVE"
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20); // "fmt "
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61); // "data"
    header.setUint32(40, dataLength, Endian.little);
    return header.buffer.asUint8List();
  }

  Future<void> _playMaskedVoice(StateSetter setLocalState) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/masked_test.wav');
    final header = _buildWavHeader(_recordedBytes.length);
    final bytes = Uint8List(header.length + _recordedBytes.length);
    bytes.setAll(0, header);
    bytes.setAll(header.length, _recordedBytes);
    await file.writeAsBytes(bytes);
    
    await _audioPlayer.setSourceDeviceFile(file.path);
    await _audioPlayer.resume();
    
    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) {
        setLocalState(() {
          _isPlayingTest = false;
          _hasRecording = false; // Reset to "Test My Voice"
        });
      }
    });
  }

  Future<void> _toggleVoiceTest(StateSetter setLocalState) async {
    if (_isPlayingTest) {
      // Stop playback early
      await _audioPlayer.stop();
      setLocalState(() {
        _isPlayingTest = false;
        _hasRecording = false; // Reset to "Test My Voice" immediately
      });
      return;
    }

    if (_hasRecording && !_isRecordingTest) {
      // Play the recorded masked voice
      setLocalState(() => _isPlayingTest = true);
      await _playMaskedVoice(setLocalState);
      return;
    }

    if (_isRecordingTest) {
      // Stop recording -> show "Play Recording" button
      _testTimer?.cancel();
      _pcmSub?.cancel();
      await _audioRecorder.stop();
      setLocalState(() {
        _isRecordingTest = false;
        _testSecondsLeft = 0;
        _hasRecording = _recordedBytes.isNotEmpty;
      });
    } else {
      // Start recording
      if (await _audioRecorder.hasPermission()) {
        _recordedBytes.clear();
        setLocalState(() {
          _isRecordingTest = true;
          _hasRecording = false;
          _testSecondsLeft = 10;
        });
        
        await VoiceMaskService.instance.setPreset(_voiceMaskPreset);
        
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ));
        
        _pcmSub = stream.listen((data) async {
          final processed = await VoiceMaskService.instance.processFrame(data);
          if (processed != null) {
            _recordedBytes.addAll(processed);
          } else {
            _recordedBytes.addAll(data);
          }
        });
        
        _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (_testSecondsLeft > 1) {
            setLocalState(() => _testSecondsLeft--);
          } else {
            // Auto-stop recording
            timer.cancel();
            _pcmSub?.cancel();
            await _audioRecorder.stop();
            setLocalState(() {
              _isRecordingTest = false;
              _testSecondsLeft = 0;
              _hasRecording = _recordedBytes.isNotEmpty;
            });
          }
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localLoc = prefs.getString('bolroom_location') ?? 'Global';

      final bp = await _sb.from('bolroom_profiles').select('*').eq('id', _targetId).maybeSingle();
      if (bp != null && mounted) {
        final String? avatarKey = bp['avatar_key'] as String?;
        setState(() {
          _anonName = bp['anon_name'] ?? 'Anonymous';
          _anonBio = bp['anon_bio'] ?? '';
          _auraColorHex = bp['aura_color'] ?? '#8A2BE2';
          _avatarUrl = bp['avatar_url'];
          _avatarKey = avatarKey ?? BolroomAvatars.forUser(_targetId).id;
          _location = _isMe ? localLoc : (bp['location'] ?? 'Global');
          _roomsHosted = bp['rooms_hosted'] ?? 0;
          _voiceMaskEnabled = bp['voice_mask_enabled'] ?? false;
          _voicePitch = (bp['voice_pitch'] ?? 0.5).toDouble();
          _voiceMaskPreset = (bp['voice_mask_preset'] ?? 'ghost').toString();
          _loading = false;
        });
        // Persist random assignment to DB if needed
        if (avatarKey == null && _isMe) {
          _sb.from('bolroom_profiles')
              .update({'avatar_key': _avatarKey}).eq('id', _myId)
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
        final fCheck = await _sb.from('bolroom_follows').select('id').eq('follower_id', _myId).eq('following_id', _targetId).maybeSingle();
        if (mounted) setState(() => _isFollowing = fCheck != null);
      }
    } catch (e) {
      debugPrint('Load profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFollowCounts() async {
    try {
      final followers = await _sb.from('bolroom_follows').select('id').eq('following_id', _targetId);
      final following = await _sb.from('bolroom_follows').select('id').eq('follower_id', _targetId);
      if (mounted) setState(() { _followerCount = (followers as List).length; _followingCount = (following as List).length; });
    } catch (_) {}
  }

  Future<void> _updateProfile(Map<String, dynamic> data) async {
    try {
      if (data.containsKey('location')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bolroom_location', data['location']);
        data.remove('location');
      }
      // Voice mask changes: ONLY write to DB.
      // The BolRoom screen has a realtime Supabase subscription on bolroom_profiles
      // that picks up the change and calls _updateNativeVoiceMasking() automatically.
      // This ensures single source of truth and no conflicts between screens.
      if (data.isNotEmpty) {
        data['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await _sb.from('bolroom_profiles').update(data).eq('id', _myId);
      }
    } catch (e) { debugPrint('Update profile: $e'); }
  }

  String _fmtNum(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  DateTime _lastVoiceMaskRefresh = DateTime(2000);

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    if (_loading) return Scaffold(backgroundColor: doodle ? DoodleColors.paper : bgColor, body: Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : purpleGlow, strokeWidth: 2)));

    return Scaffold(
      backgroundColor: doodle ? DoodleColors.paper : bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav from shell
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
              if (_isMe) _buildEditProfileButton(doodle) else _buildPublicActionButtons(),
              const SizedBox(height: 30),
              if (_isMe) ...[
                _buildFeaturesRow(),
                const SizedBox(height: 32),
                _buildVoiceEffectsSection(doodle),
                const SizedBox(height: 32),
              ],
              _buildSectionHeader('Badges', 'View All', doodle, onActionTap: _showAllBadgesSheet),
              _buildBadgesRow(),
              const SizedBox(height: 24),
              if (_isMe) ...[
                _buildQuickSettingsHeader(doodle),
                _buildQuickSettingsItem(doodle),
                const SizedBox(height: 40),
              ],
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
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report/Block menu coming soon.'))),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : Colors.white24, borderRadius: BorderRadius.circular(2))),
          _menuTile(Icons.auto_awesome, 'Choose Avatar', const Color(0xFF8A2BE2), () { Navigator.pop(context); _showAvatarOptionsSheet(); }),
          _menuTile(Icons.share_outlined, 'Share Profile', const Color(0xFFFF6B00), () { 
            Navigator.pop(context); 
            Share.share('Join me on Bolrooms! Check out my profile: https://meetra.app/profile/$_myId'); 
          }),
          _menuTile(Icons.palette_outlined, 'Change Aura', const Color(0xFFFFD700), () { Navigator.pop(context); _showAuraChangerSheet(); }),
          _menuTile(Icons.block_outlined, 'Blocked Users', const Color(0xFFFF4655), () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No blocked users.'))); }),
          _menuTile(Icons.logout, 'Sign Out', Colors.redAccent, () async {
            Navigator.pop(context);
            await _sb.auth.signOut();
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, Color color, VoidCallback onTap) {
    final doodle = isDoodleMode(context);
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      title: Text(label, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 15).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
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
          _showToast('Avatar updated! ✨');
        },
      ),
    );
  }

  void _showAvatarOptionsSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : Colors.white24, borderRadius: BorderRadius.circular(2))),
            Text('Profile Picture', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAvatarActionBtn(Icons.auto_awesome, 'Avatars', purpleGlow, () {
                  Navigator.pop(context);
                  _showAvatarPickerSheet();
                }),
                _buildAvatarActionBtn(Icons.camera_alt, 'Camera', purpleGlow, () => _pickAndUploadAvatar(ImageSource.camera)),
                _buildAvatarActionBtn(Icons.photo_library, 'Gallery', const Color(0xFFFF6B00), () => _pickAndUploadAvatar(ImageSource.gallery)),
                if (_avatarUrl != null)
                  _buildAvatarActionBtn(Icons.delete_outline, 'Remove', Colors.redAccent, _removeAvatar),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAvatarActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    final doodle = isDoodleMode(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    Navigator.pop(context); // Close the bottom sheet
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    
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

    if (croppedFile == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await croppedFile.readAsBytes();
      final ext = croppedFile.path.split('.').last.replaceAll('jpg', 'jpeg');
      
      // Use a completely unique file path so we NEVER hit Supabase or Flutter caching issues
      final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'bolroom_avatars/${_myId}_$uniqueTimestamp.$ext';
      
      // Upload to Supabase Storage
      await _sb.storage.from('avatars').uploadBinary(
        path, 
        bytes, 
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true)
      );
      
      final url = _sb.storage.from('avatars').getPublicUrl(path);
      
      await _updateProfile({'avatar_url': url});
      
      if (mounted) setState(() { _avatarUrl = url; _uploadingAvatar = false; });
      _showToast('Profile picture updated successfully! 🎉');
    } catch (e) {
      debugPrint('Avatar upload: $e');
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _showToast('Failed to upload image. Please try again.');
      }
    }
  }

  Future<void> _removeAvatar() async {
    Navigator.pop(context); // Close sheet
    setState(() => _uploadingAvatar = true);
    try {
      // We don't necessarily need to delete the file, just remove the reference from the profile
      await _updateProfile({'avatar_url': null});
      if (mounted) setState(() { _avatarUrl = null; _uploadingAvatar = false; });
      _showToast('Profile picture removed.');
    } catch (e) {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: cardColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: purpleGlow.withValues(alpha: 0.3))),
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
      child: Icon(icon, color: doodle ? DoodleColors.brown : Colors.white, size: 20),
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
                width: 140, height: 140,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: cardColor),
                child: const Center(child: CircularProgressIndicator(color: purpleGlow, strokeWidth: 2)),
              )
            : BolroomAvatarWidget(
                size: 140,
                avatarUrl: _avatarUrl,
                avatarKey: _avatarKey,
                userId: _targetId,
                showRing: !doodle,
              ),
          // Edit badge
          if (_isMe)
            Positioned(
              bottom: 5, right: 5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: doodle ? DoodleColors.paper : bgColor, shape: BoxShape.circle),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: doodle ? DoodleColors.brown : const Color(0xFF7B2CBF), shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome, color: doodle ? DoodleColors.cream : Colors.white, size: 14),
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
            Icon(Icons.verified, color: doodle ? DoodleColors.blue : const Color(0xFF7B2CBF), size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _anonBio.isNotEmpty ? '"$_anonBio"' : '"Whisperer of midnight thoughts. Anonymous since 2024."',
          style: doodle 
            ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 16)
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
                border: Border.all(color: BolroomTheme.gold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: BolroomTheme.gold.withValues(alpha: 0.1), blurRadius: 10),
                ],
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: doodle ? DoodleColors.orange : BolroomTheme.gold, size: 16),
              const SizedBox(width: 6),
              Text(
                'Lv. $auraLevel Aura',
                style: doodle
                  ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 14).copyWith(fontWeight: FontWeight.bold)
                  : const TextStyle(color: BolroomTheme.gold, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
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
            _fmtNum(_followerCount), 'Followers',
            Icons.people_alt_outlined, const [Color(0xFFD433FF), Color(0xFF7B2CBF)], doodle,
            onTap: () => _showFollowListSheet('Followers'),
          ),
          _buildStatCard(
            _fmtNum(_followingCount), 'Following',
            Icons.person_outline, const [Color(0xFFFFD700), Color(0xFFFF8C00)], doodle,
            onTap: () => _showFollowListSheet('Following'),
          ),
          _buildStatCard(
            _fmtNum(_roomsHosted), 'Rooms Hosted',
            Icons.local_fire_department_outlined, const [Color(0xFFFF6B00), Color(0xFF1E90FF)], doodle,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, List<Color> gradientColors, bool doodle, {VoidCallback? onTap}) {
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
                Text(value, style: DoodleFonts.heading(color: DoodleColors.brown, fontSize: 24))
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
                  Icon(icon, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: doodle
                      ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12)
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
              Icon(Icons.edit_outlined, color: doodle ? DoodleColors.blue : const Color(0xFFB983FF), size: 18),
              const SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: doodle
                  ? DoodleFonts.heading(color: DoodleColors.blue, fontSize: 16)
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
                  border: Border.all(color: _isFollowing ? const Color(0xFF3B2768) : Colors.transparent),
                  boxShadow: _isFollowing ? [] : [BoxShadow(color: purpleGlow.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)],
                ),
                child: _isFollowLoading 
                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isFollowing ? Icons.person_remove_rounded : Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isFollowing ? 'Unfollow' : 'Follow',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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
                    Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFFFF6B00), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Message',
                      style: TextStyle(color: Color(0xFFFF6B00), fontSize: 15, fontWeight: FontWeight.w600),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Invalid user session or profile (Missing ID).'), backgroundColor: Colors.redAccent));
      return;
    }
    try {
      final existing = await _sb.from('bolroom_dm_conversations').select('*')
        .or('and(user1_id.eq.$_myId,user2_id.eq.$_targetId),and(user1_id.eq.$_targetId,user2_id.eq.$_myId)')
        .maybeSingle();

      String convId;
      if (existing != null) {
        convId = existing['id'].toString();
      } else {
        final newConvo = await _sb.from('bolroom_dm_conversations').insert({
          'user1_id': _myId, 'user2_id': _targetId,
        }).select().single();
        convId = newConvo['id'].toString();
      }

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => BolroomDmChatScreen(
        conversationId: convId,
        partnerId: _targetId,
        partnerName: _anonName,
        partnerAvatarKey: _avatarUrl ?? 'default',
      )));
    } catch (e) {
      debugPrint('Start/Navigate to chat error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_targetId.isEmpty || _myId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Invalid user session or profile (Missing ID).'), backgroundColor: Colors.redAccent));
      return;
    }
    if (_isFollowLoading) return;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });
    try {
      if (!_isFollowing) { // Previously it was following, now we deleted it
        await _sb.from('bolroom_follows').delete().eq('follower_id', _myId).eq('following_id', _targetId);
      } else {
        await _sb.from('bolroom_follows').insert({'follower_id': _myId, 'following_id': _targetId});
        
        // Notify both users
        try {
          final me = await _sb.from('bolroom_profiles').select('anon_name').eq('id', _myId).maybeSingle();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Widget _buildSectionHeader(String title, String action, bool doodle, {VoidCallback? onActionTap}) {
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
                Icon(Icons.chevron_right, color: doodle ? DoodleColors.blue : const Color(0xFFB983FF), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text("BolRoom Features", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildFeatureCard(
                'Aura Signature', 'Shift global colors', Icons.color_lens, const Color(0xFF8A2BE2),
                onTap: _showAuraChangerSheet,
              ),
              _buildFeatureCard(
                'Ghost Protocol', 'Complete incognito', Icons.visibility_off, const Color(0xFFFF4655),
                onTap: _showGhostProtocolSheet,
              ),
              _buildFeatureCard(
                'Encrypted Radar', 'Hide exact GPS', Icons.radar, const Color(0xFF00FF00),
                onTap: _showEncryptedRadarSheet,
              ),
              _buildFeatureCard(
                'Broadcast Region', 'Set your local base', Icons.location_on, const Color(0xFFFFB347),
                onTap: _showLocationSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String subtitle, IconData icon, Color accent, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: textMuted, fontSize: 11)),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showAuraChangerSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Shift Aura Signature", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildColorChanger(const Color(0xFF8A2BE2), '#8A2BE2', setSheetState),
                    _buildColorChanger(const Color(0xFFFF6B00), '#00E5FF', setSheetState),
                    _buildColorChanger(const Color(0xFFFF4655), '#FF4655', setSheetState),
                    _buildColorChanger(const Color(0xFFFFD700), '#FFD700', setSheetState),
                    _buildColorChanger(const Color(0xFF00FF00), '#00FF00', setSheetState),
                  ],
                ),
                const SizedBox(height: 24),
                const Text("Changes made here reflect instantly across\nEchoes, Hubs, and DMs.", textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildColorChanger(Color color, String hex, StateSetter setSheetState) {
    bool isSelected = _auraColorHex.toUpperCase() == hex.toUpperCase();
    return GestureDetector(
      onTap: () {
        setState(() => _auraColorHex = hex);
        setSheetState(() {});
        _updateProfile({'aura_color': hex});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)] : null,
        ),
      ),
    );
  }

  bool _voiceMaskEnabled = false;
  double _voicePitch = 0.5; // 0..1 mapping to -12..+12 semitones
  double _voiceFormant = 0.0; // raw semitones -6..+6 (horizontal/brightness)
  String _voiceMaskPreset = 'ghost';
  bool _isEditingVoiceMask = false;

  Widget _buildVoiceEffectsSection(bool doodle) {
    final presets = VoiceMaskPreset.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("Voice Effects", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: doodle
            ? DoodleDecorations.card(color: DoodleColors.paper)
            : BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Enable Voice Masking", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _voiceMaskEnabled ? "Your voice is disguised" : "Original Voice",
                  style: TextStyle(color: _voiceMaskEnabled ? const Color(0xFFFF6B00) : textMuted, fontSize: 12)
                ),
                value: _voiceMaskEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFFFF6B00),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: const Color(0xFF2A2440),
                onChanged: (v) {
                  _localActionTime = DateTime.now(); // debounce guard
                  setState(() {
                    _voiceMaskEnabled = v;
                    _isEditingVoiceMask = v; // show grid on ON, hide on OFF
                  });
                  _updateProfile({'voice_mask_enabled': v});
                },
              ),
              if (_voiceMaskEnabled) ...[
                const Divider(color: borderColor, height: 32),
                if (_isEditingVoiceMask) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (_, i) {
                    final p = presets[i];
                    final isActive = _voiceMaskPreset == p.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _voiceMaskPreset = p.id;
                          _isEditingVoiceMask = true;
                          _hasRecording = false;
                          _isPlayingTest = false;
                          _isRecordingTest = false;
                        });
                        _audioPlayer.stop();
                        _updateProfile({'voice_mask_preset': p.id});
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: p.colors,
                              ),
                              border: Border.all(
                                color: isActive ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: p.colors.first.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(p.icon, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.name,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Custom voice pitch graph (only when 'custom' preset is selected)
                if (_voiceMaskPreset == 'custom') ...[
                  const SizedBox(height: 12),
                  _buildProfileCustomVoicePad(setState, isDoodleMode(context)),
                ],
                const SizedBox(height: 12),
                // Test button
                GestureDetector(
                  onTap: () => _toggleVoiceTest(setState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: (_isRecordingTest || _isPlayingTest || _hasRecording) ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_isRecordingTest || _isPlayingTest || _hasRecording) ? const Color(0xFFFF6B00) : borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPlayingTest ? Icons.stop_circle
                              : _isRecordingTest ? Icons.stop_circle_outlined
                              : _hasRecording ? Icons.play_circle_fill
                              : Icons.mic_none,
                          color: const Color(0xFFFF6B00),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPlayingTest ? 'Stop Playing'
                              : _isRecordingTest ? 'Stop Recording ($_testSecondsLeft s)'
                              : _hasRecording ? 'Play Recording'
                              : 'Test My Voice',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Use this voice button
                GestureDetector(
                  onTap: () {
                    _updateProfile({
                      'voice_mask_enabled': _voiceMaskEnabled,
                      'voice_mask_preset': _voiceMaskPreset,
                    });
                    setState(() => _isEditingVoiceMask = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice masking saved successfully! Participants will now hear this voice.'))
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFF007BFF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Use this voice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                ] else ...[
                  // Show active voice mask card (collapsed view)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Active Voice Mask",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Builder(builder: (ctx) {
                          final p = VoiceMaskPreset.byId(_voiceMaskPreset) ?? VoiceMaskPreset.all.first;
                          return Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: p.colors,
                                  ),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.colors.first.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: Text(p.icon, style: const TextStyle(fontSize: 32)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isEditingVoiceMask = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: const Text(
                                    "Change",
                                    style: TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // Show pitch slider in collapsed view for Custom preset
                              if (p.id == 'custom') ...[ 
                                const SizedBox(height: 16),
                                if (_voiceMaskEnabled && _voiceMaskPreset == 'custom') ...[
                                  const SizedBox(height: 20),
                                  _buildProfileCustomVoicePad(setState, doodle),
                                ],
                              ],
                              if (p.id != 'custom') const SizedBox(height: 0),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Original Voice promotional card when OFF
                const Divider(color: borderColor, height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.record_voice_over, color: Color(0xFFFF6B00), size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Original Voice Active",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Mask your voice to speak freely and anonymously! Choose from fun presets like Ghost, Robot, or Alien to disguise your identity in any BolRoom.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  /// Custom 2D voice pad for profile section: pitch (vertical) × formant (horizontal).
  /// Matches the voiceroom custom pad for consistent UX.
  /// Custom 2D voice pad - pitch (vertical, top=high) x brightness/formant (horizontal, right=bright).
  Widget _buildProfileCustomVoicePad(StateSetter setSheetState, bool doodle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Voice Tuner', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Drag the dot to find your perfect voice texture', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 12) : const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 10),
        Container(
          height: 180,
          decoration: doodle
            ? DoodleDecorations.card(color: DoodleColors.paper)
            : BoxDecoration(color: const Color(0xFF13101E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF231D38))),
          child: LayoutBuilder(builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            double pitchNorm = ((_voicePitch - 0.5) * 24.0).clamp(-12.0, 12.0).toDouble();
            double formantNorm = _voiceFormant.clamp(-6.0, 6.0).toDouble();
            double dotX = (formantNorm + 6.0) / 12.0 * w;
            double dotY = (1.0 - (pitchNorm + 12.0) / 24.0) * h;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                final lx = d.localPosition.dx.clamp(0.0, w);
                final ly = d.localPosition.dy.clamp(0.0, h);
                final newPitch = (1.0 - ly / h) * 24.0 - 12.0;
                final newFormant = (lx / w) * 12.0 - 6.0;
                setState(() {
                  _voicePitch = (newPitch / 24.0) + 0.5;
                  _voiceFormant = newFormant;
                });
                setSheetState(() {});
                VoiceMaskService.instance.setCustomPitch(newPitch);
                VoiceMaskService.instance.setCustomFormant(newFormant);
              },
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _VoicePadPainter(dotX: dotX, dotY: dotY))),
                  Positioned(left: dotX - 14, top: dotY - 14, child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, gradient: doodle ? null : const RadialGradient(colors: [Color(0xFFFF6B00), Color(0xFF007BFF)]), color: doodle ? DoodleColors.orange : null, border: doodle ? Border.all(color: DoodleColors.brown, width: 2) : null, boxShadow: doodle ? [] : [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2)]))),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Pitch: ${((_voicePitch - 0.5) * 24).toStringAsFixed(1)} st · Brightness: ${_voiceFormant.toStringAsFixed(1)} st', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 12) : const TextStyle(color: Colors.white70, fontSize: 11))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            _localActionTime = DateTime.now();
            _updateProfile({'voice_pitch': _voicePitch, 'voice_formant': _voiceFormant});
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom voice saved successfully!')));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: doodle ? DoodleDecorations.card(color: DoodleColors.blue).copyWith(borderRadius: BorderRadius.circular(16)) : BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF007BFF)]), borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('Use this voice', style: doodle ? DoodleFonts.body(color: DoodleColors.cream, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          ),
        ),
      ],
    );
  }

  /// Returns a human-readable zone label for the current pad position.

  void _showVoiceMaskingSheet() {
    bool isRecording = false;
    bool isPlaying = false;
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      isScrollControlled: true,
      shape: doodle ? null : const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final presets = VoiceMaskPreset.all;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.masks, color: doodle ? DoodleColors.orange : const Color(0xFFFF6B00), size: 48),
                const SizedBox(height: 12),
                Text("Voice Masking", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 22) : const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Disguise your voice globally across all BolRooms.", textAlign: TextAlign.center, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : const TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: Text("Enable Masking", style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 18).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 16)),
                  value: _voiceMaskEnabled,
                  activeThumbColor: doodle ? DoodleColors.cream : const Color(0xFFFF6B00),
                  activeTrackColor: doodle ? DoodleColors.blue : null,
                  inactiveThumbColor: doodle ? DoodleColors.brown : null,
                  inactiveTrackColor: doodle ? DoodleColors.paper : null,
                  trackOutlineColor: doodle ? WidgetStateProperty.all(DoodleColors.brown) : null,
                  onChanged: (v) {
                    setState(() => _voiceMaskEnabled = v);
                    setSheetState(() {});
                    // Decouple DB write from UI state
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _updateProfile({'voice_mask_enabled': v});
                    });
                  },
                ),
                if (_voiceMaskEnabled) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text("Select Voice Preset", style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Preset Grid (match reference image style)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: presets.length,
                    itemBuilder: (_, i) {
                      final p = presets[i];
                      final isActive = _voiceMaskPreset == p.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _voiceMaskPreset = p.id;
                            _hasRecording = false;
                            _isPlayingTest = false;
                            _isRecordingTest = false;
                          });
                          setSheetState(() {});
                          _audioPlayer.stop();
                          _updateProfile({'voice_mask_preset': p.id});
                          VoiceMaskService.instance.setPreset(p.id);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: doodle
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive ? DoodleColors.orange : DoodleColors.paper,
                                    border: Border.all(color: DoodleColors.brown, width: isActive ? 3 : 2),
                                  )
                                : BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: p.colors,
                                    ),
                                    border: Border.all(
                                      color: isActive ? Colors.white : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: p.colors.first.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                              child: Center(
                                child: Text(p.icon,
                                    style: const TextStyle(fontSize: 30)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.name,
                              style: doodle ? DoodleFonts.body(color: isActive ? DoodleColors.blue : DoodleColors.brown, fontSize: 12).copyWith(fontWeight: isActive ? FontWeight.bold : FontWeight.normal) : TextStyle(
                                color: isActive ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    VoiceMaskPreset.byId(_voiceMaskPreset)?.description ?? '',
                    style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12) : const TextStyle(color: textMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Custom pitch slider (only for custom preset)
                  if (_voiceMaskPreset == 'custom') ...[
                    Text("Pitch Shift Level", style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.white, fontSize: 14)),
                    SliderTheme(
                      data: doodle ? SliderThemeData(
                        activeTrackColor: DoodleColors.blue,
                        inactiveTrackColor: DoodleColors.paper,
                        thumbColor: DoodleColors.orange,
                        overlayColor: DoodleColors.orange.withValues(alpha: 0.2),
                      ) : SliderTheme.of(context),
                      child: Slider(
                        value: _voicePitch,
                        min: 0.0,
                        max: 1.0,
                        activeColor: doodle ? null : const Color(0xFFFF6B00),
                        onChanged: (v) {
                          setState(() => _voicePitch = v);
                          setSheetState(() {});
                        },
                        onChangeEnd: (v) {
                          _updateProfile({'voice_pitch': v});
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Test voice button
                  GestureDetector(
                    onTap: () => _toggleVoiceTest(setSheetState),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      width: double.infinity,
                      decoration: doodle
                        ? DoodleDecorations.card(color: (_isRecordingTest || _isPlayingTest || _hasRecording) ? DoodleColors.cream : DoodleColors.paper).copyWith(borderRadius: BorderRadius.circular(16))
                        : BoxDecoration(
                            color: (_isRecordingTest || _isPlayingTest || _hasRecording)
                                ? const Color(0xFFFF6B00).withValues(alpha: 0.2)
                                : const Color(0xFF1A132F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (_isRecordingTest || _isPlayingTest || _hasRecording)
                                  ? const Color(0xFFFF6B00) 
                                  : const Color(0xFF3B2768),
                            ),
                          ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPlayingTest ? Icons.stop_circle
                                : _isRecordingTest ? Icons.stop_circle_outlined
                                : _hasRecording ? Icons.play_circle_fill
                                : Icons.mic_none, 
                            color: const Color(0xFFFF6B00),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPlayingTest ? 'Stop Playing'
                                : _isRecordingTest ? 'Stop Recording ($_testSecondsLeft s)'
                                : _hasRecording ? 'Play Recording'
                                : 'Test My Voice',
                            style: TextStyle(
                              color: (_isRecordingTest || _isPlayingTest || _hasRecording) ? const Color(0xFFFF6B00) : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Use this voice button
                  GestureDetector(
                    onTap: () {
                      _updateProfile({
                        'voice_mask_enabled': _voiceMaskEnabled,
                        'voice_mask_preset': _voiceMaskPreset,
                      });
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Voice masking saved successfully! Participants will now hear this voice.'))
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFF007BFF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Use this voice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  double _semitoneToRate(double semitones) {
    // Convert semitones to playback rate
    // +12 semitones = 2x rate, -12 = 0.5x rate
    return _pow2(semitones / 12.0);
  }

  double _pow2(double x) {
    // 2^x approximation for playback rate conversion
    if (x == 0) return 1.0;
    return _exp(x * 0.6931471805599453); // ln(2) * x
  }

  double _exp(double x) {
    // Simple e^x using Taylor series (sufficient for small x)
    double sum = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }

  bool _ghostProtocolEnabled = false;

  void _showGhostProtocolSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_off, color: Color(0xFFFF4655), size: 48),
                const SizedBox(height: 12),
                Text("Ghost Protocol", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("When active, you will appear fully offline. Your aura will be hidden and read receipts disabled.", textAlign: TextAlign.center, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 13) : const TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text("Activate Ghost Protocol", style: TextStyle(color: Colors.white, fontSize: 16)),
                  value: _ghostProtocolEnabled,
                  activeThumbColor: const Color(0xFFFF4655),
                  onChanged: (v) {
                    setState(() => _ghostProtocolEnabled = v);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  bool _encryptedRadarEnabled = true;

  void _showEncryptedRadarSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radar, color: Color(0xFF00FF00), size: 48),
                const SizedBox(height: 12),
                Text("Encrypted Radar", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Your location and proximity data will be encrypted end-to-end.", textAlign: TextAlign.center, style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 13) : const TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text("Radar Broadcasting", style: TextStyle(color: Colors.white, fontSize: 16)),
                  value: _encryptedRadarEnabled,
                  activeThumbColor: const Color(0xFF00FF00),
                  onChanged: (v) {
                    setState(() => _encryptedRadarEnabled = v);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildBadgesRow() {
    final doodle = isDoodleMode(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildHexBadge(doodle, 'Founder', Icons.star_rounded, const [Color(0xFFFFDF00), Color(0xFFD4AF37)]),
            _buildHexBadge(doodle, 'Night Owl', Icons.nightlight_round, const [Color(0xFFB983FF), Color(0xFF7B2CBF)]),
            _buildHexBadge(doodle, 'Elite Host', Icons.workspace_premium_rounded, const [Color(0xFFFF6B00), Color(0xFF1E90FF)]),
            _buildHexBadge(doodle, 'Top Speaker', Icons.local_fire_department_rounded, const [Color(0xFFFF00FF), Color(0xFF8A2BE2)]),
            _buildMoreBadge(doodle),
          ],
        ),
      ),
    );
  }

  Widget _buildHexBadge(bool doodle, String label, IconData icon, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 75,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hexagon border
                ClipPath(
                  clipper: HexagonClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Inner dark hexagon
                ClipPath(
                  clipper: HexagonClipper(),
                  child: Container(
                    width: 66,
                    height: 71,
                    decoration: BoxDecoration(
                      color: doodle ? DoodleColors.paper : cardColor,
                    ),
                  ),
                ),
                // Glowing Icon
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: doodle ? DoodleColors.textMuted : textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildMoreBadge(bool doodle) {
      return GestureDetector(
        onTap: _showAllBadgesSheet,
        child: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 75,
                decoration: BoxDecoration(
                  color: doodle ? DoodleColors.paper : cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: doodle ? DoodleColors.cardBorder : borderColor),
                ),
                child: Center(
                  child: Text(
                    '+6',
                    style: TextStyle(
                      color: doodle ? DoodleColors.textPrimary : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            const Text(
              'More',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllBadgesSheet() {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: doodle ? DoodleColors.cardBorder : Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('BolRoom Badges', style: TextStyle(color: doodle ? DoodleColors.textPrimary : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Your digital anonymous achievements', style: TextStyle(color: doodle ? DoodleColors.textMuted : textMuted, fontSize: 14)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildBadgeDetailRow('Founder', 'Joined in the first year of BolRoom', Icons.star_rounded, const [Color(0xFFFFDF00), Color(0xFFD4AF37)], true),
                    _buildBadgeDetailRow('Night Owl', 'Active in 50+ rooms between 12 AM - 4 AM', Icons.nightlight_round, const [Color(0xFFB983FF), Color(0xFF7B2CBF)], true),
                    _buildBadgeDetailRow('Elite Host', 'Hosted rooms with over 1k combined listeners', Icons.workspace_premium_rounded, const [Color(0xFFFF6B00), Color(0xFF1E90FF)], true),
                    _buildBadgeDetailRow('Top Speaker', 'Spoke for 100+ hours in total', Icons.local_fire_department_rounded, const [Color(0xFFFF00FF), Color(0xFF8A2BE2)], true),
                    _buildBadgeDetailRow('Trend Setter', 'Created a room that trended globally', Icons.trending_up_rounded, const [Color(0xFF00FF87), Color(0xFF60EFFF)], true),
                    _buildBadgeDetailRow('Shadow Guide', 'Mentored 10+ new users', Icons.groups_rounded, const [Color(0xFFFF4655), Color(0xFF8A2BE2)], true),
                    
                    const SizedBox(height: 12),
                    const Divider(color: borderColor),
                    const SizedBox(height: 12),
                    
                    _buildBadgeDetailRow('Cipher Master', 'Unlock by staying completely anonymous for 1 year', Icons.vpn_key_rounded, const [Color(0xFF8E8B99), Color(0xFF5A5866)], false),
                    _buildBadgeDetailRow('Echo Lord', 'Reach 10,000 followers', Icons.record_voice_over_rounded, const [Color(0xFF8E8B99), Color(0xFF5A5866)], false),
                    _buildBadgeDetailRow('Phantom', 'Use Ghost Protocol for 500 hours', Icons.visibility_off_rounded, const [Color(0xFF8E8B99), Color(0xFF5A5866)], false),
                    _buildBadgeDetailRow('Global Voice', 'Speak in 20 different Broadcast Regions', Icons.public_rounded, const [Color(0xFF8E8B99), Color(0xFF5A5866)], false),
                    
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: doodle ? DoodleColors.cream : bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: doodle ? DoodleColors.cardBorder : const Color(0xFF3B2768)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: doodle ? DoodleColors.amber : const Color(0xFFB983FF), size: 24),
                              const SizedBox(width: 10),
                              Text('How Badges Work', style: TextStyle(color: doodle ? DoodleColors.textPrimary : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Badges in BolRoom are earned through your interactions, hostings, and exploration of the platform. They are a way to showcase your journey while maintaining absolute anonymity.\n\n'
                            '• Earned Badges: Displayed in full vibrant colors.\n'
                            '• Locked Badges: Displayed in grey. The criteria to unlock them is shown next to the badge.\n\n'
                            'Equip up to 4 badges to your public profile to show off your greatest achievements to other users when they tap your avatar in a room.',
                            style: TextStyle(color: doodle ? DoodleColors.textMuted : textMuted, fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBadgeDetailRow(String title, String desc, IconData icon, List<Color> colors, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: unlocked ? 1.0 : 0.4,
            child: SizedBox(
              width: 50,
              height: 55,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipPath(clipper: HexagonClipper(), child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors)))),
                  ClipPath(clipper: HexagonClipper(), child: Container(width: 46, height: 51, decoration: BoxDecoration(color: isDoodleMode(context) ? DoodleColors.paper : cardColor))),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(color: unlocked ? (isDoodleMode(context) ? DoodleColors.textPrimary : Colors.white) : (isDoodleMode(context) ? DoodleColors.textMuted : textMuted), fontSize: 16, fontWeight: FontWeight.w600)),
                    if (unlocked) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF87), size: 14),
                    ] else ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_rounded, color: textMuted, size: 14),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: isDoodleMode(context) ? DoodleColors.textMuted : textMuted, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowListSheet(String type) {
    final doodle = isDoodleMode(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _FollowListSheet(
        targetId: _targetId,
        type: type,
        onProfileTap: (uid) {
          Navigator.pop(ctx);
          if (uid != _targetId) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BolroomProfileScreen(targetUserId: uid)));
          }
        },
      ),
    );
  }

  Widget _buildQuickSettingsHeader(bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Quick Settings',
          style: doodle
            ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18)
            : const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  Widget _buildQuickSettingsItem(bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: doodle
          ? DoodleDecorations.card(color: DoodleColors.paper)
          : BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: doodle ? DoodleColors.cream : borderColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: doodle ? DoodleColors.brown : textMuted, size: 20),
          ),
          title: Text(
            'Privacy',
            style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16).copyWith(fontWeight: FontWeight.w600) : const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            'Control who sees your profile and activity.',
            style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 13) : const TextStyle(color: textMuted, fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, color: doodle ? DoodleColors.brown : textMuted, size: 20),
        ),
      ),
    );
  }

  void _showEditProfile() {
    final doodle = isDoodleMode(context);
    final nameCtrl = TextEditingController(text: _anonName);
    final bioCtrl = TextEditingController(text: _anonBio);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: doodle
          ? BoxDecoration(color: DoodleColors.paper, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: DoodleColors.brown, width: 2))
          : BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: borderColor)),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, left: 24, right: 24, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 24),
          Text('Edit Profile', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 20),
          Text('ANONYMOUS NAME', style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          SizedBox(height: 8),
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(filled: true, fillColor: cardColor, hintText: 'Enter name...', hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          SizedBox(height: 16),
          Text('BIO', style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          SizedBox(height: 8),
          TextField(controller: bioCtrl, style: const TextStyle(color: Colors.white), maxLines: 3,
            decoration: InputDecoration(filled: true, fillColor: cardColor, hintText: 'Tell them about your shadow...', hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final bio = bioCtrl.text.trim();
              if (name.isNotEmpty) { await _updateProfile({'anon_name': name, 'anon_bio': bio}); setState(() { _anonName = name; _anonBio = bio; }); }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: purpleGlow, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
          )),
        ]),
      ),
    );
  }

  final Map<String, List<String>> _indiaLocations = {
    // 28 States
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Tirupati', 'Kakinada', 'Kadapa', 'Anantapur', 'Rajahmundry', 'Eluru', 'Ongole', 'Machilipatnam', 'Chittoor'],
    'Arunachal Pradesh': ['Itanagar', 'Tawang', 'Naharlagun', 'Pasighat', 'Ziro', 'Tezu', 'Bomdila', 'Aalo', 'Roing'],
    'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Tezpur', 'Bongaigaon', 'Karimganj', 'Diphu', 'Sivasagar', 'Goalpara', 'Barpeta', 'Dhubri'],
    'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 'Ara', 'Begusarai', 'Katihar', 'Munger', 'Chhapra', 'Saharsa', 'Hajipur', 'Sasaram', 'Bettiah', 'Motihari'],
    'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Rajnandgaon', 'Raigarh', 'Jagdalpur', 'Ambikapur', 'Dhamtari', 'Mahasamund', 'Durg', 'Chirmiri'],
    'Goa': ['Panaji', 'Vasco da Gama', 'Margao', 'Mapusa', 'Ponda', 'Bicholim', 'Curchorem', 'Sanquelim', 'Cuncolim'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar', 'Anand', 'Navsari', 'Morbi', 'Nadiad', 'Bharuch', 'Porbandar', 'Mehsana', 'Bhuj'],
    'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Rohtak', 'Hisar', 'Karnal', 'Sonipat', 'Panchkula', 'Yamunanagar', 'Bhiwani', 'Sirsa', 'Bahadurgarh', 'Kurukshetra', 'Jind', 'Kaithal'],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Mandi', 'Solan', 'Kullu', 'Palampur', 'Chamba', 'Nahan', 'Una', 'Bilaspur', 'Hamirpur', 'Manali'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar', 'Hazaribagh', 'Phusro', 'Giridih', 'Ramgarh', 'Medininagar', 'Chirkunda', 'Dumka'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi', 'Davangere', 'Ballari', 'Kalaburagi', 'Shivamogga', 'Tumakuru', 'Raichur', 'Bidar', 'Hospet', 'Gadag', 'Hassan', 'Udupi', 'Kolar'],
    'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam', 'Alappuzha', 'Palakkad', 'Kannur', 'Kottayam', 'Manjeri', 'Thalassery', 'Ponnani', 'Kasaragod', 'Pathanamthitta'],
    'Madhya Pradesh': ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa', 'Murwara', 'Singrauli', 'Burhanpur', 'Khandwa', 'Morena', 'Bhind', 'Chhindwara', 'Guna'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Solapur', 'Amravati', 'Nanded', 'Kolhapur', 'Akola', 'Jalgaon', 'Latur', 'Dhule', 'Ahmednagar', 'Chandrapur', 'Parbhani', 'Thane', 'Kalyan-Dombivli', 'Navi Mumbai', 'Vasai-Virar'],
    'Manipur': ['Imphal', 'Thoubal', 'Kakching', 'Churachandpur', 'Bishnupur', 'Ukhrul', 'Jiribam', 'Senapati'],
    'Meghalaya': ['Shillong', 'Tura', 'Nongstoin', 'Jowai', 'Williamnagar', 'Baghmara', 'Resubelpara'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Saiha', 'Champhai', 'Kolasib', 'Serchhip', 'Lawngtlai'],
    'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Tuensang', 'Wokha', 'Zunheboto', 'Kiphire', 'Phek'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Brahmapur', 'Sambalpur', 'Puri', 'Balasore', 'Bhadrak', 'Baripada', 'Jharsuguda', 'Bargarh', 'Rayagada', 'Koraput', 'Angul'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Hoshiarpur', 'Mohali', 'Batala', 'Pathankot', 'Moga', 'Abohar', 'Malerkotla', 'Khanna', 'Phagwara', 'Muktsar', 'Faridkot'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner', 'Ajmer', 'Bhilwara', 'Alwar', 'Bharatpur', 'Sikar', 'Pali', 'Sri Ganganagar', 'Kishangarh', 'Baran', 'Tonk', 'Hanumangarh', 'Beawar'],
    'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing', 'Mangan', 'Singtam', 'Rangpo', 'Jorethang'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Tiruppur', 'Erode', 'Vellore', 'Thoothukudi', 'Dindigul', 'Thanjavur', 'Ranipet', 'Sivakasi', 'Karur', 'Ooty', 'Hosur', 'Nagercoil', 'Kanchipuram'],
    'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam', 'Ramagundam', 'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Suryapet', 'Miryalaguda', 'Jagtial'],
    'Tripura': ['Agartala', 'Udaipur', 'Dharmanagar', 'Kailashahar', 'Belonia', 'Khowai', 'Bishalgarh', 'Ambassa'],
    'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Varanasi', 'Meerut', 'Prayagraj', 'Bareilly', 'Aligarh', 'Moradabad', 'Saharanpur', 'Gorakhpur', 'Noida', 'Firozabad', 'Jhansi', 'Muzaffarnagar', 'Mathura', 'Ayodhya', 'Rampur', 'Shahjahanpur'],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Rudrapur', 'Kashipur', 'Rishikesh', 'Mussoorie', 'Nainital', 'Almora', 'Pithoragarh'],
    'West Bengal': ['Kolkata', 'Howrah', 'Darjeeling', 'Siliguri', 'Asansol', 'Durgapur', 'Bardhaman', 'English Bazar', 'Baharampur', 'Habra', 'Kharagpur', 'Shantipur', 'Dankuni', 'Haldia', 'Jalpaiguri', 'Kalyani', 'Raiganj'],
    
    // 8 Union Territories
    'Andaman and Nicobar Islands': ['Port Blair', 'Garacharma', 'Bambooflat', 'Prothrapur'],
    'Chandigarh': ['Chandigarh'],
    'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Diu', 'Silvassa', 'Amli'],
    'Delhi': ['New Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi', 'Central Delhi', 'Shahdara', 'Rohini', 'Dwarka', 'Chanakyapuri', 'Connaught Place'],
    'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Kathua', 'Sopore', 'Bandipora', 'Poonch', 'Kupwara', 'Udhampur', 'Pulwama'],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<String> displayItems = [];
          
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            _indiaLocations.forEach((state, cities) {
              if (state.toLowerCase().contains(query) && !displayItems.contains(state)) displayItems.add(state);
              for (var city in cities) {
                if (city.toLowerCase().contains(query) && !displayItems.contains(city)) displayItems.add(city);
              }
            });
          } else if (selectedState != null) {
            displayItems = ['All of $selectedState', ...(_indiaLocations[selectedState] ?? [])];
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
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      )
                    else
                      const Icon(Icons.location_on, color: Color(0xFFFFB347)),
                    Text(
                      selectedState != null && searchQuery.isEmpty ? selectedState! : 'Broadcast Region',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _location = 'Global');
                        _updateProfile({'location': 'Global'});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Global', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
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
                          const Text('Current Profile Location', style: TextStyle(color: textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_location, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          setSheetState(() => isFetching = true);
                          try {
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) throw 'Location disabled';
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) throw 'Permission denied';
                            }
                            final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)));
                            final res = await http.get(
                              Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&addressdetails=1'),
                              headers: {'User-Agent': 'MeetraApp/1.0'},
                            ).timeout(const Duration(seconds: 8));
                            if (res.statusCode == 200) {
                              final data = jsonDecode(res.body);
                              final address = data['address'] ?? {};
                              final city = address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'] ?? '';
                              final state = address['state'] ?? '';
                              String locStr = [city, state].where((e) => e.toString().trim().isNotEmpty).join(', ');
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB347).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isFetching
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Color(0xFFFFB347), strokeWidth: 2))
                            : const Row(
                                children: [
                                  Icon(Icons.my_location, color: Color(0xFFFFB347), size: 14),
                                  SizedBox(width: 4),
                                  Text('Auto-Fetch', style: TextStyle(color: Color(0xFFFFB347), fontSize: 12, fontWeight: FontWeight.bold)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                        title: Text(item, style: TextStyle(color: isAll ? const Color(0xFFFFB347) : Colors.white, fontWeight: isAll ? FontWeight.bold : FontWeight.normal)),
                        trailing: (isState && searchQuery.isEmpty) ? const Icon(Icons.chevron_right, color: textMuted) : null,
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

// Custom Clipper for the Hexagon Badges
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0); // Top center
    path.lineTo(size.width, size.height * 0.25); // Top right
    path.lineTo(size.width, size.height * 0.75); // Bottom right
    path.lineTo(size.width * 0.5, size.height); // Bottom center
    path.lineTo(0, size.height * 0.75); // Bottom left
    path.lineTo(0, size.height * 0.25); // Top left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _FollowListSheet extends StatefulWidget {
  final String targetId;
  final String type; // 'Followers' or 'Following'
  final Function(String) onProfileTap;

  const _FollowListSheet({required this.targetId, required this.type, required this.onProfileTap});

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  Set<String> _myFollowings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final myId = _sb.auth.currentUser?.id ?? '';
      if (myId.isNotEmpty) {
        final myFollowingData = await _sb.from('bolroom_follows').select('following_id').eq('follower_id', myId);
        _myFollowings = (myFollowingData as List).map((e) => e['following_id'].toString()).toSet();
      }

      final isFollowers = widget.type == 'Followers';
      final matchCol = isFollowers ? 'following_id' : 'follower_id';
      final fetchCol = isFollowers ? 'follower_id' : 'following_id';

      final List<dynamic> rels = await _sb.from('bolroom_follows').select(fetchCol).eq(matchCol, widget.targetId);
      
      if (rels.isEmpty) {
        if (mounted) setState(() { _loading = false; });
        return;
      }

      final ids = rels.map((e) => e[fetchCol].toString()).toList();
      final profiles = await _sb.from('bolroom_profiles').select('*').inFilter('id', ids);
      
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(profiles); _loading = false; });
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
        await _sb.from('bolroom_follows').delete().eq('follower_id', myId).eq('following_id', uid);
      } else {
        await _sb.from('bolroom_follows').insert({'follower_id': myId, 'following_id': uid});
        final me = await _sb.from('bolroom_profiles').select('anon_name').eq('id', myId).maybeSingle();
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(widget.type, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2), strokeWidth: 2))
                : _users.isEmpty 
                  ? Center(child: Text('No ${widget.type.toLowerCase()} yet.', style: const TextStyle(color: Color(0xFF8E8B99), fontSize: 16)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final u = _users[index];
                        final Color aura = Color(int.tryParse('FF${(u['aura_color'] ?? '#8A2BE2').replaceFirst('#', '')}') ?? 0xFF8A2BE2);
                          final uid = u['id']?.toString() ?? '';
                          final isMe = uid == (_sb.auth.currentUser?.id ?? '');
                          final isFollowing = _myFollowings.contains(uid);

                          Widget trailingAction = const SizedBox.shrink();
                          if (!isMe) {
                            trailingAction = GestureDetector(
                              onTap: () => _toggleFollowUser(uid, u['anon_name'] ?? 'User'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isFollowing ? Colors.transparent : const Color(0xFF1E90FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isFollowing ? Colors.white38 : Colors.transparent),
                                ),
                                child: Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: isFollowing ? Colors.white : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            leading: GestureDetector(
                              onTap: () => widget.onProfileTap(uid),
                              child: BolroomAvatarWidget(
                                size: 50,
                                avatarUrl: u['avatar_url']?.toString(),
                                avatarKey: u['avatar_key']?.toString(),
                                userId: uid,
                                showRing: true,
                              ),
                            ),
                            title: GestureDetector(
                              onTap: () => widget.onProfileTap(uid),
                              child: Text(u['anon_name'] ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))
                            ),
                            subtitle: Text(u['location'] ?? 'Global', style: const TextStyle(color: Color(0xFF8E8B99), fontSize: 13)),
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

class _VoicePadPainter extends CustomPainter {
  final double dotX;
  final double dotY;
  const _VoicePadPainter({required this.dotX, required this.dotY});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // === Background gradient (dark left, bright right, low bottom, high top) ===
    // Row 1: top-left=dark-high, top-right=bright-high
    // Row 2: bottom-left=dark-low, bottom-right=bright-low
    final bgPaint = Paint();
    final bgRect = Rect.fromLTWH(0, 0, w, h);

    // Vertical gradient: deep purple bottom, indigo top
    bgPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A0A2E), Color(0xFF0C0914)],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Horizontal tint overlay: cyan tint on right (brightness)
    bgPaint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        const Color(0xFFFF6B00).withAlpha(30),
      ],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // === Zone region fills ===
    final zonePaint = Paint()..style = PaintingStyle.fill;
    // High zone (top third) - slight purple tint
    zonePaint.color = const Color(0xFF8A2BE2).withAlpha(20);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), zonePaint);
    // Low zone (bottom third) - slight orange tint
    zonePaint.color = const Color(0xFFFF6600).withAlpha(15);
    canvas.drawRect(Rect.fromLTWH(0, h * 2 / 3, w, h / 3), zonePaint);

    // === Grid lines ===
    final gridPaint = Paint()
      ..color = const Color(0xFF231D38)
      ..strokeWidth = 0.8;
    for (int i = 1; i < 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (int i = 1; i < 4; i++) {
      final x = w * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // === Center crosshair (neutral point) ===
    final crossPaint = Paint()
      ..color = const Color(0xFFFF6B00).withAlpha(50)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), crossPaint);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), crossPaint);

    // === Pitch zone labels on Y axis ===
    _drawZoneLabel(canvas, 'High', Offset(w * 0.5, h * 0.12), true);
    _drawZoneLabel(canvas, 'Mid',  Offset(w * 0.5, h * 0.5),  true);
    _drawZoneLabel(canvas, 'Low',  Offset(w * 0.5, h * 0.88), true);

    // === Ripple rings around dot position ===
    final ripplePaint = Paint()
      ..color = const Color(0xFFFF6B00).withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(dotX, dotY), 24, ripplePaint);
    ripplePaint.color = const Color(0xFFFF6B00).withAlpha(12);
    canvas.drawCircle(Offset(dotX, dotY), 38, ripplePaint);
  }

  void _drawZoneLabel(Canvas canvas, String text, Offset center, bool horizontal) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Color(0x30FFFFFF), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_VoicePadPainter old) => old.dotX != dotX || old.dotY != dotY;
}
