import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'services/location_service.dart';
import 'image_upload_service.dart';
import 'widgets/location_picker_sheet.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/doodle_theme.dart';
import 'messages_screen.dart';

// --- Data Models ---
class Community {
  final String id;
  final String name;
  final String category;
  final String creatorId;
  final int memberCount;
  final String avatar;
  final String lastMessage;
  final String lastMessageTime;
  int unreadCount;
  final String? locationDistrict;
  final List<CommunityChannel> channels;
  final bool isPrivate;
  final String chatType;
  final bool isBroadcastOnly;

  Community({
    required this.id,
    required this.name,
    required this.category,
    required this.creatorId,
    required this.memberCount,
    required this.avatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.locationDistrict,
    required this.channels,
    this.isPrivate = false,
    this.chatType = 'group',
    this.isBroadcastOnly = false,
  });
}

class CommunityChannel {
  final String name;
  final List<CommunityMessage> messages;
  CommunityChannel({required this.name, required this.messages});
}

class CommunityMessage {
  final String id;
  final String userId;
  final String username;
  final String avatar;
  final String timestamp;
  final String text;
  final bool isModerator;

  CommunityMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.timestamp,
    required this.text,
    this.isModerator = false,
  });
}

// --- Sample Data ---
final _sampleMessages = [
  CommunityMessage(id: '1', userId: 'u1', username: 'Zion', avatar: 'https://i.pravatar.cc/150?u=Zion', timestamp: '10:30 AM', text: "Hey everyone! Welcome to the new members!", isModerator: true),
  CommunityMessage(id: '2', userId: 'u2', username: 'Maya', avatar: 'https://i.pravatar.cc/150?u=Maya', timestamp: '10:32 AM', text: "Thanks! Excited to be here. What's everyone up to this weekend?"),
  CommunityMessage(id: '3', userId: 'u3', username: 'Aria', avatar: 'https://i.pravatar.cc/150?u=Aria', timestamp: '10:35 AM', text: "There's a great art exhibition opening in SoHo. Anyone want to check it out?"),
  CommunityMessage(id: '4', userId: 'u4', username: 'Kai', avatar: 'https://i.pravatar.cc/150?u=Kai', timestamp: '10:36 AM', text: "I'm down! What time?"),
  CommunityMessage(id: '5', userId: 'u5', username: 'Luna', avatar: 'https://i.pravatar.cc/150?u=Luna', timestamp: '10:38 AM', text: "Count me in too. Love discovering new artists."),
];

class CommunitiesListWidget extends StatefulWidget {
  final String searchQuery;
  const CommunitiesListWidget({super.key, this.searchQuery = ''});

  @override
  State<CommunitiesListWidget> createState() => _CommunitiesListWidgetState();
}

class _CommunitiesListWidgetState extends State<CommunitiesListWidget> {
  List<Community> _communities = [];
  bool _isLoading = true;
  RealtimeChannel? _listChannel;

  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Local', 'Joined'];
  Set<String> _joinedCommunityIds = {};

  @override
  void initState() {
    super.initState();
    _fetchCamps();
    _subscribeRealtime();
    locationService.activeDistrictNotifier.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    locationService.activeDistrictNotifier.removeListener(_onLocationChanged);
    _listChannel?.unsubscribe();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) {
      _fetchCamps();
      setState(() {});
    }
  }

  void _subscribeRealtime() {
    _listChannel = Supabase.instance.client
        .channel('public:communities_list_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'text_camps',
          callback: (payload) => _fetchCamps(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'text_camp_messages',
          callback: (payload) => _fetchCamps(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'text_camp_members',
          callback: (payload) => _fetchCamps(),
        )
        .subscribe();
  }

  String _cleanSavedDistrict(String? raw) {
    if (raw == null) return 'Unknown';
    String d = raw.trim();
    if (d.isEmpty) return 'Unknown';
    
    if (d.toLowerCase().contains('bundelkhand') || 
        d.toLowerCase().contains('engineering') || 
        d.toLowerCase().contains('biet') || 
        d.toLowerCase().contains('kanpur road')) {
      return 'Jhansi';
    }
    
    final cleaned = locationService.sanitizeDistrict(d, '');
    if (cleaned.length > 25) {
      return '${cleaned.substring(0, 22)}...';
    }
    return cleaned;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _fetchCamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final membersRes = await Supabase.instance.client
            .from('text_camp_members')
            .select('camp_id')
            .eq('user_id', uid);
        _joinedCommunityIds = (membersRes as List).map((m) => m['camp_id'].toString()).toSet();
      }

      final res = await Supabase.instance.client
          .from('text_camps')
          .select('*, text_camp_messages(user_id, text, created_at)')
          .order('created_at', ascending: false)
          .order('created_at', referencedTable: 'text_camp_messages', ascending: false)
          .limit(1, referencedTable: 'text_camp_messages');

      final List<Community> fetched = (res as List).map((row) {
        final messagesList = row['text_camp_messages'] as List?;
        String lastMsg = "Welcome to ${row['name']}!";
        String lastMsgTime = "Just now";
        int unreadCount = 0;
        if (messagesList != null && messagesList.isNotEmpty) {
          final first = messagesList.first;
          final rawText = first['text'] as String? ?? '';
          if (rawText.startsWith('[IMAGE]')) {
            lastMsg = '📷 Photo';
          } else if (rawText.startsWith('[AUDIO]')) {
            lastMsg = '🎵 Voice message';
          } else {
            lastMsg = rawText;
          }
          final createdAtStr = first['created_at'] as String?;
          if (createdAtStr != null) {
            try {
              final dt = DateTime.parse(createdAtStr).toLocal();
              lastMsgTime = _formatTime(dt);
            } catch (_) {}
          }
          final senderId = first['user_id'] as String? ?? '';
          if (uid != null && senderId != uid) {
            final lastReadStr = prefs.getString('community_last_read_${row['id']}');
            if (lastReadStr != null && createdAtStr != null) {
              try {
                final lastRead = DateTime.parse(lastReadStr);
                final msgTime = DateTime.parse(createdAtStr);
                if (msgTime.isAfter(lastRead)) {
                  unreadCount = 1;
                }
              } catch (_) {}
            } else {
              unreadCount = 1;
            }
          }
        }

        return Community(
          id: row['id'] ?? '',
          name: row['name'] ?? '',
          category: row['category'] ?? 'General',
          creatorId: row['creator_id'] ?? '',
          memberCount: row['member_count'] ?? 1,
          avatar: row['avatar_url'] ?? 'https://images.unsplash.com/photo-1516862523118-a3724eb136d7?auto=format&fit=crop&w=150&q=80',
          lastMessage: lastMsg,
          lastMessageTime: lastMsgTime,
          unreadCount: unreadCount,
          locationDistrict: _cleanSavedDistrict(row['location_district'] as String?),
          channels: [CommunityChannel(name: 'general', messages: _sampleMessages)],
          isPrivate: row['is_private'] ?? false,
          chatType: row['chat_type'] ?? 'group',
          isBroadcastOnly: row['is_broadcast_only'] ?? false,
        );
      }).toList();
      
      if (mounted) {
        setState(() {
          _communities = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching text_camps: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openCommunity(Community community) {
    HapticFeedback.lightImpact();
    setState(() {
      community.unreadCount = 0;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('community_last_read_${community.id}', DateTime.now().toUtc().toIso8601String());
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChatRoomScreen(community: community),
      ),
    );
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    String photoUrl = '';
    bool isPrivate = false;

    // Auto-fetch user location from profile if not yet resolved
    _loadLocationForCreateSheet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF090710),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF231D38),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Create TEXT CAMP', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('Start a new real-world social loop', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 22),
                
                // Photo Upload
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final url = await ImageUploadService.pickAndUpload(context: context, folder: 'communities');
                      if (url != null && url.isNotEmpty) {
                        setSheet(() => photoUrl = url);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF13101E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.5), width: 2),
                        image: photoUrl.isNotEmpty
                            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: photoUrl.isEmpty
                          ? const Icon(Icons.add_a_photo, color: Color(0xFFFF6B00))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Community Name...',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF13101E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF231D38))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF231D38))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: const Color(0xFFFF6B00).withValues(alpha: 0.4))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catCtrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Interest (e.g. Art, Tech, Food)...',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF13101E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF231D38))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF231D38))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: const Color(0xFFFF6B00).withValues(alpha: 0.4))),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location Display — reactive to locationService ValueNotifiers
                Text('YOUR LOCATION', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: locationService.activeDistrictNotifier,
                  builder: (_, district, __) {
                    return ValueListenableBuilder<String>(
                      valueListenable: locationService.activeStateNotifier,
                      builder: (_, stateVal, __) {
                        final isLoading = district.isEmpty && stateVal.isEmpty;
                        final locStr = district.isNotEmpty && stateVal.isNotEmpty
                            ? '$district, $stateVal'
                            : district.isNotEmpty
                                ? district
                                : stateVal.isNotEmpty
                                    ? stateVal
                                    : null;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: locStr != null
                                  ? const Color(0xFFFF6B00).withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: locStr != null ? const Color(0xFFFF6B00) : Colors.white38,
                                  size: 18),
                              const SizedBox(width: 10),
                              if (isLoading) ...[
                                const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)),
                                ),
                                const SizedBox(width: 10),
                                Text('Detecting location...', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                              ] else
                                Text(
                                  locStr ?? 'Location unavailable',
                                  style: GoogleFonts.inter(
                                    color: locStr != null ? Colors.white : Colors.white38,
                                    fontSize: 14,
                                    fontWeight: locStr != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Public / Private Community Choice
                Text('PRIVACY SETTING', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setSheet(() => isPrivate = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isPrivate ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : const Color(0xFF13101E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !isPrivate ? const Color(0xFFFF6B00) : const Color(0xFF231D38),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.public, color: !isPrivate ? const Color(0xFFFF6B00) : Colors.white54, size: 20),
                              const SizedBox(height: 4),
                              Text('Public', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Anyone can join', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setSheet(() => isPrivate = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isPrivate ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : const Color(0xFF13101E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPrivate ? const Color(0xFFFF6B00) : const Color(0xFF231D38),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.lock_outline, color: isPrivate ? const Color(0xFFFF6B00) : Colors.white54, size: 20),
                              const SizedBox(height: 4),
                              Text('Private', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Requires host approval', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ValueListenableBuilder<String>(
                    valueListenable: locationService.activeDistrictNotifier,
                    builder: (_, currentDist, __) {
                      return ValueListenableBuilder<String>(
                        valueListenable: locationService.activeStateNotifier,
                        builder: (_, currentState, __) {
                          return ElevatedButton(
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final cat = catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim();
                              final uid = Supabase.instance.client.auth.currentUser?.id;
                              if (uid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
                                return;
                              }
                              try {
                                final res = await Supabase.instance.client.from('text_camps').insert({
                                  'name': nameCtrl.text.trim(),
                                  'category': cat,
                                  'avatar_url': photoUrl.isNotEmpty ? photoUrl : null,
                                  'location_district': currentDist.isNotEmpty ? currentDist : null,
                                  'location_state': currentState.isNotEmpty ? currentState : null,
                                  'creator_id': uid,
                                  'is_private': isPrivate,
                                }).select().single();

                                await Supabase.instance.client.from('text_camp_members').insert({
                                  'camp_id': res['id'],
                                  'user_id': uid,
                                });

                                final newComm = Community(
                                  id: res['id'],
                                  name: res['name'],
                                  category: res['category'] ?? 'General',
                                  creatorId: res['creator_id'] ?? uid,
                                  memberCount: res['member_count'] ?? 1,
                                  avatar: res['avatar_url'] ?? 'https://images.unsplash.com/photo-1516862523118-a3724eb136d7?auto=format&fit=crop&w=150&q=80',
                                  lastMessage: 'Welcome to ${res['name']}!',
                                  lastMessageTime: 'Just now',
                                  unreadCount: 0,
                                  locationDistrict: _cleanSavedDistrict(res['location_district'] as String?),
                                  channels: [CommunityChannel(name: 'general', messages: [])],
                                  isPrivate: res['is_private'] ?? false,
                                );
                                setState(() => _communities.insert(0, newComm));
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                              } catch (e) {
                                debugPrint('Insert text_camp error: $e');
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create community: $e')));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text('Create Community', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                          );
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


  /// Fetches user location from profile or requests live GPS coordinates,
  /// then reverse geocodes via Nominatim.
  Future<void> _loadLocationForCreateSheet() async {
    if (locationService.activeDistrict.isNotEmpty) return;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('lat, lng, city, district, state')
          .eq('id', uid)
          .maybeSingle();

      double? lat;
      double? lng;
      String savedLocation = '';
      String? savedDistrict;
      String? savedState;

      if (profile != null) {
        lat = (profile['lat'] as num?)?.toDouble();
        lng = (profile['lng'] as num?)?.toDouble();
        savedLocation = profile['city'] as String? ?? profile['district'] as String? ?? '';
        savedDistrict = profile['district'] as String?;
        savedState = profile['state'] as String?;
      }

      // Fallback to live device GPS location if profile lacks coordinates
      if (lat == null || lng == null) {
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
              final position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: Duration(seconds: 8),
                ),
              );
              lat = position.latitude;
              lng = position.longitude;
            }
          }
        } catch (e) {
          debugPrint('Geolocator auto-fetch error: $e');
        }
      }

      if (lat != null && lng != null) {
        await _nominatimReverse(lat, lng);
      } else if (savedLocation.isNotEmpty) {
        if (savedDistrict != null && savedDistrict.isNotEmpty) {
          locationService.setLocation(savedLocation, lat: lat, lng: lng, district: savedDistrict, state: savedState);
        } else {
          final parts = savedLocation.split(',').map((p) => p.trim()).toList();
          final district = locationService.sanitizeDistrict(
            parts.isNotEmpty ? parts.first : '',
            savedLocation,
          );
          final state = parts.length > 1 ? parts[1] : '';
          locationService.setLocation(savedLocation, lat: lat, lng: lng, district: district, state: state);
        }
      }
    } catch (e) {
      debugPrint('_loadLocationForCreateSheet error: $e');
    }
  }

  Future<void> _nominatimReverse(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'RelayaApp/1.0');
      final resp = await request.close();
      final body = await resp.transform(const Utf8Decoder()).join();
      httpClient.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      final rawDistrict = (addr['city']
          ?? addr['town']
          ?? addr['village']
          ?? addr['municipality']
          ?? addr['county']
          ?? addr['state_district']
          ?? '').toString();
      final district = locationService.sanitizeDistrict(
          rawDistrict, data['display_name']?.toString() ?? '');
      final state = addr['state']?.toString() ?? '';
      locationService.setLocation(
        data['display_name']?.toString() ?? '',
        lat: lat, lng: lng,
        district: district,
        state: state,
      );
    } catch (e) {
      debugPrint('_nominatimReverse error: $e');
    }
  }


  Widget _buildFilters() {
    final activeDistrict = locationService.activeDistrict;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _activeFilter = filter);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF16161D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF27272A)),
                      ),
                      child: Center(
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (activeDistrict.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  locationService.setLocation('', district: '', state: '');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13101E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        activeDistrict,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.close, color: Colors.white54, size: 12),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                showLocationSearchSheet(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161D),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    List<Community> filteredCommunities = _communities.where((c) {
      // 1. Text Search Filter
      if (widget.searchQuery.isNotEmpty && !c.name.toLowerCase().contains(widget.searchQuery.toLowerCase())) {
        return false;
      }

      // 2. Chip Filter Logic
      if (_activeFilter == 'Joined') {
        return _joinedCommunityIds.contains(c.id);
      }

      // 3. Local-only filter
      if (_activeFilter == 'Local') {
        final userDistrict = locationService.activeDistrict;
        if (userDistrict.isEmpty || userDistrict == 'Unknown') return false;
        final ud = userDistrict.toLowerCase().trim();
        final cd = (c.locationDistrict ?? '').toLowerCase().trim();
        return cd.contains(ud) || ud.contains(cd);
      }

      // 4. 'All': district soft filter (show community if untagged OR matches district)
      final userDistrict = locationService.activeDistrict;
      if (userDistrict.isNotEmpty && userDistrict != 'Unknown') {
        final ud = userDistrict.toLowerCase().trim();
        final cd = (c.locationDistrict ?? '').toLowerCase().trim();
        if (cd.isEmpty || cd == 'unknown') return true;
        return cd.contains(ud) || ud.contains(cd);
      }
      return true;
    }).toList();

    // Sort: local communities first in 'All' view
    if (_activeFilter == 'All') {
      final userDistrict = locationService.activeDistrict.toLowerCase().trim();
      filteredCommunities.sort((a, b) {
        final aIsLocal = userDistrict.isNotEmpty &&
            ((a.locationDistrict ?? '').toLowerCase().contains(userDistrict) ||
             userDistrict.contains((a.locationDistrict ?? '').toLowerCase()));
        final bIsLocal = userDistrict.isNotEmpty &&
            ((b.locationDistrict ?? '').toLowerCase().contains(userDistrict) ||
             userDistrict.contains((b.locationDistrict ?? '').toLowerCase()));
        if (aIsLocal && !bIsLocal) return -1;
        if (!aIsLocal && bIsLocal) return 1;
        return b.memberCount.compareTo(a.memberCount);
      });
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(),
        Expanded(
          child: _CommunitiesListView(
            communities: filteredCommunities,
            onTapCommunity: _openCommunity,
            onCreateTap: _showCreateSheet,
          ),
        ),
      ],
    );
  }
}

class CommunitiesStandaloneScreen extends StatefulWidget {
  const CommunitiesStandaloneScreen({super.key});

  @override
  State<CommunitiesStandaloneScreen> createState() => _CommunitiesStandaloneScreenState();
}

class _CommunitiesStandaloneScreenState extends State<CommunitiesStandaloneScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleTab() {
    final nextIndex = _currentIndex == 0 ? 1 : 0;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDoodle = isDoodleMode(context);
    final bgColor = isDoodle ? DoodleColors.cream : const Color(0xFF000000);
    final textColor = isDoodle ? DoodleColors.textPrimary : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDoodle ? DoodleColors.paper : const Color(0xFF1A1A1A),
                        shape: BoxShape.circle,
                        border: isDoodle ? Border.all(color: DoodleColors.cardBorder) : null,
                      ),
                      child: Icon(Icons.arrow_back, color: textColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Text Camps',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.search, color: textColor),
                    onPressed: () {
                      // TODO: Implement search if needed
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: const Color(0xFFFF6B00)),
                    onPressed: () {
                      // TODO: Implement add logic
                    },
                  ),
                ],
              ),
            ),
            
            // ── Section Title (Direct Messages or Groups) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentIndex == 0 ? 'Direct Messages' : 'Groups',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: 2,
                    color: const Color(0xFFFF6B00),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Content PageView ──
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: [
                  ChatsView(searchQuery: '', filter: 'All'),
                  const CommunitiesListWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _toggleTab();
          },
          backgroundColor: const Color(0xFFFF6B00),
          elevation: 4,
          child: Icon(
            _currentIndex == 0 ? Icons.groups : Icons.chat_bubble_outline,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 1: Communities List
// ==========================================
class _CommunitiesListView extends StatelessWidget {
  final List<Community> communities;
  final Function(Community) onTapCommunity;
  final VoidCallback onCreateTap;

  const _CommunitiesListView({
    required this.communities,
    required this.onTapCommunity,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // List
            Expanded(
              child: communities.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.explore_off_rounded, color: Color(0xFFFF6B00), size: 48),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Camps Found',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different filter or search query\\nto discover new communities.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 100),
                itemCount: communities.length + 1,
                itemBuilder: (context, index) {
                  // Static "New Community" button at the top
                  if (index == 0) {
                    return InkWell(
                      onTap: onCreateTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF23252A),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.group_add, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'New Community',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final c = communities[index - 1];
                  final bool isUnread = c.unreadCount > 0;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A2D35)),
                    ),
                    child: InkWell(
                      onTap: () => onTapCommunity(c),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(c.avatar),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.lastMessage,
                                    style: GoogleFonts.inter(
                                      color: isUnread ? const Color(0xFFFF6B00) : Colors.white54,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.people_outline, color: Colors.white54, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${c.memberCount} members',
                                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                      ),
                                      if (c.lastMessageTime.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '· ${c.lastMessageTime}',
                                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isUnread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                                child: Text(
                                  '${c.unreadCount}',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              const Icon(Icons.chevron_right, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

      ],
    );
  }
}

// ==========================================
// SCREEN 2: Community Chat Room
// ==========================================
class CommunityChatRoomScreen extends StatefulWidget {
  final Community community;

  const CommunityChatRoomScreen({super.key, required this.community});

  @override
  State<CommunityChatRoomScreen> createState() => _CommunityChatRoomScreenState();
}

class _CommunityChatRoomScreenState extends State<CommunityChatRoomScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, Map<String, dynamic>> _profileCache = {};
  bool _showEmojiPicker = false;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  // Reply-to
  Map<String, dynamic>? _replyToMessage;

  // Reactions: messageId -> list of reaction records
  final Map<String, List<Map<String, dynamic>>> _reactionsCache = {};

  // Pinned message
  Map<String, dynamic>? _pinnedMessage;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _loadPinnedMessage();
  }

  void _loadPinnedMessage() async {
    try {
      final pinRes = await Supabase.instance.client
          .from('text_camp_pinned_messages')
          .select()
          .eq('camp_id', widget.community.id)
          .maybeSingle();

      if (pinRes != null) {
        final msgId = pinRes['message_id'];
        final msgRes = await Supabase.instance.client
            .from('text_camp_messages')
            .select()
            .eq('id', msgId)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _pinnedMessage = msgRes; // null-safe: will be null if message was deleted
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _pinnedMessage = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pinned message: $e');
    }
  }

  void _pinMessage(Map<String, dynamic> msg) async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null) return;
    try {
      await Supabase.instance.client
          .from('text_camp_pinned_messages')
          .upsert({
            'camp_id': widget.community.id,
            'message_id': msg['id'],
            'pinned_by': myUid,
            'pinned_at': DateTime.now().toUtc().toIso8601String(),
          });
      _loadPinnedMessage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message pinned to top! 📌')),
        );
      }
    } catch (e) {
      debugPrint('Error pinning message: $e');
    }
  }

  void _unpinMessage() async {
    try {
      await Supabase.instance.client
          .from('text_camp_pinned_messages')
          .delete()
          .eq('camp_id', widget.community.id);
      if (mounted) {
        setState(() {
          _pinnedMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unpinned!')),
        );
      }
    } catch (e) {
      debugPrint('Error unpinning message: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await Supabase.instance.client
          .from('text_camp_messages')
          .select()
          .eq('camp_id', widget.community.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
        _loadAllReactions();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _channel = Supabase.instance.client
        .channel('text_camp_messages:${widget.community.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'text_camp_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'camp_id',
            value: widget.community.id,
          ),
          callback: (payload) {
            final event = payload.eventType;
            if (event == PostgresChangeEvent.insert) {
              final newRow = payload.newRecord;
              if (mounted && newRow.isNotEmpty) {
                final alreadyExists = _messages.any((m) => m['id'] == newRow['id']);
                if (!alreadyExists) {
                  setState(() {
                    _messages.insert(0, newRow);
                  });
                  _scrollToBottom();
                }
              }
            } else if (event == PostgresChangeEvent.delete) {
              final oldRow = payload.oldRecord;
              if (mounted && oldRow.isNotEmpty) {
                setState(() {
                  _messages.removeWhere((m) => m['id'] == oldRow['id']);
                });
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'text_camp_message_reactions',
          callback: (payload) {
            final event = payload.eventType;
            if (event == PostgresChangeEvent.insert) {
              final newRow = payload.newRecord;
              final mid = newRow['message_id'] as String?;
              if (mid != null) {
                _loadReactionsFor(mid);
              }
            } else if (event == PostgresChangeEvent.delete) {
              final oldRow = payload.oldRecord;
              final mid = oldRow['message_id'] as String?;
              if (mid != null) {
                _loadReactionsFor(mid);
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _textCtrl.dispose();
    _scrollController.dispose();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('community_last_read_${widget.community.id}', DateTime.now().toUtc().toIso8601String());
    });
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<Map<String, dynamic>> _getProfile(String uid) async {
    if (_profileCache.containsKey(uid)) return _profileCache[uid]!;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (res != null) {
        _profileCache[uid] = res;
        return res;
      }
    } catch (_) {}
    return {'name': 'Unknown', 'avatar_url': 'https://i.pravatar.cc/150'};
  }

  void _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _textCtrl.clear();
    final replyId = _replyToMessage?['id'] as String?;
    if (mounted) setState(() => _replyToMessage = null);

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'camp_id': widget.community.id,
      'user_id': uid,
      'text': text,
      'reply_to_id': replyId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (mounted) {
      setState(() => _messages.insert(0, tempMsg));
      _scrollToBottom();
    }

    try {
      final payload = <String, dynamic>{
        'camp_id': widget.community.id,
        'user_id': uid,
        'text': text,
      };
      if (replyId != null) payload['reply_to_id'] = replyId;
      final inserted = await Supabase.instance.client
          .from('text_camp_messages').insert(payload).select().single();
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) _messages[idx] = inserted;
        });
      }
    } catch (e) {
      debugPrint('Failed to send: $e');
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['id'] == tempId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  static const _quickReactions = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

  void _showMessageOptions(Map<String, dynamic> msg) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final isOwn = msg['user_id'] == myUid;
    final isHost = myUid == widget.community.creatorId;
    final msgId = msg['id'].toString();
    final isTemp = msgId.startsWith('temp_');
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0B14),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Quick reactions row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _quickReactions.map((e) => GestureDetector(
                onTap: () { Navigator.pop(ctx); _toggleReaction(msg['id'], e); },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          if (!isTemp)
            _optionTile(Icons.reply, 'Reply', () { Navigator.pop(ctx); setState(() => _replyToMessage = msg); }),
          _optionTile(Icons.copy, 'Copy', () { Navigator.pop(ctx); Clipboard.setData(ClipboardData(text: msg['text'] ?? '')); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'))); }),
          if (isHost)
            _optionTile(
              _pinnedMessage?['id'] == msg['id'] ? Icons.pin_drop_outlined : Icons.pin_drop,
              _pinnedMessage?['id'] == msg['id'] ? 'Unpin Message' : 'Pin Message',
              () {
                Navigator.pop(ctx);
                if (_pinnedMessage?['id'] == msg['id']) {
                  _unpinMessage();
                } else {
                  _pinMessage(msg);
                }
              },
            ),
          if (isOwn || isHost)
            _optionTile(Icons.delete_outline, 'Delete', () { Navigator.pop(ctx); _deleteMessage(msg); }, color: Colors.redAccent),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70, size: 22),
      title: Text(label, style: GoogleFonts.inter(color: color ?? Colors.white, fontSize: 15)),
      onTap: onTap,
    );
  }

  void _toggleReaction(String? messageId, String emoji) async {
    if (messageId == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final existing = await Supabase.instance.client.from('text_camp_message_reactions')
          .select().eq('message_id', messageId).eq('user_id', uid).eq('emoji', emoji);
      if ((existing as List).isNotEmpty) {
        await Supabase.instance.client.from('text_camp_message_reactions')
            .delete().eq('message_id', messageId).eq('user_id', uid).eq('emoji', emoji);
      } else {
        await Supabase.instance.client.from('text_camp_message_reactions')
            .insert({'message_id': messageId, 'user_id': uid, 'emoji': emoji});
      }
      _loadReactionsFor(messageId);
    } catch (e) { 
      debugPrint('Reaction error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to react: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  void _loadReactionsFor(String messageId) async {
    try {
      final res = await Supabase.instance.client.from('text_camp_message_reactions')
          .select().eq('message_id', messageId);
      if (mounted) setState(() => _reactionsCache[messageId] = List<Map<String, dynamic>>.from(res as List));
    } catch (_) {}
  }

  void _loadAllReactions() async {
    final ids = _messages.map((m) => m['id'] as String?).where((id) => id != null && !id.startsWith('temp_')).toList();
    if (ids.isEmpty) return;
    try {
      final res = await Supabase.instance.client.from('text_camp_message_reactions')
          .select().inFilter('message_id', ids);
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final r in (res as List)) {
        final mid = r['message_id'] as String;
        grouped.putIfAbsent(mid, () => []).add(Map<String, dynamic>.from(r));
      }
      if (mounted) setState(() => _reactionsCache.addAll(grouped));
    } catch (_) {}
  }

  void _deleteMessage(Map<String, dynamic> msg) async {
    final msgId = msg['id'] as String?;
    if (msgId == null) return;
    try {
      await Supabase.instance.client.from('text_camp_messages').delete().eq('id', msgId);
      if (mounted) setState(() => _messages.removeWhere((m) => m['id'] == msgId));
    } catch (e) { debugPrint('Delete error: $e'); }
  }

  bool _isJoining = false;

  void _joinCommunity() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (mounted) setState(() => _isJoining = true);
    try {
      await Supabase.instance.client.from('text_camp_members').insert({
        'camp_id': widget.community.id,
        'user_id': uid,
      });
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Joined ${widget.community.name}! 🎉'),
          backgroundColor: const Color(0xFFFF6B00),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint('Error joining: $e');
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to join: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  void _toggleJoinRequest(bool hasRequested) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _isRequesting = true);
    try {
      if (hasRequested) {
        await Supabase.instance.client
            .from('text_camp_join_requests')
            .delete()
            .eq('camp_id', widget.community.id)
            .eq('user_id', uid);
      } else {
        await Supabase.instance.client
            .from('text_camp_join_requests')
            .insert({
              'camp_id': widget.community.id,
              'user_id': uid,
            });
      }
    } catch (e) {
      debugPrint('Error toggle request: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _approveJoinRequest(String reqUid) async {
    try {
      // 1. Delete request
      await Supabase.instance.client
          .from('text_camp_join_requests')
          .delete()
          .eq('camp_id', widget.community.id)
          .eq('user_id', reqUid);
          
      // 2. Insert into members
      await Supabase.instance.client
          .from('text_camp_members')
          .insert({
            'camp_id': widget.community.id,
            'user_id': reqUid,
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Join request approved! 🎉'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('Approve request error: $e');
    }
  }

  void _declineJoinRequest(String reqUid) async {
    try {
      await Supabase.instance.client
          .from('text_camp_join_requests')
          .delete()
          .eq('camp_id', widget.community.id)
          .eq('user_id', reqUid);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Join request declined.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      debugPrint('Decline request error: $e');
    }
  }

  void _leaveCommunity() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        title: Text('Leave Community?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('You won\'t be able to send messages in ${widget.community.name}.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Leave', style: GoogleFonts.inter(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.from('text_camp_members')
          .delete()
          .eq('camp_id', widget.community.id)
          .eq('user_id', uid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error leaving: $e');
    }
  }

  void _removeMember(String userId) async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid != widget.community.creatorId) return; // host only
    try {
      await Supabase.instance.client.from('text_camp_members')
          .delete()
          .eq('camp_id', widget.community.id)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Remove member error: $e');
    }
  }

  void _showMembersSheet(List<Map<String, dynamic>> members) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final isHost = myUid == widget.community.creatorId;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090710),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        final hostId = widget.community.creatorId;
        final sorted = List<Map<String, dynamic>>.from(members)
          ..sort((a, b) => a['user_id'] == hostId ? -1 : b['user_id'] == hostId ? 1 : 0);
        return DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
          builder: (_, sc) => CustomScrollView(
            controller: sc,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 12),
                    Text(widget.community.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (widget.community.locationDistrict != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            widget.community.locationDistrict!,
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text('${sorted.length} members', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              if (isHost)
                SliverToBoxAdapter(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('text_camp_join_requests')
                        .stream(primaryKey: ['id'])
                        .eq('camp_id', widget.community.id),
                    builder: (context, reqSnap) {
                      final requests = reqSnap.data ?? [];
                      if (requests.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              'JOIN REQUESTS (${requests.length})',
                              style: GoogleFonts.inter(color: const Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: requests.length,
                            itemBuilder: (context, idx) {
                              final reqUid = requests[idx]['user_id'] as String;
                              return FutureBuilder<Map<String, dynamic>>(
                                future: _getProfile(reqUid),
                                builder: (context, profileSnap) {
                                  final name = profileSnap.data?['name'] ?? 'Loading...';
                                  final avatar = profileSnap.data?['avatar_url'] ?? 'https://i.pravatar.cc/150';
                                  return ListTile(
                                    leading: CircleAvatar(backgroundImage: NetworkImage(avatar), backgroundColor: const Color(0xFF1A1A1A)),
                                    title: Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                                          onPressed: () => _approveJoinRequest(reqUid),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                                          onPressed: () => _declineJoinRequest(reqUid),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const Divider(color: Colors.white10),
                        ],
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'MEMBERS',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final memberId = sorted[i]['user_id'] as String? ?? '';
                    final memberIsHost = memberId == hostId;
                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getProfile(memberId),
                      builder: (_, snap) {
                        final name = snap.data?['name'] ?? 'Loading...';
                        final avatar = snap.data?['avatar_url'] ?? 'https://i.pravatar.cc/150';
                        return ListTile(
                          leading: CircleAvatar(backgroundImage: NetworkImage(avatar), backgroundColor: const Color(0xFF1A1A1A)),
                          title: Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: memberIsHost ? Text('Host', style: GoogleFonts.inter(color: const Color(0xFFFF6B00), fontSize: 12)) : null,
                          trailing: isHost && !memberIsHost
                              ? GestureDetector(
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    _removeMember(memberId);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                                    ),
                                    child: Text('Remove', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                )
                              : memberIsHost ? const Icon(Icons.star, color: Color(0xFFFF6B00), size: 18) : null,
                        );
                      },
                    );
                  },
                  childCount: sorted.length,
                ),
              ),
              if (!isHost && myUid != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () { Navigator.pop(sheetCtx); _leaveCommunity(); },
                        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                        label: Text('Leave Community', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStackedAvatars(List<Map<String, dynamic>> members) {
    final displayMembers = members.take(3).toList();
    final extraCount = members.length > 3 ? members.length - 3 : 0;
    
    return GestureDetector(
      onTap: () => _showMembersSheet(members),
      child: Container(
        color: Colors.transparent, // expand tap area
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: displayMembers.length * 18.0 + (extraCount > 0 ? 32.0 : 12.0),
              height: 32,
              child: Stack(
                children: [
                  for (int i = 0; i < displayMembers.length; i++)
                    Positioned(
                      left: i * 18.0,
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _getProfile(displayMembers[i]['user_id']),
                        builder: (context, snap) {
                          final avatarUrl = snap.data?['avatar_url'] as String?;
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(avatarUrl ?? 'https://i.pravatar.cc/150'),
                              backgroundColor: const Color(0xFF1A1A1A),
                            ),
                          );
                        },
                      ),
                    ),
                  if (extraCount > 0)
                    Positioned(
                      left: displayMembers.length * 18.0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+$extraCount', 
                          style: GoogleFonts.inter(
                            color: Colors.white, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: const Color(0xFF2196F3).withValues(alpha: 0.8), offset: const Offset(-1, 0), blurRadius: 4),
                              Shadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.8), offset: const Offset(1, 0), blurRadius: 4),
                            ],
                          )
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

  Widget _buildReplyPreview(String replyToId) {
    final parentMsg = _messages.firstWhere(
      (m) => m['id'] == replyToId,
      orElse: () => <String, dynamic>{},
    );
    if (parentMsg.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Original message deleted',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
        ),
      );
    }

    final parentUserId = parentMsg['user_id'] as String? ?? '';
    final parentText = parentMsg['text'] as String? ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _getProfile(parentUserId),
      builder: (context, snap) {
        final parentName = snap.data?['name'] ?? '...';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(top: 4, bottom: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFFFF6B00), width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                parentName,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF6B00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                parentText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeChannel = widget.community.channels.isNotEmpty
        ? widget.community.channels.first
        : CommunityChannel(name: 'general', messages: []);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('text_camp_members')
              .stream(primaryKey: ['id'])
              .eq('camp_id', widget.community.id)
              .handleError((err) => debugPrint('Member Stream Error: $err')),
          builder: (context, memberSnap) {
            final fetchedMembers = memberSnap.data ?? [];
            final members = List<Map<String, dynamic>>.from(fetchedMembers);
            
            // Ensure creator is in the members list
            if (widget.community.creatorId.isNotEmpty && !members.any((m) => m['user_id'] == widget.community.creatorId)) {
              members.insert(0, {'user_id': widget.community.creatorId, 'camp_id': widget.community.id});
            }

            final currentUid = Supabase.instance.client.auth.currentUser?.id;
            final isHost = currentUid != null && widget.community.creatorId == currentUid;
            final isJoined = members.any((m) => m['user_id'] == currentUid);
            final isMember = isHost || isJoined || (currentUid != null && currentUid == widget.community.creatorId);

            return Column(
              children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.community.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${members.length} members · ${widget.community.category}',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStackedAvatars(members),
            ],
          ),
        ),

        const SizedBox(height: 8),

        if (widget.community.isPrivate && !isMember) ...[
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('text_camp_join_requests')
                  .stream(primaryKey: ['id'])
                  .eq('camp_id', widget.community.id),
              builder: (context, reqSnap) {
                final requests = reqSnap.data ?? [];
                final hasRequested = requests.any((r) => r['user_id'] == currentUid);

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13101E),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.2), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            hasRequested ? Icons.hourglass_empty_rounded : Icons.lock_outline_rounded,
                            color: const Color(0xFFFF6B00),
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Private Community',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This group is private. You must request approval from the host to join and view messages.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isRequesting ? null : () => _toggleJoinRequest(hasRequested),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasRequested ? const Color(0xFF1D1B26) : const Color(0xFFFF6B00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                                side: hasRequested ? const BorderSide(color: Colors.white10) : BorderSide.none,
                              ),
                              elevation: 0,
                            ),
                            child: _isRequesting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    hasRequested ? 'Cancel Join Request' : 'Request to Join',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: hasRequested ? Colors.white70 : Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          if (_pinnedMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF13101E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded, color: Color(0xFFFF6B00), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Scroll to message or show details
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF0D0B14),
                            title: Text('Pinned Message 📌', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                            content: Text(_pinnedMessage!['text'] ?? '', style: GoogleFonts.inter(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Close', style: GoogleFonts.inter(color: const Color(0xFFFF6B00))),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'Pinned: ${_pinnedMessage!['text']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  if (isHost)
                    GestureDetector(
                      onTap: _unpinMessage,
                      child: const Icon(Icons.close, color: Colors.white38, size: 16),
                    ),
                ],
              ),
            ),
          ),


        // Chat List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Be the first to say hi! 👋',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final userId = msg['user_id'] as String? ?? '';
                        final text = msg['text'] as String? ?? '';
                        final msgId = msg['id'] as String? ?? '';
                        final replyToId = msg['reply_to_id'] as String?;
                        final dt = DateTime.tryParse(msg['created_at'] ?? '')?.toLocal() ?? DateTime.now();
                        final timeStr = DateFormat('h:mm a').format(dt);
                        final reactions = _reactionsCache[msgId] ?? [];

                        // Group reactions by emoji
                        final Map<String, int> emojiCounts = {};
                        for (final r in reactions) {
                          final e = r['emoji'] as String? ?? '';
                          emojiCounts[e] = (emojiCounts[e] ?? 0) + 1;
                        }

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getProfile(userId),
                          builder: (context, profileSnap) {
                            final profile = profileSnap.data ?? {'name': '...', 'avatar_url': 'https://i.pravatar.cc/150'};
                            final avatarUrl = profile['avatar_url'] as String?;
                            final username = profile['name'] as String? ?? 'User';

                            return GestureDetector(
                              onLongPress: () => _showMessageOptions(msg),
                              child: Dismissible(
                                key: ValueKey(msgId),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (direction) async {
                                  final isTemp = msgId.startsWith('temp_');
                                  if (!isTemp) {
                                    setState(() => _replyToMessage = msg);
                                  }
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  color: Colors.transparent,
                                  child: const Icon(Icons.reply, color: Colors.white54),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: NetworkImage(avatarUrl ?? 'https://i.pravatar.cc/150'),
                                      backgroundColor: const Color(0xFF1A1A1A),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(username, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                            if (userId == widget.community.creatorId) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(color: const Color(0xFFFF6B00).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                                child: const Icon(Icons.star, color: Color(0xFFFF6B00), size: 10),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Text(timeStr, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                                          ]),
                                          // Reply-to preview
                                          if (replyToId != null) ...[
                                            const SizedBox(height: 4),
                                            _buildReplyPreview(replyToId),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(text, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, height: 1.4)),
                                          // Reactions row
                                          if (emojiCounts.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(spacing: 4, children: emojiCounts.entries.map((e) => GestureDetector(
                                              onTap: () => _toggleReaction(msgId, e.key),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                                                child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 13)),
                                              ),
                                            )).toList()),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),

        // Bottom Input Bar
        Container(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: SafeArea(
            top: false,
            child: isMember 
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyToMessage != null) ...[
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getProfile(_replyToMessage!['user_id'] as String? ?? ''),
                        builder: (context, snap) {
                          final name = snap.data?['name'] ?? '...';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13101E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.reply, color: Color(0xFFFF6B00), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Replying to $name',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFFF6B00),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replyToMessage!['text'] as String? ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _replyToMessage = null),
                                  child: const Icon(Icons.close, color: Colors.white54, size: 18),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _textCtrl,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Message #${activeChannel.name}...',
                                      hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 15),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    onTap: () {
                                      if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.sentiment_satisfied_alt, color: Colors.white54),
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B00),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : _joinCommunity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _isJoining
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Join Community to Chat', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
          ),
        ),
        if (_showEmojiPicker)
          SizedBox(
            height: 250,
            child: emoji.EmojiPicker(
              textEditingController: _textCtrl,
              config: emoji.Config(
                height: 250,
                checkPlatformCompatibility: true,
                emojiViewConfig: emoji.EmojiViewConfig(
                  backgroundColor: const Color(0xFF1B202D),
                  columns: 7,
                  emojiSizeMax: 28,
                ),
                categoryViewConfig: const emoji.CategoryViewConfig(
                  backgroundColor: Color(0xFF1B202D),
                  iconColorSelected: Color(0xFFFF6B00),
                  indicatorColor: Color(0xFFFF6B00),
                ),
                bottomActionBarConfig: const emoji.BottomActionBarConfig(
                  backgroundColor: Color(0xFF1B202D),
                  buttonColor: Color(0xFF1B202D),
                  buttonIconColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
          ],
        );
      },
    ),
      ),
    );
  }
}
