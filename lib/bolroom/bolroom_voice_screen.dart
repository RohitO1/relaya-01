// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'dart:math';

import '../services/notification_service.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chatroom_live_screen.dart';
import '../services/location_service.dart';

import '../services/doodle_theme.dart';
import 'bolroom_avatars.dart';

class BolroomVoiceScreen extends StatefulWidget {
  const BolroomVoiceScreen({super.key});
  @override
  State<BolroomVoiceScreen> createState() => _BolroomVoiceScreenState();
}

class _BolroomVoiceScreenState extends State<BolroomVoiceScreen> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  int _selectedFilter = 0;
  final List<String> _filters = ["Global", "Nearby", "Trending", "Music", "Gaming", "Talk", "Study"];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _myLocation = 'Fetching location...';
  Timer? _lobbySweepTimer;
  Timer? _refreshTimer;
  RealtimeChannel? _roomsSub;

  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color purpleDark = Color(0xFF7B2CBF);
  static const Color textMuted = Color(0xFF8E8B99);
  static const Color cyanBright = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadRooms();
    _startLobbySweepTimer();
    // Realtime: INSERT/DELETE/UPDATE on chatrooms
    _roomsSub = _sb.channel('bolroom_voice_rooms_v2').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'chatrooms',
      callback: (_) => _loadRooms(),
    ).subscribe();
    // Immediate patch when host transfer happens (in-process direct signal)
    BolRoomManager.hostChangedNotifier.addListener(_onHostChanged);
    // 10s safety-net refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadRooms();
    });
    locationService.activeDistrictNotifier.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) {
      final loc = locationService.activeDistrict;
      setState(() {
        _myLocation = (loc.isNotEmpty && loc != 'Unknown') ? loc : 'Global';
      });
      _loadRooms();
    }
  }

  @override
  void dispose() {
    _lobbySweepTimer?.cancel();
    _refreshTimer?.cancel();
    BolRoomManager.hostChangedNotifier.removeListener(_onHostChanged);
    if (_roomsSub != null) _sb.removeChannel(_roomsSub!);
    _searchCtrl.dispose();
    locationService.activeDistrictNotifier.removeListener(_onLocationChanged);
    super.dispose();
  }

  /// Called instantly when any host transfer fires BolRoomManager.hostChangedNotifier.
  /// Patches _rooms in-memory first (zero latency), then does a full DB refresh.
  void _onHostChanged() {
    if (!mounted) return;
    // Apply all pending host name changes directly to _rooms without a DB round-trip
    final pending = BolRoomManager.pendingHostNames;
    if (pending.isNotEmpty) {
      setState(() {
        for (int i = 0; i < _rooms.length; i++) {
          final rId = _rooms[i]['id']?.toString();
          if (rId != null && pending.containsKey(rId)) {
            _rooms[i] = Map<String, dynamic>.from(_rooms[i])
              ..['host_name'] = pending[rId];
          }
        }
      });
    }
    // Also do a full refresh so DB state stays in sync
    _loadRooms();
  }

  void _startLobbySweepTimer() {
    _lobbySweepTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final roomsRes = await _sb.from('chatrooms').select('id, created_at');
        if (roomsRes.isEmpty) return;

        final membersRes = await _sb.from('chatroom_members').select('room_id');
        final activeRoomIds = (membersRes as List).map((m) => m['room_id'].toString()).toSet();

        final now = DateTime.now();
        for (var r in roomsRes) {
          final roomId = r['id'].toString();
          final createdAtStr = r['created_at']?.toString();
          if (createdAtStr != null) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              final age = now.difference(createdAt);
              if (age.inSeconds > 60 && !activeRoomIds.contains(roomId)) {
                await _sb.from('chatrooms').delete().eq('id', roomId);
                debugPrint('Lobby Sweep: Deleted empty room $roomId');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Lobby Sweep Error: $e');
      }
    });
  }

  Future<void> _loadRooms() async {
    try {
      final myId = _sb.auth.currentUser?.id;
      var query = _sb.from('chatrooms').select('*');
      final res = await query
          .or('visibility.neq.invite,host_id.eq.$myId')
          .neq('room_status', 'deleted')
          .order('created_at', ascending: false)
          .limit(50);

      final rooms = List<Map<String, dynamic>>.from(res);

      // ── Live host-name lookup ─────────────────────────────────────────────
      // chatrooms.host_name and chatroom_members.user_name can be stale if the 
      // user updated their profile. Always fetch the absolute latest name from profiles.
      if (rooms.isNotEmpty) {
        try {
          final hostIds = rooms
              .map((r) => r['host_id']?.toString())
              .whereType<String>()
              .toSet() // Use a Set to avoid duplicate profile queries
              .toList();

          if (hostIds.isNotEmpty) {
            final profilesRes = await _sb
                .from('profiles')
                .select('id, name')
                .inFilter('id', hostIds);

            // Build: user_id → name
            final profileMap = <String, String>{};
            for (final p in profilesRes) {
              final pId = p['id']?.toString();
              final pName = p['name']?.toString();
              if (pId != null && pName != null && pName.isNotEmpty) {
                profileMap[pId] = pName;
              }
            }

            // For each room, replace host_name with the latest profile name
            for (final room in rooms) {
              final hId = room['host_id']?.toString();
              if (hId != null && profileMap.containsKey(hId)) {
                room['host_name'] = profileMap[hId];
              }
            }
          }
        } catch (e) {
          debugPrint('Host-name live lookup error: $e');
          // Falls back to whatever host_name is stored in chatrooms
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      if (mounted) setState(() { _rooms = rooms; _loading = false; });
    } catch (e) {
      debugPrint('Load rooms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final locSvc = LocationService();
      final loc = locSvc.activeDistrict;
      if (mounted) {
        setState(() {
          _myLocation = (loc.isNotEmpty && loc != 'Unknown') ? loc : 'Global';
        });
      }
    } catch (e) {
      debugPrint('Location service fetch error: $e');
      if (mounted) setState(() => _myLocation = 'Global');
    }
  }

  void _joinRoom(Map<String, dynamic> room) {
    HapticFeedback.lightImpact();
    BolRoomManager.requestSwitchRoom(context, onProceed: () {
      BolRoomManager.openRoom(context,
        roomId: room['id'].toString(), roomName: room['name'] ?? 'Untitled', topic: room['topic'] ?? 'General',
        hostId: room['host_id']?.toString() ?? '', hostName: room['host_name'] ?? 'Host',
      );
    });
  }

  Color _getAuraColor(String hostId) {
    // Generate a consistent pseudo-random neon color based on host ID
    final colors = [
      const Color(0xFFFF6B00),
      const Color(0xFFFF00FF),
      const Color(0xFF8A2BE2),
      const Color(0xFFFF4655),
      const Color(0xFF00FF00),
      const Color(0xFFF7931A),
    ];
    int hash = hostId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  String _getLoc(dynamic topicStr) {
    if (topicStr == null) return 'Global';
    final parts = topicStr.toString().split('|').map((e) => e.trim()).toList();
    if (parts.length > 1) {
      final last = parts.last;
      return last.isNotEmpty ? last : 'Global';
    }
    return 'Global';
  }

  List<String> _getTags(dynamic topicStr) {
    if (topicStr == null) return ['General'];
    final parts = topicStr.toString().split('|').map((e) => e.trim()).toList();
    if (parts.length > 1) {
      parts.removeLast(); // Remove the trailing location part
    }
    final tags = parts.where((e) => e.isNotEmpty && !e.toLowerCase().contains('could not')).toList();
    return tags.isEmpty ? ['General'] : tags;
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    final now = DateTime.now();
    List<Map<String, dynamic>> filteredRooms = _rooms;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredRooms = filteredRooms.where((r) {
        final name = (r['name'] ?? '').toString().toLowerCase();
        final topic = (r['topic'] ?? '').toString().toLowerCase();
        final tags = (r['tags'] ?? '').toString().toLowerCase();
        return name.contains(q) || topic.contains(q) || tags.contains(q);
      }).toList();
    }

    // Tag / Region filter
    // Index 0 = Global → show ALL rooms (no filter)
    // Index 1 = Nearby → filter by activeDistrict
    if (_selectedFilter == 1) {
      final activeLoc = LocationService().activeDistrict.toLowerCase().trim();
      if (activeLoc.isNotEmpty && activeLoc != 'unknown' && activeLoc != 'global') {
        filteredRooms = filteredRooms.where((r) {
          final topic = (r['topic'] ?? '').toString().toLowerCase();
          final tags = (r['tags'] ?? '').toString().toLowerCase();
          return topic.contains(activeLoc) || tags.contains(activeLoc);
        }).toList();
      }
      // If activeLoc is empty/unknown, Nearby shows all (graceful fallback)
    } else if (_selectedFilter > 1) {
      final tag = _filters[_selectedFilter].toLowerCase();
      filteredRooms = filteredRooms.where((r) {
        final topic = (r['topic'] ?? '').toString().toLowerCase();
        final tags = (r['tags'] ?? '').toString().toLowerCase();
        return topic.contains(tag) || tags.contains(tag);
      }).toList();
    }

    final live = filteredRooms.where((r) => r['scheduled_at'] == null || DateTime.tryParse(r['scheduled_at']?.toString() ?? '')?.isBefore(now) == true).toList();
    final scheduled = filteredRooms.where((r) {
      if (r['scheduled_at'] == null) return false;
      final t = DateTime.tryParse(r['scheduled_at'].toString());
      return t != null && t.isAfter(now);
    }).toList();

    return SafeArea(
      child: _loading
        ? Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : purplePrimary, strokeWidth: 2))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader("VoiceRoom", Icons.add_circle, doodle, onAction: () => _showCreateRoomSheet(context)),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: doodle
                    ? InputDecoration(
                        hintText: 'Search rooms by title or tag...',
                        hintStyle: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 13),
                        filled: true, fillColor: DoodleColors.paper,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DoodleColors.sketchLine)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DoodleColors.sketchLine)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DoodleColors.orange, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(Icons.search, color: DoodleColors.brown.withValues(alpha: 0.5), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                          onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }),
                          icon: Icon(Icons.close, color: DoodleColors.brown.withValues(alpha: 0.5), size: 18),
                        ) : null,
                      )
                    : InputDecoration(
                        hintText: 'Search rooms by title or tag...',
                        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
                        filled: true, fillColor: cardColor,
                        prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                          onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }),
                          icon: const Icon(Icons.close, color: textMuted, size: 18),
                        ) : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                ),
              ),

              // Return to Room banner
              if (BolRoomManager.hasActiveRoom)
                GestureDetector(
                  onTap: () => BolRoomManager.maximizeRoom(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [purpleDark.withValues(alpha: 0.4), cyanBright.withValues(alpha: 0.15)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cyanBright.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Return to active room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                      const Icon(Icons.arrow_forward_ios, color: cyanBright, size: 14),
                    ]),
                  ),
                ),
              
              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: List.generate(_filters.length, (index) {
                    bool isSelected = _selectedFilter == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: doodle
                          ? BoxDecoration(
                              color: isSelected ? DoodleColors.cream : DoodleColors.paper,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: DoodleColors.brown, width: isSelected ? 2 : 1),
                              boxShadow: isSelected ? [BoxShadow(color: DoodleColors.brown, offset: const Offset(2, 2))] : [],
                            )
                          : BoxDecoration(
                              color: isSelected ? purpleDark.withValues(alpha: 0.3) : cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? purplePrimary : borderColor),
                            ),
                        child: Row(
                          children: [
                            if (index == 0) ...[
                              Icon(Icons.public, size: 14, color: doodle ? DoodleColors.blue : (isSelected ? cyanBright : textMuted)),
                              const SizedBox(width: 6),
                            ],
                            if (index == 1) ...[
                              Icon(Icons.location_on, size: 14, color: doodle ? DoodleColors.blue : (isSelected ? cyanBright : textMuted)),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              index == 1 && _myLocation != 'Global' && _myLocation != 'Fetching location...' 
                                  ? _myLocation 
                                  : _filters[index],
                              style: doodle
                                ? DoodleFonts.body(
                                    color: DoodleColors.brown,
                                    fontSize: 13,
                                  ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
                                : TextStyle(
                                    color: isSelected ? Colors.white : textMuted,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    if (live.isNotEmpty) ...[
                      ...live.map((r) => _buildLiveRoomCard(
                        room: r,
                        title: r['name'] ?? 'Untitled Echo',
                        host: r['host_name'] ?? 'Anonymous Host',
                        listeners: "${r['member_count'] ?? 1}",
                        tags: _getTags(r['topic']),
                        auraColor: _getAuraColor(r['host_id']?.toString() ?? ''),
                        doodle: doodle,
                      )),
                      const SizedBox(height: 24),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text("No Active Orbits found in this frequency.", style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14) : const TextStyle(color: textMuted)),
                        ),
                      ),
                    ],

                    if (scheduled.isNotEmpty) ...[
                      Text("Scheduled Rooms", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...scheduled.map((r) {
                        final t = DateTime.tryParse(r['scheduled_at'].toString())?.toLocal();
                        String timeStr = 'Later';
                        if (t != null) {
                          final diff = t.difference(DateTime.now());
                          if (diff.inHours > 0) {
                            timeStr = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
                          } else if (diff.inMinutes > 0) {
                            timeStr = 'Starts in ${diff.inMinutes}m';
                          } else {
                            timeStr = 'Starting soon';
                          }
                        }
                        return _buildScheduledRoom(
                          r,
                          r['name'] ?? 'Scheduled Room',
                          timeStr,
                          _getAuraColor(r['host_id']?.toString() ?? ''),
                          doodle,
                        );
                      }),
                      const SizedBox(height: 80),
                    ]
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildHeader(String title, IconData actionIcon, bool doodle, {VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: doodle
                    ? DoodleDecorations.card()
                    : BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                  child: Icon(Icons.arrow_back_ios_new, color: doodle ? DoodleColors.brown : Colors.white, size: 18),
                ),
              ),
              Text(title, style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 32) : const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showLocationFilterSheet(context),
                child: Container(
                  width: 44, height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: doodle
                    ? DoodleDecorations.card()
                    : BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                  child: Icon(Icons.location_on, color: doodle ? DoodleColors.blue : cyanBright, size: 20),
                ),
              ),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  width: 44, height: 44,
                  decoration: doodle
                    ? DoodleDecorations.card()
                    : BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)],
                      ),
                  child: Icon(actionIcon, color: doodle ? DoodleColors.blue : purplePrimary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRoomCard({
    required Map<String, dynamic> room,
    required String title,
    required String host,
    required String listeners,
    required List<String> tags,
    required Color auraColor,
    required bool doodle,
  }) {
    final maxP = room['max_participants'] as int? ?? 0;
    final count = room['member_count'] as int? ?? 1;
    final isFull = maxP > 0 && count >= maxP;

    return GestureDetector(
      onTap: () {
        if (isFull) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Room is full'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
          return;
        }
        _joinRoom(room);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: doodle
          ? DoodleDecorations.card(color: DoodleColors.paper)
          : BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: auraColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: auraColor.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2),
              ],
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 20) : const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3))),
                const SizedBox(width: 8),
                if (isFull)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))),
                    child: const Text('Full', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
                  doodle ? Icon(Icons.waves, color: DoodleColors.blue) : _buildAudioVisualizer(auraColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                doodle ? CircleAvatar(backgroundColor: DoodleColors.orange, radius: 16, child: Icon(Icons.person, color: DoodleColors.cream, size: 16)) : _buildGlowingAvatar(auraColor, 32, userId: room['host_id']?.toString()),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: doodle ? DoodleColors.blue : cyanBright, size: 12),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              _getLoc(room['topic']),
                              style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: cyanBright, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: doodle ? DoodleColors.cream : const Color(0xFF1A132F), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.headphones, color: doodle ? DoodleColors.brown : purplePrimary, size: 12),
                    const SizedBox(width: 4),
                    Text(listeners, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: purplePrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Wrap(
                  spacing: 8,
                  children: tags.map((t) => Text("#$t", style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 12) : TextStyle(color: auraColor.withValues(alpha: 0.7), fontSize: 12))).toList(),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: doodle
                    ? BoxDecoration(
                        color: isFull ? DoodleColors.paper : DoodleColors.cream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DoodleColors.brown),
                      )
                    : BoxDecoration(
                        color: isFull ? Colors.white10 : auraColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isFull ? Colors.white24 : auraColor.withValues(alpha: 0.4)),
                      ),
                  child: Text(isFull ? 'Full' : 'Join', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : TextStyle(color: isFull ? Colors.white38 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledRoom(Map<String, dynamic> room, String title, String time, Color color, bool doodle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: doodle
        ? DoodleDecorations.card(color: DoodleColors.paper)
        : BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: doodle ? DoodleColors.cream : color.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: Icon(Icons.schedule, color: doodle ? DoodleColors.brown : color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: doodle ? DoodleColors.orange.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('Scheduled', style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 10).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(title, style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time, style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 14) : TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final myId = _sb.auth.currentUser?.id;
              if (myId == null) return;
              final roomId = room['id']?.toString() ?? '';
              try {
                await _sb.from('chatroom_reminders').upsert({
                  'room_id': roomId,
                  'user_id': myId,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('You\'ll be reminded 5 min before start'),
                    backgroundColor: doodle ? DoodleColors.blue : const Color(0xFF7B2CBF), behavior: SnackBarBehavior.floating));
                }
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: doodle
                ? DoodleDecorations.card(color: DoodleColors.cream)
                : BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_active, color: doodle ? DoodleColors.brown : color, size: 14),
                const SizedBox(width: 4),
                Text('Remind Me', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomSheet(BuildContext context) {
    BolRoomManager.requestSwitchRoom(context, isCreate: true, onProceed: () {
      _showCreateRoomSheetInternal(context);
    });
  }

  void _showCreateRoomSheetInternal(BuildContext context) {
    final doodle = isDoodleMode(context);
    final titleCtrl = TextEditingController();
    bool isRecording = false;
    String? gameMode;
    String visibility = 'public'; // 'public', 'friends', 'invite'
    int maxParticipants = 0; // 0 = unlimited
    final List<String> tagOptions = ['Music', 'Gaming', 'Talk', 'Chill', 'Study', 'Debate', 'Language', 'News'];
    final Set<String> selectedTags = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scroll) => SingleChildScrollView(
              controller: scroll,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                left: 24, right: 24, top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Create Room', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Set up your live audio space', style: TextStyle(color: textMuted, fontSize: 13)),
                  const SizedBox(height: 24),

                  // Title (required)
                  const Text('Room Title *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleCtrl,
                    maxLength: 60,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'What\'s the vibe?',
                      hintStyle: const TextStyle(color: textMuted),
                      filled: true, fillColor: bgColor,
                      counterStyle: const TextStyle(color: textMuted, fontSize: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags (multi-select chips)
                  const Text('Tags', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: tagOptions.map((tag) {
                      final selected = selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setSheetState(() {
                          if (selected) { selectedTags.remove(tag); }
                          else { selectedTags.add(tag); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? purpleDark.withValues(alpha: 0.4) : bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? purplePrimary : borderColor),
                          ),
                          child: Text(tag, style: TextStyle(color: selected ? Colors.white : textMuted, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Game Mode
                  const Text('Game Mode', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = null),
                          child: Container(
                            width: 110,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == null ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == null ? cyanBright : borderColor),
                            ),
                            child: Center(child: Text('💬 None', style: TextStyle(color: gameMode == null ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == null ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = 'truth_dare'),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == 'truth_dare' ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == 'truth_dare' ? cyanBright : borderColor),
                              boxShadow: gameMode == 'truth_dare' ? [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 10)] : [],
                            ),
                            child: Center(child: Text('🍾 Truth or Dare', style: TextStyle(color: gameMode == 'truth_dare' ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == 'truth_dare' ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = 'two_truths'),
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == 'two_truths' ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == 'two_truths' ? cyanBright : borderColor),
                              boxShadow: gameMode == 'two_truths' ? [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 10)] : [],
                            ),
                            child: Center(child: Text('🎭 Two Truths, One Lie', style: TextStyle(color: gameMode == 'two_truths' ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == 'two_truths' ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSheetState(() => gameMode = 'blind_date'),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gameMode == 'blind_date' ? cyanBright.withValues(alpha: 0.2) : bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gameMode == 'blind_date' ? cyanBright : borderColor),
                              boxShadow: gameMode == 'blind_date' ? [BoxShadow(color: cyanBright.withValues(alpha: 0.2), blurRadius: 10)] : [],
                            ),
                            child: Center(child: Text('🔥 Blind Date', style: TextStyle(color: gameMode == 'blind_date' ? cyanBright : textMuted, fontSize: 13, fontWeight: gameMode == 'blind_date' ? FontWeight.bold : FontWeight.normal))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Go Live button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final name = titleCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Room title is required'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }

                        final myId = _sb.auth.currentUser?.id;
                        if (myId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
                          return;
                        }

                        String hostName = 'Host';
                        String? hostAvatar;
                        final profile = await _sb.from('profiles').select('full_name, avatar_url').eq('id', myId).maybeSingle();
                        if (profile != null) {
                          if (profile['full_name'] != null) hostName = profile['full_name'];
                          hostAvatar = profile['avatar_url']?.toString();
                        }

                        String topic = selectedTags.isNotEmpty ? selectedTags.join(' | ') : 'General';
                        topic += ' | $_myLocation';

                        try {
                          final res = await _sb.from('chatrooms').insert({
                            'name': name,
                            'host_id': myId,
                            'host_name': hostName,
                            'host_avatar': hostAvatar,
                            'topic': topic,
                            'speak_permission': 'everyone',
                            'is_recording': isRecording,
                            'game_mode': gameMode,
                            'visibility': visibility,
                            'max_participants': maxParticipants,
                            'room_status': 'active',
                            'scheduled_at': null,
                            'created_at': DateTime.now().toUtc().toIso8601String(),
                          }).select().single();

                          // Update bolroom profile hosted count
                          try {
                            final p = await _sb.from('bolroom_profiles').select('rooms_hosted').eq('id', myId).maybeSingle();
                            if (p == null) {
                              await _sb.from('bolroom_profiles').upsert({'id': myId, 'anon_name': hostName, 'rooms_hosted': 1});
                            } else {
                              await _sb.from('bolroom_profiles').update({'rooms_hosted': (p['rooms_hosted'] ?? 0) + 1}).eq('id', myId);
                            }
                          } catch (_) {}
                          
                          // Notify followers/followings
                          try {
                            final reqs = await _sb.from('requests').select('sender_id, target_id').eq('target_type', 'follow').eq('status', 'approved').or('sender_id.eq.$myId,target_id.eq.$myId');
                            
                            final Set<String> usersToNotify = {};
                            for (var r in (reqs as List)) {
                              final sId = r['sender_id']?.toString();
                              final tId = r['target_id']?.toString();
                              if (sId != null && sId != myId) usersToNotify.add(sId);
                              if (tId != null && tId != myId) usersToNotify.add(tId);
                            }
                            
                            for (var uId in usersToNotify) {
                              NotificationService.sendNotification(
                                userId: uId,
                                type: NotificationType.system,
                                title: '$hostName is Live! 🎙️',
                                body: 'Hop in to BolRoom: $name',
                                payload: {'bolroom_live': true, 'room_id': res['id'].toString()},
                              );
                            }
                          } catch (_) {}

                          _loadRooms();
                          Navigator.pop(ctx);
                          _joinRoom(res);
                        } catch (e) {
                          debugPrint('Create room error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cell_tower, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Go Live 🔴',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlowingAvatar(Color glowColor, double size, {bool isPulsing = false, String? userId, String? avatarKey}) {
    // If we have a userId, prefer BolroomAvatarWidget for the custom avatar experience
    if (userId != null && userId.isNotEmpty) {
      return BolroomAvatarWidget(
        size: size,
        avatarUrl: null,
        avatarKey: avatarKey,
        userId: userId,
        showRing: true,
      );
    }
    // Fallback: plain glow ring with person icon
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [glowColor, purpleDark, glowColor]),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: isPulsing ? 25 : 15,
            spreadRadius: isPulsing ? 5 : 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: bgColor),
          child: CircleAvatar(
            backgroundColor: cardColor,
            child: Icon(Icons.person, color: Colors.white30, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioVisualizer(Color color) {
    final random = Random();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: 10.0 + random.nextInt(15),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color, blurRadius: 4)],
          ),
        );
      }),
    );
  }


  void _showLocationFilterSheet(BuildContext context) {
    final doodle = isDoodleMode(context);
    String query = '';
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: doodle ? DoodleColors.paper : cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Location Filter", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 24) : const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {
                        locationService.setLocation('Global', district: 'Global', state: '');
                        setState(() {
                          _myLocation = 'Global';
                          _selectedFilter = 0; // Switch to Global filter
                        });
                        Navigator.pop(ctx);
                        _loadRooms();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: doodle ? DoodleColors.blue.withValues(alpha: 0.15) : cyanBright.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: doodle ? DoodleColors.blue.withValues(alpha: 0.4) : cyanBright.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public, size: 14, color: doodle ? DoodleColors.blue : cyanBright),
                            const SizedBox(width: 4),
                            Text("Global", style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: cyanBright, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Search bar
                TextField(
                  style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: doodle
                    ? InputDecoration(
                        hintText: 'Search city or region...',
                        hintStyle: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 13),
                        filled: true, fillColor: DoodleColors.cream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DoodleColors.sketchLine)),
                        prefixIcon: Icon(Icons.search, color: DoodleColors.brown.withValues(alpha: 0.5), size: 20),
                      )
                    : InputDecoration(
                        hintText: 'Search city or region...',
                        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
                        filled: true, fillColor: bgColor,
                        prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                  onChanged: (val) async {
                    query = val;
                    if (query.trim().length >= 3) {
                      setSheetState(() => isSearching = true);
                      final res = await locationService.searchLocations(query);
                      if (query == val && mounted) {
                        setSheetState(() {
                          searchResults = res;
                          isSearching = false;
                        });
                      }
                    } else {
                      setSheetState(() {
                        searchResults = [];
                        isSearching = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Auto Fetch
                GestureDetector(
                  onTap: () async {
                    setSheetState(() => isSearching = true);
                    await locationService.fetchLiveLocation(forceReverseGeocode: true);
                    if (mounted) {
                      final loc = locationService.activeDistrict;
                      setState(() {
                        _myLocation = (loc.isNotEmpty && loc != 'Unknown') ? loc : 'Global';
                        _selectedFilter = 1; // Auto-switch to Nearby filter
                      });
                      Navigator.pop(ctx);
                      _loadRooms();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: doodle ? DoodleColors.blue.withValues(alpha: 0.1) : cyanBright.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: doodle ? DoodleColors.blue.withValues(alpha: 0.3) : cyanBright.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location, color: doodle ? DoodleColors.blue : cyanBright, size: 18),
                        const SizedBox(width: 8),
                        Text("Use My Current Location", style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: cyanBright, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: isSearching
                    ? Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : cyanBright))
                    : ListView(
                        children: (query.trim().length >= 3 ? searchResults : LocationService.popularCities).map((loc) {
                          final name = loc['name']?.toString() ?? '';
                          final dist = loc['district']?.toString();
                          final st = loc['state']?.toString();
                          final lat = (loc['lat'] as num?)?.toDouble();
                          final lng = (loc['lng'] as num?)?.toDouble();
                          
                          return ListTile(
                            leading: Icon(Icons.location_city, color: doodle ? DoodleColors.brown : textMuted),
                            title: Text(name, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 16) : const TextStyle(color: Colors.white, fontSize: 15)),
                            subtitle: (st != null && st.isNotEmpty) ? Text(st, style: TextStyle(color: doodle ? DoodleColors.brown.withValues(alpha: 0.6) : textMuted, fontSize: 12)) : null,
                            onTap: () {
                              locationService.setLocation(name, lat: lat, lng: lng, district: dist, state: st);
                              setState(() {
                                _myLocation = dist ?? name;
                                _selectedFilter = 1; // Auto-switch to Nearby filter
                              });
                              Navigator.pop(ctx);
                              _loadRooms();
                            },
                          );
                        }).toList(),
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
