import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────
// FEATURE GUIDE — 5-slide walkthrough
// ─────────────────────────────────────────────────────────────────
class FeatureGuideScreen extends StatefulWidget {
  final Function(BuildContext) onComplete;
  const FeatureGuideScreen({super.key, required this.onComplete});

  @override
  State<FeatureGuideScreen> createState() => _FeatureGuideScreenState();
}

class _FeatureGuideScreenState extends State<FeatureGuideScreen> with TickerProviderStateMixin {
  int _current = 0;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;
  late AnimationController _ringCtrl;

  static const _slides = [
    _SlideData(
      emoji: '🏠',
      title: 'Your Personalized Feed',
      desc: 'Discover posts from people who share your interests. Filter by location and topics. Connect with your community!',
      color: Color(0xFFFF6B00),
    ),
    _SlideData(
      emoji: '🤖',
      title: 'AI-Powered Matching',
      desc: 'Our AI analyzes your interests and activities to find your perfect matches. See compatibility scores and reasons why you\'d click!',
      color: Color(0xFFFF7E40),
    ),
    _SlideData(
      emoji: '⚡',
      title: 'Spark: Rush-ins & Activities',
      desc: 'Create anonymous Rush-ins for spontaneous meetups or host public Activities. Join others on the map and make every moment count!',
      color: Color(0xFFF97316),
    ),
    _SlideData(
      emoji: '🎪',
      title: 'Experience: Events & Companions',
      desc: 'Book premium events — date nights, trips, concerts. Or connect with verified companions — therapists, musicians, coaches & more!',
      color: Color(0xFFFF3D00),
    ),
    _SlideData(
      emoji: '🚀',
      title: 'You\'re All Set!',
      desc: 'Explore 5 powerful sections — Home, Explore, Spark, Market & Profile. Your next real connection is just a tap away.',
      color: Color(0xFF22C55E),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween(begin: 0.0, end: -10.0).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  void _goTo(int idx) {
    if (idx < 0 || idx >= _slides.length) return;
    HapticFeedback.selectionClick();
    setState(() => _current = idx);
  }

  void _next() {
    if (_current >= _slides.length - 1) {
      debugPrint('Meetra: Get Started button clicked on last slide');
      widget.onComplete(context);
    } else {
      _goTo(_current + 1);
    }
  }

  void _prev() => _goTo(_current - 1);

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];
    final isLast = _current == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient orbs
            _buildOrbs(slide.color),



            // Main content
            Column(
              children: [
                const Spacer(flex: 2),

                // Illustration
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(offset: Offset(0, _floatAnim.value), child: child),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildIllustration(slide),
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    slide.title,
                    key: ValueKey('t_$_current'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    key: ValueKey('d_$_current'),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      slide.desc,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8), height: 1.6),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final isActive = i == _current;
                    return GestureDetector(
                      onTap: () => _goTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isActive ? const Color(0xFFFF6B00) : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // Nav buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (_current > 0)
                        Expanded(
                          child: GestureDetector(
                            onTap: _prev,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: const Center(child: Icon(Icons.arrow_back, color: Color(0xFF94A3B8), size: 20)),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: _current > 0 ? 2 : 1,
                        child: GestureDetector(
                          onTap: _next,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF22C55E)]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLast) const Icon(Icons.rocket_launch, color: Colors.black, size: 18),
                                if (isLast) const SizedBox(width: 6),
                                Text(
                                  isLast ? 'Get Started' : 'Next',
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontWeight: isLast ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: isLast ? 16 : 14,
                                  ),
                                ),
                                if (!isLast) const SizedBox(width: 4),
                                if (!isLast) const Icon(Icons.arrow_forward, color: Colors.black, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(_SlideData slide) {
    return SizedBox(
      key: ValueKey('ill_$_current'),
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow bg
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [slide.color.withValues(alpha: 0.2), Colors.transparent],
              ),
            ),
          ),
          // Rotating ring
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _ringCtrl.value * 2 * math.pi,
              child: child,
            ),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: slide.color.withValues(alpha: 0.15), width: 2),
              ),
            ),
          ),
          // Emoji
          Text(slide.emoji, style: const TextStyle(fontSize: 64)),
        ],
      ),
    );
  }

  Widget _buildOrbs(Color accentColor) {
    return Stack(
      children: [
        Positioned(top: -80, right: -60, child: _orb(250, accentColor.withValues(alpha: 0.12))),
        Positioned(bottom: 100, left: -40, child: _orb(200, const Color(0xFFFF7E40).withValues(alpha: 0.08))),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _SlideData {
  final String emoji;
  final String title;
  final String desc;
  final Color color;
  const _SlideData({required this.emoji, required this.title, required this.desc, required this.color});
}
