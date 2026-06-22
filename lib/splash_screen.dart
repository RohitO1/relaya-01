import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/doodle_theme.dart';

// ═══════════════════════════════════════════════════════════════
// MEETRA — PREMIUM SPLASH SCREEN (YIN YANG CRESCENT LOGO)
// Cinematic loading experience with floating social icons,
// particle system, and lowkey premium aesthetics.
// ═══════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _logoOpacity;

  late AnimationController _glowCtrl;
  late Animation<double> _glowScale;

  late AnimationController _ringCtrl;

  late AnimationController _wordCtrl;
  late Animation<double> _wordOpacity;
  late Animation<Offset> _wordSlide;

  late AnimationController _tagCtrl;
  late Animation<double> _tagOpacity;
  late Animation<Offset> _tagSlide;

  late AnimationController _loaderCtrl;
  late Animation<double> _loaderWidth;

  late AnimationController _gradientCtrl;
  late AnimationController _orbCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _particleCtrl;
  late List<_Particle> _particles;

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 20),
    ]).animate(_logoCtrl);
    
    _logoRotate = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -math.pi, end: 0.1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 20),
    ]).animate(_logoCtrl);
    
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4)));

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _glowScale = Tween(begin: 0.9, end: 1.3).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _wordCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _wordOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOut));
    _wordSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOutCubic));

    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _tagOpacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));
    _tagSlide = Tween(begin: const Offset(0, 0.8), end: Offset.zero).animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOutCubic));

    _loaderCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _loaderWidth = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeInOut));

    _gradientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _particles = List.generate(20, (_) => _Particle(_rng));

    _startSequence();
  }

  Future<void> _startSequence() async {
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    _ringCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _wordCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _tagCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _loaderCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2400));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    _ringCtrl.dispose();
    _wordCtrl.dispose();
    _tagCtrl.dispose();
    _loaderCtrl.dispose();
    _gradientCtrl.dispose();
    _orbCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: isDoodleMode(context) ? DoodleColors.cream : const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          _buildGradientMesh(size),
          _buildAmbientOrbs(size),
          _buildParticles(size),
          _buildFloatingIcons(size),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogoSection(),
                const SizedBox(height: 40),
                SlideTransition(
                  position: _wordSlide,
                  child: FadeTransition(
                    opacity: _wordOpacity,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF8A00), Color(0xFFFF5C00)],
                      ).createShader(bounds),
                      child: Text(
                        'MEETRA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SlideTransition(
                  position: _tagSlide,
                  child: FadeTransition(
                    opacity: _tagOpacity,
                    child: Text(
                      'Unite the World.\nFind Your Missing Half.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 2.0,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                _buildLoadingBar(),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _tagOpacity,
              child: Text(
                'v1.0 · Lowkey Premium',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientMesh(Size size) {
    return AnimatedBuilder(
      animation: _gradientCtrl,
      builder: (_, __) {
        final t = _gradientCtrl.value;
        return Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(math.sin(t * 2 * math.pi) * 0.5, -1),
              end: Alignment(math.cos(t * 2 * math.pi) * 0.5, 1),
              colors: const [
                Color(0xFF050505),
                Color(0xFF0F0A05),
                Color(0xFF0A0500),
                Color(0xFF050505),
              ],
              stops: [0.0, 0.3 + 0.1 * math.sin(t * math.pi), 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmbientOrbs(Size size) {
    return AnimatedBuilder(
      animation: _orbCtrl,
      builder: (_, __) {
        final t = _orbCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: size.height * 0.2 + 30 * math.sin(t * math.pi),
              left: -50 + 20 * math.cos(t * math.pi),
              child: _glowOrb(300, const Color(0xFFFF5C00), 0.08),
            ),
            Positioned(
              bottom: size.height * 0.15 + 40 * math.cos(t * math.pi),
              right: -80 + 30 * math.sin(t * math.pi),
              child: _glowOrb(400, const Color(0xFFFF8A00), 0.06),
            ),
          ],
        );
      },
    );
  }

  Widget _glowOrb(double diameter, Color color, double alpha) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (_, __) {
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(_particles, _particleCtrl.value),
        );
      },
    );
  }

  Widget _buildFloatingIcons(Size size) {
    final icons = [
      const _FloatingIcon(Icons.diamond_outlined, Color(0xFFFF8A00), 0.15, 0.20, 0.5, 1.0),
      const _FloatingIcon(Icons.auto_awesome, Color(0xFFFF5C00), 0.85, 0.30, 0.2, 1.2),
      const _FloatingIcon(Icons.spa_outlined, Color(0xFFFF8A00), 0.20, 0.75, 0.8, 0.9),
      const _FloatingIcon(Icons.local_fire_department_outlined, Color(0xFFFF5C00), 0.80, 0.80, 0.4, 1.1),
    ];

    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, __) {
        final t = _floatCtrl.value;
        return Stack(
          children: icons.map((fi) {
            final dx = fi.baseX * size.width + 15 * math.sin((t * fi.speed + fi.phase) * 2 * math.pi);
            final dy = fi.baseY * size.height + 15 * math.cos((t * fi.speed + fi.phase) * 2 * math.pi);
            final opacity = (0.05 + 0.05 * math.sin((t * fi.speed + fi.phase + 0.5) * 2 * math.pi)).clamp(0.0, 1.0);

            return Positioned(
              left: dx,
              top: dy,
              child: Opacity(
                opacity: opacity,
                child: Icon(fi.icon, color: fi.color, size: 28),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLogoSection() {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _glowScale,
            builder: (_, __) => Transform.scale(
              scale: _glowScale.value,
              child: AnimatedBuilder(
                animation: _logoOpacity,
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value * 0.6,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.5), blurRadius: 60, spreadRadius: 10),
                        BoxShadow(color: const Color(0xFFFF8A00).withValues(alpha: 0.3), blurRadius: 80, spreadRadius: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ..._buildRings(),
          AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => Transform.scale(
              scale: _logoScale.value,
              child: Transform.rotate(
                angle: _logoRotate.value,
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: YinYangCrescentPainter(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRings() {
    final ringData = [
      (10.0, 0.0, const Color(0xFFFF5C00)),
      (30.0, 0.15, const Color(0xFFFF8A00)),
      (50.0, 0.30, const Color(0xFFFF5C00)),
    ];
    return ringData.map((r) {
      final (inset, delay, color) = r;
      return AnimatedBuilder(
        animation: _ringCtrl,
        builder: (_, __) {
          final t = (_ringCtrl.value - delay).clamp(0.0, 1.0);
          final scale = 0.5 + t * 0.8;
          final opacity = t < 0.4 ? t * 2.5 : (1 - t) * 1.67;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0) * 0.5,
              child: Container(
                width: 140 + inset * 2,
                height: 140 + inset * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 2.0),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildLoadingBar() {
    return FadeTransition(
      opacity: _tagOpacity,
      child: Column(
        children: [
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: AnimatedBuilder(
              animation: _loaderWidth,
              builder: (_, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _loaderWidth.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C00), Color(0xFFFF8A00), Color(0xFFFF5C00)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon {
  final IconData icon;
  final Color color;
  final double baseX, baseY, phase, speed;
  const _FloatingIcon(this.icon, this.color, this.baseX, this.baseY, this.phase, this.speed);
}

class _Particle {
  late double x, y, size, speed, phase;
  late Color color;
  _Particle(math.Random rng) {
    x = rng.nextDouble();
    y = rng.nextDouble();
    size = 1.0 + rng.nextDouble() * 2.0;
    speed = 0.2 + rng.nextDouble() * 0.5;
    phase = rng.nextDouble();
    final colors = [const Color(0xFFFF5C00), const Color(0xFFFF8A00), Colors.white70];
    color = colors[rng.nextInt(colors.length)];
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  _ParticlePainter(this.particles, this.time);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (time * p.speed + p.phase) % 1.0;
      final px = p.x * size.width + 5 * math.sin(t * 2 * math.pi);
      final py = (p.y + t * 0.2) % 1.0 * size.height;
      final opacity = (0.1 + 0.2 * math.sin(t * 2 * math.pi)).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(px, py), p.size, Paint()..color = p.color.withValues(alpha: opacity));
    }
  }
  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

class YinYangCrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF8A00), Color(0xFFFF5C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF5C00), Color(0xFFFF2A00)],
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(center.dx - radius + 10, center.dy);
    path1.arcToPoint(Offset(center.dx + radius - 10, center.dy), radius: Radius.circular(radius - 10), clockwise: true);
    path1.arcToPoint(Offset(center.dx, center.dy), radius: Radius.circular((radius - 10) / 2), clockwise: true);
    path1.arcToPoint(Offset(center.dx - radius + 10, center.dy), radius: Radius.circular((radius - 10) / 2), clockwise: false);

    final path2 = Path();
    path2.moveTo(center.dx + radius - 10, center.dy);
    path2.arcToPoint(Offset(center.dx - radius + 10, center.dy), radius: Radius.circular(radius - 10), clockwise: true);
    path2.arcToPoint(Offset(center.dx, center.dy), radius: Radius.circular((radius - 10) / 2), clockwise: true);
    path2.arcToPoint(Offset(center.dx + radius - 10, center.dy), radius: Radius.circular((radius - 10) / 2), clockwise: false);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);

    final dotPaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawCircle(Offset(center.dx + (radius - 10) / 2, center.dy), 10, dotPaint);
    canvas.drawCircle(Offset(center.dx - (radius - 10) / 2, center.dy), 10, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
