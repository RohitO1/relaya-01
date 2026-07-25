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
  late Animation<double> _blinkScale;

  @override
  void initState() {
    super.initState();

    // Total sequence duration: 1800ms for a fast, snappy cinematic feel
    _sequenceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

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

    // Phase 3: Blink (both eyelids close and open)
    _blinkScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 68), // Starts fully open
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
                      width: 203,
                      height: 150,
                      child: FittedBox(
                        child: SizedBox(
                          width: 553,
                          height: 408,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Base Head
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/Relaya_Base_Head_EmptyEyes.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const SizedBox(),
                                ),
                              ),

                              // Left Iris
                              Positioned(
                                left: 159,
                                top: 200,
                                child: Image.asset('assets/images/Relaya_Iris_Left.png'),
                              ),

                              // Right Iris
                              Positioned(
                                left: 319,
                                top: 195,
                                child: Image.asset('assets/images/Relaya_Iris_Right.png'),
                              ),

                              // Left Eyelid (Blinking)
                              Positioned(
                                left: 129,
                                top: 120,
                                child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()..scale(1.0, 1.0 - _blinkScale.value),
                                  child: Image.asset('assets/images/Relaya_Eyelid_Left.png'),
                                ),
                              ),

                              // Right Eyelid (Blinking)
                              Positioned(
                                left: 287,
                                top: 110,
                                child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()..scale(1.0, 1.0 - _blinkScale.value),
                                  child: Image.asset('assets/images/Relaya_Eyelid_Right.png'),
                                ),
                              ),

                              // Left Paw (Pops out and sticks back)
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(-12.0 * _pawPopValue.value, -20.0 * _pawPopValue.value),
                                  child: Image.asset(
                                    'assets/images/Sloth_Left_Paw.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const SizedBox(),
                                  ),
                                ),
                              ),

                              // Right Paw (Pops out and sticks back)
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(12.0 * _pawPopValue.value, -20.0 * _pawPopValue.value),
                                  child: Image.asset(
                                    'assets/images/Sloth_Right_Paw.png',

                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const SizedBox(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

