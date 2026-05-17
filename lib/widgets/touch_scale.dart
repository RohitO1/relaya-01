import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TouchScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;
  final bool enableHaptic; // Optionally add haptic feedback on press

  const TouchScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.95,
    this.enableHaptic = true,
  });

  @override
  State<TouchScale> createState() => _TouchScaleState();
}

class _TouchScaleState extends State<TouchScale> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
