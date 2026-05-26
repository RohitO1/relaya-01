// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

/// Full-screen custom 1:1 crop screen.
/// Shows the full image with a draggable square crop window + 3x3 grid overlay.
/// Returns [Uint8List] of the cropped region on "Use Photo", or null if cancelled.
class ImageCropScreen extends StatefulWidget {
  final File imageFile;
  const ImageCropScreen({super.key, required this.imageFile});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  // Decoded image info
  ui.Image? _image;
  bool _loading = true;

  // The image is displayed inside a container. We track its render rect.
  final GlobalKey _imageKey = GlobalKey();

  // Scale used to fit the image inside the display container
  double _scale = 1.0; // display pixels per image pixel
  Offset _imageOrigin = Offset.zero; // top-left of rendered image in container coords

  // Crop square in display coords (relative to the full-screen container)
  Offset _cropOffset = Offset.zero;
  double _cropSize = 0;
  bool _initialized = false;

  // Drag state
  Offset? _dragStart;
  Offset? _cropOffsetOnDragStart;


  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _image = frame.image;
      _loading = false;
    });
  }

  void _initCropRect(BoxConstraints constraints) {
    if (_initialized || _image == null) return;
    _initialized = true;

    final displayW = constraints.maxWidth;
    final displayH = constraints.maxHeight;

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();

    // Fit image (cover-style to fill width)
    final scaleX = displayW / imgW;
    final scaleY = displayH / imgH;
    _scale = math.min(scaleX, scaleY); // use "contain" fit

    final renderedW = imgW * _scale;
    final renderedH = imgH * _scale;

    _imageOrigin = Offset(
      (displayW - renderedW) / 2,
      (displayH - renderedH) / 2,
    );

    // Initial crop square = smallest dimension of rendered image, centered
    _cropSize = math.min(renderedW, renderedH);
    _cropOffset = Offset(
      _imageOrigin.dx + (renderedW - _cropSize) / 2,
      _imageOrigin.dy + (renderedH - _cropSize) / 2,
    );
  }

  void _onPanStart(DragStartDetails d) {
    _dragStart = d.localPosition;
    _cropOffsetOnDragStart = _cropOffset;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragStart == null || _cropOffsetOnDragStart == null || _image == null) return;

    final delta = d.localPosition - _dragStart!;
    final imgRenderedW = _image!.width * _scale;
    final imgRenderedH = _image!.height * _scale;

    // Clamp so crop stays inside rendered image
    final newDx = (_cropOffsetOnDragStart!.dx + delta.dx).clamp(
      _imageOrigin.dx,
      _imageOrigin.dx + imgRenderedW - _cropSize,
    );
    final newDy = (_cropOffsetOnDragStart!.dy + delta.dy).clamp(
      _imageOrigin.dy,
      _imageOrigin.dy + imgRenderedH - _cropSize,
    );

    setState(() {
      _cropOffset = Offset(newDx, newDy);
    });
  }

  Future<void> _onUsePhoto() async {
    if (_image == null) return;

    // Convert crop rect from display coords to image pixel coords
    final cropInImageX = (_cropOffset.dx - _imageOrigin.dx) / _scale;
    final cropInImageY = (_cropOffset.dy - _imageOrigin.dy) / _scale;
    final cropInImageSize = _cropSize / _scale;

    // Clamp to image bounds
    final srcX = cropInImageX.clamp(0, _image!.width.toDouble() - 1).round();
    final srcY = cropInImageY.clamp(0, _image!.height.toDouble() - 1).round();
    final srcSize = cropInImageSize
        .clamp(1, math.min(_image!.width - srcX, _image!.height - srcY).toDouble())
        .round();

    // Use ui.PictureRecorder to draw the cropped region
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Draw the cropped region scaled to srcSize x srcSize output
    canvas.drawImageRect(
      _image!,
      Rect.fromLTWH(srcX.toDouble(), srcY.toDouble(), srcSize.toDouble(), srcSize.toDouble()),
      Rect.fromLTWH(0, 0, srcSize.toDouble(), srcSize.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(srcSize, srcSize);
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      Navigator.pop(context, null);
      return;
    }

    Navigator.pop(context, byteData.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _buildCropUI(),
    );
  }

  Widget _buildCropUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initCropRect(constraints);

        return Stack(
          children: [
            // Full image displayed
            Positioned.fill(
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.contain,
                key: _imageKey,
              ),
            ),

            // Dark overlay outside crop rect — use CustomPaint
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropOverlayPainter(
                    cropRect: Rect.fromLTWH(
                      _cropOffset.dx,
                      _cropOffset.dy,
                      _cropSize,
                      _cropSize,
                    ),
                  ),
                ),
              ),
            ),

            // Gesture detector on the crop square for dragging
            Positioned(
              left: _cropOffset.dx,
              top: _cropOffset.dy,
              width: _cropSize,
              height: _cropSize,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Top bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, null),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Move to Crop',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40), // balance
                    ],
                  ),
                ),
              ),
            ),

            // Bottom bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Row(
                    children: [
                      // Hint
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('1:1 Square', style: GoogleFonts.inter(color: const Color(0xFFFF6B00), fontSize: 12, fontWeight: FontWeight.w700)),
                          Text('Drag to reposition', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      // Use Photo button
                      GestureDetector(
                        onTap: _onUsePhoto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, color: Colors.black, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Use Photo',
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints a dark overlay with a transparent 1:1 crop window cut out.
/// Draws a 3×3 grid inside the crop window + corner handles.
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final cornerPaint = Paint()
      ..color = const Color(0xFFFF6B00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Draw dark overlay with hole
    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()..addRect(cropRect);
    final overlayPath = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(overlayPath, darkPaint);

    // Crop border
    canvas.drawRect(cropRect, borderPaint);

    // 3×3 grid lines inside crop
    final third = cropRect.width / 3;
    for (int i = 1; i <= 2; i++) {
      final x = cropRect.left + third * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      final y = cropRect.top + third * i;
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }

    // Corner handles (L-shaped cyan brackets)
    const handleLen = 20.0;
    const corners = [
      // [x, y, dx1, dy1, dx2, dy2] — two line directions from the corner
    ];

    void drawCorner(Offset corner, Offset hDir, Offset vDir) {
      canvas.drawLine(corner, corner + hDir * handleLen, cornerPaint);
      canvas.drawLine(corner, corner + vDir * handleLen, cornerPaint);
    }

    drawCorner(cropRect.topLeft, const Offset(1, 0), const Offset(0, 1));
    drawCorner(cropRect.topRight, const Offset(-1, 0), const Offset(0, 1));
    drawCorner(cropRect.bottomLeft, const Offset(1, 0), const Offset(0, -1));
    drawCorner(cropRect.bottomRight, const Offset(-1, 0), const Offset(0, -1));

    // ignore: unused_local_variable
    final _ = corners; // suppress lint
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) => old.cropRect != cropRect;
}
