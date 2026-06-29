import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';

class LocationMapScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String title;
  const LocationMapScreen({super.key, required this.lat, required this.lng, required this.title});

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  bool _disposed = false;
  bool _isMapDark = true;
  bool _isNavigating = false;
  bool _isLoadingRoute = false;
  final MapController _mapController = MapController();

  LatLng? _myLocation;
  double _speedKmh = 0.0;
  double _distanceMeters = 0.0;
  StreamSubscription<Position>? _positionSub;
  List<LatLng> _routePoints = [];
  String? _routeError;

  // ── Polyline5 decoder (Google/OSRM standard) ─────────────────────────────
  // Returns raw decoded points. No guard — trust the API data.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // --- decode latitude delta ---
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // --- decode longitude delta ---
      result = 0; shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      final double dLat = lat / 1e5;
      final double dLng = lng / 1e5;
      // Clamp to valid range just in case of data anomaly
      if (dLat >= -90 && dLat <= 90 && dLng >= -180 && dLng <= 180) {
        poly.add(LatLng(dLat, dLng));
      }
    }
    debugPrint('[Route] decoded ${poly.length} points from ${encoded.length}-char geometry');
    return poly;
  }

  // ── Fit map to show both markers ─────────────────────────────────────────
  void _fitBothLocations(LatLng a, LatLng b) {
    final minLat = math.min(a.latitude, b.latitude);
    final maxLat = math.max(a.latitude, b.latitude);
    final minLng = math.min(a.longitude, b.longitude);
    final maxLng = math.max(a.longitude, b.longitude);
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  // ── Fetch OSRM driving route ──────────────────────────────────────────────
  Future<void> _fetchRoute() async {
    if (_myLocation == null) return;
    if (!_disposed && mounted) setState(() { _isLoadingRoute = true; _routeError = null; _routePoints = []; });
    final start = _myLocation!;
    final end = LatLng(widget.lat, widget.lng);
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=polyline&steps=false',
      );
      debugPrint('[Route] fetching: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      debugPrint('[Route] status: ${response.statusCode}');

      if (_disposed || !mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final code = data['code'] as String? ?? 'Unknown';
        debugPrint('[Route] OSRM code: $code');

        if (code == 'Ok') {
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final geometry = routes[0]['geometry'] as String;
            final points = _decodePolyline(geometry);
            if (points.isNotEmpty) {
              setState(() {
                _routePoints = points;
                _isLoadingRoute = false;
                _isNavigating = true;
                _routeError = null;
              });
              _fitBothLocations(start, end);
              return;
            } else {
              // Geometry decoded to 0 points — use straight line fallback
              _useFallbackLine(start, end);
              return;
            }
          }
        }
        // Any non-Ok OSRM code — fallback
        debugPrint('[Route] OSRM non-Ok code: $code');
        _useFallbackLine(start, end);
      } else {
        debugPrint('[Route] HTTP error: ${response.statusCode}');
        _useFallbackLine(start, end);
      }
    } on TimeoutException {
      debugPrint('[Route] request timed out');
      if (!_disposed && mounted) _useFallbackLine(start, end);
    } catch (e) {
      debugPrint('[Route] error: $e');
      if (!_disposed && mounted) _useFallbackLine(start, end);
    }
  }

  // ── Straight-line fallback when OSRM fails ────────────────────────────────
  void _useFallbackLine(LatLng start, LatLng end) {
    if (_disposed || !mounted) return;
    setState(() {
      // Interpolate 20 points along the straight line for a smoother look
      _routePoints = List.generate(21, (i) {
        final t = i / 20.0;
        return LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t,
        );
      });
      _isLoadingRoute = false;
      _isNavigating = true;
      _routeError = 'Showing direct path (road data unavailable)';
    });
    _fitBothLocations(start, end);
  }

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
    ).listen((pos) {
      if (_disposed || !mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, widget.lat, widget.lng);
      setState(() {
        _myLocation = loc;
        _speedKmh = (pos.speed * 3.6).clamp(0, 300);
        _distanceMeters = dist;
      });
      // In navigation mode, keep camera following the user
      if (_isNavigating && !_disposed) {
        _mapController.move(loc, _mapController.camera.zoom);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    // Defer mapController dispose to avoid deactivated-ancestor error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try { _mapController.dispose(); } catch (_) {}
    });
    super.dispose();
  }

  String _formatDist(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  String _eta() {
    if (_distanceMeters <= 0 || _speedKmh <= 0) return '--';
    final hours = (_distanceMeters / 1000) / _speedKmh;
    final mins = (hours * 60).round();
    if (mins < 60) return '$mins min';
    return '${hours.floor()}h ${(mins % 60)}m';
  }

  @override
  Widget build(BuildContext context) {
    final eventPoint = LatLng(widget.lat, widget.lng);
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        elevation: 0,
        title: Text(
          _isNavigating ? 'Navigating…' : widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Dark / light toggle
          IconButton(
            icon: Icon(
              _isMapDark ? Icons.wb_sunny : Icons.nightlight_round,
              color: _isMapDark ? Colors.yellow : Colors.blueGrey,
            ),
            onPressed: () => setState(() => _isMapDark = !_isMapDark),
          ),
        ],
      ),
      body: Column(children: [
        // ── Status bar ────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
          child: Row(children: [
            Icon(
              _isNavigating ? Icons.navigation : Icons.verified,
              color: const Color(0xFFFF6B00), size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _isNavigating
                  ? 'Navigation active — follow the blue route'
                  : 'You are approved — live location active',
              style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ]),
        ),

        // ── Map (STATIC — no scroll/zoom gestures) ────────────────────────
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myLocation ?? eventPoint,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                // Proper dark/light tiles — NO color inversion that would hide the route
                TileLayer(
                  userAgentPackageName: 'com.meetra.app',
                  urlTemplate: _isMapDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                // Route polyline — rendered AFTER tiles so it appears on top
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Dark outline
                      Polyline(
                        points: _routePoints,
                        color: const Color(0xFF1E3A8A),
                        strokeWidth: 10.0,
                      ),
                      // Bright blue inner line
                      Polyline(
                        points: _routePoints,
                        color: const Color(0xFF60A5FA),
                        strokeWidth: 6.0,
                      ),
                    ],
                  ),
                MarkerLayer(markers: [
                  // ── Destination pin ──────────────────────────────────
                  Marker(
                    point: eventPoint, width: 80, height: 80,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 4)],
                        ),
                        child: const Icon(Icons.flash_on, color: Colors.black, size: 22),
                      ),
                      CustomPaint(size: const Size(12, 8), painter: _TrianglePainter(const Color(0xFFFF6B00))),
                    ]),
                  ),
                  // ── Live user dot ────────────────────────────────────
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!, width: 56, height: 56,
                      child: Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                          ),
                        ),
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3B82F6),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)],
                          ),
                        ),
                      ]),
                    ),
                ]),
              ],
            ),

            // Route error toast
            if (_routeError != null)
              Positioned(
                top: 12, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(_routeError!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
              ),
          ]),
        ),

        // ── Live HUD ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          color: const Color(0xFF0A0A0F),
          child: Column(children: [
            Row(children: [
              Expanded(child: _hudTile(
                icon: Icons.directions_walk, color: const Color(0xFF10B981),
                label: 'Distance', value: _myLocation == null ? '—' : _formatDist(_distanceMeters),
              )),
              const SizedBox(width: 12),
              // Jump to destination
              GestureDetector(
                onTap: () => _mapController.move(eventPoint, 15),
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.flash_on, color: Color(0xFFFF6B00), size: 22),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ETA row (only in navigation mode)
            if (_isNavigating && _speedKmh > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const Icon(Icons.access_time, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text('ETA: ${_eta()}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (_myLocation != null) _fitBothLocations(_myLocation!, eventPoint);
                    },
                    child: const Text('Show full route', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),

            // ── Navigation / Start button ────────────────────────────────
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNavigating ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isLoadingRoute
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isNavigating ? Icons.navigation : Icons.directions, color: Colors.white, size: 20),
                label: Text(
                  _isLoadingRoute ? 'Fetching route…' : (_isNavigating ? 'Navigating' : 'Start Navigation'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: (_isLoadingRoute || _myLocation == null) ? null : () {
                  if (!_isNavigating) {
                    _fetchRoute();
                  } else {
                    // Reset navigation
                    setState(() { _isNavigating = false; _routePoints = []; _routeError = null; });
                    if (_myLocation != null) _mapController.move(_myLocation!, 14);
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _hudTile({required IconData icon, required Color color, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── Destination pin triangle ──────────────────────────────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════════
