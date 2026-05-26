import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════
// MEETRA — PREMIUM SPLASH SCREEN
// Cinematic loading experience with floating social icons,
// particle system, and glassmorphic design elements.
// ═══════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Core animation controllers
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

  // Floating social icons
  late AnimationController _floatCtrl;

  // Particle system
  late AnimationController _particleCtrl;
  late List<_Particle> _particles;

  // Feature capsules
  late AnimationController _capsuleCtrl;

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    // Logo entrance: dramatic scale + rotation
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
    ]).animate(_logoCtrl);
    _logoRotate = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -math.pi, end: 0.2), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 10),
    ]).animate(_logoCtrl);
    _logoOpacity = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4)));

    // Glow pulse
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _glowScale = Tween(begin: 0.9, end: 1.3).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Rings
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    // Wordmark — slide up + fade
    _wordCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _wordOpacity = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOut));
    _wordSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOutCubic));

    // Tagline — slide up + fade (delayed feel)
    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _tagOpacity = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));
    _tagSlide = Tween(begin: const Offset(0, 0.8), end: Offset.zero)
        .animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOutCubic));

    // Loading bar
    _loaderCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _loaderWidth = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeInOut));

    // Gradient shift on background
    _gradientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

    // Ambient orbs
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);

    // Floating social icons
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    // Particles
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _particles = List.generate(30, (_) => _Particle(_rng));

    // Feature capsule reveal
    _capsuleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Logo entrance
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    // Rings expand
    _ringCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    // Feature capsules
    _capsuleCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // Wordmark
    _wordCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    // Tagline
    _tagCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));

    // Loading bar
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
    _capsuleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Stack(
        children: [
          // Layer 0: Animated gradient mesh background
          _buildGradientMesh(size),

          // Layer 1: Ambient orbs (matching Explore)
          _buildAmbientOrbs(size),

          // Layer 2: Particle field
          _buildParticles(size),

          // Layer 3: Floating social/feature icons
          _buildFloatingIcons(size),

          // Layer 4: Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Feature capsules above logo
                _buildFeatureCapsules(),
                const SizedBox(height: 30),

                // Logo with rings & glow
                _buildLogoSection(),

                const SizedBox(height: 32),

                // Wordmark "MEETRA"
                SlideTransition(
                  position: _wordSlide,
                  child: FadeTransition(
                    opacity: _wordOpacity,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFF22C55E), Color(0xFF06B6D4)],
                      ).createShader(bounds),
                      child: Text(
                        'MEETRA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tagline
                SlideTransition(
                  position: _tagSlide,
                  child: FadeTransition(
                    opacity: _tagOpacity,
                    child: Text(
                      'Meet People Who Match Your Vibe',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Loading bar
                _buildLoadingBar(),
              ],
            ),
          ),

          // Layer 5: Version watermark
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _tagOpacity,
              child: Text(
                'v1.0 · Made in India 🇮🇳',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.15),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GRADIENT MESH — animated deep background
  // ═══════════════════════════════════════════════════════════
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
                Color(0xFF050510),
                Color(0xFF0A0A1A),
                Color(0xFF0D0520),
                Color(0xFF050510),
              ],
              stops: [0.0, 0.3 + 0.1 * math.sin(t * math.pi), 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // AMBIENT ORBS — matching Explore page aesthetic
  // ═══════════════════════════════════════════════════════════
  Widget _buildAmbientOrbs(Size size) {
    return AnimatedBuilder(
      animation: _orbCtrl,
      builder: (_, __) {
        final t = _orbCtrl.value;
        return Stack(
          children: [
            // Cyan orb — top right
            Positioned(
              top: -120 + 25 * math.sin(t * math.pi),
              right: -100 + 30 * math.cos(t * math.pi),
              child: _glowOrb(350, const Color(0xFFFF6B00), 0.12),
            ),
            // Purple orb — bottom left
            Positioned(
              bottom: size.height * 0.12,
              left: -80 - 20 * math.cos(t * math.pi),
              child: _glowOrb(300, const Color(0xFFFF7E40), 0.10),
            ),
            // Pink orb — mid-right
            Positioned(
              top: size.height * 0.35,
              right: -70 + 15 * math.sin(t * math.pi * 1.3),
              child: _glowOrb(250, const Color(0xFFFF3D00), 0.08),
            ),
            // Orange orb — bottom center
            Positioned(
              bottom: -80 + 10 * math.sin(t * math.pi),
              left: size.width * 0.25,
              child: _glowOrb(200, const Color(0xFFF97316), 0.06),
            ),
            // Blue orb — top left
            Positioned(
              top: size.height * 0.15 + 20 * math.cos(t * math.pi * 0.7),
              left: -60,
              child: _glowOrb(200, const Color(0xFF3B82F6), 0.08),
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

  // ═══════════════════════════════════════════════════════════
  // PARTICLE FIELD — tiny floating dots
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // FLOATING SOCIAL ICONS — drift around the screen
  // ═══════════════════════════════════════════════════════════
  Widget _buildFloatingIcons(Size size) {
    final icons = [
      const _FloatingIcon(Icons.people_outline, Color(0xFFFF6B00), 0.12, 0.15, 0.7, 1.0),
      const _FloatingIcon(Icons.chat_bubble_outline, Color(0xFFFF7E40), 0.85, 0.20, 0.5, 1.3),
      const _FloatingIcon(Icons.explore_outlined, Color(0xFFFF3D00), 0.08, 0.65, 0.6, 0.8),
      const _FloatingIcon(Icons.favorite_outline, Color(0xFFF97316), 0.88, 0.70, 0.8, 1.1),
      const _FloatingIcon(Icons.music_note_outlined, Color(0xFF22C55E), 0.75, 0.40, 0.4, 1.5),
      const _FloatingIcon(Icons.sports_esports_outlined, Color(0xFF06B6D4), 0.20, 0.85, 0.9, 0.7),
      const _FloatingIcon(Icons.camera_alt_outlined, Color(0xFFFF7E40), 0.60, 0.10, 0.3, 1.2),
      const _FloatingIcon(Icons.flight_takeoff, Color(0xFF10B981), 0.40, 0.78, 0.55, 0.9),
      const _FloatingIcon(Icons.restaurant_outlined, Color(0xFFEF4444), 0.92, 0.50, 0.75, 1.4),
      const _FloatingIcon(Icons.menu_book_outlined, Color(0xFF3B82F6), 0.15, 0.42, 0.65, 1.0),
      const _FloatingIcon(Icons.rocket_launch_outlined, Color(0xFFF59E0B), 0.70, 0.88, 0.35, 0.8),
      const _FloatingIcon(Icons.local_fire_department_outlined, Color(0xFFFF3D00), 0.50, 0.30, 0.85, 1.2),
    ];

    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, __) {
        final t = _floatCtrl.value;
        return Stack(
          children: icons.map((fi) {
            final dx = fi.baseX * size.width +
                12 * math.sin((t * fi.speed + fi.phase) * 2 * math.pi);
            final dy = fi.baseY * size.height +
                10 * math.cos((t * fi.speed + fi.phase) * 2 * math.pi);
            final opacity = (0.08 + 0.06 * math.sin((t * fi.speed + fi.phase + 0.5) * 2 * math.pi))
                .clamp(0.0, 1.0);

            return Positioned(
              left: dx,
              top: dy,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fi.color.withValues(alpha: 0.06),
                    border: Border.all(color: fi.color.withValues(alpha: 0.08), width: 1),
                  ),
                  child: Icon(fi.icon, color: fi.color.withValues(alpha: 0.3), size: 18),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FEATURE CAPSULES — glassmorphic pills above logo
  // ═══════════════════════════════════════════════════════════
  Widget _buildFeatureCapsules() {
    final features = [
      ('🎯', 'Discover'),
      ('💬', 'Connect'),
      ('⚡', 'Rush-In'),
    ];

    return AnimatedBuilder(
      animation: _capsuleCtrl,
      builder: (_, __) {
        final t = _capsuleCtrl.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: features.asMap().entries.map((entry) {
                final delay = entry.key * 0.2;
                final capsuleT = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);

                return Transform.scale(
                  scale: 0.8 + 0.2 * capsuleT,
                  child: Opacity(
                    opacity: capsuleT,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.value.$1, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            entry.value.$2,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOGO SECTION — enlarged with rings, glow, gradient shift
  // ═══════════════════════════════════════════════════════════
  Widget _buildLogoSection() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Multi-layered glow
          AnimatedBuilder(
            animation: _glowScale,
            builder: (_, __) => Transform.scale(
              scale: _glowScale.value,
              child: AnimatedBuilder(
                animation: _logoOpacity,
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value * 0.5,
                  child: AnimatedBuilder(
                    animation: _gradientCtrl,
                    builder: (_, __) {
                      final t = _gradientCtrl.value;
                      return Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(
                              0.3 * math.sin(t * 2 * math.pi),
                              0.3 * math.cos(t * 2 * math.pi),
                            ),
                            colors: [
                              const Color(0xFFFF6B00).withValues(alpha: 0.3),
                              const Color(0xFFFF7E40).withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Animated rings
          ..._buildRings(),

          // Logo image — enlarged with dramatic entrance
          AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => Transform.scale(
              scale: _logoScale.value,
              child: Transform.rotate(
                angle: _logoRotate.value,
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF7E40).withValues(alpha: 0.15),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/meetra_logo.jpg',
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
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

  // ═══════════════════════════════════════════════════════════
  // RINGS — expanding pulse rings
  // ═══════════════════════════════════════════════════════════
  List<Widget> _buildRings() {
    final ringData = [
      (15.0, 0.0, const Color(0xFFFF6B00)),
      (35.0, 0.12, const Color(0xFFFF7E40)),
      (55.0, 0.24, const Color(0xFFFF3D00)),
      (75.0, 0.36, const Color(0xFF06B6D4)),
    ];

    return ringData.map((r) {
      final (inset, delay, color) = r;

      return AnimatedBuilder(
        animation: _ringCtrl,
        builder: (_, __) {
          final t = (_ringCtrl.value - delay).clamp(0.0, 1.0);
          final scale = 0.4 + t * 0.9;
          final opacity = t < 0.4 ? t * 2.5 : (1 - t) * 1.67;

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0) * 0.4,
              child: Container(
                width: 140 + inset * 2,
                height: 140 + inset * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // LOADING BAR — gradient progress indicator
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoadingBar() {
    return FadeTransition(
      opacity: _tagOpacity,
      child: Column(
        children: [
          Container(
            width: 180,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: AnimatedBuilder(
              animation: _loaderWidth,
              builder: (_, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _loaderWidth.value,
                child: AnimatedBuilder(
                  animation: _gradientCtrl,
                  builder: (_, __) {
                    final t = _gradientCtrl.value;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B00),
                            Color.lerp(const Color(0xFF22C55E), const Color(0xFF06B6D4), math.sin(t * math.pi).abs())!,
                            const Color(0xFFFF7E40),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _loaderWidth,
            builder: (_, __) {
              final pct = (_loaderWidth.value * 100).round();
              return Text(
                'Loading experience · $pct%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 0.5,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FLOATING ICON DATA
// ═══════════════════════════════════════════════════════════════
class _FloatingIcon {
  final IconData icon;
  final Color color;
  final double baseX, baseY;
  final double phase, speed;

  const _FloatingIcon(this.icon, this.color, this.baseX, this.baseY, this.phase, this.speed);
}

// ═══════════════════════════════════════════════════════════════
// PARTICLE SYSTEM
// ═══════════════════════════════════════════════════════════════
class _Particle {
  late double x, y, size, speed, phase;
  late Color color;

  _Particle(math.Random rng) {
    x = rng.nextDouble();
    y = rng.nextDouble();
    size = 1.0 + rng.nextDouble() * 2.5;
    speed = 0.3 + rng.nextDouble() * 0.7;
    phase = rng.nextDouble();
    final colors = [
      const Color(0xFFFF6B00),
      const Color(0xFFFF7E40),
      const Color(0xFFFF3D00),
      const Color(0xFF06B6D4),
      const Color(0xFF22C55E),
    ];
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
      final px = p.x * size.width + 8 * math.sin(t * 2 * math.pi);
      final py = (p.y + t * 0.3) % 1.0 * size.height;
      final opacity = (0.15 + 0.15 * math.sin(t * 2 * math.pi)).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()..color = p.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
