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
  late Animation<double> _textScale;
  late Animation<double> _blinkScale;

  @override
  void initState() {
    super.initState();

    // Cinematic 3.5 second sequence
    _sequenceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));

    // Phase 1: Fade In Head (0% - 15% -> 0 to 525ms)
    _slothOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceCtrl,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    // Phase 2: Rise up (15% - 40% -> 525 to 1400ms)
    _slothOffsetY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(50.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 50.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 25),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
    ]).animate(_sequenceCtrl);

    // Phase 3: Eyelids open smoothly, then hold, then cinematic blink
    _blinkScale = TweenSequence<double>([
      // 0 - 35%: Closed (value = 1.0)
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      // 35 - 45%: Eyelids slowly open (1.0 -> 0.0)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 10),
      // 45 - 80%: Hold open (value = 0.0)
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 35),
      // 80 - 86%: Close for blink
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 6),
      // 86 - 92%: Open from blink
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 6),
      // 92 - 100%: Hold open
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 8),
    ]).animate(_sequenceCtrl);

    // Phase 4: Paws slowly reach out
    _pawPopValue = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 45), // Wait for eyes to open
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
    ]).animate(_sequenceCtrl);

    // Phase 5: Text fades in & scales up slightly
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceCtrl,
        curve: const Interval(0.55, 0.75, curve: Curves.easeIn),
      ),
    );
    _textScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _sequenceCtrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _sequenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Center(
        child: AnimatedBuilder(
          animation: _sequenceCtrl,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                              Positioned.fill(
                                child: Image.asset('assets/images/Relaya_Base_Head_EmptyEyes.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox()),
                              ),
                              Positioned(
                                left: 159,
                                top: 200,
                                child: Image.asset('assets/images/Relaya_Iris_Left.png'),
                              ),
                              Positioned(
                                left: 319,
                                top: 195,
                                child: Image.asset('assets/images/Relaya_Iris_Right.png'),
                              ),
                              Positioned(
                                left: 129,
                                top: 120,
                                child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()..scale(1.0, _blinkScale.value == 0.0 ? 0.001 : _blinkScale.value),
                                  child: Image.asset('assets/images/Relaya_Eyelid_Left.png'),
                                ),
                              ),
                              Positioned(
                                left: 287,
                                top: 110,
                                child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()..scale(1.0, _blinkScale.value == 0.0 ? 0.001 : _blinkScale.value),
                                  child: Image.asset('assets/images/Relaya_Eyelid_Right.png'),
                                ),
                              ),
                              // Cinematic gentle reach: paws slide from center slightly out and up to cradle the body
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(-22.0 * _pawPopValue.value, -30.0 * _pawPopValue.value),
                                  child: Image.asset('assets/images/Sloth_Left_Paw.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox()),
                                ),
                              ),
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: Offset(22.0 * _pawPopValue.value, -30.0 * _pawPopValue.value),
                                  child: Image.asset('assets/images/Sloth_Right_Paw.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox()),
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
                Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.scale(
                    scale: _textScale.value,
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
