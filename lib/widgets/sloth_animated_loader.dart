import 'package:flutter/material.dart';

/// Premium animated Sloth face loader.
///
/// Uses separate PNG layers placed at their exact canvas coordinates
/// (canvas size 553 × 408):
///   • Base_Head_EmptyEyes  –  Positioned.fill (full canvas)
///   • Iris_Left            –  (159, 200)  68×68
///   • Iris_Right           –  (319, 195)  68×68
///   • Eyelid_Left          –  (129, 120)  134×124
///   • Eyelid_Right         –  (287, 110)  135×129
///
/// Animation loop:
///   1. Eyes glide left  (easeInOutSine)
///   2. Pause briefly
///   3. Eyes glide right (easeInOutSine)
///   4. Eyes return to centre
///   5. Subtle blink (both eyelids scale-Y close then open)
///   Repeat forever.
class SlothAnimatedLoader extends StatefulWidget {
  final double size;

  const SlothAnimatedLoader({super.key, this.size = 160});

  @override
  State<SlothAnimatedLoader> createState() => _SlothAnimatedLoaderState();
}

class _SlothAnimatedLoaderState extends State<SlothAnimatedLoader>
    with TickerProviderStateMixin {
  // Horizontal eye-travel animation
  late final AnimationController _gazeCtrl;
  // Blink animation (runs periodically, separate from gaze)
  late final AnimationController _blinkCtrl;

  late final Animation<double> _gazeX;    // –1 … +1
  late final Animation<double> _gazeY;    // slight arc
  late final Animation<double> _blinkL;   // 0 open … 1 closed
  late final Animation<double> _blinkR;   // same, tiny offset for realism

  @override
  void initState() {
    super.initState();

    // ── Gaze controller – 2.8 s per cycle (look left → centre → right → centre) ──
    _gazeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // Eyes travel in a smooth S-curve: left, pause, right, pause, centre
    _gazeX = TweenSequence<double>([
      // Glide left
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      // Hold left
      TweenSequenceItem(tween: ConstantTween(-1.0), weight: 8),
      // Glide right
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25,
      ),
      // Hold right
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 8),
      // Return centre
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      // Pause at centre (before blink window)
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 23),
    ]).animate(_gazeCtrl);

    // Slight arc: irises dip very slightly when at extremes
    _gazeY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 5.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(5.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: 5.0, end: 5.0).chain(CurveTween(curve: Curves.linear)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(5.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: 5.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 23),
    ]).animate(_gazeCtrl);

    // ── Blink controller – 400 ms, triggers in last 25% of gaze cycle ──
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Left eyelid: scaleY 0→1→0
    _blinkL = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(_blinkCtrl);

    // Right eyelid: same shape, 30 ms delay gives naturalistic feel
    _blinkR = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 8),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 18),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 4),
    ]).animate(_blinkCtrl);

    // Trigger a blink whenever the gaze cycle enters its last quarter
    _gazeCtrl.addListener(() {
      if (_gazeCtrl.value >= 0.76 && _gazeCtrl.value <= 0.78) {
        if (!_blinkCtrl.isAnimating) {
          _blinkCtrl.forward(from: 0.0);
        }
      }
    });
  }

  @override
  void dispose() {
    _gazeCtrl.dispose();
    _blinkCtrl.dispose();
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
            animation: Listenable.merge([_gazeCtrl, _blinkCtrl]),
            builder: (context, _) {
              const double maxDx = 22.0; // pixels on 553-wide canvas
              final double dx = _gazeX.value * maxDx;
              final double dy = _gazeY.value;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Base Head ──────────────────────────────────────────────
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/Relaya_Base_Head_EmptyEyes.png',
                      fit: BoxFit.fill,
                    ),
                  ),

                  // ── Left Iris (159, 200) 68×68 ─────────────────────────────
                  Positioned(
                    left: 159 + dx,
                    top: 200 + dy,
                    width: 68,
                    height: 68,
                    child: Image.asset('assets/images/Relaya_Iris_Left.png'),
                  ),

                  // ── Right Iris (319, 195) 68×68 ────────────────────────────
                  Positioned(
                    left: 319 + dx,
                    top: 195 + dy,
                    width: 68,
                    height: 68,
                    child: Image.asset('assets/images/Relaya_Iris_Right.png'),
                  ),

                  // ── Left Eyelid (129, 120) 134×124 ─────────────────────────
                  Positioned(
                    left: 129,
                    top: 120,
                    width: 134,
                    height: 124,
                    child: Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.identity()
                        ..scale(1.0, 1.0 - _blinkL.value),
                      child: Image.asset('assets/images/Relaya_Eyelid_Left.png'),
                    ),
                  ),

                  // ── Right Eyelid (287, 110) 135×129 ────────────────────────
                  Positioned(
                    left: 287,
                    top: 110,
                    width: 135,
                    height: 129,
                    child: Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.identity()
                        ..scale(1.0, 1.0 - _blinkR.value),
                      child: Image.asset('assets/images/Relaya_Eyelid_Right.png'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
