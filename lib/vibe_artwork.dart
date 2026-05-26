import 'dart:math' as math;
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
// Vibe Artwork Library — Animated Characters for Meetra Home Page
// Each character uses CustomPainter for premium flat-design art
// ══════════════════════════════════════════════════════════════════

// ── Shared skin & base colors ──────────────────────────────────
const _kSkin = Color(0xFFFFCC99);
const _kSkinShade = Color(0xFFE8A87C);
const _kHair = Color(0xFF3A2310);

// ── Utility: base animated wrapper ────────────────────────────
class _AnimWidget extends StatefulWidget {
  final CustomPainter Function(double t) painterFn;
  final Duration speed;
  const _AnimWidget({required this.painterFn, this.speed = const Duration(milliseconds: 2000)});

  @override
  State<_AnimWidget> createState() => _AnimWidgetState();
}

class _AnimWidgetState extends State<_AnimWidget> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.speed)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: widget.painterFn(_c.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Shared drawing helper functions
// ══════════════════════════════════════════════════════════════════
void _drawHead(Canvas c, Offset center, double r, Paint p) {
  // Hair
  p.color = _kHair;
  c.drawCircle(center.translate(0, -r * 0.2), r * 1.05, p);
  // Face
  p.color = _kSkin;
  c.drawCircle(center, r, p);
  // Eyes
  p.color = const Color(0xFF2D1B0E);
  c.drawCircle(center.translate(-r * 0.3, -r * 0.1), r * 0.14, p);
  c.drawCircle(center.translate(r * 0.3, -r * 0.1), r * 0.14, p);
  // Smile
  p.color = _kSkinShade;
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 1.2;
  c.drawArc(
    Rect.fromCenter(center: center.translate(0, r * 0.15), width: r * 0.7, height: r * 0.4),
    0, math.pi, false, p,
  );
  p.style = PaintingStyle.fill;
}

void _drawRoundRect(Canvas c, Rect rect, double radius, Color color) {
  final p = Paint()..color = color;
  c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), p);
}

// ══════════════════════════════════════════════════════════════════
// STUDY ARTWORK — Person reading, floating books
// ══════════════════════════════════════════════════════════════════
class StudyArtwork extends StatelessWidget {
  const StudyArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2400),
      painterFn: (t) => _StudyPainter(t),
    );
  }
}

class _StudyPainter extends CustomPainter {
  final double t;
  _StudyPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi) * 4;
    final cx = size.width * 0.6;
    final cy = size.height * 0.55 + bob;

    // Floating books background
    for (int i = 0; i < 3; i++) {
      final bx = size.width * (0.1 + i * 0.28);
      final by = size.height * 0.15 + math.sin((t + i * 0.35) * 2 * math.pi) * 6;
      p.color = const Color(0xFF6366F1).withValues(alpha: 0.25 + i * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(bx, by), width: 14, height: 18), const Radius.circular(2)),
        p,
      );
      p.color = const Color(0xFF4338CA).withValues(alpha: 0.5);
      canvas.drawRect(Rect.fromLTWH(bx - 7, by - 9, 4, 18), p);
    }

    // Body (indigo shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 12), width: 32, height: 36), 8, const Color(0xFF4338CA));

    // Head
    _drawHead(canvas, Offset(cx, cy - 14), 13, p);

    // Arms holding book
    p.color = const Color(0xFF3730A3);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 22, cy + 8), width: 10, height: 26), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 18, cy + 8), width: 10, height: 22), const Radius.circular(5)), p);

    // Book in hands
    final bookAngle = math.sin(t * 2 * math.pi * 1.3) * 0.08;
    canvas.save();
    canvas.translate(cx - 4, cy + 30);
    canvas.rotate(bookAngle);
    p.color = const Color(0xFF6366F1);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -11, 40, 20), const Radius.circular(3)), p);
    p.color = const Color(0xFF4338CA);
    canvas.drawRect(const Rect.fromLTWH(-20, -11, 6, 20), p);
    // Page lines
    p.color = Colors.white.withValues(alpha: 0.35);
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(-12, -7 + i * 5.5, 28, 2), p);
    }
    canvas.restore();

    // Legs
    p.color = const Color(0xFF1E1B4B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 9, cy + 38), width: 13, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 9, cy + 38), width: 13, height: 22), const Radius.circular(5)), p);

    // Shoes
    p.color = const Color(0xFF312E81);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 10, cy + 51), width: 16, height: 8), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 10, cy + 51), width: 16, height: 8), p);
  }

  @override
  bool shouldRepaint(_StudyPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// FITNESS ARTWORK — Character lifting weights / flexing
// ══════════════════════════════════════════════════════════════════
class FitnessArtwork extends StatelessWidget {
  const FitnessArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 1600),
      painterFn: (t) => _FitnessPainter(t),
    );
  }
}

class _FitnessPainter extends CustomPainter {
  final double t;
  _FitnessPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi) * 4;
    final armAngle = math.sin(t * 2 * math.pi) * 0.45; // arm flex animation
    final cx = size.width * 0.58;
    final cy = size.height * 0.5 + bob;

    // Stars / sparkles
    for (int i = 0; i < 4; i++) {
      final sx = size.width * (0.05 + i * 0.25);
      final sy = size.height * 0.15 + math.sin((t + i * 0.28) * 2 * math.pi) * 8;
      p.color = const Color(0xFFFF6B6B).withValues(alpha: 0.3 + (i % 2) * 0.15);
      canvas.drawCircle(Offset(sx, sy), 3 + (i % 2).toDouble(), p);
    }

    // Body (red shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 10), width: 34, height: 34), 8, const Color(0xFFB91C1C));

    // Head
    _drawHead(canvas, Offset(cx, cy - 15), 13, p);

    // Left arm (raised/flexed)
    canvas.save();
    canvas.translate(cx - 17, cy);
    canvas.rotate(-armAngle - 0.3);
    p.color = const Color(0xFF991B1B);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -26, 10, 26), const Radius.circular(5)), p);
    // Fist/hand
    p.color = _kSkin;
    canvas.drawCircle(const Offset(0, -28), 6, p);
    canvas.restore();

    // Right arm (raised/flexed)
    canvas.save();
    canvas.translate(cx + 17, cy);
    canvas.rotate(armAngle + 0.3);
    p.color = const Color(0xFF991B1B);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -26, 10, 26), const Radius.circular(5)), p);
    p.color = _kSkin;
    canvas.drawCircle(const Offset(0, -28), 6, p);
    canvas.restore();

    // Legs
    final legAngle = math.sin(t * 2 * math.pi) * 0.12;
    p.color = const Color(0xFF450A0A);
    canvas.save();
    canvas.translate(cx - 8, cy + 28);
    canvas.rotate(legAngle);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 0, 12, 24), const Radius.circular(5)), p);
    canvas.restore();
    canvas.save();
    canvas.translate(cx + 8, cy + 28);
    canvas.rotate(-legAngle);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 0, 12, 24), const Radius.circular(5)), p);
    canvas.restore();

    // Shoes
    p.color = const Color(0xFF7F1D1D);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 54), width: 16, height: 8), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 54), width: 16, height: 8), p);

    // Energy lines
    p.color = const Color(0xFFEF4444).withValues(alpha: 0.4);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.5;
    for (int i = 0; i < 3; i++) {
      final lx = cx + 30.0 + i * 5;
      final opacity = math.sin((t + i * 0.15) * 2 * math.pi);
      if (opacity > 0) {
        p.color = const Color(0xFFEF4444).withValues(alpha: opacity * 0.4);
        canvas.drawLine(Offset(lx, cy - 10), Offset(lx + 8, cy - 10 + i * 6), p);
      }
    }
    p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(_FitnessPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// MUSIC ARTWORK — Musician playing cello, notes floating
// ══════════════════════════════════════════════════════════════════
class MusicArtwork extends StatelessWidget {
  const MusicArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2200),
      painterFn: (t) => _MusicPainter(t),
    );
  }
}

class _MusicPainter extends CustomPainter {
  final double t;
  _MusicPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final sway = math.sin(t * 2 * math.pi) * 3;
    final cx = size.width * 0.58;
    final cy = size.height * 0.52 + sway;

    // Floating music notes
    final notes = ['♪', '♫', '♩', '♬'];
    for (int i = 0; i < notes.length; i++) {
      final nx = size.width * (0.05 + i * 0.22);
      final ny = size.height * 0.2 - math.sin((t * 1.2 + i * 0.4) * 2 * math.pi) * 12;
      final opacity = ((math.sin((t + i * 0.25) * 2 * math.pi) + 1) / 2) * 0.7 + 0.1;
      final textPainter = TextPainter(
        text: TextSpan(
          text: notes[i],
          style: TextStyle(
            color: const Color(0xFFC084FC).withValues(alpha: opacity),
            fontSize: 12 + (i % 2) * 3.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(nx, ny));
    }

    // Cello/instrument body
    canvas.save();
    canvas.translate(cx + 18, cy + 5);
    canvas.rotate(math.sin(t * 2 * math.pi) * 0.06);
    p.color = const Color(0xFFFF5C00);
    // Instrument shape
    final instPath = Path()
      ..moveTo(-8, -25)
      ..cubicTo(-18, -15, -18, 0, -10, 8)
      ..cubicTo(-14, 12, -14, 20, -8, 25)
      ..lineTo(8, 25)
      ..cubicTo(14, 20, 14, 12, 10, 8)
      ..cubicTo(18, 0, 18, -15, 8, -25)
      ..close();
    canvas.drawPath(instPath, p);
    // Sound hole
    p.color = const Color(0xFF4C1D95);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 5), width: 8, height: 12), p);
    // Neck
    p.color = const Color(0xFF5B21B6);
    canvas.drawRect(const Rect.fromLTWH(-3, -50, 6, 30), p);
    // Strings
    p.color = Colors.white.withValues(alpha: 0.5);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.8;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(Offset(-4.0 + i * 2.5, -45), Offset(-4.0 + i * 2.5, 25), p);
    }
    p.style = PaintingStyle.fill;
    canvas.restore();

    // Body (purple shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 10), width: 30, height: 34), 8, const Color(0xFF6D28D9));

    // Head
    _drawHead(canvas, Offset(cx, cy - 14), 12, p);

    // Left arm (bow arm, extended)
    canvas.save();
    canvas.translate(cx - 15, cy + 2);
    canvas.rotate(-0.6 + math.sin(t * 2 * math.pi) * 0.08);
    p.color = const Color(0xFF5B21B6);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -20, 10, 28), const Radius.circular(5)), p);
    // Bow
    p.color = _kSkin;
    canvas.drawCircle(const Offset(0, -22), 5, p);
    canvas.restore();

    // Legs
    p.color = const Color(0xFF2E1065);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 8, cy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 8, cy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    p.color = const Color(0xFF3B0764);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 49), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 49), width: 15, height: 7), p);
  }

  @override
  bool shouldRepaint(_MusicPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// STARTUP ARTWORK — Developer at laptop with lightbulb
// ══════════════════════════════════════════════════════════════════
class StartupArtwork extends StatelessWidget {
  const StartupArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2600),
      painterFn: (t) => _StartupPainter(t),
    );
  }
}

class _StartupPainter extends CustomPainter {
  final double t;
  _StartupPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi) * 3;
    final cx = size.width * 0.55;
    final cy = size.height * 0.48 + bob;

    // Laptop
    canvas.save();
    canvas.translate(cx - 6, cy + 38);
    // Screen
    p.color = const Color(0xFF0C1445);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -22, 48, 32), const Radius.circular(4)), p);
    p.color = const Color(0xFF1D4ED8).withValues(alpha: 0.15 + math.sin(t * 2 * math.pi * 2) * 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-21, -19, 42, 26), const Radius.circular(2)), p);
    // Code lines on screen
    p.color = const Color(0xFF60A5FA).withValues(alpha: 0.7);
    for (int i = 0; i < 4; i++) {
      final lineW = 12.0 + (i % 3) * 8;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-18, -14 + i * 6.0, lineW, 2), const Radius.circular(1)), p);
    }
    // Keyboard base
    p.color = const Color(0xFF1E40AF);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-26, 10, 52, 5), const Radius.circular(2)), p);
    canvas.restore();

    // Body (blue shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 8), width: 31, height: 32), 7, const Color(0xFF1D4ED8));

    // Head with slight thinking tilt
    canvas.save();
    canvas.translate(cx, cy - 15);
    canvas.rotate(math.sin(t * 2 * math.pi * 0.7) * 0.06);
    _drawHead(canvas, Offset.zero, 12, p);
    canvas.restore();

    // Left arm (forward, typing)
    p.color = const Color(0xFF1E40AF);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 20, cy + 12), width: 9, height: 24), const Radius.circular(4)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 20, cy + 12), width: 9, height: 24), const Radius.circular(4)), p);

    // Legs
    p.color = const Color(0xFF1E3A8A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 8, cy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 8, cy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    p.color = const Color(0xFF172554);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 49), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 49), width: 15, height: 7), p);

    // Lightbulb above head (pulsing)
    final bulbScale = 0.85 + math.sin(t * 2 * math.pi * 1.5) * 0.2;
    final bulbOpacity = 0.5 + math.sin(t * 2 * math.pi * 1.5) * 0.4;
    canvas.save();
    canvas.translate(cx + 18, cy - 40);
    canvas.scale(bulbScale, bulbScale);
    p.color = const Color(0xFFFBBF24).withValues(alpha: bulbOpacity);
    canvas.drawCircle(Offset.zero, 8, p);
    p.color = const Color(0xFFFCD34D).withValues(alpha: bulbOpacity * 0.6);
    canvas.drawCircle(Offset.zero, 12, p); // glow
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StartupPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// TRAVEL ARTWORK — Character walking with backpack, clouds
// ══════════════════════════════════════════════════════════════════
class TravelArtwork extends StatelessWidget {
  const TravelArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 1800),
      painterFn: (t) => _TravelPainter(t),
    );
  }
}

class _TravelPainter extends CustomPainter {
  final double t;
  _TravelPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final walkPhase = t * 2 * math.pi;
    final bob = math.sin(walkPhase * 2) * 2.5;
    final cx = size.width * 0.55;
    final cy = size.height * 0.5 + bob;

    // Drifting clouds
    for (int i = 0; i < 2; i++) {
      final cx2 = (size.width * 0.1 + size.width * t + i * size.width * 0.5) % (size.width + 30) - 15;
      p.color = Colors.white.withValues(alpha: 0.08 + i * 0.04);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx2, size.height * (0.1 + i * 0.12)), width: 35, height: 16), p);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx2 + 12, size.height * 0.08 + i * 0.12 * size.height), width: 22, height: 14), p);
    }

    // Backpack (behind body)
    p.color = const Color(0xFF047857);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 12, cy), width: 18, height: 26), const Radius.circular(5)), p);
    // Backpack straps
    p.color = const Color(0xFF065F46);
    canvas.drawRect(Rect.fromLTWH(cx + 4, cy - 12, 3, 20), p);

    // Body (green shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 6), width: 28, height: 30), 7, const Color(0xFF059669));

    // Head
    _drawHead(canvas, Offset(cx, cy - 15), 12, p);

    // Walking arms
    final armSwing = math.sin(walkPhase) * 0.5;
    p.color = const Color(0xFF047857);
    canvas.save();
    canvas.translate(cx - 14, cy + 5);
    canvas.rotate(-armSwing);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -12, 9, 22), const Radius.circular(4)), p);
    canvas.restore();
    canvas.save();
    canvas.translate(cx + 14, cy + 5);
    canvas.rotate(armSwing);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -12, 9, 22), const Radius.circular(4)), p);
    canvas.restore();

    // Walking legs
    final legSwing = math.sin(walkPhase) * 0.4;
    p.color = const Color(0xFF064E3B);
    canvas.save();
    canvas.translate(cx - 7, cy + 26);
    canvas.rotate(legSwing);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5.5, 0, 11, 22), const Radius.circular(5)), p);
    canvas.restore();
    canvas.save();
    canvas.translate(cx + 7, cy + 26);
    canvas.rotate(-legSwing);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5.5, 0, 11, 22), const Radius.circular(5)), p);
    canvas.restore();

    // Shoes
    p.color = const Color(0xFF022C22);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 8, cy + 50), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 8, cy + 50), width: 15, height: 7), p);

    // Ground line
    p.color = const Color(0xFF10B981).withValues(alpha: 0.2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, size.height * 0.88, size.width, 3), const Radius.circular(2)), p);
  }

  @override
  bool shouldRepaint(_TravelPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// GAMING ARTWORK — Character gaming with screen glow
// ══════════════════════════════════════════════════════════════════
class GamingArtwork extends StatelessWidget {
  const GamingArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 1400),
      painterFn: (t) => _GamingPainter(t),
    );
  }
}

class _GamingPainter extends CustomPainter {
  final double t;
  _GamingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi * 1.5) * 2;
    final cx = size.width * 0.55;
    final cy = size.height * 0.52 + bob;

    // Game screen behind character
    final screenGlow = (math.sin(t * 2 * math.pi * 3) + 1) / 2;
    p.color = const Color(0xFF5B21B6).withValues(alpha: 0.15 + screenGlow * 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 22, cy - 15), width: 38, height: 28), const Radius.circular(4)), p);
    // Screen content
    p.color = const Color(0xFFFF5C00).withValues(alpha: 0.4 + screenGlow * 0.3);
    canvas.drawRect(Rect.fromLTWH(cx + 5, cy - 27, 32, 22), p);
    // Pixel art on screen
    p.color = const Color(0xFF60A5FA).withValues(alpha: 0.6);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 4; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(cx + 7 + j * 7.5, cy - 25 + i * 7.0, 6, 5), p);
        }
      }
    }

    // Body (dark purple shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 8), width: 30, height: 32), 7, const Color(0xFF4C1D95));

    // Head (slightly tilted toward screen)
    canvas.save();
    canvas.translate(cx, cy - 16);
    canvas.rotate(0.1);
    _drawHead(canvas, Offset.zero, 12, p);
    canvas.restore();

    // Arms holding controller
    p.color = const Color(0xFF3B0764);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 18, cy + 12), width: 9, height: 22), const Radius.circular(4)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 18, cy + 12), width: 9, height: 22), const Radius.circular(4)), p);

    // Controller
    canvas.save();
    canvas.translate(cx, cy + 30);
    canvas.rotate(math.sin(t * 2 * math.pi) * 0.04);
    p.color = const Color(0xFF2E1065);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -8, 40, 16), const Radius.circular(8)), p);
    // D-pad
    p.color = const Color(0xFF6D28D9);
    canvas.drawCircle(const Offset(-10, 0), 5, p);
    // Buttons
    final btnColors = [const Color(0xFF10B981), const Color(0xFFEF4444), const Color(0xFFFBBF24), const Color(0xFF3B82F6)];
    for (int i = 0; i < 4; i++) {
      p.color = btnColors[i];
      canvas.drawCircle(Offset(10 + (i % 2 == 0 ? -3.5 : 3.5), -3.5 + (i < 2 ? -3.5 : 3.5)), 2.5, p);
    }
    canvas.restore();

    // Legs
    p.color = const Color(0xFF1E1B4B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 8, cy + 38), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 8, cy + 38), width: 12, height: 22), const Radius.circular(5)), p);
    p.color = const Color(0xFF0C0A1E);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 50), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 50), width: 15, height: 7), p);
  }

  @override
  bool shouldRepaint(_GamingPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// PHOTO ARTWORK — Photographer with camera, flash sparks
// ══════════════════════════════════════════════════════════════════
class PhotoArtwork extends StatelessWidget {
  const PhotoArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2800),
      painterFn: (t) => _PhotoPainter(t),
    );
  }
}

class _PhotoPainter extends CustomPainter {
  final double t;
  _PhotoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi) * 3;
    final cx = size.width * 0.55;
    final cy = size.height * 0.5 + bob;

    // Flash burst (periodic)
    final flashPhase = (t * 1.2) % 1.0;
    if (flashPhase < 0.08) {
      p.color = const Color(0xFFFBBF24).withValues(alpha: 1 - flashPhase / 0.08);
      canvas.drawCircle(Offset(cx - 18, cy - 18), 18 * (1 - flashPhase / 0.08) + 4, p);
    }

    // Floating sparkles
    for (int i = 0; i < 4; i++) {
      final sx = cx - 35 + math.sin((t * 2.5 + i * 1.4) * math.pi) * 30;
      final sy = cy - 30 + i * 8 - math.cos((t * 2.5 + i * 1.0) * math.pi) * 10;
      final sp = ((t + i * 0.25) * 1.3) % 1.0;
      p.color = const Color(0xFFF59E0B).withValues(alpha: (1 - sp) * 0.6);
      canvas.drawCircle(Offset(sx, sy), 2.0 + sp * 2, p);
    }

    // Body (amber/brown shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 10), width: 30, height: 32), 7, const Color(0xFF92400E));

    // Head
    _drawHead(canvas, Offset(cx, cy - 15), 12, p);

    // Camera (held up to eye)
    canvas.save();
    canvas.translate(cx - 16, cy - 10);
    canvas.rotate(-0.15);
    p.color = const Color(0xFF1C1917);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -9, 28, 19), const Radius.circular(4)), p);
    // Lens
    p.color = const Color(0xFF284153);
    canvas.drawCircle(const Offset(0, 0), 7, p);
    p.color = const Color(0xFF1D4ED8).withValues(alpha: 0.6);
    canvas.drawCircle(const Offset(0, 0), 5, p);
    p.color = Colors.white.withValues(alpha: 0.3);
    canvas.drawCircle(const Offset(-2, -2), 2, p);
    // Flash
    p.color = const Color(0xFFFBBF24).withValues(alpha: 0.8);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, -12, 10, 6), const Radius.circular(2)), p);
    canvas.restore();

    // Arms (holding camera up)
    p.color = const Color(0xFF78350F);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 15, cy - 2), width: 9, height: 22), const Radius.circular(4)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 15, cy + 8), width: 9, height: 22), const Radius.circular(4)), p);

    // Legs
    p.color = const Color(0xFF451A03);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 8, cy + 37), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 8, cy + 37), width: 12, height: 22), const Radius.circular(5)), p);
    p.color = const Color(0xFF292524);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 50), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 50), width: 15, height: 7), p);
  }

  @override
  bool shouldRepaint(_PhotoPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// COOKING ARTWORK — Chef stirring, steam rising
// ══════════════════════════════════════════════════════════════════
class CookingArtwork extends StatelessWidget {
  const CookingArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2000),
      painterFn: (t) => _CookingPainter(t),
    );
  }
}

class _CookingPainter extends CustomPainter {
  final double t;
  _CookingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi * 1.2) * 2;
    final cx = size.width * 0.54;
    final cy = size.height * 0.48 + bob;

    // Pot / stove
    p.color = const Color(0xFF1C0A00);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 42), width: 46, height: 14), const Radius.circular(4)), p);
    // Pot sheen
    p.color = const Color(0xFF7C2D12).withValues(alpha: 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 40), width: 40, height: 10), const Radius.circular(3)), p);
    // Pot handles
    p.color = const Color(0xFF1C0A00);
    canvas.drawRect(Rect.fromLTWH(cx - 26, cy + 36, 8, 5), p);
    canvas.drawRect(Rect.fromLTWH(cx + 18, cy + 36, 8, 5), p);

    // Soup/liquid swirl
    p.color = const Color(0xFFFF6B35).withValues(alpha: 0.5);
    final swirlAngle = t * 2 * math.pi * 2;
    for (int i = 0; i < 3; i++) {
      final angle = swirlAngle + i * 2.1;
      final rx = cx + math.cos(angle) * 8;
      final ry = cy + 36 + math.sin(angle) * 4;
      canvas.drawCircle(Offset(rx, ry), 4 - i.toDouble(), p);
    }

    // Steam wisps
    for (int i = 0; i < 3; i++) {
      final steamT = (t * 1.5 + i * 0.33) % 1.0;
      final sx = cx - 10 + i * 10.0 + math.sin(steamT * math.pi * 2) * 4;
      final sy = cy + 28 - steamT * 30;
      p.color = Colors.white.withValues(alpha: (1 - steamT) * 0.25);
      canvas.drawOval(Rect.fromCenter(center: Offset(sx, sy), width: 6, height: 10), p);
    }

    // Body (orange/brown shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 8), width: 30, height: 32), 7, const Color(0xFF9A3412));

    // Chef hat
    p.color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy - 30), width: 22, height: 16), const Radius.circular(4)), p);
    p.color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 24), width: 24, height: 10), p);
    // Hat band
    p.color = const Color(0xFFE5E7EB);
    canvas.drawRect(Rect.fromLTWH(cx - 11, cy - 27, 22, 4), p);

    // Head
    _drawHead(canvas, Offset(cx, cy - 15), 12, p);

    // Right arm (stirring - animated rotation)
    final stirAngle = math.sin(t * 2 * math.pi * 2) * 0.5;
    canvas.save();
    canvas.translate(cx + 14, cy + 5);
    canvas.rotate(stirAngle + 0.4);
    p.color = const Color(0xFF7C2D12);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -5, 9, 28), const Radius.circular(4)), p);
    // Spoon/ladle
    p.color = const Color(0xFF44403C);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-2, 22, 4, 14), const Radius.circular(2)), p);
    canvas.drawOval(const Rect.fromLTWH(-5, 33, 10, 8), p);
    canvas.restore();

    // Left arm
    p.color = const Color(0xFF7C2D12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 18, cy + 10), width: 9, height: 26), const Radius.circular(4)), p);

    // Legs
    p.color = const Color(0xFF3F2500);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 8, cy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 8, cy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    p.color = const Color(0xFF1C1917);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 49), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 49), width: 15, height: 7), p);
  }

  @override
  bool shouldRepaint(_CookingPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// PERFORM ARTWORK — Performer on stage with arms raised
// ══════════════════════════════════════════════════════════════════
class ArtArtwork extends StatelessWidget {
  const ArtArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 1900),
      painterFn: (t) => _PerformPainter(t),
    );
  }
}

class _PerformPainter extends CustomPainter {
  final double t;
  _PerformPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi * 1.1) * 4;
    final cx = size.width * 0.54;
    final cy = size.height * 0.5 + bob;

    // Spotlight cone
    final spotOpacity = 0.1 + math.sin(t * 2 * math.pi * 0.8) * 0.05;
    p.color = const Color(0xFF10B981).withValues(alpha: spotOpacity);
    final spotPath = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 40, size.height)
      ..lineTo(cx + 40, size.height)
      ..close();
    canvas.drawPath(spotPath, p);

    // Stage
    p.color = const Color(0xFF065F46).withValues(alpha: 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, size.height * 0.86, size.width, 8), const Radius.circular(2)), p);

    // Grass/stage plants
    for (int i = 0; i < 5; i++) {
      final gx = size.width * (0.05 + i * 0.2);
      final grassH = 8.0 + (i % 3) * 4;
      p.color = const Color(0xFF059669).withValues(alpha: 0.4 + (i % 2) * 0.2);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(gx, size.height * 0.82, 4, grassH),
        const Radius.circular(2),
      ), p);
    }

    // Stars around performer
    for (int i = 0; i < 5; i++) {
      final angle = (t * 2 + i / 5) * 2 * math.pi;
      const sr = 38.0;
      final sx = cx + math.cos(angle) * sr;
      final sy = cy - 8 + math.sin(angle) * sr * 0.5;
      final starT = ((t * 2 + i * 0.2) % 1.0);
      p.color = const Color(0xFFFCD34D).withValues(alpha: starT < 0.5 ? starT * 2 * 0.6 : (1 - starT) * 2 * 0.6);
      canvas.drawCircle(Offset(sx, sy), 2, p);
    }

    // Body (teal shirt)
    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, cy + 8), width: 30, height: 32), 7, const Color(0xFF047857));

    // Head
    _drawHead(canvas, Offset(cx, cy - 15), 12, p);

    // Arms raised triumphantly
    final armAngle = 0.5 + math.sin(t * 2 * math.pi * 1.3) * 0.15;
    p.color = const Color(0xFF065F46);
    canvas.save();
    canvas.translate(cx - 15, cy + 5);
    canvas.rotate(-armAngle - 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -26, 9, 26), const Radius.circular(4)), p);
    p.color = _kSkin;
    canvas.drawCircle(const Offset(0, -28), 5.5, p);
    canvas.restore();

    canvas.save();
    canvas.translate(cx + 15, cy + 5);
    canvas.rotate(armAngle + 0.3);
    p.color = const Color(0xFF065F46);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -26, 9, 26), const Radius.circular(4)), p);
    p.color = _kSkin;
    canvas.drawCircle(const Offset(0, -28), 5.5, p);
    canvas.restore();

    // Legs
    p.color = const Color(0xFF022C22);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 8, cy + 37), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 8, cy + 37), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy + 50), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy + 50), width: 15, height: 7), p);
  }

  @override
  bool shouldRepaint(_PerformPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// TECH & AI ARTWORK — Robot + human, circuit patterns
// ══════════════════════════════════════════════════════════════════
class TechArtwork extends StatelessWidget {
  const TechArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2200),
      painterFn: (t) => _TechPainter(t),
    );
  }
}

class _TechPainter extends CustomPainter {
  final double t;
  _TechPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi) * 3;

    // ── Robot (right side) ──
    final rx = size.width * 0.72;
    final ry = size.height * 0.52 + bob * 0.7;
    const robotColor = Color(0xFF0EA5E9);
    const robotDark = Color(0xFF0369A1);

    // Robot antenna
    p.color = robotDark;
    canvas.drawRect(Rect.fromLTWH(rx - 1.5, ry - 38, 3, 10), p);
    final pulseR = 0.6 + math.sin(t * 2 * math.pi * 3) * 0.3;
    p.color = const Color(0xFF38BDF8).withValues(alpha: pulseR);
    canvas.drawCircle(Offset(rx, ry - 40), 4, p);

    // Robot head
    p.color = robotColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx, ry - 22), width: 22, height: 18), const Radius.circular(5)), p);
    // Robot eyes (LED)
    final eyeGlow = (math.sin(t * 2 * math.pi * 2) + 1) / 2;
    p.color = const Color(0xFF38BDF8).withValues(alpha: 0.5 + eyeGlow * 0.5);
    canvas.drawRect(Rect.fromLTWH(rx - 8, ry - 26, 6, 4), p);
    canvas.drawRect(Rect.fromLTWH(rx + 2, ry - 26, 6, 4), p);
    // Speaker mouth
    p.color = robotDark;
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(Rect.fromLTWH(rx - 6 + i * 3.5, ry - 17, 2.5, 3), p);
    }

    // Robot body
    p.color = const Color(0xFF0284C7);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx, ry + 5), width: 26, height: 28), const Radius.circular(5)), p);
    // Circuit on chest
    p.color = const Color(0xFF38BDF8).withValues(alpha: 0.4);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1;
    canvas.drawRect(Rect.fromCenter(center: Offset(rx, ry + 3), width: 12, height: 10), p);
    canvas.drawLine(Offset(rx - 6, ry + 3), Offset(rx - 12, ry + 3), p);
    canvas.drawLine(Offset(rx + 6, ry + 3), Offset(rx + 12, ry + 3), p);
    p.style = PaintingStyle.fill;

    // Robot arms
    p.color = robotDark;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx - 17, ry + 5), width: 8, height: 22), const Radius.circular(4)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx + 17, ry + 5), width: 8, height: 22), const Radius.circular(4)), p);

    // Robot legs
    p.color = const Color(0xFF075985);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx - 7, ry + 28), width: 10, height: 18), const Radius.circular(4)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx + 7, ry + 28), width: 10, height: 18), const Radius.circular(4)), p);

    // ── Human (left side) ──
    final hx = size.width * 0.38;
    final hy = size.height * 0.52 + bob;

    _drawRoundRect(canvas, Rect.fromCenter(center: Offset(hx, hy + 8), width: 28, height: 30), 7, const Color(0xFF0C4A6E));
    _drawHead(canvas, Offset(hx, hy - 15), 12, p);

    // Arms (one reaching toward robot)
    p.color = const Color(0xFF0369A1);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hx - 16, hy + 8), width: 9, height: 24), const Radius.circular(4)), p);
    // Extended arm toward robot
    canvas.save();
    canvas.translate(hx + 14, hy + 5);
    canvas.rotate(-0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -8, 9, 28), const Radius.circular(4)), p);
    p.color = _kSkin;
    canvas.drawCircle(const Offset(0, 22), 5, p);
    canvas.restore();

    // Legs
    p.color = const Color(0xFF082F49);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hx - 8, hy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hx + 8, hy + 36), width: 12, height: 22), const Radius.circular(5)), p);
    p.color = const Color(0xFF0C1A25);
    canvas.drawOval(Rect.fromCenter(center: Offset(hx - 9, hy + 49), width: 15, height: 7), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(hx + 9, hy + 49), width: 15, height: 7), p);

    // Connection arc between human & robot
    p.color = const Color(0xFF38BDF8).withValues(alpha: 0.3 + math.sin(t * 2 * math.pi * 2) * 0.15);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.5;
    final arcPath = Path()
      ..moveTo(hx + 20, hy - 5)
      ..quadraticBezierTo((hx + rx) / 2, hy - 30, rx - 14, ry - 5);
    canvas.drawPath(arcPath, p);
    p.style = PaintingStyle.fill;

    // Floating AI text
    final aiOpacity = (math.sin(t * 2 * math.pi * 1.2) + 1) / 2 * 0.7;
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'AI',
        style: TextStyle(
          color: const Color(0xFF38BDF8).withValues(alpha: aiOpacity),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset((hx + rx) / 2 - 8, hy - 38));
  }

  @override
  bool shouldRepaint(_TechPainter old) => old.t != t;
}

// ══════════════════════════════════════════════════════════════════
// DATING ARTWORK — Two characters, hearts floating between them
// ══════════════════════════════════════════════════════════════════
class DatingArtwork extends StatelessWidget {
  const DatingArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    return _AnimWidget(
      speed: const Duration(milliseconds: 2400),
      painterFn: (t) => _DatingPainter(t),
    );
  }
}

class _DatingPainter extends CustomPainter {
  final double t;
  _DatingPainter(this.t);

  void _drawPerson(Canvas canvas, double cx, double cy, Color bodyColor, bool isFemale, double t) {
    final p = Paint()..style = PaintingStyle.fill;
    final bob = math.sin(t * 2 * math.pi + (isFemale ? math.pi : 0)) * 3;
    final acy = cy + bob;

    // Body
    if (isFemale) {
      // Dress shape
      p.color = bodyColor;
      final dressPath = Path()
        ..moveTo(cx - 12, acy)
        ..lineTo(cx - 18, acy + 36)
        ..lineTo(cx + 18, acy + 36)
        ..lineTo(cx + 12, acy)
        ..close();
      canvas.drawPath(dressPath, p);
    } else {
      _drawRoundRect(canvas, Rect.fromCenter(center: Offset(cx, acy + 10), width: 26, height: 30), 7, bodyColor);
    }

    // Head
    _drawHead(canvas, Offset(cx, acy - 14), 11, p);

    // Hair (female gets longer hair)
    if (isFemale) {
      p.color = const Color(0xFF92400E);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, acy - 22), width: 24, height: 14), p);
      // Long hair strands
      p.color = const Color(0xFF78350F);
      canvas.drawRect(Rect.fromLTWH(cx - 13, acy - 22, 5, 22), p);
      canvas.drawRect(Rect.fromLTWH(cx + 8, acy - 22, 5, 18), p);
    }

    // Arms (reaching toward center)
    p.color = bodyColor.withValues(alpha: 0.8);
    final armDir = isFemale ? 1.0 : -1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + armDir * 16, acy + 6),
          width: 9, height: 22),
      const Radius.circular(4),
    ), p);
    // Other arm
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - armDir * 14, acy + 6),
          width: 9, height: 22),
      const Radius.circular(4),
    ), p);

    // Legs
    p.color = Color.lerp(bodyColor, Colors.black, 0.5)!;
    if (!isFemale) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 7, acy + 36), width: 11, height: 22), const Radius.circular(5)), p);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 7, acy + 36), width: 11, height: 22), const Radius.circular(5)), p);
      p.color = Colors.black.withValues(alpha: 0.5);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - 8, acy + 49), width: 14, height: 6), p);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + 8, acy + 49), width: 14, height: 6), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    // Female (left) — pink
    _drawPerson(canvas, size.width * 0.28, size.height * 0.48, const Color(0xFFFF3D00), true, t);
    // Male (right) — blue/indigo
    _drawPerson(canvas, size.width * 0.72, size.height * 0.48, const Color(0xFF6366F1), false, t);

    // Floating hearts between them
    for (int i = 0; i < 5; i++) {
      final heartT = ((t * 1.4 + i * 0.2)) % 1.0;
      final hx = size.width * (0.38 + heartT * 0.14);
      final hy = size.height * 0.38 - heartT * 28 + math.sin(heartT * math.pi * 2) * 6;
      final scale = 0.5 + heartT * 0.8;
      final opacity = heartT < 0.7 ? heartT * 1.5 : (1 - heartT) * 3.5;
      p.color = const Color(0xFFFF3B7F).withValues(alpha: opacity.clamp(0, 0.8));
      _drawHeart(canvas, Offset(hx, hy), 4 * scale, p);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint p) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.5);
    path.cubicTo(
      center.dx - size * 2, center.dy - size * 0.5,
      center.dx - size * 2, center.dy - size * 2,
      center.dx, center.dy - size,
    );
    path.cubicTo(
      center.dx + size * 2, center.dy - size * 2,
      center.dx + size * 2, center.dy - size * 0.5,
      center.dx, center.dy + size * 0.5,
    );
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_DatingPainter old) => old.t != t;
}
