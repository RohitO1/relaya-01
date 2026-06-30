import 'package:flutter/material.dart';

class TiltableHeroSection extends StatefulWidget {
  final Widget child;

  const TiltableHeroSection({super.key, required this.child});

  @override
  State<TiltableHeroSection> createState() => _TiltableHeroSectionState();
}

class _TiltableHeroSectionState extends State<TiltableHeroSection> {
  double _rx = 0.0;
  double _ry = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _rx -= details.delta.dy * 0.01;
          _ry += details.delta.dx * 0.01;
          // Clamp the rotation
          _rx = _rx.clamp(-0.2, 0.2);
          _ry = _ry.clamp(-0.2, 0.2);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _rx = 0.0;
          _ry = 0.0;
        });
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: _rx),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, rx, child) {
          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: _ry),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, ry, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateX(rx)
                  ..rotateY(ry),
                alignment: FractionalOffset.center,
                child: widget.child,
              );
            },
          );
        },
      ),
    );
  }
}
