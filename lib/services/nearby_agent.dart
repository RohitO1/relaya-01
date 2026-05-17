import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_service.dart';

// ════════════════════════════════════════════════════════════════════
// AI NEARBY AGENT — Real-time intelligent notification system
// Monitors new rush-ins, activities, and companions near the user
// ════════════════════════════════════════════════════════════════════

class NearbyAgent {
  static NearbyAgent? _instance;
  static NearbyAgent get instance => _instance ??= NearbyAgent._();
  NearbyAgent._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _activityChannel;
  RealtimeChannel? _companionChannel;
  final Set<String> _seenIds = {};
  BuildContext? _context;
  double _radiusKm = 15.0;
  bool _isRunning = false;

  /// Start listening for nearby events
  void start(BuildContext context, {double radiusKm = 15.0}) {
    if (_isRunning) return;
    _context = context;
    _radiusKm = radiusKm;
    _isRunning = true;
    _listenActivities();
    _listenCompanions();
    debugPrint('[NearbyAgent] Started with radius ${radiusKm}km');
  }

  /// Stop all listeners
  void stop() {
    _activityChannel?.unsubscribe();
    _companionChannel?.unsubscribe();
    _activityChannel = null;
    _companionChannel = null;
    _isRunning = false;
    _context = null;
    debugPrint('[NearbyAgent] Stopped');
  }

  /// Listen for new activities and rush-ins
  void _listenActivities() {
    _activityChannel = _supabase
        .channel('nearby-activities')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activities',
          callback: (payload) => _onNewActivity(payload.newRecord),
        )
        .subscribe();
  }

  /// Listen for new companion listings
  void _listenCompanions() {
    _companionChannel = _supabase
        .channel('nearby-companions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'companions',
          callback: (payload) => _onNewCompanion(payload.newRecord),
        )
        .subscribe();
  }

  void _onNewActivity(Map<String, dynamic> record) {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (record['user_id'] == uid) return; // Skip own
    final id = record['id']?.toString() ?? '';
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);

    final lat = _toDouble(record['lat']) ?? _toDouble(record['latitude']);
    final lng = _toDouble(record['lng']) ?? _toDouble(record['longitude']);
    if (lat == null || lng == null) return;

    final myLat = locationService.activeLat;
    final myLng = locationService.activeLng;
    if (myLat == null || myLng == null) return;

    final dist = _haversineKm(myLat, myLng, lat, lng);
    if (dist > _radiusKm) return;

    final isRushIn = record['is_rush_in'] == true;
    final title = record['title'] ?? 'New Activity';
    final location = record['location_name'] ?? '';
    final distStr = dist < 1 ? '${(dist * 1000).round()}m' : '${dist.toStringAsFixed(1)}km';

    _showPopup(
      emoji: isRushIn ? '🔥' : '📍',
      title: isRushIn ? 'Rush-In Nearby!' : 'New Activity Nearby!',
      body: '$title${location.isNotEmpty ? ' at $location' : ''} • $distStr away',
      color: isRushIn ? const Color(0xFFFF007F) : const Color(0xFF00E5FF),
      payload: {'type': isRushIn ? 'rush_in' : 'activity', 'id': id},
    );
  }

  void _onNewCompanion(Map<String, dynamic> record) {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (record['user_id'] == uid) return;
    final id = record['id']?.toString() ?? '';
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);

    final name = record['name'] ?? record['title'] ?? 'New Companion';
    final category = record['category'] ?? '';

    _showPopup(
      emoji: '🤝',
      title: 'New Companion Available!',
      body: '$name${category.isNotEmpty ? ' • $category' : ''}',
      color: const Color(0xFF10B981),
      payload: {'type': 'companion', 'id': id},
    );
  }

  void _showPopup({
    required String emoji,
    required String title,
    required String body,
    required Color color,
    required Map<String, dynamic> payload,
  }) {
    final ctx = _context;
    if (ctx == null || !ctx.mounted) return;

    // Use an OverlayEntry for a premium popup
    final overlay = Overlay.of(ctx);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _NearbyPopup(
        emoji: emoji,
        title: title,
        body: body,
        color: color,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          // Could navigate to detail screen based on payload
        },
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Haversine distance in km
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);
}

// ════════════════════════════════════════════════════════════════════
// POPUP WIDGET — Slides in from top with premium glassmorphism
// ════════════════════════════════════════════════════════════════════
class _NearbyPopup extends StatefulWidget {
  final String emoji;
  final String title;
  final String body;
  final Color color;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NearbyPopup({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NearbyPopup> createState() => _NearbyPopupState();
}

class _NearbyPopupState extends State<_NearbyPopup> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: widget.onTap,
            onHorizontalDragEnd: (_) => widget.onDismiss(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101015).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: widget.color.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: widget.color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
                  const BoxShadow(color: Colors.black54, blurRadius: 15),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(widget.title,
                                style: TextStyle(color: widget.color, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(widget.body,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: widget.color.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
