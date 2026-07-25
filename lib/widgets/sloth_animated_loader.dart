import 'package:flutter/material.dart';

class SlothAnimatedLoader extends StatefulWidget {
  final double size;

  const SlothAnimatedLoader({super.key, this.size = 160});

  @override
  State<SlothAnimatedLoader> createState() => _SlothAnimatedLoaderState();
}

class _SlothAnimatedLoaderState extends State<SlothAnimatedLoader>
    with TickerProviderStateMixin {
  late final AnimationController _gazeCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _breathCtrl;

  late final Animation<double> _gazeX;
  late final Animation<double> _gazeY;
  late final Animation<double> _blinkL;
  late final Animation<double> _blinkR;
  late final Animation<double> _breathScale;

  @override
  void initState() {
    super.initState();

    // ── Breathing Controller (Continuous subtle scale in/out) ──
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _breathScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOutSine),
    );

    // ── Gaze Controller – 6s Cinematic Look Cycle ──
    _gazeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _gazeX = TweenSequence<double>([
      // Centre to Left
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(-1.0), weight: 15),
      // Left to Right
      TweenSequenceItem(tween: Tween(begin: -1.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
      // Right to Centre
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    ]).animate(_gazeCtrl);

    _gazeY = TweenSequence<double>([
      // Look slightly down when traversing
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(6.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 6.0).chain(CurveTween(curve: Curves.linear)), weight: 25),
      TweenSequenceItem(tween: ConstantTween(6.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    ]).animate(_gazeCtrl);

    // ── Blink Controller (Triggered occasionally) ──
    // A cinematic sloth blink is slow and deliberate.
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _blinkL = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 45),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 45),
    ]).animate(_blinkCtrl);

    // Right eyelid has a tiny delay for realism
    _blinkR = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 45),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 35),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
    ]).animate(_blinkCtrl);

    _gazeCtrl.addListener(() {
      // Trigger slow blink near the end of the cycle
      if (_gazeCtrl.value > 0.85 && _gazeCtrl.value < 0.87) {
        if (!_blinkCtrl.isAnimating) _blinkCtrl.forward(from: 0.0);
      }
      // Occasional double blink around the left gaze
      if (_gazeCtrl.value > 0.20 && _gazeCtrl.value < 0.22) {
        if (!_blinkCtrl.isAnimating) _blinkCtrl.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _gazeCtrl.dispose();
    _blinkCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double canvasW = 553.0;
    const double canvasH = 408.0;
    final double widgetH = widget.size * (canvasH / canvasW);

    return SizedBox(
      width: widget.size,
      height: widgetH,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: canvasW,
          height: canvasH,
          child: AnimatedBuilder(
            animation: Listenable.merge([_gazeCtrl, _blinkCtrl, _breathCtrl]),
            builder: (context, _) {
              const double maxDx = 25.0; 
              final double dx = _gazeX.value * maxDx;
              final double dy = _gazeY.value;

              return Transform.scale(
                scale: _breathScale.value,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset('assets/images/Relaya_Base_Head_EmptyEyes.png', fit: BoxFit.fill),
                    ),
                    Positioned(
                      left: 159 + dx,
                      top: 200 + dy,
                      child: Image.asset('assets/images/Relaya_Iris_Left.png'),
                    ),
                    Positioned(
                      left: 319 + dx,
                      top: 195 + dy,
                      child: Image.asset('assets/images/Relaya_Iris_Right.png'),
                    ),
                    Positioned(
                      left: 129,
                      top: 120,
                      child: Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.identity()..scale(1.0, _blinkL.value == 0.0 ? 0.001 : _blinkL.value),
                        child: Image.asset('assets/images/Relaya_Eyelid_Left.png'),
                      ),
                    ),
                    Positioned(
                      left: 287,
                      top: 110,
                      child: Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.identity()..scale(1.0, _blinkR.value == 0.0 ? 0.001 : _blinkR.value),
                        child: Image.asset('assets/images/Relaya_Eyelid_Right.png'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
