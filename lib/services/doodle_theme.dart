// ignore_for_file: unused_element
// ─────────────────────────────────────────────────────────────────────────────
// DOODLE DIARY THEME SYSTEM
// Hand-drawn journal/notebook aesthetic — LIGHT MODE ONLY
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER
// ═══════════════════════════════════════════════════════════════════════════════

/// Returns true when the app is in light mode (doodle diary style should show)
bool isDoodleMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

// ═══════════════════════════════════════════════════════════════════════════════
// COLORS
// ═══════════════════════════════════════════════════════════════════════════════

class DoodleColors {
  // ── Backgrounds ──
  static const cream         = Color(0xFFFFF5E6);
  static const creamDark     = Color(0xFFFFE8CC);
  static const parchment     = Color(0xFFFFF0D6);
  static const warmWhite     = Color(0xFFFFFBF5);
  static const paper         = Color(0xFFFFFDF8);

  // ── Cards ──
  static const cardBg        = Color(0xFFFFFCF5);
  static const cardBorder    = Color(0xFFE0C9A8);
  static const cardShadow    = Color(0x22B8956E);

  // ── Accent ──
  static const orange        = Color(0xFFFF8C42);
  static const orangeDark    = Color(0xFFE67A30);
  static const amber         = Color(0xFFFFC857);
  static const coral         = Color(0xFFFF6B6B);
  static const brown         = Color(0xFF4E342E);
  static const blue          = Color(0xFF1976D2);
  static const green         = Color(0xFF2E7D32);

  // ── Pastel tile accents ──
  static const pastelLavender = Color(0xFFE8D5F5);
  static const pastelMint     = Color(0xFFD5F0E8);
  static const pastelPeach    = Color(0xFFFFE0CC);
  static const pastelSky      = Color(0xFFD5E8F5);
  static const pastelLemon    = Color(0xFFFFF5CC);
  static const pastelRose     = Color(0xFFFFD5E0);

  // ── Text ──
  static const textPrimary   = Color(0xFF2C1810);
  static const textSecondary = Color(0xFF6B5B4F);
  static const textMuted     = Color(0xFF9B8E84);
  static const textHint      = Color(0xFFBBA99A);

  // ── Borders / Lines ──
  static const sketchLine    = Color(0xFF8B7355);
  static const sketchLineLight = Color(0xFFCBB99A);
  static const notebookLine  = Color(0xFFE8D5C0);

  // ── Nav ──
  static const navBg         = Color(0xFFFFF5E6);
  static const navBorder     = Color(0xFFE0C9A8);
  static const navActive     = Color(0xFF2C1810);
  static const navInactive   = Color(0xFFBBA99A);

  // ── Input ──
  static const inputBg       = Color(0xFFFFFDF5);
  static const inputBorder   = Color(0xFFD4BFA0);

  /// Get a random pastel color for grid tiles
  static Color pastelAt(int index) {
    const pastels = [pastelLavender, pastelMint, pastelPeach, pastelSky, pastelLemon, pastelRose];
    return pastels[index % pastels.length];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPOGRAPHY HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

class DoodleFonts {
  /// Handwritten display font for headings
  static TextStyle heading({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color color = DoodleColors.textPrimary,
  }) =>
      GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Semi-handwritten for sub-headings and section titles
  static TextStyle subheading({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = DoodleColors.textPrimary,
  }) =>
      GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Body text — clean but warm
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = DoodleColors.textPrimary,
  }) =>
      GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Small label text
  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = DoodleColors.textSecondary,
  }) =>
      GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Caption / muted text
  static TextStyle caption({
    double fontSize = 11,
    Color color = DoodleColors.textMuted,
  }) =>
      GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Paints a wobbly hand-drawn rectangle border (sketch effect)
class SketchBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double wobble;
  final double radius;

  SketchBorderPainter({
    this.color = DoodleColors.sketchLine,
    this.strokeWidth = 1.5,
    this.wobble = 2.0,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rng = math.Random(size.width.toInt() ^ size.height.toInt());
    final path = Path();

    final r = radius;
    final w = size.width;
    final h = size.height;

    // Top-left corner
    path.moveTo(r, _w(0, rng));
    // Top edge
    for (double x = r; x < w - r; x += 8) {
      path.lineTo(x, _w(0, rng));
    }
    // Top-right corner
    path.quadraticBezierTo(w + _w(0, rng), _w(0, rng), w + _w(0, rng), r);
    // Right edge
    for (double y = r; y < h - r; y += 8) {
      path.lineTo(w + _w(0, rng), y);
    }
    // Bottom-right corner
    path.quadraticBezierTo(w + _w(0, rng), h + _w(0, rng), w - r, h + _w(0, rng));
    // Bottom edge
    for (double x = w - r; x > r; x -= 8) {
      path.lineTo(x, h + _w(0, rng));
    }
    // Bottom-left corner
    path.quadraticBezierTo(_w(0, rng), h + _w(0, rng), _w(0, rng), h - r);
    // Left edge
    for (double y = h - r; y > r; y -= 8) {
      path.lineTo(_w(0, rng), y);
    }
    // Close back to top-left
    path.quadraticBezierTo(_w(0, rng), _w(0, rng), r, _w(0, rng));

    canvas.drawPath(path, paint);
  }

  double _w(double base, math.Random rng) =>
      base + (rng.nextDouble() - 0.5) * wobble;

  @override
  bool shouldRepaint(covariant SketchBorderPainter old) =>
      color != old.color || strokeWidth != old.strokeWidth;
}

/// Paints scattered doodle decorations (stars, hearts, sparkles, arrows)
class ScatteredDoodlesPainter extends CustomPainter {
  final int seed;
  final double density;
  final Color color;

  ScatteredDoodlesPainter({
    this.seed = 42,
    this.density = 0.6,
    this.color = const Color(0x30B8956E),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final count = (size.width * size.height / 25000 * density).clamp(4, 20).toInt();

    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final type = rng.nextInt(6);
      final s = 6.0 + rng.nextDouble() * 8;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rng.nextDouble() * math.pi * 0.3 - 0.15);

      switch (type) {
        case 0: _drawStar(canvas, paint, s); break;
        case 1: _drawHeart(canvas, fillPaint, s * 0.7); break;
        case 2: _drawSparkle(canvas, paint, s); break;
        case 3: _drawCircle(canvas, paint, s * 0.5); break;
        case 4: _drawSwirl(canvas, paint, s); break;
        case 5: _drawArrow(canvas, paint, s); break;
      }
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double s) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 144 - 90) * math.pi / 180;
      final x = math.cos(angle) * s;
      final y = math.sin(angle) * s;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Paint paint, double s) {
    final path = Path();
    path.moveTo(0, s * 0.3);
    path.cubicTo(-s, -s * 0.5, -s * 0.3, -s, 0, -s * 0.4);
    path.cubicTo(s * 0.3, -s, s, -s * 0.5, 0, s * 0.3);
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(Canvas canvas, Paint paint, double s) {
    // 4-point sparkle
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * math.pi / 180;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * s, math.sin(angle) * s),
        paint,
      );
    }
  }

  void _drawCircle(Canvas canvas, Paint paint, double s) {
    canvas.drawCircle(Offset.zero, s, paint);
  }

  void _drawSwirl(Canvas canvas, Paint paint, double s) {
    final path = Path();
    for (double t = 0; t < 2 * math.pi; t += 0.3) {
      final r = s * t / (2 * math.pi);
      final x = math.cos(t) * r;
      final y = math.sin(t) * r;
      if (t == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Paint paint, double s) {
    canvas.drawLine(Offset(-s, 0), Offset(s, 0), paint);
    canvas.drawLine(Offset(s * 0.5, -s * 0.4), Offset(s, 0), paint);
    canvas.drawLine(Offset(s * 0.5, s * 0.4), Offset(s, 0), paint);
  }

  @override
  bool shouldRepaint(covariant ScatteredDoodlesPainter old) =>
      seed != old.seed || density != old.density || color != old.color;
}

/// Paints horizontal notebook lines
class NotebookLinesPainter extends CustomPainter {
  final Color lineColor;
  final double spacing;

  NotebookLinesPainter({
    this.lineColor = DoodleColors.notebookLine,
    this.spacing = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;

    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant NotebookLinesPainter old) =>
      lineColor != old.lineColor || spacing != old.spacing;
}

/// Draws a hand-drawn circle border (for avatars)
class SketchCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  SketchCirclePainter({
    this.color = DoodleColors.orange,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (math.min(size.width, size.height) / 2) - strokeWidth;
    final rng = math.Random(size.width.toInt());

    final path = Path();
    for (double angle = 0; angle < math.pi * 2; angle += 0.15) {
      final wobble = (rng.nextDouble() - 0.5) * 2.0;
      final x = cx + (r + wobble) * math.cos(angle);
      final y = cy + (r + wobble) * math.sin(angle);
      if (angle == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SketchCirclePainter old) =>
      color != old.color || strokeWidth != old.strokeWidth;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DECORATIONS
// ═══════════════════════════════════════════════════════════════════════════════

class DoodleDecorations {
  /// Standard doodle card decoration
  static BoxDecoration card({
    Color? color,
    double radius = 16,
    Color borderColor = DoodleColors.cardBorder,
  }) =>
      BoxDecoration(
        color: color ?? DoodleColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DoodleColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(2, 3),
          ),
        ],
      );

  /// Pastel-tinted card for grid tiles
  static BoxDecoration pastelCard(int index, {double radius = 14}) =>
      BoxDecoration(
        color: DoodleColors.pastelAt(index).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: DoodleColors.pastelAt(index).withValues(alpha: 0.8),
          width: 1.5,
        ),
      );

  /// Parchment page background gradient
  static BoxDecoration parchmentBg() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DoodleColors.cream,
            DoodleColors.parchment,
            DoodleColors.creamDark,
          ],
        ),
      );

  /// Input field decoration
  static BoxDecoration input({bool focused = false}) => BoxDecoration(
        color: DoodleColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? DoodleColors.orange : DoodleColors.inputBorder,
          width: focused ? 2.0 : 1.5,
        ),
      );

  /// Bottom nav bar decoration
  static BoxDecoration navBar() => const BoxDecoration(
        color: DoodleColors.navBg,
        border: Border(
          top: BorderSide(color: DoodleColors.navBorder, width: 1.5),
        ),
      );

  /// Chip / pill decoration
  static BoxDecoration chip({bool selected = false}) => BoxDecoration(
        color: selected
            ? DoodleColors.orange.withValues(alpha: 0.15)
            : DoodleColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? DoodleColors.orange : DoodleColors.cardBorder,
          width: 1.5,
        ),
      );

  /// Section header underline
  static BoxDecoration sectionUnderline() => const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: DoodleColors.sketchLineLight,
            width: 1.5,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WRAPPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// A scaffold wrapper that applies parchment background + scattered doodles
/// in light mode. In dark mode, it simply returns the child unchanged.
class DoodleScaffold extends StatelessWidget {
  final Widget child;
  final bool showDoodles;
  final bool showNotebookLines;
  final int doodleSeed;
  final Color? backgroundColor;

  const DoodleScaffold({
    super.key,
    required this.child,
    this.showDoodles = true,
    this.showNotebookLines = false,
    this.doodleSeed = 42,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDoodleMode(context)) return child;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundColor ?? DoodleColors.cream,
            DoodleColors.parchment,
            DoodleColors.creamDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          if (showNotebookLines)
            Positioned.fill(
              child: CustomPaint(
                painter: NotebookLinesPainter(),
              ),
            ),
          if (showDoodles)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ScatteredDoodlesPainter(
                    seed: doodleSeed,
                    density: 0.4,
                    color: const Color(0x20B8956E),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// A card with sketch-style hand-drawn border
class DoodleCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const DoodleCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDoodleMode(context)) {
      return Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: CustomPaint(
        painter: SketchBorderPainter(
          color: borderColor ?? DoodleColors.sketchLine,
          radius: radius,
          wobble: 1.5,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor ?? DoodleColors.cardBg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Avatar with hand-drawn circle border
class DoodleAvatar extends StatelessWidget {
  final String url;
  final double size;
  final Color borderColor;
  final Widget? fallback;

  const DoodleAvatar({
    super.key,
    required this.url,
    this.size = 60,
    this.borderColor = DoodleColors.orange,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipOval(
      child: SizedBox(
        width: size - 8,
        height: size - 8,
        child: url.isNotEmpty
            ? Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultFallback())
            : fallback ?? _defaultFallback(),
      ),
    );

    if (!isDoodleMode(context)) {
      return SizedBox(width: size, height: size, child: Center(child: child));
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SketchCirclePainter(
          color: borderColor,
          strokeWidth: 2.5,
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _defaultFallback() => Container(
        color: DoodleColors.pastelLavender,
        child: Icon(Icons.person, color: DoodleColors.textMuted, size: size * 0.5),
      );
}

/// Section header with doodle underline
class DoodleSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final IconData? icon;
  final Color? iconColor;

  const DoodleSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDoodleMode(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Text(title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            )),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? DoodleColors.orange, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: DoodleFonts.subheading(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DoodleColors.sketchLine, width: 1.5),
                color: DoodleColors.paper,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: DoodleFonts.label(fontSize: 11, color: DoodleColors.textPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Floating doodle decoration widget (paper plane, star, heart, etc.)
class DoodleDecoration extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final double rotation;

  const DoodleDecoration({
    super.key,
    required this.icon,
    this.size = 20,
    this.color = const Color(0x40B8956E),
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDoodleMode(context)) return const SizedBox.shrink();

    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Icon(icon, size: size, color: color),
    );
  }
}

/// A tape/sticker-like accent strip
class DoodleTapeStrip extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final double rotation;

  const DoodleTapeStrip({
    super.key,
    this.color = const Color(0x30FFC857),
    this.width = 60,
    this.height = 20,
    this.rotation = -5,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDoodleMode(context)) return const SizedBox.shrink();

    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOODLE BOTTOM NAV BAR
// ═══════════════════════════════════════════════════════════════════════════════

/// Nav bar item data for the doodle style nav bar
class DoodleNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const DoodleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Bottom nav bar in the doodle/notebook style
class DoodleBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final Widget centerButton;
  final double bottomPadding;

  const DoodleBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.centerButton,
    this.bottomPadding = 0,
  });

  static const _items = [
    DoodleNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    DoodleNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Explore'),
    // Center button placeholder — skip index 2
    DoodleNavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
    DoodleNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: DoodleColors.navBg,
        border: Border(
          top: BorderSide(color: DoodleColors.navBorder, width: 1.5),
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _buildItem(0, _items[0]),
            _buildItem(1, _items[1]),
            Expanded(child: centerButton),
            _buildItem(3, _items[2]),
            _buildItem(4, _items[3]),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(int index, DoodleNavItem item) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? DoodleColors.navActive : DoodleColors.navInactive,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: DoodleFonts.caption(
                fontSize: 10,
                color: isSelected ? DoodleColors.navActive : DoodleColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOODLE BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class DoodleButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;

  const DoodleButton({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDoodleMode(context)) {
      return ElevatedButton(onPressed: onTap, child: Text(text));
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? DoodleColors.orange : DoodleColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? DoodleColors.orangeDark : DoodleColors.cardBorder,
            width: 1.5,
          ),
          boxShadow: filled
              ? [BoxShadow(color: DoodleColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(2, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: filled ? Colors.white : DoodleColors.textPrimary, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: DoodleFonts.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : DoodleColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
