import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/location_service.dart';
import 'widgets/location_picker_sheet.dart';

class _LocationSession {
  static bool fetchedThisSession = false;
}

bool get locationFetchedThisSession => _LocationSession.fetchedThisSession;
void markLocationFetchedThisSession() {
  _LocationSession.fetchedThisSession = true;
}

class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;
  const LocationPermissionScreen({super.key, required this.onPermissionGranted});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isDetecting = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocation();
    });
  }

  Future<void> _requestLocation() async {
    setState(() {
      _isDetecting = true;
      _errorMsg = '';
    });

    final success = await locationService.fetchLiveLocation(forceReverseGeocode: true);

    if (!mounted) return;

    if (success) {
      HapticFeedback.heavyImpact();
      markLocationFetchedThisSession();
      widget.onPermissionGranted();
    } else {
      setState(() {
        _isDetecting = false;
        _errorMsg = 'Location access denied or GPS is off.\nPlease allow location to continue.';
      });
    }
  }

  void _skipWithManual() async {
    await showLocationSearchSheet(context);
    if (!mounted) return;
    if (locationService.activeDistrict.isNotEmpty &&
        locationService.activeDistrict != 'Unknown') {
      markLocationFetchedThisSession();
      widget.onPermissionGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: Center(
        child: _isDetecting
            ? const CircularProgressIndicator(color: Color(0xFFFF6B00))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMsg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _requestLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Try Again', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _skipWithManual,
                      child: Text('Set City Manually', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
