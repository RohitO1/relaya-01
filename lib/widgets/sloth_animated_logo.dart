import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SlothAnimatedLogo extends StatefulWidget {
  final bool isSignUpMode;

  const SlothAnimatedLogo({
    super.key,
    required this.isSignUpMode,
  });

  @override
  State<SlothAnimatedLogo> createState() => _SlothAnimatedLogoState();
}

class _SlothAnimatedLogoState extends State<SlothAnimatedLogo> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnim;
  Timer? _blinkTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // ── Blink Animation ──
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    // 1.0 = open, 0.0 = closed
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    if (!mounted) return;
    final delay = 3 + _random.nextInt(3); // Random 3 to 5 seconds
    _blinkTimer = Timer(Duration(seconds: delay), () async {
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
      _scheduleNextBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The sloth images are all on the SAME pre-aligned 553x408 transparent canvas.
    // They must all be stacked at the exact same size with BoxFit.contain.
    // ANY translation or rotation breaks the alignment. Only the eyelids blink.
    return SizedBox(
      width: 220,
      height: 165,
      child: AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          return Stack(
            children: [
              // Layer 1: Base Head (foundation)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Sloth_Base_Head.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox(),
                ),
              ),

              // Layer 2: Left Paw (static, pre-aligned on canvas)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Sloth_Left_Paw.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox(),
                ),
              ),

              // Layer 3: Right Paw (static, pre-aligned on canvas)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Sloth_Right_Paw.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox(),
                ),
              ),

              // Layer 4: Eyelids — ONLY these blink (scaleY on center)
              Positioned.fill(
                child: Transform.scale(
                  scaleY: _blinkAnim.value,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/Sloth_Eyelids.png',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const SizedBox(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
