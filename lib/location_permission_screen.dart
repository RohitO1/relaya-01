// ignore_for_file: use_build_context_synchronously
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'services/location_service.dart';
import 'services/doodle_theme.dart';
import 'widgets/location_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────
// In-memory flag — true for this process lifetime only.
// Clears on cold start (process kill), which is exactly what we want.
// ─────────────────────────────────────────────────────────────
class _LocationSession {
  static bool fetchedThisSession = false;
}

/// Call this to check whether location was already fetched in this session.
bool get locationFetchedThisSession => _LocationSession.fetchedThisSession;

/// Mark location as fetched for this session.
void markLocationFetchedThisSession() {
  _LocationSession.fetchedThisSession = true;
}

// ─────────────────────────────────────────────────────────────
// LOCATION GATE SCREEN
// ─────────────────────────────────────────────────────────────
class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;
  const LocationPermissionScreen({super.key, required this.onPermissionGranted});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

enum _GateState { idle, detecting, success, error }

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with TickerProviderStateMixin {
  _GateState _state = _GateState.idle;
  String _detectedCity = '';
  String _errorMsg = '';

  late AnimationController _pulseCtrl;
  late AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _state = _GateState.detecting;
      _errorMsg = '';
    });

    final success = await locationService.fetchLiveLocation(forceReverseGeocode: true);

    if (!mounted) return;

    if (success) {
      final city = locationService.activeDistrict.isNotEmpty
          ? locationService.activeDistrict
          : locationService.activeLocation.split(',').first.trim();
      setState(() {
        _state = _GateState.success;
        _detectedCity = city.isNotEmpty ? city : 'Your Location';
      });
      HapticFeedback.heavyImpact();
      // Brief success pause before proceeding
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      markLocationFetchedThisSession();
      widget.onPermissionGranted();
    } else {
      setState(() {
        _state = _GateState.error;
        _errorMsg = 'Location access denied or GPS is off.\nYou can set it manually below.';
      });
    }
  }

  void _skipWithManual() async {
    HapticFeedback.lightImpact();
    showLocationSearchSheet(context);
    // Give the sheet time to close before checking state
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // If user picked a location from the picker, proceed
    if (locationService.activeDistrict.isNotEmpty &&
        locationService.activeDistrict != 'Unknown') {
      markLocationFetchedThisSession();
      widget.onPermissionGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final doodle = isDoodleMode(context);

    return Scaffold(
      backgroundColor: doodle ? DoodleColors.cream : const Color(0xFF060608),
      body: Stack(
        children: [
          // ── Ambient orbs (dark mode only) ──
          if (!doodle) _buildAmbientOrbs(size),

          // ── Doodle bg (light mode only) ──
          if (doodle)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ScatteredDoodlesPainter(
                    seed: 99, density: 0.25, color: const Color(0x18B8956E)),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // ── Central illustration ──
                _buildCentralIllustration(doodle),

                const SizedBox(height: 40),

                // ── Title ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    _state == _GateState.success
                        ? '📍 $_detectedCity'
                        : 'Where are you?',
                    textAlign: TextAlign.center,
                    style: doodle
                        ? DoodleFonts.heading(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: DoodleColors.textPrimary,
                          )
                        : GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                  ).animate(key: ValueKey(_state)).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                ),

                const SizedBox(height: 14),

                // ── Subtitle ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _state == _GateState.success
                        ? 'Your feed, people, events & rooms are all set for $_detectedCity'
                        : _state == _GateState.detecting
                            ? 'Detecting your location…'
                            : 'Relaya uses your location to show you people, events, rooms, and communities nearby.',
                    textAlign: TextAlign.center,
                    style: doodle
                        ? DoodleFonts.body(
                            fontSize: 15,
                            color: DoodleColors.textSecondary,
                          )
                        : GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.white60,
                            height: 1.5,
                          ),
                  ).animate(key: ValueKey('sub$_state')).fadeIn(duration: 400.ms),
                ),

                // ── Error message ──
                if (_state == _GateState.error && _errorMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, left: 36, right: 36),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMsg,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.redAccent.shade100,
                        ),
                      ),
                    ),
                  ).animate().shakeX(amount: 4),

                const Spacer(),

                // ── Buttons ──
                _buildButtons(doodle),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientOrbs(Size size) {
    return AnimatedBuilder(
      animation: _orbCtrl,
      builder: (_, __) {
        final t = _orbCtrl.value;
        return Stack(
          children: [
            Positioned(
              top: size.height * 0.1 + 30 * math.sin(t * math.pi * 2),
              left: -60 + 20 * math.cos(t * math.pi * 2),
              child: _glowOrb(280, const Color(0xFFFF5C00), 0.07),
            ),
            Positioned(
              bottom: size.height * 0.1 + 40 * math.cos(t * math.pi * 2),
              right: -80 + 30 * math.sin(t * math.pi * 2),
              child: _glowOrb(360, const Color(0xFFFF8A00), 0.05),
            ),
            Positioned(
              top: size.height * 0.45,
              right: 60 + 20 * math.sin(t * math.pi * 2),
              child: _glowOrb(120, const Color(0xFFFF6B00), 0.06),
            ),
          ],
        );
      },
    );
  }

  Widget _glowOrb(double diameter, Color color, double alpha) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildCentralIllustration(bool doodle) {
    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final t = _pulseCtrl.value;
                final scale = 0.6 + (i * 0.15) + t * 0.1;
                final opacity = (0.3 - i * 0.08 + t * 0.1).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: doodle
                              ? DoodleColors.orange.withValues(alpha: 0.3)
                              : const Color(0xFFFF6B00).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Core circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: doodle
                  ? LinearGradient(
                      colors: [
                        DoodleColors.orange.withValues(alpha: 0.15),
                        DoodleColors.amber.withValues(alpha: 0.08),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        const Color(0xFFFF3D00).withValues(alpha: 0.1),
                      ],
                    ),
              border: Border.all(
                color: doodle
                    ? DoodleColors.orange.withValues(alpha: 0.4)
                    : const Color(0xFFFF6B00).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: _state == _GateState.success
                ? Icon(
                    Icons.check_circle_rounded,
                    size: 60,
                    color: doodle ? DoodleColors.orange : const Color(0xFFFF6B00),
                  ).animate().scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        curve: Curves.elasticOut,
                        duration: 600.ms,
                      )
                : _state == _GateState.detecting
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: doodle
                              ? DoodleColors.orange
                              : const Color(0xFFFF6B00),
                        ),
                      )
                    : Icon(
                        Icons.location_on_rounded,
                        size: 60,
                        color: doodle
                            ? DoodleColors.orange
                            : const Color(0xFFFF6B00),
                      ).animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        ).scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.05, 1.05),
                          duration: 2.seconds,
                          curve: Curves.easeInOut,
                        ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(bool doodle) {
    if (_state == _GateState.success) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Let\'s go!',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ).animate().scale(
              begin: const Offset(0.9, 0.9),
              curve: Curves.elasticOut,
              duration: 500.ms,
            ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Primary: Allow location
          GestureDetector(
            onTap: _state == _GateState.detecting ? null : _requestLocation,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: doodle
                  ? BoxDecoration(
                      color: DoodleColors.orange,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: DoodleColors.orangeDark, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: DoodleColors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    )
                  : BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
              child: Center(
                child: _state == _GateState.detecting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _state == _GateState.error
                                ? 'Try Again'
                                : 'Use My Location',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Secondary: Set manually
          GestureDetector(
            onTap: _state == _GateState.detecting ? null : _skipWithManual,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: doodle
                  ? BoxDecoration(
                      color: DoodleColors.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: DoodleColors.sketchLine, width: 1.5),
                    )
                  : BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
              child: Center(
                child: Text(
                  'Set City Manually',
                  style: doodle
                      ? DoodleFonts.body(
                          color: DoodleColors.textSecondary,
                          fontSize: 15,
                        ).copyWith(fontWeight: FontWeight.w600)
                      : GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }
}
