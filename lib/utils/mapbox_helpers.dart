/// Mapbox helpers — provides a declarative wrapper matching
/// the old Google Maps Flutter interface so existing screens
/// need minimal code changes.
///
/// On web, renders a static map image fallback since mapbox_maps_flutter
/// does not support the web platform.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'latlng.dart';

export 'latlng.dart';

const String _mapboxPublicToken =
    'pk.eyJ1IjoiYW51cmFnOTY5NiIsImEiOiJjbXNya2t4a2kwMTZlMndyMGN2NjlvaXNtIn0.ruhrrp8_1119Mf5ADCkEOA';

/// Deep navy style — Mapbox Navigation Night matches the migomap aesthetic:
/// deep navy background, muted silver roads, minimal labels, no POI clutter.
const String _kNavyNightStyle =
    'mapbox://styles/mapbox/navigation-night-v1';

/// Light mode style for day.
const String _kLightStyle = 'mapbox://styles/mapbox/light-v11';

/// Initialize Mapbox — call once from main() before runApp.
/// On web this is a safe no-op.
Future<void> initMapbox() async {
  if (kIsWeb) return; // mapbox_maps_flutter doesn't support web
  try {
    mb.MapboxOptions.setAccessToken(_mapboxPublicToken);
  } catch (e) {
    debugPrint('[Mapbox] init error (safe to ignore on web): $e');
  }
}

// ── Premium marker image builder ─────────────────────────────────────────

/// Renders a glowing circular pin with inner dot — GenZ aesthetic.
  double _currentZoom = 14.0;
  final Map<String, Uint8List> _markerCache = {};

  Future<Uint8List> _buildMarkerImage(SimpleMarker m) async {
    final bool useImage = m.imageUrl != null && _currentZoom >= 14.0;
    final String cacheKey = '${m.id}_${useImage ? 'img' : 'emj'}';
    
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    final double size = useImage ? 160.0 : 100.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;
    final color = m.color ?? const Color(0xFFFF5B14);

    if (useImage) {
      // Draw rounded image banner
      paint.color = color;
      final rect = RRect.fromLTRBR(0, 0, size, size, const Radius.circular(24));
      
      // Shadow
      canvas.drawRRect(
        rect.shift(const Offset(0, 8)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      
      // Border
      canvas.drawRRect(rect, paint);
      
      try {
        final res = await http.get(Uri.parse(m.imageUrl!));
        if (res.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(res.bodyBytes, targetWidth: size.toInt(), targetHeight: size.toInt());
          final frame = await codec.getNextFrame();
          final image = frame.image;
          
          final innerRect = RRect.fromLTRBR(6, 6, size - 6, size - 6, const Radius.circular(18));
          canvas.save();
          canvas.clipRRect(innerRect);
          paint.filterQuality = FilterQuality.high;
          canvas.drawImageRect(image, 
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), 
            Rect.fromLTWH(6, 6, size - 12, size - 12), 
            paint);
          canvas.restore();
        } else {
          _drawFallbackPin(canvas, size, color, m.emoji);
        }
      } catch (_) {
        _drawFallbackPin(canvas, size, color, m.emoji);
      }
    } else {
      _drawFallbackPin(canvas, size, color, m.emoji);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    _markerCache[cacheKey] = bytes;
    return bytes;
  }

  void _drawFallbackPin(Canvas canvas, double size, Color color, String? emoji) {
    final paint = Paint()..isAntiAlias = true;
    
    // Shadow
    canvas.drawCircle(Offset(size/2, size/2 + 4), size/2 - 12, 
      Paint()..color = color.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      
    // White Border
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size/2, size/2), size/2 - 8, paint);
    
    // Core color
    paint.color = color;
    canvas.drawCircle(Offset(size/2, size/2), size/2 - 12, paint);
    
    // Emoji
    if (emoji != null && emoji.isNotEmpty) {
      final span = TextSpan(style: TextStyle(fontSize: size/2.2), text: emoji);
      final tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    }
  }

// ── Coordinate helpers ───────────────────────────────────────────────────

/// Convert our LatLng to Mapbox Point (note: Mapbox uses lng, lat order).
mb.Point toPoint(LatLng ll) =>
    mb.Point(coordinates: mb.Position(ll.longitude, ll.latitude));

/// Convert Mapbox Point back to our LatLng.
LatLng fromPoint(mb.Point p) =>
    LatLng(p.coordinates.lat.toDouble(), p.coordinates.lng.toDouble());

// ── Annotation Click Listener ────────────────────────────────────────────

class _AnnotationClickListener extends mb.OnPointAnnotationClickListener {
  final void Function(mb.PointAnnotation) callback;
  _AnnotationClickListener(this.callback);

  @override
  void onPointAnnotationClick(mb.PointAnnotation annotation) {
    callback(annotation);
  }
}

// ── Lightweight map controller wrapper ───────────────────────────────────

class MapController {
  mb.MapboxMap? _map;
  mb.PointAnnotationManager? _pointManager;
  mb.PolylineAnnotationManager? _polylineManager;
  final Map<String, void Function()> _markerTaps = {};

  mb.MapboxMap? get raw => _map;
  bool get isReady => _map != null || kIsWeb;

  Future<void> _init(mb.MapboxMap map) async {
    _map = map;
    _pointManager = await map.annotations.createPointAnnotationManager();
    _polylineManager =
        await map.annotations.createPolylineAnnotationManager();

    _pointManager!.addOnPointAnnotationClickListener(
      _AnnotationClickListener((annotation) {
        final tap = _markerTaps[annotation.id];
        if (tap != null) {
          tap();
        }
      }),
    );
  }

  /// Fly camera to a position.
  Future<void> animateToLatLng(LatLng ll, {double? zoom}) async {
    if (kIsWeb || _map == null) return;
    await _map?.flyTo(
      mb.CameraOptions(center: toPoint(ll), zoom: zoom),
      mb.MapAnimationOptions(duration: 600),
    );
  }

  /// Fit camera to show two points with padding.
  Future<void> fitBounds(LatLng sw, LatLng ne, {double padding = 60}) async {
    if (kIsWeb || _map == null) return;
    final camera = await _map?.cameraForCoordinateBounds(
      mb.CoordinateBounds(
        southwest: toPoint(sw),
        northeast: toPoint(ne),
        infiniteBounds: false,
      ),
      mb.MbxEdgeInsets(
          top: padding, left: padding, bottom: padding, right: padding),
      null,
      null,
      null,
      null,
    );
    if (camera != null) {
      await _map?.flyTo(camera, mb.MapAnimationOptions(duration: 600));
    }
  }

  /// Set markers on the map. Clears previous markers first.
  /// Uses a custom glowing circular pin for a premium look.
  Future<void> setMarkers(List<SimpleMarker> markers) async {
    if (kIsWeb || _pointManager == null) return;
    await _pointManager!.deleteAll();
    _markerTaps.clear();

    for (final m in markers) {
      final imageData = await _buildMarkerImage(m);

      final annotation = await _pointManager!.create(mb.PointAnnotationOptions(
        geometry: toPoint(m.position),
        image: imageData,
        iconSize: 0.6,
        textField: m.label,
        textSize: 11.0,
        textColor: Colors.white.value,
        textHaloColor: const Color(0xFF0A1628).value,
        textHaloWidth: 2.0,
        textOffset: [0, 2.2],
      ));
      if (m.onTap != null) {
        _markerTaps[annotation.id] = m.onTap!;
      }
    }
  }

  /// Draw polylines on the map. Clears previous polylines first.
  Future<void> setPolylines(List<SimplePolyline> polylines) async {
    if (kIsWeb || _polylineManager == null) return;
    await _polylineManager!.deleteAll();
    for (final p in polylines) {
      await _polylineManager!.create(mb.PolylineAnnotationOptions(
        geometry: mb.LineString(
            coordinates: p.points
                .map((ll) => mb.Position(ll.longitude, ll.latitude))
                .toList()),
        lineColor: p.color.value,
        lineWidth: p.width,
        lineBlur: 1.0,
      ));
    }
  }

  void dispose() {
    // MapboxMap cleanup is handled by the widget.
  }
}

// ── Simple data classes to match old Google Maps style ────────────────────

class SimpleMarker {
  final String id;
  final LatLng position;
  final String? label;
  final Color? color;
  final String? imageUrl;
  final String? emoji;
  final void Function()? onTap;
  const SimpleMarker({
    required this.id,
    required this.position,
    this.label,
    this.color,
    this.imageUrl,
    this.emoji,
    this.onTap,
  });
}

class SimplePolyline {
  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
  const SimplePolyline({
    required this.id,
    required this.points,
    this.color = const Color(0xFF3B82F6),
    this.width = 5.0,
  });
}

// ── Drop-in MapWidget replacement ────────────────────────────────────────

/// A simplified MapView that can be used as a near drop-in replacement
/// for GoogleMap. Pass `onMapReady` to get a [MapController].
class AppMapView extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final void Function(MapController controller)? onMapReady;
  final bool myLocationEnabled;
  final bool interactive;
  final List<SimpleMarker> markers;
  final List<SimplePolyline> polylines;
  final void Function(LatLng point)? onTap;
  final void Function(double zoom)? onZoomChanged;

  const AppMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14.0,
    this.onMapReady,
    this.myLocationEnabled = true,
    this.interactive = true,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.onZoomChanged,
  });

  @override
  State<AppMapView> createState() => _AppMapViewState();
}

class _AppMapViewState extends State<AppMapView> {
  MapController? _controller;

  @override
  void didUpdateWidget(covariant AppMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _controller!.isReady) {
      if (oldWidget.markers != widget.markers) {
        _controller!.setMarkers(widget.markers);
      }
      if (oldWidget.polylines != widget.polylines) {
        _controller!.setPolylines(widget.polylines);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // On web, use a static map image fallback
    if (kIsWeb) {
      return _buildWebFallback(isDarkMode);
    }

    // Dark = deep navy night, Light = clean muted
    final String styleUri = isDarkMode ? _kNavyNightStyle : _kLightStyle;

    return Stack(
      fit: StackFit.expand,
      children: [
        mb.MapWidget(
          cameraOptions: mb.CameraOptions(
            center: toPoint(widget.initialCenter),
            zoom: widget.initialZoom,
          ),
          styleUri: styleUri,
          onTapListener: widget.onTap != null
              ? (context) {
                  widget.onTap!(fromPoint(context.point));
                }
              : null,
          onMapCreated: (map) async {
            // Hide Mapbox logo and attribution ornaments completely
            try {
              await map.logo.updateSettings(mb.LogoSettings(position: mb.OrnamentPosition.TOP_LEFT, marginTop: -9999.0, marginLeft: -9999.0));
              await map.attribution.updateSettings(mb.AttributionSettings(position: mb.OrnamentPosition.TOP_LEFT, marginTop: -9999.0, marginLeft: -9999.0));
              await map.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
              await map.compass.updateSettings(mb.CompassSettings(enabled: false));
            } catch (_) {}
            // Premium electric-blue pulsing puck
            if (widget.myLocationEnabled) {
              await map.location.updateSettings(mb.LocationComponentSettings(
                enabled: true,
                pulsingEnabled: true,
                pulsingColor: const Color(0xFF3B82F6).value,
                pulsingMaxRadius: 50.0,
                puckBearingEnabled: true,
              ));
            }
            if (!widget.interactive) {
              await map.gestures.updateSettings(mb.GesturesSettings(
                scrollEnabled: false,
                pinchToZoomEnabled: false,
                doubleTapToZoomInEnabled: false,
                doubleTouchToZoomOutEnabled: false,
                quickZoomEnabled: false,
              ));
            }
            final ctrl = MapController();
            await ctrl._init(map);
            _controller = ctrl;
            if (widget.markers.isNotEmpty) {
              await ctrl.setMarkers(widget.markers);
            }
            if (widget.polylines.isNotEmpty) {
              await ctrl.setPolylines(widget.polylines);
            }
            if (widget.onMapReady != null) widget.onMapReady!(ctrl);
          },
          onCameraChangeListener: (event) async {
            if (_controller != null && _controller!.isReady && _controller!._map != null) {
              final state = await _controller!._map!.getCameraState();
              _currentZoom = state.zoom;
              if (widget.onZoomChanged != null) {
                widget.onZoomChanged!(_currentZoom);
              }
            }
          },
        ),
      ],
    );
  }

  /// Web fallback: renders a Mapbox Static Images API image with pin markers.
  Widget _buildWebFallback(bool isDarkMode) {
    final lat = widget.initialCenter.latitude;
    final lng = widget.initialCenter.longitude;
    final zoom = widget.initialZoom.clamp(0, 22).toInt();

    // Build pin overlays for markers (up to 50 to stay within URL limits)
    final pinOverlays = widget.markers.take(50).map((m) {
      final hex = _colorToHex(m.color ?? Colors.red);
      return 'pin-s+$hex(${m.position.longitude},${m.position.latitude})';
    }).join(',');

    final overlaySegment = pinOverlays.isNotEmpty ? '$pinOverlays/' : '';
    // navigation-night matches the deep navy aesthetic on web fallback too
    final styleId = isDarkMode ? 'navigation-night-v1' : 'light-v11';
    final url =
        'https://api.mapbox.com/styles/v1/mapbox/$styleId/static/'
        '$overlaySegment'
        '$lng,$lat,$zoom,0/800x600@2x'
        '?access_token=$_mapboxPublicToken';

    // Provide a no-op MapController to callers on web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller == null) {
        final ctrl = MapController();
        _controller = ctrl;
        widget.onMapReady?.call(ctrl);
      }
    });

    return GestureDetector(
      onTapUp: widget.onTap != null
          ? (details) {
              // On web we can't map pixel → latlng, so use center
              widget.onTap!(widget.initialCenter);
            }
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFF0A1628),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00),
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF0A1628),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map, color: Colors.white38, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mapbox attribution (required)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© Mapbox',
                style: TextStyle(color: Colors.white60, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _colorToHex(Color c) {
    return '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}';
  }
}
