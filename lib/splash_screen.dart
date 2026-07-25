import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _sequenceCtrl;

  late Animation<double> _slothOpacity;
  late Animation<double> _slothOffsetY;
  late Animation<double> _pawPopValue;
  late Animation<double> _textOpacity;
  late Animation<double> _winkScale;

  @override
  void initState() {
    super.initState();

    // Total sequence duration: 2.2 seconds for a fast, snappy cinematic feel
    _sequenceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    // Phase 1: Fade In (0ms to 800ms -> 0.0 to 0.23)
    _slothOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceCtrl,
        curve: const Interval(0.0, 0.23, curve: Curves.easeIn),
      ),
    );

    // Phase 2: Pop Up Head (1000ms to 1600ms -> 0.28 to 0.45)
    _slothOffsetY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(50.0), weight: 28),
      TweenSequenceItem(
          tween: Tween(begin: 50.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 17),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 55),
    ]).animate(_sequenceCtrl);

    // Phase 2b: Paws pop out and stick back
    _pawPopValue = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 48),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 5), // pop out
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 4), // hold
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 5), // stick back
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 38),
    ]).animate(_sequenceCtrl);

    // Text fades in (1300ms to 2000ms -> 0.37 to 0.57)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceCtrl,
        curve: const Interval(0.37, 0.57, curve: Curves.easeIn),
      ),
    );

    // Phase 3: Wink (2400ms to 2800ms -> 0.68 to 0.80)
    _winkScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 68), // Starts fully open (0 scale for eyelid)
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 4), // close
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 4), // hold closed
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 4), // open
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_sequenceCtrl);

    _sequenceCtrl.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _sequenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pure black background matching the storyboard
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Center(
        child: AnimatedBuilder(
          animation: _sequenceCtrl,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Container holding the sloth components
                Opacity(
                  opacity: _slothOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _slothOffsetY.value),
                    child: SizedBox(
                      width: 200,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Base Head
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/Sloth_Base_Head.png',
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const SizedBox(),
                            ),
                          ),

                          // Eyelids (Winking - clips right half so only left eyelid animates)
                          Positioned.fill(
                            child: ClipRect(
                              clipper: HalfClipper(),
                              child: Transform.scale(
                                scaleY: _winkScale.value,
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/images/Sloth_Eyelids.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const SizedBox(),
                                ),
                              ),
                            ),
                          ),
                          // Left Paw (Animating diagonally out from center)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(-4.0 * _pawPopValue.value, -8.0 * _pawPopValue.value),
                              child: Image.asset(
                                'assets/images/Sloth_Left_Paw.png',
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const SizedBox(),
                              ),
                            ),
                          ),

                          // Right Paw (Animating diagonally out from center)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(4.0 * _pawPopValue.value, -8.0 * _pawPopValue.value),
                              child: Image.asset(
                                'assets/images/Sloth_Right_Paw.png',
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const SizedBox(),
                              ),
                            ),
                          ),

                          // Hide the bottom edge of the sloth using a dark gradient/box
                          Positioned(
                            bottom: -20,
                            child: Container(
                              width: 220,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF030303).withValues(alpha: 0.0),
                                    const Color(0xFF030303),
                                    const Color(0xFF030303),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // RELAYA Text
                Opacity(
                  opacity: _textOpacity.value,
                  child: Column(
                    children: [
                      Text(
                        'RELAYA',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 10.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'WHERE CONNECTIONS BEGIN.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF8A00),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    // Only clip the left half of the image
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
