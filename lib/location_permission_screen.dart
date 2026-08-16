import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;
  const LocationPermissionScreen(
      {super.key, required this.onPermissionGranted});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with WidgetsBindingObserver {
  bool _isPrompting = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning to the app from settings, recheck location automatically
    if (state == AppLifecycleState.resumed && !_isPrompting) {
      _requestLocation();
    }
  }

  Future<void> _requestLocation() async {
    if (!mounted) return;
    setState(() {
      _isPrompting = true;
      _errorMsg = '';
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _isPrompting = false;
        _errorMsg =
            'GPS is disabled. Please turn it on in your device settings to proceed.';
      });
      return;
    }

    final success =
        await locationService.fetchLiveLocation(forceReverseGeocode: true);
    if (!mounted) return;

    if (success) {
      locationService.isLocationGrantedNotifier.value = true;
      widget.onPermissionGranted();
    } else {
      final p = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _isPrompting = false;
        if (p == LocationPermission.deniedForever) {
          _errorMsg =
              'Location permission is permanently denied. Please grant it from app settings.';
        } else {
          _errorMsg =
              'Please grant the location permission to access the core services of the app.';
        }
      });
    }
  }

  Future<void> _onAllowClicked() async {
    HapticFeedback.lightImpact();
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    } else if (!(await Geolocator.isLocationServiceEnabled())) {
      await Geolocator.openLocationSettings();
    } else {
      await _requestLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If waiting for the system prompt or checking, show a clean black slate (or minimal loader)
    if (_isPrompting) {
      return const Scaffold(
        backgroundColor: Color(0xFF060608),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B00),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Animated glowing icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A0C02),
                  border: Border.all(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFFF6B00),
                    size: 56,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              Text(
                'Location Required',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              Text(
                _errorMsg,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Core Call to Action
              GestureDetector(
                onTap: _onAllowClicked,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Allow Location Access',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
