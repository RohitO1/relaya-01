// ignore_for_file: duplicate_ignore, unused_element
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'package:http/http.dart' as http;

import 'rush_in_consumer_detail_view.dart';
import 'host_activity_screen.dart';
import 'spark_detail_screen.dart';
import 'services/doodle_theme.dart';



// ==========================================
// COLORS & CONSTANTS
// ==========================================
class SparkColors {
  // Deep dark base inspired by the reference image
  static const bg = Color(0xFF000000);   // pure black
  static const bg2 = Color(0xFF0A0C12);  // near-black
  static const card = Color(0xFF0A0C12); // card surface
  static const cardH = Color(0xFF171A26); // card hover / elevated
  // Neon accent palette
  static const cyan = Color(0xFFFF6B00);    // brand orange
  static const purple = Color(0xFFFF7E40);  // warm amber
  static const pink = Color(0xFFFF3D00);    // deep orange-red
  static const orange = Color(0xFFFF6B00);  // vibrant brand orange
  static const coral = Color(0xFFFF6B57);   // coral
  static const blue = Color(0xFF4E8BFF);    // bright blue
  static const green = Color(0xFF4ADE80);   // neon green
  static const yellow = Color(0xFFFFC107);  // amber glow
  static const red = Color(0xFFFF3D5A);     // coral red
  // Text hierarchy
  static const txt = Color(0xFFFFFFFF);     // pure white
  static const txt2 = Color(0xFF9E9E9E);    // muted grey
  static const muted = Color(0xFF616161);   // deep muted
  
  static const glass = Color(0xFF0C0E14);
  static final gborder = Colors.white.withValues(alpha: 0.08);

  // Activity-specific premium palette
  static const actPrimary = Color(0xFFFF5C00); // deep orange
  static const actSecondary = Color(0xFFFF7E40);
  static const actAccent = Color(0xFFFF3D00); // red-orange
}

// ==========================================
// DUMMY DATA STORE
// ==========================================
class SparkItem {
  final String id;
  final String type; // 'rush' or 'act'
  final String title;
  final String desc;
  final List<String> tags;
  final String? radius;
  final String? timer;
  final String slots;
  final double lat;
  final double lng;
  final int waitlist;
  final String host;
  final String? date;
  final String? time;
  final String? location;
  final String? hostAvatar;
  final List<Color>? hostColor;
  final List<String>? members;
  final bool isApproved;
  final bool hasRequested;
  final bool isAnonymous;
  final String? imageUrl;
  final String? hostId;
  final DateTime? createdAt;
  final DateTime? activityTime;
  final DateTime? expiresAt;
  final String? district;
  final bool isWithinHostRadius;
  final int joinedMembers;

  SparkItem({
    required this.id, required this.type, required this.title, required this.desc,
    required this.tags, required this.slots, required this.lat, required this.lng,
    required this.waitlist, required this.host, this.radius, this.timer, this.date,
    this.time, this.location, this.hostAvatar, this.hostColor, this.members,
    this.isApproved = false,
    this.hasRequested = false,
    this.isAnonymous = false,
    this.imageUrl,
    this.hostId,
    this.createdAt,
    this.activityTime,
    this.expiresAt,
    this.district,
    this.isWithinHostRadius = true,
    this.joinedMembers = 0,
  });

  bool get isFull {
    try {
      if (slots.isEmpty) return false;
      final parts = slots.split('/');
      if (parts.length == 2) {
        final current = int.tryParse(parts[0].trim()) ?? 0;
        final total = int.tryParse(parts[1].trim()) ?? 0;
        return current >= total && total > 0;
      }
    } catch (_) {}
    return false;
  }
}

final Map<String, SparkItem> sparkDataStore = {};

IconData _getVibeIcon(SparkItem item) {
  if (item.tags.isEmpty) return Icons.flash_on;
  final allTags = item.tags.join(', ').split(',').map((e) => e.trim()).toList();
  for (final tag in allTags) {
    switch (tag) {
      case 'Outdoor': return Icons.park;
      case 'Sports': return Icons.sports_soccer;
      case 'Music': return Icons.music_note;
      case 'Food': return Icons.restaurant;
      case 'Study': return Icons.menu_book;
      case 'Gaming': return Icons.sports_esports;
      case 'Fitness': return Icons.fitness_center;
    }
  }
  return Icons.flash_on;
}

// ==========================================
// MAIN SCREEN
// ==========================================
class SparkScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SparkScreen({super.key, required this.onBack});

  @override
  State<SparkScreen> createState() => _SparkScreenState();
}

class _SparkScreenState extends State<SparkScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  // State
  
  String _activeView = 'map'; // 'list' or 'map'
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  String _sortBy = 'Nearest';
  bool _loadingData = true;
  bool _isMapDark = true;
  bool _isFabVisible = true;

  // Live data from Supabase
  List<SparkItem> _rushIns = [];
  

  // My personal dashboard data
  List<Map<String, dynamic>> _myHostedRushIns = [];
  List<Map<String, dynamic>> _myJoinedRushIns = [];
  
  

  // Overlays
  OverlayEntry? _toastEntry;

  final Set<String> _optimisticPendingIds = {};
  final Set<String> _optimisticApprovedIds = {};

  RealtimeChannel? _activitiesChannel;
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _fetchMyDashboardData();
    // Listen to coordinate updates specifically
    locationService.coordinatesUpdateNotifier.addListener(_fetchActivities);

    // Supabase Realtime subscriptions for instant updates
    _activitiesChannel = Supabase.instance.client
        .channel('public:activities_spark')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'activities',
            callback: (payload) {
              if (mounted) _refreshAll();
            })
        .subscribe();

    _requestsChannel = Supabase.instance.client
        .channel('public:requests_spark')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'requests',
            callback: (payload) {
              if (mounted) _refreshAll();
            })
        .subscribe();
        
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_isFabVisible) setState(() => _isFabVisible = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_isFabVisible) setState(() => _isFabVisible = true);
      }
    });
  }

  @override
  void dispose() {
    if (_activitiesChannel != null) {
      Supabase.instance.client.removeChannel(_activitiesChannel!);
    }
    if (_requestsChannel != null) {
      Supabase.instance.client.removeChannel(_requestsChannel!);
    }
    locationService.coordinatesUpdateNotifier.removeListener(_fetchActivities);
    _scrollController.dispose();
    _toastEntry?.remove();
    super.dispose();
  }

  void _refreshAll() {
    _fetchActivities();
    _fetchMyDashboardData();
  }

  Future<void> _fetchActivities() async {
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;

      var query = sb.from('activities')
          .select('*')
          .eq('is_active', true);

      // We fetch globally (no district filter) so Map View can see everything.
      // List View will filter locally.
      final rows = await query.order('created_at', ascending: false).limit(300);

      // Map profiles manually due to missing database foreign key join
      final Set<String> userIds = {};
      final List<String> allActivityIds = [];
      for (final r in rows as List) {
        if (r['user_id'] != null) userIds.add(r['user_id'].toString());
        if (r['id'] != null) allActivityIds.add(r['id'].toString());
      }
      final Map<String, dynamic> profilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          final pRows = await sb.from('profiles').select('id, name, avatar_url').inFilter('id', userIds.toList());
          for (final p in pRows as List) {
            profilesMap[p['id'].toString()] = p;
          }
        } catch (_) {}
      }

      // Batch fetch requests to prevent N+1 query
      final Map<String, List<Map<String, dynamic>>> requestsMap = {};
      if (allActivityIds.isNotEmpty) {
        try {
          final allReqs = await sb.from('requests').select('target_id, status, sender_id').inFilter('target_id', allActivityIds);
          for (final req in allReqs as List) {
            final tId = req['target_id']?.toString() ?? '';
            requestsMap.putIfAbsent(tId, () => []).add(req as Map<String, dynamic>);
          }
        } catch (_) {}
      }

      // Fetch hidden items for current user
      Set<String> hiddenIds = {};
      if (uid != null) {
        try {
          final hidden = await sb.from('hidden_feed').select('rush_in_id').eq('user_id', uid);
          hiddenIds = (hidden as List).map((r) => r['rush_in_id']?.toString() ?? '').toSet();
        } catch (_) {}
      }

      // Fetch participant counts
      final List<SparkItem> rushIns = [];
      

      for (final row in (rows as List)) {
        final id = row['id']?.toString() ?? '';
        if (hiddenIds.contains(id)) continue;

        final creatorId = row['user_id']?.toString() ?? '';
        if (creatorId == uid) continue; // Skip the user's own created items so they only appear in their dashboard

        final profile = profilesMap[creatorId] as Map?;
        final hostName = profile?['name'] ?? 'Someone';
        final hostAvatarUrl = profile?['avatar_url'] ?? '';
        final descStr = row['description']?.toString() ?? '';
        
        // ── Extract metadata tags from description ──
        // Fields like expires_at, participant_limit, radius_km, is_rush_in, duration_hours
        // are stored as [key:value] tags in the description because the DB table
        // only has safe columns. We must extract them here.
        String? _extractTag(String key) {
          final match = RegExp('\\[$key:(.*?)\\]').firstMatch(descStr);
          return match?.group(1);
        }
        
        final isRushIn = row['is_rush_in'] == true || (descStr.contains('[is_rush_in:true]'));
        final limit = row['participant_limit'] ?? int.tryParse(_extractTag('participant_limit') ?? '') ?? 4;
        
        final lat = double.tryParse(row['lat']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(row['lng']?.toString() ?? '') ?? 0.0;
        
        bool withinRadius = true;
        // Host defined visibility limit natively computed via Haversine 
        if (isRushIn && locationService.activeLat != null && locationService.activeLng != null) {
          final hostRadius = double.tryParse(_extractTag('radius_km') ?? '') 
              ?? double.tryParse(row['radius_km']?.toString() ?? '') 
              ?? 5.0;
          final currentDist = locationService.calculateDistanceInKm(
            locationService.activeLat!, 
            locationService.activeLng!, 
            lat, 
            lng
          );
          if (currentDist > hostRadius) withinRadius = false;
        }

        // ── Parse expires_at from DB column first, then from description tags ──
        DateTime? parsedExpiresAt;
        if (isRushIn) {
          String? expiresAtStr = row['expires_at']?.toString();
          if (expiresAtStr == null || expiresAtStr.isEmpty) {
            expiresAtStr = _extractTag('expires_at');
          }
          if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
            parsedExpiresAt = DateTime.tryParse(expiresAtStr)?.toLocal();
          }
          
          // If still null, compute from activity_time + duration_hours
          if (parsedExpiresAt == null) {
            final durationStr = _extractTag('duration_hours');
            final actTimeStr = row['activity_time']?.toString();
            if (durationStr != null && actTimeStr != null) {
              final durationHours = int.tryParse(durationStr);
              final actTimeParsed = DateTime.tryParse(actTimeStr)?.toLocal();
              if (durationHours != null && actTimeParsed != null) {
                parsedExpiresAt = actTimeParsed.add(Duration(hours: durationHours));
              }
            }
          }
          
          if (parsedExpiresAt != null && parsedExpiresAt.isBefore(DateTime.now().subtract(const Duration(hours: 6)))) {
            continue; // Skip expired rush-ins after 6 hours
          }
        }

        // Count participants and check approval
        int joined = 0;
        int waitlisted = 0;
        bool isApproved = false;
        bool hasRequested = false;
        try {
          final reqs = requestsMap[id] ?? [];
          for (final r in reqs) {
            if (r['status'] == 'approved') {
              joined++;
              if (r['sender_id'] == uid) isApproved = true;
            }
            else if (r['status'] == 'pending') {
              waitlisted++;
              if (r['sender_id'] == uid) hasRequested = true;
            }
          }
        } catch (_) {}

        final isAnonymous = row['is_anonymous'] == true;

        final actTime = row['activity_time'] != null ? DateTime.tryParse(row['activity_time'])?.toLocal() : null;
        String? timerDisplay;
        if (isRushIn && actTime != null) {
          final now = DateTime.now();
          final diff = actTime.difference(now);
          if (diff.isNegative) {
            // Rush-in has started — show "Ends in X"
            if (parsedExpiresAt != null) {
              final endDiff = parsedExpiresAt.difference(now);
              if (endDiff.isNegative) {
                timerDisplay = 'ENDED';
              } else if (endDiff.inHours > 0) {
                timerDisplay = 'Ends in ${endDiff.inHours}h ${endDiff.inMinutes % 60}m';
              } else {
                timerDisplay = 'Ends in ${endDiff.inMinutes}m';
              }
            } else {
              timerDisplay = 'Live Now';
            }
          } else if (diff.inHours > 0) {
            timerDisplay = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
          } else {
            timerDisplay = 'Starts in ${diff.inMinutes}m';
          }
        }

        String? extractedImageUrl = row['image_url']?.toString();
        if (extractedImageUrl == null || extractedImageUrl.isEmpty) {
          extractedImageUrl = _extractTag('image_url');
        }

        // Parse radius from DB or description
        final rawRadius = _extractTag('radius_km') ?? row['radius_km']?.toString();
        final radiusKm = rawRadius ?? '5';

        final item = SparkItem(
          id: id,
          type: isRushIn ? 'rush' : 'act',
          title: row['title'] ?? 'Untitled',
          desc: descStr.replaceAll(RegExp(r'\n?\[[a-zA-Z0-9_]+:.*?\]'), '').trim(),
          tags: [row['category']?.toString() ?? (isRushIn ? 'Rush' : 'Activity')],
          slots: '$joined/$limit',
          lat: double.tryParse(row['lat']?.toString() ?? '') ?? 0,
          lng: double.tryParse(row['lng']?.toString() ?? '') ?? 0,
          waitlist: waitlisted,
          host: hostName,
          radius: '$radiusKm km',
          timer: timerDisplay,
          date: actTime != null ? _formatDate(row['activity_time']) : null,
          time: row['activity_time'] != null ? _formatTime(row['activity_time']) : null,
          location: row['location_name']?.toString() ?? '',
          hostAvatar: hostAvatarUrl.isNotEmpty ? hostAvatarUrl : (hostName.isNotEmpty ? hostName[0].toUpperCase() : '?'),
          hostColor: isRushIn ? [SparkColors.purple, SparkColors.pink] : [SparkColors.actPrimary, SparkColors.actSecondary],
          members: [],
          isApproved: isApproved || (uid == row['user_id']) || _optimisticApprovedIds.contains(id),
          hasRequested: hasRequested || _optimisticPendingIds.contains(id),
          isAnonymous: isAnonymous,
          imageUrl: extractedImageUrl,
          hostId: row['user_id']?.toString(),
          createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at']) : null,
          activityTime: actTime,
          expiresAt: parsedExpiresAt,
          district: row['district']?.toString(),
          isWithinHostRadius: withinRadius,
          joinedMembers: joined,
        );


        // Also update the global store for detail sheets
        sparkDataStore[id] = item;

        if (isRushIn) {
          rushIns.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _rushIns = rushIns;
          
          _loadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch spark activities error: $e');
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _fetchMyDashboardData() async {
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;
      if (uid == null) return;

      // 1) Fetch MY hosted activities
      final hosted = await sb.from('activities').select('*').eq('user_id', uid).eq('is_active', true).order('created_at', ascending: false);
      final hostedRush = <Map<String, dynamic>>[];
      

      // Batch fetch requests for hosted activities
      final List<String> hostedIds = (hosted as List).map((h) => h['id'].toString()).toList();
      final Map<String, List<Map<String, dynamic>>> hostedReqsMap = {};
      
      if (hostedIds.isNotEmpty) {
        try {
          final allHostedReqs = await sb.from('requests').select('target_id, status').inFilter('target_id', hostedIds);
          for (final req in (allHostedReqs as List)) {
            final targetId = req['target_id']?.toString() ?? '';
            hostedReqsMap.putIfAbsent(targetId, () => []).add(req as Map<String, dynamic>);
          }
        } catch (_) {}
      }

      for (final row in hosted) {
        int joinedCount = 0; int pendingCount = 0;
        final targetId = row['id'].toString();
        final reqs = hostedReqsMap[targetId] ?? [];
        
        for (final r in reqs) {
          if (r['status'] == 'approved') {
            joinedCount++;
          } else if (r['status'] == 'pending') {
            pendingCount++;
          }
        }

        final enriched = Map<String, dynamic>.from(row);
        enriched['_joinedCount'] = joinedCount;
        enriched['_pendingCount'] = pendingCount;
        if (row["is_rush_in"] == true || (row["description"]?.toString().contains("[is_rush_in:true]") ?? false)) {
          hostedRush.add(enriched);
        }
      }

      // 2) Fetch activities I JOINED / REQUESTED
      final myReqs = await sb.from('requests').select('target_id, status').eq('sender_id', uid);
      final joinedRush = <Map<String, dynamic>>[];
      

      final List<String> joinedTargetIds = (myReqs as List).map((r) => r['target_id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();

      if (joinedTargetIds.isNotEmpty) {
        try {
          final joinedActRows = await sb.from('activities').select('*').inFilter('id', joinedTargetIds).eq('is_active', true);
          
          final List<String> hostIds = (joinedActRows as List).map((r) => r['user_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet().toList();
          final Map<String, String> hostNameMap = {};
          
          if (hostIds.isNotEmpty) {
            final hostProfiles = await sb.from('profiles').select('id, name').inFilter('id', hostIds);
            for (final p in (hostProfiles as List)) {
              hostNameMap[p['id'].toString()] = p['name']?.toString() ?? 'Someone';
            }
          }

          final reqStatusMap = {for (var r in myReqs) r['target_id'].toString(): r['status']};

          for (final row in joinedActRows) {
            final enriched = Map<String, dynamic>.from(row);
            final targetId = row['id'].toString();
            enriched['_myStatus'] = reqStatusMap[targetId];
            
            final hostId = row['user_id']?.toString() ?? '';
            enriched['_hostName'] = hostNameMap[hostId] ?? 'Someone';
            
            if (enriched["is_rush_in"] == true || (enriched["description"]?.toString().contains("[is_rush_in:true]") ?? false)) {
              joinedRush.add(enriched);
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _myHostedRushIns = hostedRush;
          _myJoinedRushIns = joinedRush;
          
          
        });
      }
    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
    }
  }

  String _formatDate(dynamic dt) {
    try {
      final d = DateTime.parse(dt.toString());
      return '${d.day}/${d.month}';
    } catch (_) { return 'TBD'; }
  }

  String _formatTime(dynamic dt) {
    try {
      final d = DateTime.parse(dt.toString());
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return 'TBD'; }
  }

  // --- View Switchers ---
  void _setTab(String tab) {
    setState(() {
      
      _searchQuery = '';
    });
  }

  void _setView(String view) {
    setState(() => _activeView = view);
  }

  // --- Overlay Triggers ---
  void _showDetailSheet(SparkItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SparkDetailScreen(
          item: item,
          onJoin: (itm) => _handleJoin(itm, fromSheet: true),
          onHide: _handleHide,
        ),
      ),
    );
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _SparkCreateModal(initialTab: "rush"),
    ).then((val) {
      if (val is Map) {
        _showToast(val['title'], val['desc']);
        _refreshAll(); // Refresh everything after creation
      }
    });
  }

  Future<void> _handleJoin(SparkItem item, {bool fromSheet = false}) async {
    if (item.isApproved) {
      _showCustomDialog(
        title: 'Already Joined!',
        message: 'You are already a participant in "${item.title}". You can access the chat and details inside this Rush-In.',
        icon: Icons.check_circle,
        color: const Color(0xFF10B981),
      );
      return;
    }

    if (item.hasRequested) {
      _showCustomDialog(
        title: 'Request Pending',
        message: 'Your request to join "${item.title}" is currently pending approval from the host.',
        icon: Icons.hourglass_empty,
        color: const Color(0xFFFF9F0A),
      );
      return;
    }
    
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;
      if (uid == null) return;

      if (item.isFull) {
        _showToast('📋 Added to Waitlist!', 'You\'re on the waitlist for "${item.title}". You\'ll be notified when a spot opens.');
        return;
      }

      // Optimistically update to pending
      setState(() {
        _optimisticPendingIds.add(item.id);
      });

      // Show Join Request Sent popup immediately
      _showCustomDialog(
        title: 'Join Request Sent!',
        message: 'Your request to join "${item.title}" has been sent to the host. You will be notified once they approve.',
        icon: Icons.electric_bolt_rounded,
        color: const Color(0xFFFF6B00),
      );

      await sb.from('requests').insert({
        'sender_id': uid,
        'target_id': item.id,
        'target_type': 'rush_in',
        'status': 'pending',
      });

      _refreshAll(); // Refresh to sync database status
    } catch (e) {
      // Revert optimistic update
      setState(() {
        _optimisticPendingIds.remove(item.id);
      });
      _showToast('Error', 'Failed to send request: $e');
    }
  }

  Future<void> _handleHide(SparkItem item) async {
    Navigator.pop(context); // Close sheet
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;
      if (uid == null) return;
      await sb.from('hidden_feed').insert({
        'user_id': uid,
        'item_id': item.id,
      });

      if (!mounted) return;
      _showToast('🚫 Hidden', 'You won\'t see this rush-in anymore.');
      _refreshAll(); // Refresh feed and counts
    } catch (e) {
      _showToast('Error', 'Failed to hide item: $e');
    }
  }

  void _showToast(String title, String desc) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (context) => _SparkToast(title: title, desc: desc, onDismiss: () => _toastEntry?.remove()),
    );
    if (!mounted) return;
    final entry = _toastEntry;
    if (entry != null) {
      Overlay.of(context).insert(entry);
    }
  }

  void _showCustomDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeInOut.transform(anim1.value);
        return Transform.scale(
          scale: 0.85 + 0.15 * curve,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: const Color(0xFF151821),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B00),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : SparkColors.bg,
      body: Stack(
        children: [
          
          // 1. Map View (Full Screen Background)
          if (_activeView == 'map') 
            Positioned.fill(child: _buildMapView()),

          // 2. Foreground Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                if (_activeView == 'list')
                  Expanded(child: _buildListView()),
              ],
            ),
          ),

          // Progress Bar (Mock at top)
          _buildScrollProgress(),
        ],
      ),
      floatingActionButton: null,
    );
  }


  Widget _buildScrollProgress() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _scrollController,
            builder: (context, _) {
              double progress = 0;
              if (_scrollController.hasClients) {
                try {
                  final pos = _scrollController.position;
                  if (pos.hasContentDimensions) {
                    final max = pos.maxScrollExtent;
                    if (max > 0) {
                      progress = (_scrollController.offset / max).clamp(0.0, 1.0);
                    }
                  }
                } catch (_) {
                  // Fallback for invalid positions
                }
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 3,
                  width: constraints.maxWidth * progress,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [SparkColors.orange, SparkColors.yellow, SparkColors.cyan]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final doodle = isDoodleMode(context);
    bool isLightMap = _activeView == 'map' && !_isMapDark;
    Color textColor = doodle ? DoodleColors.textPrimary : (isLightMap ? Colors.black : Colors.white);
    Color iconColor = doodle ? DoodleColors.textSecondary : (isLightMap ? Colors.black87 : Colors.white70);
    Color bgBoxColor = doodle ? DoodleColors.paper : (isLightMap ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05));
    Color borderBoxColor = doodle ? DoodleColors.cardBorder : (isLightMap ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios_new, color: textColor, size: 22),
                const SizedBox(width: 8),
                doodle
                  ? Text(
                      "Rush-in",
                      style: DoodleFonts.heading(fontSize: 32, color: textColor, fontWeight: FontWeight.w700),
                    )
                  : Text(
                      "RUSH-IN",
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: textColor,
                        letterSpacing: 1.5,
                      ),
                    ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _activeView = _activeView == 'list' ? 'map' : 'list'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: bgBoxColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderBoxColor, width: doodle ? 1.5 : 1.0),
              ),
              child: Row(
                children: [
                  Icon(_activeView == 'list' ? Icons.map_outlined : Icons.list_rounded, color: iconColor, size: 16),
                  const SizedBox(width: 6),
                  Text(_activeView == 'list' ? 'Map View' : 'List View', 
                    style: doodle 
                      ? DoodleFonts.body(color: iconColor, fontSize: 13, fontWeight: FontWeight.w700)
                      : GoogleFonts.inter(color: iconColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- LIST VIEW COMPONENTS ---
  Widget _buildListView() {
    final activeDistrict = locationService.activeDistrict;
    final myLat = locationService.activeLat;
    final myLng = locationService.activeLng;

    final list = _rushIns;
    var filteredList = list.where((e) {
      // ── Location filter (list view only) ──
      if (myLat != null && myLng != null) {
        // If we have GPS coords, use a 50 km bounding box
        final dist = locationService.calculateDistanceInKm(myLat, myLng, e.lat, e.lng);
        if (dist > 50.0) return false;
      } else if (activeDistrict.isNotEmpty && activeDistrict != 'Unknown') {
        // Fallback: district string match
        final itemDistrict = (e.district ?? '').toLowerCase();
        final itemLocation = (e.location ?? '').toLowerCase();
        final needle = activeDistrict.toLowerCase();
        if (!itemDistrict.contains(needle) && !itemLocation.contains(needle)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(query);
        final matchLoc = e.location?.toLowerCase().contains(query) ?? false;
        final matchHost = e.host.toLowerCase().contains(query);
        if (!matchTitle && !matchLoc && !matchHost) return false;
      }
      
      if (_selectedCategories.isNotEmpty) {
        bool matchCat = false;
        final itemTags = e.tags.join(', ');
        for (final cat in _selectedCategories) {
          if (itemTags.contains(cat)) {
            matchCat = true;
            break;
          }
        }
        if (!matchCat) return false;
      }
      return true;
    }).toList();

    // Sorting logic
    if (_sortBy == 'Nearest') {
      final myLat0 = locationService.activeLat ?? 0.0;
      final myLng0 = locationService.activeLng ?? 0.0;
      filteredList.sort((a, b) {
        final distA = locationService.calculateDistanceInKm(myLat0, myLng0, a.lat, a.lng);
        final distB = locationService.calculateDistanceInKm(myLat0, myLng0, b.lat, b.lng);
        return distA.compareTo(distB);
      });
    } else if (_sortBy == 'Newest') {
      filteredList.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    } else if (_sortBy == 'Expiring Soon') {
      filteredList.sort((a, b) {
        final timeA = a.activityTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.activityTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final now = DateTime.now();
        final diffA = timeA.difference(now).inMilliseconds;
        final diffB = timeB.difference(now).inMilliseconds;
        if (diffA > 0 && diffB > 0) return diffA.compareTo(diffB);
        if (diffA > 0) return -1;
        if (diffB > 0) return 1;
        return diffB.compareTo(diffA);
      });
    } else if (_sortBy == 'Most Members') {
      filteredList.sort((a, b) => b.joinedMembers.compareTo(a.joinedMembers));
    }
    
    final remainingItems = filteredList;
    final cityLabel = activeDistrict.isNotEmpty && activeDistrict != 'Unknown' ? activeDistrict : 'your area';

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16).copyWith(bottom: 120),
      children: [
        _buildSearchBar('Search rush-ins...'),
        const SizedBox(height: 16),
        _buildDashboardOverview(),
        const SizedBox(height: 28),

        // HAPPENING NOW Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Happening Now',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'See all',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF6B00),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (remainingItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: const Center(child: Icon(Icons.electric_bolt_rounded, color: Colors.white, size: 32)),
                ),
                const SizedBox(height: 16),
                Text('No Rush-ins in $cityLabel',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Be the first to create one — hit the ⚡ button!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              ],
            ),
          )
        else
          Column(
            children: remainingItems.map((item) => _buildListTile(item)).toList(),
          ),
      ],
    );
  }

  Widget _buildCardImageWidget(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(width: width, height: height, color: const Color(0xFF1a1a2e)),
        );
      } catch (_) {
        return Container(width: width, height: height, color: const Color(0xFF1a1a2e));
      }
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(width: width, height: height, color: const Color(0xFF1a1a2e)),
    );
  }

  Widget _buildFeaturedEvent(SparkItem item) {
    final imageId = item.id.hashCode.abs() % 100;
    final imageUrl = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
        ? item.imageUrl!
        : 'https://picsum.photos/seed/${imageId + 5}/800/600';

    // Compute dynamic timer for featured card
    String _featTimer = item.timer ?? '2h left';
    bool _featIsLive = false;
    if (item.activityTime != null) {
      final now = DateTime.now();
      final diff = item.activityTime!.difference(now);
      if (diff.isNegative) {
        _featIsLive = true;
        if (item.expiresAt != null) {
          final endDiff = item.expiresAt!.difference(now);
          if (endDiff.isNegative) {
            _featTimer = 'Ended';
          } else if (endDiff.inHours > 0) {
            _featTimer = 'Ends in ${endDiff.inHours}h ${endDiff.inMinutes % 60}m';
          } else {
            _featTimer = 'Ends in ${endDiff.inMinutes}m';
          }
        } else {
          _featTimer = 'Live Now';
        }
      } else if (diff.inHours > 0) {
        _featTimer = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        _featTimer = 'Starts in ${diff.inMinutes}m';
      }
    }

    final doodle = isDoodleMode(context);
    return GestureDetector(
      onTap: () => _showDetailSheet(item),
      child: Container(
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: doodle ? DoodleDecorations.card() : BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(doodle ? 16 : 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardImageWidget(imageUrl, fit: BoxFit.cover),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              // Live status & Time remaining
              Positioned(
                top: 16,
                left: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE NOW',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _featIsLive ? Colors.red.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _featIsLive ? Icons.local_fire_department : Icons.access_time,
                            color: Colors.white, size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _featTimer,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Title & details overlay
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.toUpperCase(),
                      style: doodle
                        ? DoodleFonts.subheading(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800)
                        : GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          item.location?.isNotEmpty == true ? item.location!.split(',').first : 'Brooklyn, NY',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.people, color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${item.slots} filled',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(SparkItem item) {
    final imageId = item.id.hashCode.abs() % 100;
    final imageUrl = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
        ? item.imageUrl!
        : 'https://picsum.photos/seed/${imageId + 22}/800/600';
        
    // Distance calc
    final myLat = locationService.activeLat ?? 0.0;
    final myLng = locationService.activeLng ?? 0.0;
    final dist = locationService.calculateDistanceInKm(myLat, myLng, item.lat, item.lng);
    final distStr = '${dist.toStringAsFixed(1)} km away';

    // Time left / Expire calc
    String timerOverlay = 'TBA';
    bool isExpiredWarning = false;
    if (item.activityTime != null) {
      final now = DateTime.now();
      final diff = item.activityTime!.difference(now);
      if (diff.isNegative) {
        isExpiredWarning = true;
        if (item.expiresAt != null) {
          final endDiff = item.expiresAt!.difference(now);
          if (endDiff.isNegative) {
            timerOverlay = 'Ended';
          } else {
            if (endDiff.inHours > 0) {
              timerOverlay = 'Ends in ${endDiff.inHours}h ${endDiff.inMinutes % 60}m';
            } else {
              timerOverlay = 'Ends in ${endDiff.inMinutes}m';
            }
          }
        } else {
          timerOverlay = 'Live / Expires soon';
        }
      } else {
        if (diff.inHours > 0) {
          timerOverlay = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          timerOverlay = 'Starts in ${diff.inMinutes}m';
        }
      }
    }

    // Slots
    int joined = 0; int limit = 0;
    if (item.slots.isNotEmpty) {
      final pts = item.slots.split('/');
      if (pts.length == 2) {
        joined = int.tryParse(pts[0].trim()) ?? 0;
        limit = int.tryParse(pts[1].trim()) ?? 0;
      }
    }
    final slotsStr = limit > 0 ? '$joined/$limit Crew' : '$joined Joined';

    final doodle = isDoodleMode(context);
    if (doodle) {
      return GestureDetector(
        onTap: () => _showDetailSheet(item),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: DoodleDecorations.card(color: DoodleColors.cream),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80, height: 80,
                  child: _buildCardImageWidget(imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: DoodleFonts.heading(color: DoodleColors.brown, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: DoodleColors.brown, size: 12),
                        const SizedBox(width: 4),
                        Text('24 May • 7:00 PM', style: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: DoodleColors.brown, size: 12),
                        const SizedBox(width: 4),
                        Expanded(child: Text(item.location ?? 'Location', style: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Avatar stack for "going"
                        SizedBox(
                          width: 50, height: 20,
                          child: Stack(
                            children: [
                              for (int i=0; i<3; i++)
                                Positioned(
                                  left: i * 14.0,
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(color: DoodleColors.paper, shape: BoxShape.circle, border: Border.all(color: DoodleColors.brown, width: 1)),
                                    child: Center(child: Icon(Icons.person, size: 12, color: DoodleColors.brown)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text('+${limit > 0 ? joined : 12} going', style: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _handleJoin(item),
                child: Container(
                  margin: const EdgeInsets.only(top: 30),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: DoodleDecorations.card(color: DoodleColors.orange, radius: 20),
                  child: Text(item.isApproved ? 'Joined' : (item.hasRequested ? 'Pending' : 'Join'), style: DoodleFonts.body(color: DoodleColors.brown, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showDetailSheet(item),
      child: Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: doodle ? DoodleDecorations.card() : BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(doodle ? 16 : 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardImageWidget(imageUrl, fit: BoxFit.cover),
              // Gradient for text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              
              // Top-Left: Time Left
              Positioned(
                top: 14, left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpiredWarning ? Colors.red.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(isExpiredWarning ? Icons.local_fire_department : Icons.access_time, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(timerOverlay, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              
              // Top-Right: Crew limit
              Positioned(
                top: 14, right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(slotsStr, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // Bottom-Left: Distance and Title
              Positioned(
                bottom: 16, left: 16, right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text(distStr, style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${item.host}',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom-Right CTA button: "JOIN" or pending status
                    GestureDetector(
                      onTap: () => _handleJoin(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: item.isApproved ? const Color(0xFF10B981) : 
                                 (item.hasRequested ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFFF6B00)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.isApproved ? 'JOINED' : (item.hasRequested ? 'PENDING' : 'JOIN'),
                          style: GoogleFonts.inter(
                            color: item.isApproved || item.hasRequested ? Colors.white : Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildDashboardOverview() {
    final doodle = isDoodleMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (doodle)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: DoodleDecorations.card(color: DoodleColors.amber.withValues(alpha: 0.5)).copyWith(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const DoodleDecoration(icon: Icons.star_border, color: DoodleColors.orange, size: 16, rotation: -10),
                      const SizedBox(width: 8),
                      Text('YOUR RUSH-INS', style: DoodleFonts.heading(fontSize: 18, color: DoodleColors.brown)),
                      const SizedBox(width: 8),
                      const DoodleDecoration(icon: Icons.star_border, color: DoodleColors.orange, size: 16, rotation: 10),
                    ],
                  ),
                )
              else ...[
                Text('Your ', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Rush-Ins", style: GoogleFonts.plusJakartaSans(color: SparkColors.orange, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome, color: SparkColors.purple, size: 20),
              ]
            ],
          ),
          if (!doodle) ...[
            const SizedBox(height: 4),
            Text('Manage events you create and the ones you\'re part of.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildHeroCard(
                  doodle: doodle,
                  title: doodle ? "EVENTS I'M\nHOSTING" : 'Events I\'m\nHosting',
                  subtitle: '${_myHostedRushIns.length + 0} Active Event(s)',
                  desc: doodle ? 'Events you created\nand are hosting.' : 'Events you created\nand are hosting.',
                  colors: [SparkColors.orange.withValues(alpha: 0.15), SparkColors.orange.withValues(alpha: 0.05)],
                  borderColor: SparkColors.orange.withValues(alpha: 0.3),
                  accentColor: SparkColors.orange,
                  doodleColor: DoodleColors.orange,
                  icon: Icons.mic_external_on,
                  chipLabel: doodle ? 'YOU CREATE' : 'You create',
                  onTap: _showHostedSheet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHeroCard(
                  doodle: doodle,
                  title: doodle ? "UPCOMING\nEVENTS" : 'Upcoming\nEvents',
                  subtitle: '${_myJoinedRushIns.length + 0} Upcoming',
                  desc: doodle ? 'Events you\'re going to\nor have joined.' : 'Events you\'re going to\nor have joined.',
                  colors: [SparkColors.blue.withValues(alpha: 0.15), SparkColors.purple.withValues(alpha: 0.05)],
                  borderColor: SparkColors.blue.withValues(alpha: 0.3),
                  accentColor: SparkColors.blue,
                  doodleColor: DoodleColors.blue,
                  icon: Icons.calendar_month,
                  chipLabel: doodle ? 'YOU JOIN' : 'You join',
                  onTap: _showJoinedSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({required bool doodle, required String title, required String subtitle, required String desc, required List<Color> colors, required Color borderColor, required Color accentColor, required Color doodleColor, required IconData icon, required String chipLabel, required VoidCallback onTap}) {
    if (doodle) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 250,
          decoration: DoodleDecorations.card(color: doodleColor, borderColor: DoodleColors.brown, radius: 12),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: 10,
                child: Transform.rotate(
                  angle: 0.1,
                  child: DoodleDecoration(icon: icon, color: DoodleColors.brown, size: 80, rotation: 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: DoodleColors.brown,
                      child: Text(chipLabel, style: DoodleFonts.body(color: Colors.white, fontSize: 10)),
                    ),
                    const SizedBox(height: 16),
                    Text(title, style: DoodleFonts.heading(color: DoodleColors.brown, fontSize: 22).copyWith(height: 1.1)),
                    const SizedBox(height: 12),
                    Text(subtitle, style: DoodleFonts.body(color: DoodleColors.brown, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(desc, style: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12).copyWith(height: 1.2)),
                    const Spacer(),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: DoodleColors.brown, width: 2),
                      ),
                      child: const Icon(Icons.arrow_forward, color: DoodleColors.brown, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: 20,
              child: Icon(icon, size: 100, color: accentColor.withValues(alpha: 0.2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: accentColor, size: 10),
                        const SizedBox(width: 4),
                        Text(chipLabel, style: GoogleFonts.inter(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: GoogleFonts.inter(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(desc, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, height: 1.3)),
                  const Spacer(),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                      color: accentColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.arrow_forward, color: accentColor, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vtBtn(String title, IconData icon, String view) {
    bool active = _activeView == view;
    return GestureDetector(
      onTap: () => _setView(view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: [SparkColors.orange.withValues(alpha: 0.2), SparkColors.yellow.withValues(alpha: 0.15)]) : null,
          border: Border.all(color: active ? SparkColors.orange.withValues(alpha: 0.2) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? SparkColors.orange : SparkColors.muted, size: 13),
            const SizedBox(width: 5),
            Text(title, style: TextStyle(color: active ? SparkColors.orange : SparkColors.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ---- BOTTOM SHEETS ----
  void _showHostedSheet() {
    final items = [..._myHostedRushIns];
    items.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    
    final accent = SparkColors.orange;
    const title = 'Events I\'m Hosting';
    const emptyMsg = "You haven't created any events yet";

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.rocket_launch, color: accent, size: 20), const SizedBox(width: 8),
            Text(title, style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${items.length}', style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.bold)),
          ])),
          Divider(height: 1, color: accent.withValues(alpha: 0.1)),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Column(children: [
              const Icon(Icons.inbox_outlined, color: SparkColors.muted, size: 48), const SizedBox(height: 12),
              Text(emptyMsg, style: const TextStyle(color: SparkColors.muted, fontSize: 13), textAlign: TextAlign.center),
            ]))
          else
            Flexible(child: ListView.separated(
              shrinkWrap: true, padding: const EdgeInsets.all(12), itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = items[i];
                final isItemRush = item['is_rush_in'] == true || (item['description']?.toString().contains('[is_rush_in:true]') ?? false);
                final itemAccent = isItemRush ? SparkColors.orange : SparkColors.actPrimary;
                final joinedC = item['_joinedCount'] ?? 0;
                final pendingC = item['_pendingCount'] ?? 0;
                final limit = item['participant_limit'] ?? 4;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RushInConsumerDetailView(activity: item, onInteraction: () => _refreshAll()),
                    ));
                  },
                  child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: SparkColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: itemAccent.withValues(alpha: 0.12))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(item['title'] ?? 'Untitled', style: const TextStyle(color: SparkColors.txt, fontSize: 14, fontWeight: FontWeight.w600))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: itemAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(isItemRush ? 'Rush-in' : 'Activity', style: TextStyle(color: itemAccent, fontSize: 10, fontWeight: FontWeight.w600))),
                    ]),
                    if ((item['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item['description'].toString().replaceAll(RegExp(r'\n?\[[a-zA-Z0-9_]+:.*?\]'), '').trim(), style: const TextStyle(color: SparkColors.muted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      _sheetChip(Icons.people, '$joinedC/$limit joined', SparkColors.green),
                      const SizedBox(width: 8),
                      if (pendingC > 0) _sheetChip(Icons.hourglass_top, '$pendingC pending', SparkColors.yellow),
                    ]),
                    if (item['location_name']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on, color: SparkColors.muted, size: 13), const SizedBox(width: 4),
                        Expanded(child: Text(item['location_name'], style: const TextStyle(color: SparkColors.txt2, fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ]),
                ));
              },
            )),
        ]),
      ),
    );
  }

  void _showJoinedSheet() {
    final items = [..._myJoinedRushIns];
    items.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    
    final accent = SparkColors.purple;
    const title = 'Joined / Pending Events';
    const emptyMsg = "You haven't joined any events yet";

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.group, color: accent, size: 20), const SizedBox(width: 8),
            Text(title, style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${items.length}', style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.bold)),
          ])),
          Divider(height: 1, color: accent.withValues(alpha: 0.1)),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Column(children: [
              const Icon(Icons.explore_off, color: SparkColors.muted, size: 48), const SizedBox(height: 12),
              Text(emptyMsg, style: const TextStyle(color: SparkColors.muted, fontSize: 13), textAlign: TextAlign.center),
            ]))
          else
            Flexible(child: ListView.separated(
              shrinkWrap: true, padding: const EdgeInsets.all(12), itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = items[i];
                final isItemRush = item['is_rush_in'] == true || (item['description']?.toString().contains('[is_rush_in:true]') ?? false);
                final itemAccent = isItemRush ? SparkColors.purple : SparkColors.actSecondary;
                final status = item['_myStatus']?.toString() ?? 'pending';
                final hostName = item['_hostName'] ?? 'Someone';
                final isApproved = status == 'approved';
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RushInConsumerDetailView(activity: item, onInteraction: () => _refreshAll()),
                    ));
                  },
                  child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: SparkColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: itemAccent.withValues(alpha: 0.12))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(item['title'] ?? 'Untitled', style: const TextStyle(color: SparkColors.txt, fontSize: 14, fontWeight: FontWeight.w600))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: itemAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(isItemRush ? 'Rush-in' : 'Activity', style: TextStyle(color: itemAccent, fontSize: 10, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isApproved ? SparkColors.green.withValues(alpha: 0.15) : SparkColors.yellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isApproved ? Icons.check_circle : Icons.schedule, color: isApproved ? SparkColors.green : SparkColors.yellow, size: 11),
                          const SizedBox(width: 4),
                          Text(isApproved ? 'Approved' : 'Pending', style: TextStyle(color: isApproved ? SparkColors.green : SparkColors.yellow, fontSize: 10, fontWeight: FontWeight.w600)),
                        ])),
                    ]),
                    if ((item['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item['description'].toString().replaceAll(RegExp(r'\n?\[[a-zA-Z0-9_]+:.*?\]'), '').trim(), style: const TextStyle(color: SparkColors.muted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.person, color: SparkColors.txt2, size: 13), const SizedBox(width: 4),
                      Text('Hosted by $hostName', style: const TextStyle(color: SparkColors.txt2, fontSize: 11)),
                    ]),
                    if (item['location_name']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on, color: SparkColors.muted, size: 13), const SizedBox(width: 4),
                        Expanded(child: Text(item['location_name'], style: const TextStyle(color: SparkColors.txt2, fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ]),
                ));
              },
            )),
        ]),
      ),
    );
  }

  Widget _sheetChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12), const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _showFilterSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SparkFilterSheet(
        initialCategories: _selectedCategories,
        initialSort: _sortBy,
      ),
    );
    if (result != null && result is Map) {
      setState(() {
        _selectedCategories = result['categories'];
        _sortBy = result['sort'];
      });
    }
  }

  Widget _buildSearchBar(String hint) {
    final doodle = isDoodleMode(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: doodle
                ? DoodleDecorations.input()
                : BoxDecoration(
                    color: SparkColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SparkColors.gborder),
                  ),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Icon(Icons.search, color: doodle ? DoodleColors.brown : SparkColors.muted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: SparkColors.txt, fontSize: 13),
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5)) : const TextStyle(color: SparkColors.muted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      width: 34, height: 34,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: doodle 
                        ? DoodleDecorations.card(color: DoodleColors.orange, radius: 8)
                        : BoxDecoration(
                            gradient: const LinearGradient(colors: [SparkColors.orange, SparkColors.yellow]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                      child: Icon(Icons.tune, color: doodle ? DoodleColors.brown : Colors.black, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!doodle) const SizedBox(width: 12),
          if (!doodle) GestureDetector(
            onTap: () {
              final lat = locationService.activeLat ?? 28.6139;
              final lng = locationService.activeLng ?? 77.2090;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HostActivityScreen(
                    initialLocation: LatLng(lat, lng),
                    initialIsRushIn: true,
                  ),
                ),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [SparkColors.orange, SparkColors.yellow]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: SparkColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final doodle = isDoodleMode(context);
    if (doodle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: DoodleDecorations.card(color: DoodleColors.amber.withValues(alpha: 0.5)).copyWith(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(title.toUpperCase(), style: DoodleFonts.heading(fontSize: 16, color: DoodleColors.brown)),
            ),
            GestureDetector(
              onTap: _showFilterSheet,
              child: Row(
                children: [
                  Text('See all', style: DoodleFonts.heading(color: DoodleColors.brown, fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, color: DoodleColors.brown, size: 14),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          GestureDetector(
            onTap: _showFilterSheet,
            child: const Row(
              children: [
                Text('Filter', style: TextStyle(color: SparkColors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.tune, color: SparkColors.orange, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- MAP VIEW ---
  Widget _buildMapView() {
    return _SparkMapView(
      isDark: _isMapDark,
      onThemeToggle: (val) => setState(() => _isMapDark = val),
    );
  }

  // --- CARDS ---
  List<Widget> _buildRushInCards() {
    if (_loadingData) {
      return [const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: SparkColors.orange, strokeWidth: 2)))];
    }
    final activeDist = locationService.activeDistrict.trim().toLowerCase();
    final list = _rushIns.where((e) {
      if (!e.isWithinHostRadius) return false;
      if (activeDist.isNotEmpty && activeDist != 'unknown') {
        final d = e.district?.toLowerCase() ?? '';
        if (d.isNotEmpty && !d.contains(activeDist)) return false;
      }
      return e.title.toLowerCase().contains(_searchQuery);
    }).toList();
    if (list.isEmpty) {
      return [_buildEmptyState('No rush-ins found', 'Create one and get the ball rolling!', SparkColors.orange)];
    }
    return list.asMap().entries.map((ent) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _showDetailSheet(ent.value),
        child: _RushInCard(item: ent.value).animate().fadeIn(delay: (ent.key*100).ms).slideY(begin: 0.1, end: 0),
      ),
    )).toList();
  }

  List<Widget> _buildActivityCards() {
    if (_loadingData) {
      return [const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: SparkColors.actPrimary, strokeWidth: 2)))];
    }
    final activeDist = locationService.activeDistrict.trim().toLowerCase();
    var list = _rushIns.where((e) {
      if (!e.isWithinHostRadius) return false;
      if (activeDist.isNotEmpty && activeDist != 'unknown') {
        final d = e.district?.toLowerCase() ?? '';
        if (d.isNotEmpty && !d.contains(activeDist)) return false;
      }
      return e.title.toLowerCase().contains(_searchQuery);
    }).toList();
    if (_selectedCategories.isNotEmpty && !_selectedCategories.contains('All')) {
      list = list.where((e) => e.tags.any((t) => _selectedCategories.contains(t))).toList();
    }
    
    List<Widget> children = [];
    if (list.isEmpty) {
      children.add(_buildEmptyState('No activities found', 'Try a different category or create one!', SparkColors.actPrimary));
    } else {
      children.addAll(list.asMap().entries.map((ent) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: () => _showDetailSheet(ent.value),
          child: _ActivityCard(item: ent.value).animate().fadeIn(delay: (ent.key*100).ms).slideY(begin: 0.1, end: 0),
        ),
      )));
    }
    
    // Append the CTA banner
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 40),
        child: _buildCreateEventBanner().animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
      )
    );
    
    return children;
  }

  Widget _buildCreateEventBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SparkColors.orange.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SparkColors.orange.withValues(alpha: 0.15),
            SparkColors.pink.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: SparkColors.orange.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: SparkColors.orange, size: 24)
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .shimmer(duration: 2000.ms, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Create. Invite. Experience.',
                              style: GoogleFonts.plusJakartaSans(
                                color: SparkColors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bring your ideas to life. The world is ready to join!',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => HostActivityScreen(
                        initialLocation: locationService.activeLat != null && locationService.activeLng != null
                          ? LatLng(locationService.activeLat!, locationService.activeLng!)
                          : const LatLng(0, 0),
                        initialIsRushIn: false,
                      ),
                    )).then((_) => _refreshAll());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SparkColors.orange, SparkColors.pink],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: SparkColors.orange.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Create Event',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.search_off, color: color.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: SparkColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActCategoryScroll() {
    final cats = [
      {'icon':'🔥', 'label':'All'},
      {'icon':'🏔️', 'label':'Outdoor'},
      {'icon':'🏀', 'label':'Sports'},
      {'icon':'🎵', 'label':'Music'},
      {'icon':'🍕', 'label':'Food'},
      {'icon':'📚', 'label':'Study'},
      {'icon':'🎮', 'label':'Gaming'},
      {'icon':'💪', 'label':'Fitness'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: cats.map((c) {
          final label = c['label'] ?? 'Unknown';
          final icon = c['icon'] ?? '•';
          bool active = _selectedCategories.contains(label) || (label == 'All' && _selectedCategories.isEmpty);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (label == 'All') {
                  _selectedCategories.clear();
                } else {
                  _selectedCategories.remove('All');
                  if (_selectedCategories.contains(label)) {
                    _selectedCategories.remove(label);
                  } else {
                    _selectedCategories.add(label);
                  }
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? SparkColors.actPrimary.withValues(alpha: 0.08) : SparkColors.card,
                border: Border.all(color: active ? SparkColors.actPrimary : SparkColors.gborder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(icon),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: active ? SparkColors.actPrimary : SparkColors.txt2, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// RUSH IN CARD
// ==========================================
class _RushInCard extends StatelessWidget {
  final SparkItem item;
  const _RushInCard({required this.item});

  @override
  Widget build(BuildContext context) {
    int joined = 0;
    int total = 1;
    try {
      if (item.slots.isNotEmpty) {
        final pts = item.slots.split('/');
        if (pts.length == 2) {
          joined = int.tryParse(pts[0].trim()) ?? 0;
          total = int.tryParse(pts[1].trim()) ?? 1;
        }
      }
    } catch (_) {}
    
    double ratio = total > 0 ? (joined / total).clamp(0.0, 1.0) : 0.0;
    bool almostFull = ratio >= 0.75 && ratio < 1.0;
    bool isFull = item.isFull;

    // Dynamically compute timer at render-time from activityTime + expiresAt
    String timerText = item.timer ?? '';
    bool isLive = false;
    if (item.activityTime != null) {
      final now = DateTime.now();
      final diff = item.activityTime!.difference(now);
      if (diff.isNegative) {
        isLive = true;
        if (item.expiresAt != null) {
          final endDiff = item.expiresAt!.difference(now);
          if (endDiff.isNegative) {
            timerText = 'Ended';
          } else if (endDiff.inHours > 0) {
            timerText = 'Ends in ${endDiff.inHours}h ${endDiff.inMinutes % 60}m';
          } else {
            timerText = 'Ends in ${endDiff.inMinutes} mins';
          }
        } else {
          timerText = 'Live Now';
        }
      } else if (diff.inHours > 0) {
        timerText = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        timerText = 'Starts in ${diff.inMinutes} mins';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: SparkColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SparkColors.gborder),
      ),
      child: Stack(
        children: [
          // Top highlight line
          Positioned(top: 0, left: 0, right: 0, height: 3,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [SparkColors.orange, SparkColors.yellow, SparkColors.red]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundImage: item.hostAvatar != null && item.hostAvatar!.startsWith('http') 
                            ? NetworkImage(item.hostAvatar!) 
                            : null,
                          backgroundColor: SparkColors.purple.withValues(alpha: 0.1),
                          child: item.hostAvatar != null && !item.hostAvatar!.startsWith('http') 
                            ? Text(item.hostAvatar!, style: const TextStyle(color: SparkColors.purple, fontSize: 18, fontWeight: FontWeight.bold))
                            : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.host, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(item.type == 'rush' ? 'Rush-in Host' : 'Activity Host', style: const TextStyle(color: SparkColors.muted, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLive
                            ? SparkColors.red.withValues(alpha: 0.25)
                            : (almostFull ? SparkColors.red.withValues(alpha: 0.2) : SparkColors.red.withValues(alpha: 0.1)),
                        border: Border.all(
                            color: isLive
                                ? SparkColors.red.withValues(alpha: 0.6)
                                : (almostFull ? SparkColors.red.withValues(alpha: 0.3) : SparkColors.red.withValues(alpha: 0.2))),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLive ? Icons.local_fire_department : (almostFull ? Icons.local_fire_department : Icons.hourglass_bottom),
                            color: SparkColors.red, size: 12)
                              .animate(onPlay: (c)=>c.repeat(reverse: true)).scale(end: const Offset(1.2,1.2)),
                          const SizedBox(width: 5),
                          Text(timerText, style: const TextStyle(color: SparkColors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SparkColors.muted, fontSize: 12, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: (item.tags.isNotEmpty ? item.tags : ['Rush']).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: SparkColors.gborder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t, style: const TextStyle(color: SparkColors.txt2, fontSize: 11, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: SparkColors.cyan.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              const Icon(Icons.sensors, color: SparkColors.cyan, size: 11),
                              const SizedBox(width: 4),
                              Text('${item.radius} radius', style: const TextStyle(color: SparkColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60, height: 4,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: isFull ? 1.0 : (ratio > 0 ? ratio : 0.05), // ensure tiny sliver visible if 0
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isFull ? SparkColors.muted : (almostFull ? SparkColors.red : SparkColors.orange),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(isFull ? 'Full (${item.waitlist} waitlisted)' : (almostFull ? 'Almost full!' : '${item.slots} joined'), 
                                 style: TextStyle(color: isFull ? SparkColors.muted : (almostFull ? SparkColors.red : SparkColors.muted), fontSize: 11, fontWeight: almostFull ? FontWeight.bold : FontWeight.normal)),
                          ],
                        )
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: (isFull && !item.isApproved) ? null : 
                          (item.isApproved ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]) : 
                           (item.hasRequested ? null : const LinearGradient(colors: [SparkColors.orange, SparkColors.yellow]))),
                        color: (isFull && !item.isApproved) ? SparkColors.purple.withValues(alpha: 0.15) : 
                          (item.hasRequested && !item.isApproved ? Colors.white.withValues(alpha: 0.1) : null),
                        border: Border.all(color: (isFull && !item.isApproved) ? SparkColors.purple.withValues(alpha: 0.3) : (item.hasRequested ? SparkColors.gborder : Colors.transparent)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(item.isApproved ? Icons.check_circle : (item.hasRequested ? Icons.pending : (isFull ? Icons.access_time : Icons.bolt)), 
                               color: item.isApproved ? Colors.white : (item.hasRequested ? SparkColors.txt2 : (isFull ? SparkColors.purple : Colors.black)), size: 12),
                          const SizedBox(width: 5),
                          Text(item.isApproved ? 'Joined' : (item.hasRequested ? 'Requested' : (isFull ? 'Waitlist' : 'Request')), 
                               style: TextStyle(color: item.isApproved ? Colors.white : (item.hasRequested ? SparkColors.txt2 : (isFull ? SparkColors.purple : Colors.black)), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ACTIVITY CARD
// ==========================================
class _ActivityCard extends StatelessWidget {
  final SparkItem item;
  const _ActivityCard({required this.item});

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  Widget _buildCardImageWidget(String imageUrl, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imageUrl.startsWith('data:')) {
      try {
        final bytes = base64Decode(imageUrl.split(',').last);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(width: width, height: height, color: const Color(0xFF1a1a2e)),
        );
      } catch (_) {
        return Container(width: width, height: height, color: const Color(0xFF1a1a2e));
      }
    }
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(width: width, height: height, color: const Color(0xFF1a1a2e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final location = item.location?.split(',').first ?? 'TBD';
    final category = item.tags.isNotEmpty ? item.tags.first.toUpperCase() : 'EVENT';
    
    // Stable pseudo-random image id based on item ID
    final imageId = item.id.hashCode.abs() % 100;
    final image = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
        ? item.imageUrl!
        : 'https://picsum.photos/seed/$imageId/400/300';
    
    // Parse date if possible
    String dateStr = item.date ?? 'TBA';
    if (dateStr != 'TBA') {
       try {
         final parts = dateStr.split('-');
         if (parts.length == 3) {
            int m = int.parse(parts[1]);
            int d = int.parse(parts[2]);
            dateStr = '${_getMonth(m)} $d';
         }
       } catch (_) {}
    }
    final timeStr = item.time != null ? ' • ${item.time}' : '';
    final dateTimeStr = '$dateStr$timeStr';

    int maxParticipants = 20;
    try {
      if (item.slots.isNotEmpty) {
        final pts = item.slots.split('/');
        if (pts.length == 2) {
          maxParticipants = int.tryParse(pts[1].trim()) ?? 20;
        }
      }
    } catch (_) {}

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: SparkColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
            child: Stack(
              children: [
                _buildCardImageWidget(
                  image,
                  width: 120,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, SparkColors.card.withValues(alpha: 0.9), SparkColors.card],
                      stops: const [0.5, 0.9, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        dateTimeStr,
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SparkColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.inter(
                            color: SparkColors.purple,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      
                      // Attendee Avatars Stack
                      SizedBox(
                        width: 60,
                        height: 24,
                        child: Stack(
                          children: List.generate((item.members?.length ?? 2).clamp(0,2), (i) {
                            return Positioned(
                              right: i * 16.0 + 20,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: SparkColors.card, width: 2),
                                  image: DecorationImage(
                                    image: NetworkImage('https://i.pravatar.cc/100?img=${imageId + i + 10}'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          })..add(
                            Positioned(
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.only(left: 4),
                                alignment: Alignment.centerLeft,
                                height: 24,
                                child: Text(
                                  '+$maxParticipants',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Glowing CTA Arrow
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: SparkColors.orange.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: SparkColors.orange.withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: SparkColors.orange, size: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}





// ==========================================
// AMBIENT BACKGROUND
// ==========================================
class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();
  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  // Pre-computed random values so they don't change on every frame
  static final _particleX = List.generate(10, (i) => math.Random(i * 31 + 7).nextDouble());
  static final _particleY = List.generate(10, (i) => math.Random(i * 17 + 3).nextDouble());

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 800.0;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final v = _ctrl.value;
            return Stack(
              children: [
                Positioned(
                  top: -80 - (v * 20), right: -80 + (v * 30),
                  child: const _Orb(size: 280, color: SparkColors.orange),
                ),
                Positioned(
                  bottom: h * 0.2 + (v * 20), left: -60 - (v * 20),
                  child: const _Orb(size: 220, color: SparkColors.purple),
                ),
                Positioned(
                  top: h * 0.5, right: -40 + (v * 20),
                  child: const _Orb(size: 180, color: SparkColors.cyan),
                ),
                // Stable particles
                ...List.generate(10, (i) {
                  return Positioned(
                    left: w * _particleX[i],
                    top: h * _particleY[i] - (v * 50),
                    child: Container(
                      width: 2, height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size; final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.6), Colors.transparent]),
        ),
      ),
    ); // massive blur for ambient effect
  }
}





// ==========================================
// MAP VIEW
// ==========================================
class _SparkMapView extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeToggle;

  const _SparkMapView({required this.isDark, required this.onThemeToggle});
  @override
  State<_SparkMapView> createState() => _SparkMapViewState();
}

class _SparkMapViewState extends State<_SparkMapView> {
  final MapController _mapController = MapController();
  String _layer = 'street';
  bool _showLayersBox = false;
  LatLng? _actualLocation;

  bool _showDropdown = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchActualLocation();
  }

  Future<void> _fetchActualLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        setState(() => _actualLocation = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_actualLocation!, 14.0);
      }
    } catch (_) {
      // Fallback to active location if GPS fails or permission denied
      if (mounted) {
        final lat = locationService.activeLat;
        final lng = locationService.activeLng;
        if (lat != null && lng != null) {
          setState(() => _actualLocation = LatLng(lat, lng));
          _mapController.move(_actualLocation!, 14.0);
        }
      }
    }
  }

  String _getTileUrl() {
    switch (_layer) {
      case 'satellite': return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'terrain': return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'cycling': return 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
      default: return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
          ColorFiltered(
            colorFilter: _layer == 'street' && widget.isDark 
              ? const ColorFilter.matrix([-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0])
              : const ColorFilter.matrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _actualLocation ?? LatLng(locationService.activeLat ?? 20.5937, locationService.activeLng ?? 78.9629),
                initialZoom: 13,
                maxZoom: 22.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: _getTileUrl(), 
                  userAgentPackageName: 'com.meetra.app',
                  maxZoom: 22.0,
                  maxNativeZoom: 17,
                ),
                MarkerLayer(
                  markers: [
                    // User's Live Location Marker
                    if (_actualLocation != null)
                      Marker(
                        point: _actualLocation!,
                        width: 50, height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SparkColors.red.withValues(alpha: 0.2),
                            border: Border.all(color: SparkColors.red.withValues(alpha: 0.6), width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: SparkColors.red, shape: BoxShape.circle),
                            ),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                      ),
                    
                    // Spark Activities & Rush-ins
                    ...sparkDataStore.values.where((v) => !(v.isAnonymous && !v.isApproved)).map((v) => Marker(
                      point: LatLng(v.lat, v.lng), 
                      width: 44, height: 44,
                      child: GestureDetector(
                        onTap: () {
                          final parent = context.findAncestorStateOfType<_SparkScreenState>();
                          if (parent != null) parent._showDetailSheet(v);
                        },
                        child: v.isApproved
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]), // Emerald Neon
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [BoxShadow(color: Color(0xFF10B981), blurRadius: 15, spreadRadius: 3)],
                            ),
                            alignment: Alignment.center,
                            child: Icon(_getVibeIcon(v), color: Colors.white, size: 18),
                          ).animate(onPlay: (c)=>c.repeat(reverse: true)).scale(end: const Offset(1.2, 1.2))
                        : v.type == 'rush' 
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [SparkColors.yellow, SparkColors.orange]),
                                border: Border.all(color: SparkColors.yellow.withValues(alpha: 0.6), width: 3),
                                boxShadow: [BoxShadow(color: SparkColors.yellow.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2)],
                              ),
                              alignment: Alignment.center,
                              child: Icon(_getVibeIcon(v), color: Colors.white, size: 22),
                            ).animate(onPlay: (c)=>c.repeat(reverse: true)).scale(end: const Offset(1.15, 1.15))
                          : Container(
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(colors: [SparkColors.actPrimary, SparkColors.actSecondary]),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.white, size: 14),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(),
                      ),
                    )),
                  ],
                )
              ],
            ),
          ),
          
          // Search & Mode
          Positioned(top: 100, left: 16, right: 16, child: _buildMapSearch()),
          if (_showDropdown)
            Positioned(
              top: 150, left: 16, right: 66,
              child: _buildSearchResults(),
            ),
          
          // Layer button
          Positioned(bottom: 120, left: 16, child: _buildMapControlBtn(Icons.layers, () => setState(() => _showLayersBox = !_showLayersBox))),
          if (_showLayersBox)
            Positioned(bottom: 170, left: 16, child: _buildLayerBox()),
            
          // My loc button
          Positioned(bottom: 120, right: 16, child: _buildMapControlBtn(Icons.my_location, () async {
            try {
              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
              if (!serviceEnabled) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Row(children: [Icon(Icons.location_off, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Please enable location services'))]),
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Row(children: [Icon(Icons.not_listed_location, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permission denied'))]),
                      backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                  return;
                }
              }
              if (permission == LocationPermission.deniedForever) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Row(children: [Icon(Icons.settings, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permanently denied. Enable in settings.'))]),
                    backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    action: SnackBarAction(label: 'Settings', textColor: Colors.white, onPressed: () => Geolocator.openAppSettings()),
                  ));
                }
                return;
              }
              final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
              _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
              
              String locationText = 'Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
              try {
                final reverseUrl = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&addressdetails=1';
                final res = await http.get(Uri.parse(reverseUrl), headers: {'User-Agent': 'RelayaApp/1.0'});
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  final address = data['address'];
                  if (address != null) {
                    final local = address['hospital'] ?? address['amenity'] ?? address['mall'] ?? address['building'] ?? address['neighbourhood'] ?? address['suburb'] ?? address['village'] ?? address['city_district'] ?? '';
                    final district = address['state_district'] ?? address['county'] ?? address['city'] ?? '';
                    final state = address['state'] ?? '';
                    
                    List<String> parts = [];
                    if (local.toString().isNotEmpty) parts.add('Near $local');
                    if (district.toString().isNotEmpty) parts.add(district);
                    if (state.toString().isNotEmpty) parts.add(state);
                    
                    if (parts.isNotEmpty) {
                      locationText = parts.join(', ');
                    } else if (data['display_name'] != null) {
                      locationText = data['display_name'].toString().split(',').take(2).join(',');
                    }
                  }
                }
              } catch (_) {}

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18), 
                    const SizedBox(width: 8), 
                    Expanded(child: Text(locationText, maxLines: 2, overflow: TextOverflow.ellipsis))
                  ]),
                  backgroundColor: SparkColors.cyan, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 3),
                ));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('Could not get location: $e'))]),
                  backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              }
            }
          })),
        ],
    );
  }

  final TextEditingController _searchCtrl = TextEditingController();

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
    try {
      final encoded = Uri.encodeComponent(query);
      final url = 'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5&addressdetails=1';
      
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'RelayaApp/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data.map((it) => {
              'display_name': it['display_name'].toString().split(',').first.trim(),
              'full_name': it['display_name'].toString(),
              'lat': double.parse(it['lat'].toString()),
              'lon': double.parse(it['lon'].toString()),
            }).toList();
            _showDropdown = _searchResults.isNotEmpty;
          });
        }
      }
    } catch (_) {}
  }

  void _selectResult(Map<String, dynamic> res) {
    final lat = res['lat'] as double;
    final lon = res['lon'] as double;
    
    setState(() {
      _searchResults = [];
      _showDropdown = false;
      _searchCtrl.text = res['display_name'];
    });
    FocusScope.of(context).unfocus();
    _mapController.move(LatLng(lat, lon), 15.0);
  }

  Future<void> _searchAndMove(String query) async {
    if (query.isEmpty) return;
    try {
      final encoded = Uri.encodeComponent(query);
      final url = 'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1';
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'RelayaApp/1.0'});
      final List data = jsonDecode(res.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat'].toString());
        final lon = double.parse(data[0]['lon'].toString());
        _mapController.move(LatLng(lat, lon), 14);
        setState(() {
          _searchResults = [];
          _showDropdown = false;
        });
      }
    } catch (_) {}
  }

  Widget _buildMapSearch() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xEB111827) : Colors.white.withValues(alpha: 0.9), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: widget.isDark ? SparkColors.gborder : Colors.black12)
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: widget.isDark ? SparkColors.muted : Colors.black54, size: 16),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onSubmitted: _searchAndMove,
                  style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13), 
                  decoration: InputDecoration(hintText: 'Search places...', hintStyle: TextStyle(color: widget.isDark ? SparkColors.muted : Colors.black54), border: InputBorder.none, isDense: true)
                )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => widget.onThemeToggle(!widget.isDark),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xEB111827) : Colors.white.withValues(alpha: 0.9), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: widget.isDark ? SparkColors.gborder : Colors.black12)
            ),
            child: Icon(widget.isDark ? Icons.dark_mode : Icons.wb_sunny, color: widget.isDark ? SparkColors.yellow : Colors.orange, size: 16),
          ),
        )
      ],
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xEB111827) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? SparkColors.gborder : Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(color: widget.isDark ? Colors.white10 : Colors.black12, height: 1),
        itemBuilder: (ctx, i) {
          final res = _searchResults[i];
          return ListTile(
            dense: true,
            leading: Icon(Icons.location_on, color: widget.isDark ? SparkColors.muted : Colors.black54, size: 18),
            title: Text(res['display_name'], style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(res['full_name'], style: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _selectResult(res),
          );
        },
      ),
    );
  }

  Widget _buildMapControlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xEB111827) : Colors.white.withValues(alpha: 0.9), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: widget.isDark ? SparkColors.gborder : Colors.black12)
        ),
        child: Icon(icon, color: widget.isDark ? SparkColors.txt2 : Colors.black87, size: 16),
      ),
    );
  }

  Widget _buildLayerBox() {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xF2111827) : Colors.white.withValues(alpha: 0.95), 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: widget.isDark ? SparkColors.gborder : Colors.black12)
      ),
      child: Column(
        children: [
          _layerOpt('street', 'Street', Icons.add_road),
          _layerOpt('terrain', 'Terrain', Icons.terrain),
          _layerOpt('satellite', 'Satellite', Icons.satellite_alt),
          _layerOpt('cycling', 'Cycling', Icons.pedal_bike),
        ],
      ),
    );
  }

  Widget _layerOpt(String key, String label, IconData icon) {
    bool active = _layer == key;
    return GestureDetector(
      onTap: () => setState(() { _layer = key; _showLayersBox = false; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: active ? SparkColors.orange.withValues(alpha: widget.isDark ? 0.1 : 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, color: active ? SparkColors.orange : (widget.isDark ? SparkColors.txt2 : Colors.black87), size: 14),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: active ? SparkColors.orange : (widget.isDark ? SparkColors.txt2 : Colors.black87), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

}

// ==========================================
// DETAIL SHEET
// ==========================================
class _SparkDetailSheet extends StatelessWidget {
  final SparkItem item;
  final Function(SparkItem) onJoin;
  final Function(SparkItem) onHide;
  const _SparkDetailSheet({required this.item, required this.onJoin, required this.onHide});

  @override
  Widget build(BuildContext context) {
    // Compute dynamic timer for detail view
    String detailTimer = item.timer ?? '...';
    bool detailIsLive = false;
    if (item.activityTime != null) {
      final now = DateTime.now();
      final diff = item.activityTime!.difference(now);
      if (diff.isNegative) {
        detailIsLive = true;
        if (item.expiresAt != null) {
          final endDiff = item.expiresAt!.difference(now);
          if (endDiff.isNegative) {
            detailTimer = 'Ended';
          } else if (endDiff.inHours > 0) {
            detailTimer = 'Ends in ${endDiff.inHours}h ${endDiff.inMinutes % 60}m';
          } else {
            detailTimer = 'Ends in ${endDiff.inMinutes} mins';
          }
        } else {
          detailTimer = 'Live Now';
        }
      } else if (diff.inHours > 0) {
        detailTimer = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        detailTimer = 'Starts in ${diff.inMinutes} mins';
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: SparkColors.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              
              // Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (item.type == 'rush' ? SparkColors.orange : SparkColors.actPrimary).withValues(alpha: 0.1),
                  border: Border.all(color: (item.type == 'rush' ? SparkColors.orange : SparkColors.actPrimary).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.type == 'rush' ? Icons.bolt : Icons.calendar_today, color: item.type == 'rush' ? SparkColors.orange : SparkColors.actPrimary, size: 11),
                    const SizedBox(width: 6),
                    Text(item.type == 'rush' ? 'Rush-in • Anonymous' : 'Activity • Public', style: TextStyle(color: item.type == 'rush' ? SparkColors.orange : SparkColors.actPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(item.desc, style: const TextStyle(color: SparkColors.txt2, fontSize: 13, height: 1.6)),
              const SizedBox(height: 16),
              
              // Metas
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  if (item.type == 'rush') ...[
                    _metaIcon(
                      detailIsLive ? Icons.local_fire_department : Icons.hourglass_bottom,
                      detailTimer,
                      detailIsLive ? SparkColors.red : SparkColors.red,
                    ),
                    _metaIcon(Icons.sensors, '${item.radius ?? "..."} radius', SparkColors.cyan),
                  ] else ...[
                    _metaIcon(Icons.calendar_today, item.date ?? 'TBD'),
                    _metaIcon(Icons.access_time, item.time ?? 'TBD'),
                    _metaIcon(Icons.location_on, item.location ?? 'TBD'),
                  ],
                  _metaIcon(Icons.accessibility_new, '${item.slots} slots'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: item.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), border: Border.all(color: SparkColors.gborder), borderRadius: BorderRadius.circular(8)),
                  child: Text(t, style: const TextStyle(color: SparkColors.txt2, fontSize: 11, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
              
              const SizedBox(height: 16),
              // Host
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: SparkColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: SparkColors.gborder)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: item.hostAvatar != null && item.hostAvatar!.startsWith('http') 
                        ? NetworkImage(item.hostAvatar!) 
                        : null,
                      backgroundColor: SparkColors.bg,
                      child: item.hostAvatar != null && !item.hostAvatar!.startsWith('http') 
                        ? Text(item.hostAvatar!, style: const TextStyle(color: SparkColors.orange, fontSize: 18, fontWeight: FontWeight.bold))
                        : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(item.host, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: SparkColors.blue, size: 14),
                            ],
                          ),
                          Text(item.type == 'rush' ? 'Rush-in Organizer' : 'Activity Host • Verified', style: const TextStyle(color: SparkColors.muted, fontSize: 11)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              // Members if Act
              if (item.type != 'rush' && item.members != null) ...[
                Row(
                  children: [
                    const Icon(Icons.people, color: SparkColors.txt2, size: 12),
                    const SizedBox(width: 6),
                    Text('${item.slots} Members Joined', style: const TextStyle(color: SparkColors.txt2, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: (item.members ?? []).map((m) => Align(
                    widthFactor: 0.75,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        border: Border.all(color: SparkColors.bg2, width: 2), 
                        gradient: LinearGradient(colors: (item.hostColor != null && item.hostColor!.isNotEmpty) ? item.hostColor!.reversed.toList() : [SparkColors.actPrimary, SparkColors.actSecondary])
                      ),
                      alignment: Alignment.center,
                      child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],
              
              // Actions
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onHide(item),
                    child: Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: SparkColors.red.withValues(alpha: 0.1), border: Border.all(color: SparkColors.red.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.visibility_off, color: SparkColors.red, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: SparkColors.card, border: Border.all(color: SparkColors.gborder), borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: const Text('Close', style: TextStyle(color: SparkColors.txt2, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: (item.hasRequested || item.isApproved) ? null : () => onJoin(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: (item.isFull || item.hasRequested || item.isApproved) ? null : LinearGradient(colors: item.type == 'rush' ? [SparkColors.orange, SparkColors.yellow] : [SparkColors.actPrimary, SparkColors.actSecondary]),
                          color: item.isApproved ? (item.type == 'rush' ? SparkColors.green : SparkColors.actAccent) : (item.hasRequested ? Colors.white.withValues(alpha: 0.1) : (item.isFull ? SparkColors.purple.withValues(alpha: 0.15) : null)),
                          border: Border.all(color: item.isApproved ? Colors.transparent : (item.hasRequested ? SparkColors.gborder : (item.isFull ? SparkColors.purple.withValues(alpha: 0.3) : Colors.transparent))),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.isApproved ? Icons.check_circle : (item.hasRequested ? Icons.pending : (item.isFull ? Icons.access_time : (item.type == 'rush' ? Icons.bolt : Icons.pan_tool))), color: item.isApproved ? Colors.white : (item.hasRequested ? SparkColors.txt2 : (item.isFull ? SparkColors.purple : Colors.black)), size: 16),
                            const SizedBox(width: 6),
                            Text(item.isApproved ? 'Joined' : (item.hasRequested ? 'Requested' : (item.isFull ? 'Waitlist' : (item.type == 'rush' ? 'Request' : 'Join'))), style: TextStyle(color: item.isApproved ? Colors.white : (item.hasRequested ? SparkColors.txt2 : (item.isFull ? SparkColors.purple : Colors.black)), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (item.waitlist > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, color: SparkColors.purple, size: 11),
                        const SizedBox(width: 4),
                        Text('${item.waitlist} people on the waitlist.', style: const TextStyle(color: SparkColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaIcon(IconData icon, String text, [Color color = SparkColors.orange]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: SparkColors.glass, border: Border.all(color: SparkColors.gborder), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: SparkColors.txt2, fontSize: 12)),
        ],
      ),
    );
  }
}

// ==========================================
// CREATE MODAL
// ==========================================
class _SparkCreateModal extends StatefulWidget {
  final String initialTab;
  const _SparkCreateModal({this.initialTab = 'rush'});
  @override
  State<_SparkCreateModal> createState() => _SparkCreateModalState();
}

class _SparkCreateModalState extends State<_SparkCreateModal> {
  late String _tab;
  
  bool _isWaitlist = true;
  bool _autoApprove = false;
  bool _isAnonymous = false;
  double _radius = 5.0;
  bool _isSubmitting = false;

  final TextEditingController _rushTitle = TextEditingController();
  final TextEditingController _rushDesc = TextEditingController();
  final TextEditingController _rushSlots = TextEditingController(text: '4');
  final TextEditingController _rushExpiry = TextEditingController(text: '2');
  final TextEditingController _actTitle = TextEditingController();
  final TextEditingController _actDesc = TextEditingController();
  final TextEditingController _actDate = TextEditingController();
  final TextEditingController _actTime = TextEditingController();
  final TextEditingController _actSlots = TextEditingController(text: '8');
  final TextEditingController _actCategory = TextEditingController(text: 'Outdoor');
  final TextEditingController _actPrice = TextEditingController(text: '0');
  final TextEditingController _actLocation = TextEditingController();
  final TextEditingController _mapSearchCtrl = TextEditingController();

  LatLng _pinLocation = LatLng(
    locationService.activeLat ?? 20.5937, 
    locationService.activeLng ?? 78.9629,
  );
  final MapController _mapController = MapController();
  bool _fetchingGps = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _actLocation.text = locationService.activeLocation;
    _initMapLocation();
  }

  Future<void> _searchMapLocation() async {
    final query = _mapSearchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _fetchingGps = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'MeetraApp/1.0'});
      final str = response.body;
      final List data = jsonDecode(str);
      if (data.isNotEmpty && mounted) {
        final lat = double.parse(data[0]['lat'].toString());
        final lon = double.parse(data[0]['lon'].toString());
        setState(() {
          _pinLocation = LatLng(lat, lon);
          _fetchingGps = false;
        });
        _mapController.move(_pinLocation, 16.0);
      } else {
        if (mounted) setState(() => _fetchingGps = false);
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  Future<void> _initMapLocation() async {
    setState(() => _fetchingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
         setState(() {
           _pinLocation = LatLng(pos.latitude, pos.longitude);
           _fetchingGps = false;
         });
         _mapController.move(_pinLocation, 16.0);
      }
    } catch (_) {
      // Fall back to saved location from service
      if (mounted) {
        final lat = locationService.activeLat;
        final lng = locationService.activeLng;
        if (lat != null && lng != null) {
          setState(() {
            _pinLocation = LatLng(lat, lng);
            _fetchingGps = false;
          });
          _mapController.move(_pinLocation, 14.0);
        } else {
          setState(() => _fetchingGps = false);
        }
      }
    }
  }

  Future<String> _resolvePinLandmark(LatLng pin, String defaultName) async {
    try {
      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${pin.latitude}&lon=${pin.longitude}&zoom=18&addressdetails=1',
      );
      final geoRes = await http.get(geoUrl, headers: {'User-Agent': 'MeetraApp/1.0'});
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final address = geoData['address'] as Map<String, dynamic>? ?? {};
        final landmark = geoData['name']
            ?? address['amenity']
            ?? address['building']
            ?? address['shop']
            ?? address['leisure']
            ?? address['historic']
            ?? address['tourism'];
        if (landmark != null && landmark.toString().trim().isNotEmpty) {
          return landmark.toString().trim();
        } else {
          final road = address['road'] ?? address['pedestrian'];
          final area = address['neighbourhood'] ?? address['suburb'] ?? address['village'];
          if (road != null) {
            return area != null ? '$road, $area' : road.toString();
          } else if (area != null) {
            return area.toString();
          }
        }
      }
    } catch (_) {}
    return defaultName;
  }

  Future<void> _submit() async {
    if (_tab == 'rush' && (_rushTitle.text.isEmpty || _rushDesc.text.isEmpty)) return;
    if (_tab == 'act' && (_actTitle.text.isEmpty || _actDesc.text.isEmpty)) return;

    setState(() => _isSubmitting = true);
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final profile = await sb.from('profiles').select('name, avatar_url, city').eq('id', uid).maybeSingle();
      final hostName = profile != null ? profile['name']?.toString() ?? 'Someone' : 'Someone';
      final city = locationService.activeLocation;

      final dt = DateTime.now();

      if (_tab == 'rush') {
        final durationHours = int.tryParse(_rushExpiry.text) ?? 2;
        
        // 1. Resolve nearest landmark first
        final pinLocationName = await _resolvePinLandmark(_pinLocation, city);

        // 2. Insert into activities
        final payload = <String, dynamic>{
          'user_id': uid,
          'title': _rushTitle.text.trim(),
          'description': _rushDesc.text.trim(),
          'participant_limit': int.tryParse(_rushSlots.text) ?? 4,
          'is_active': true,
          'is_rush_in': true,
          'activity_type': 'rush_in',
          'category': 'rush_in',
          'location_name': pinLocationName,
          'district': locationService.activeLocation.split(',').first.trim(),
          'state': locationService.activeLocation.split(',').length > 1 ? locationService.activeLocation.split(',')[1].trim() : '',
          'activity_time': dt.toIso8601String(),
          'lat': _pinLocation.latitude,
          'lng': _pinLocation.longitude,
          'created_at': dt.toUtc().toIso8601String(),
          'expires_at': dt.add(Duration(hours: durationHours)).toIso8601String(),
          'duration_hours': durationHours,
          'radius_km': _radius,
          'is_anonymous': _isAnonymous,
        };

        final safeKeys = ['user_id', 'title', 'description', 'category', 'activity_time', 'lat', 'lng', 'location_name', 'district', 'state', 'is_active', 'participant_limit', 'activity_type', 'created_at'];
        final safePayload = <String, dynamic>{};
        String extraData = '';
        
        for (final key in payload.keys) {
          if (safeKeys.contains(key)) {
            safePayload[key] = payload[key];
          } else {
            if (payload[key] != null) {
              extraData += '\n[$key:${payload[key]}]';
            }
          }
        }
        
        if (extraData.isNotEmpty) {
          safePayload['description'] = (safePayload['description'] as String) + extraData;
        }

        final response = await sb.from('activities').insert(safePayload).select('id').single();

        final activityId = response['id'].toString();

        // 3. Trigger notification blast with resolved landmark
        try {
          NotificationService.notifyNearbyActivity(
            creatorId: uid,
            activityId: activityId,
            title: _rushTitle.text.trim(),
            locationName: pinLocationName,
            hostName: hostName,
            lat: _pinLocation.latitude,
            lng: _pinLocation.longitude,
            isRushIn: true,
            activityCity: city.split(',').first.trim(),
            radiusKm: _radius,
            isAnonymous: _isAnonymous,
          );
        } catch (_) {}
        if (mounted) {
          Navigator.pop(context, {
            'title': '⚡ Rush-in Created!',
            'desc': 'Your rush-in "${_rushTitle.text}" is now live! Others nearby can see it.',
          });
        }
      } else {
        DateTime actDate = dt;
        try {
          if (_actDate.text.isNotEmpty) {
            actDate = DateTime.parse(_actDate.text); // Expect YYYY-MM-DD
            if (_actTime.text.isNotEmpty) {
              final parts = _actTime.text.split(':');
              if (parts.length >= 2) {
                actDate = DateTime(actDate.year, actDate.month, actDate.day, int.parse(parts[0]), int.parse(parts[1]));
              }
            }
          }
        } catch (_) {}

        // 1. Resolve nearest landmark or user-defined location name
        String pinLocationName = _actLocation.text.trim();
        if (pinLocationName.isEmpty) {
          pinLocationName = await _resolvePinLandmark(_pinLocation, city);
        }

        // 2. Insert into activities
        final payload = <String, dynamic>{
          'user_id': uid,
          'title': _actTitle.text.trim(),
          'description': _actDesc.text.trim(),
          'participant_limit': int.tryParse(_actSlots.text) ?? 8,
          'is_active': true,
          'is_rush_in': false,
          'activity_type': 'activity',
          'category': _actCategory.text.trim().isNotEmpty ? _actCategory.text.trim() : 'General',
          'location_name': pinLocationName,
          'district': locationService.activeLocation.split(',').first.trim(),
          'state': locationService.activeLocation.split(',').length > 1 ? locationService.activeLocation.split(',')[1].trim() : '',
          'activity_time': actDate.toIso8601String(), 
          'lat': _pinLocation.latitude,
          'lng': _pinLocation.longitude,
          'created_at': dt.toUtc().toIso8601String(),
        };

        final safeKeys = ['user_id', 'title', 'description', 'category', 'activity_time', 'lat', 'lng', 'location_name', 'district', 'state', 'is_active', 'participant_limit', 'activity_type', 'created_at'];
        final safePayload = <String, dynamic>{};
        String extraData = '';
        
        for (final key in payload.keys) {
          if (safeKeys.contains(key)) {
            safePayload[key] = payload[key];
          } else {
            if (payload[key] != null) {
              extraData += '\n[$key:${payload[key]}]';
            }
          }
        }
        
        if (extraData.isNotEmpty) {
          safePayload['description'] = (safePayload['description'] as String) + extraData;
        }

        final response = await sb.from('activities').insert(safePayload).select('id').single();

        final activityId = response['id'].toString();

        // 3. Trigger notification blast with resolved landmark
        try {
          NotificationService.notifyNearbyActivity(
            creatorId: uid,
            activityId: activityId,
            title: _actTitle.text.trim(),
            locationName: pinLocationName,
            hostName: hostName,
            lat: _pinLocation.latitude,
            lng: _pinLocation.longitude,
            isRushIn: false,
            activityCity: city.split(',').first.trim(),
            radiusKm: 25.0, // Default for standard activities
            isAnonymous: false,
          );
        } catch (_) {}

        if (mounted) {
          Navigator.pop(context, {
            'title': '📅 Activity Created!',
            'desc': '"${_actTitle.text}" is now live! Others can find and request to join.',
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAct = _tab == 'act';
    final accentColor = isAct ? SparkColors.actPrimary : SparkColors.orange;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: SparkColors.bg2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: SparkColors.gborder),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isAct ? 'Create Activity 📅' : 'Create Rush-in ⚡', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: SparkColors.glass, border: Border.all(color: SparkColors.gborder), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.close, color: SparkColors.txt2, size: 14),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              // Tabs
              Row(
                children: [
                  _createTabBtn('rush', 'Rush-in', Icons.bolt, SparkColors.orange),
                  const SizedBox(width: 8),
                  _createTabBtn('act', 'Activity', Icons.calendar_today, SparkColors.actPrimary),
                ],
              ),
              const SizedBox(height: 20),

              if (_tab == 'rush') ...[
                _buildInput('Interest / Topic', Icons.tag, 'e.g., Late night coffee, Basketball...', controller: _rushTitle, accent: accentColor),
                _buildInput('Brief Description', Icons.notes, "What's the vibe? Keep it mysterious...", isArea: true, controller: _rushDesc, accent: accentColor),
                Row(
                  children: [
                    Expanded(child: _buildInput('Max People', Icons.people, '4', controller: _rushSlots, accent: accentColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput('Expires In (hrs)', Icons.access_time, '2', controller: _rushExpiry, accent: accentColor)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Radius', style: GoogleFonts.inter(color: SparkColors.txt2, fontSize: 12, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _radius, min: 1, max: 25,
                        activeColor: accentColor, inactiveColor: SparkColors.gborder,
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ),
                    Text('${_radius.toInt()} km', style: GoogleFonts.inter(color: SparkColors.txt2, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildToggle('👤 Post as Anonymous', _isAnonymous, (v) => setState(() => _isAnonymous = v), accentColor),
                const SizedBox(height: 16),
                _buildMapPicker(accentColor),
                const SizedBox(height: 16),
                _buildSubmitBtn('Create Rush-in', Icons.bolt, const LinearGradient(colors: [SparkColors.orange, SparkColors.yellow])),

              ] else ...[
                _buildInput('Activity Title', Icons.title, 'e.g., Weekend Hiking...', controller: _actTitle, accent: accentColor),
                _buildInput('Description', Icons.notes, "Describe your activity in detail...", isArea: true, controller: _actDesc, accent: accentColor),
                Row(
                  children: [
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (d != null) setState(() => _actDate.text = "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}");
                      },
                      child: AbsorbPointer(child: _buildInput('Date (YYYY-MM-DD)', Icons.calendar_today, 'Select date', controller: _actDate, accent: accentColor)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (t != null) setState(() => _actTime.text = "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}");
                      },
                      child: AbsorbPointer(child: _buildInput('Time (HH:MM)', Icons.access_time, 'Select time', controller: _actTime, accent: accentColor)),
                    )),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildInput('Max People', Icons.people, '8', controller: _actSlots, accent: accentColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput('Category', Icons.category, 'Outdoor', controller: _actCategory, accent: accentColor)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildInput('Location', Icons.location_on, 'Venue name', controller: _actLocation, accent: accentColor)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInput('Price (₹)', Icons.currency_rupee, '0', controller: _actPrice, accent: accentColor)),
                  ],
                ),
                _buildToggle('📋 Enable Waitlist', _isWaitlist, (v) => setState(() => _isWaitlist = v), accentColor),
                const SizedBox(height: 8),
                _buildToggle('🔔 Auto-approve Requests', _autoApprove, (v) => setState(() => _autoApprove = v), accentColor),
                const SizedBox(height: 16),
                _buildMapPicker(accentColor),
                const SizedBox(height: 16),
                _buildSubmitBtn('Create Activity', Icons.calendar_today, const LinearGradient(colors: [SparkColors.actPrimary, SparkColors.actSecondary])),
              ]
            ],
          ),
        ),
      ),
    );
      },
    );
  }
  Widget _buildMapPicker(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: accent, size: 14),
            const SizedBox(width: 6),
            Text('Pin Location', style: GoogleFonts.inter(color: SparkColors.txt2, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_fetchingGps) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: SparkColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: SparkColors.gborder)),
          child: Row(
            children: [
              Expanded(child: TextField(
                controller: _mapSearchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(hintText: 'Search city, landmark...', hintStyle: TextStyle(color: SparkColors.muted), border: InputBorder.none, isDense: true),
                onSubmitted: (_) => _searchMapLocation(),
              )),
              GestureDetector(
                onTap: _searchMapLocation,
                child: Icon(Icons.search, color: accent, size: 18),
              ),
            ],
          ),
        ),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SparkColors.gborder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pinLocation,
                    initialZoom: 14.0,
                    onTap: (tapPosition, point) => setState(() => _pinLocation = point),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pinLocation,
                          width: 40, height: 40,
                          child: Icon(Icons.location_pin, color: accent, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 12, right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'myLoc',
                    backgroundColor: accent,
                    onPressed: _initMapLocation,
                    child: const Icon(Icons.my_location, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('Tap map to move pin', style: GoogleFonts.inter(color: SparkColors.muted, fontSize: 10)),
      ],
    );
  }

  Widget _createTabBtn(String key, String label, IconData icon, Color color) {
    bool active = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.1) : SparkColors.card,
            border: Border.all(color: active ? color : SparkColors.gborder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? color : SparkColors.muted, size: 14),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(color: active ? color : SparkColors.muted, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, IconData icon, String hint, {bool isArea = false, TextEditingController? controller, Color accent = SparkColors.orange}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 11),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.inter(color: SparkColors.txt2, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: isArea ? 3 : 1,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: SparkColors.muted),
              filled: true,
              fillColor: SparkColors.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: SparkColors.gborder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: SparkColors.card, border: Border.all(color: SparkColors.gborder), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(color: SparkColors.txt2, fontSize: 13, fontWeight: FontWeight.bold))),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44, height: 24,
              decoration: BoxDecoration(
                gradient: value ? LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]) : null,
                color: value ? null : SparkColors.glass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: value ? Colors.transparent : SparkColors.gborder),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18, height: 18,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSubmitBtn(String label, IconData icon, Gradient grad) {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(gradient: _isSubmitting ? null : grad, color: _isSubmitting ? SparkColors.muted : null, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: _isSubmitting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.black, size: 16),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
      ),
    );
  }
}

// ==========================================
// TOAST NOTIFICATION
// ==========================================
class _SparkToast extends StatelessWidget {
  final String title;
  final String desc;
  final VoidCallback onDismiss;
  const _SparkToast({required this.title, required this.desc, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16, right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xF2111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SparkColors.gborder),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: SparkColors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Icon(Icons.bolt, color: SparkColors.orange, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(desc, style: const TextStyle(color: SparkColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, color: SparkColors.muted, size: 16),
                ),
              )
            ],
          ),
        ).animate().slideY(begin: -2, end: 0, curve: Curves.easeOutBack),
      ),
    );
  }
}

class _SparkFilterSheet extends StatefulWidget {
  final Set<String> initialCategories;
  final String initialSort;

  const _SparkFilterSheet({required this.initialCategories, required this.initialSort});

  @override
  State<_SparkFilterSheet> createState() => _SparkFilterSheetState();
}

class _SparkFilterSheetState extends State<_SparkFilterSheet> {
  late Set<String> _cats;
  late String _sort;

  final List<String> _allCats = ['Outdoor', 'Sports', 'Music', 'Food', 'Study', 'Gaming', 'Fitness'];
  final List<String> _allSorts = ['Nearest', 'Newest', 'Expiring Soon', 'Most Members'];

  @override
  void initState() {
    super.initState();
    _cats = Set.from(widget.initialCategories);
    _sort = widget.initialSort;
  }

  void _toggleCat(String c) {
    setState(() {
      if (_cats.contains(c)) {
        _cats.remove(c);
      } else {
        _cats.add(c);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SparkColors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: SparkColors.gborder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Preferences', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          const Text('Categories', style: TextStyle(color: SparkColors.txt2, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allCats.map((s) {
              final active = _cats.contains(s);
              return GestureDetector(
                onTap: () => _toggleCat(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: active ? SparkColors.actPrimary : SparkColors.gborder),
                    borderRadius: BorderRadius.circular(20),
                    color: active ? SparkColors.actPrimary.withValues(alpha: 0.1) : SparkColors.card,
                  ),
                  child: Text(s, style: TextStyle(color: active ? SparkColors.actPrimary : SparkColors.txt2, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          const Text('Sort By', style: TextStyle(color: SparkColors.txt2, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allSorts.map((s) {
              final active = _sort == s;
              return GestureDetector(
                onTap: () => setState(() => _sort = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: active ? SparkColors.orange : SparkColors.gborder),
                    borderRadius: BorderRadius.circular(20),
                    color: active ? SparkColors.orange.withValues(alpha: 0.1) : SparkColors.card,
                  ),
                  child: Text(s, style: TextStyle(color: active ? SparkColors.orange : SparkColors.txt2, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              Navigator.pop(context, {'categories': _cats, 'sort': _sort});
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [SparkColors.orange, SparkColors.yellow]),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('Apply Filters', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

