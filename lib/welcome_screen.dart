import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────
// WELCOME SCREEN — Confetti celebration + feature overview
// ─────────────────────────────────────────────────────────────────
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onEnterApp;
  const WelcomeScreen({super.key, required this.onEnterApp});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late AnimationController _confettiCtrl;
  final _rand = math.Random();

  // Confetti pieces
  late List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();

    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _checkScale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));

    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();

    _pieces = List.generate(60, (_) => _ConfettiPiece(
      x: _rand.nextDouble(),
      delay: _rand.nextDouble(),
      duration: _rand.nextDouble() * 3 + 2,
      color: [
        const Color(0xFFFF6B00), const Color(0xFFFF7E40), const Color(0xFFFF3D00),
        const Color(0xFFF97316), const Color(0xFF22C55E), const Color(0xFFEAB308),
        const Color(0xFF3B82F6),
      ][_rand.nextInt(7)],
      size: _rand.nextDouble() * 8 + 4,
      isCircle: _rand.nextBool(),
    ));

    // Start check animation after a brief delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _checkCtrl.forward();
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Ambient orbs
          Positioned(top: -80, right: -60, child: _orb(250, const Color(0xFFFF6B00))),
          Positioned(bottom: 80, left: -40, child: _orb(200, const Color(0xFFFF7E40))),

          // Confetti
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ConfettiPainter(_pieces, _confettiCtrl.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Check icon
                    ScaleTransition(
                      scale: _checkScale,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF6B00).withValues(alpha: 0.2),
                              const Color(0xFF22C55E).withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.check, color: Color(0xFFFF6B00), size: 36),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Welcome to Relaya! 🎉',
                      style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                    ),

                    const SizedBox(height: 6),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Your profile is set up and ready. Start exploring and find your real allies today!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8), height: 1.6),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Feature pills
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _featurePill('🏠', 'Home'),
                        const SizedBox(width: 12),
                        _featurePill('🔍', 'Explore'),
                        const SizedBox(width: 12),
                        _featurePill('⚡', 'Spark'),
                        const SizedBox(width: 12),
                        _featurePill('🛒', 'Market'),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Let's Go button
                    GestureDetector(
                      onTap: widget.onEnterApp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF22C55E)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rocket_launch, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Text("Let's Go!", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
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
      ),
    );
  }

  Widget _featurePill(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.12), Colors.transparent]),
      ),
    );
  }
}

// ─── Confetti data ───────────────────────────────────────────────
class _ConfettiPiece {
  final double x;
  final double delay;
  final double duration;
  final Color color;
  final double size;
  final bool isCircle;

  _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.duration,
    required this.color,
    required this.size,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter(this.pieces, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = ((progress - p.delay * 0.25) / (p.duration / 4)).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;

      final x = p.x * size.width;
      final y = -20 + t * (size.height + 40);
      final rotation = t * 720 * math.pi / 180;
      final opacity = t < 0.1 ? t * 10 : (t > 0.8 ? (1 - t) * 5 : 1.0);

      final paint = Paint()..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
