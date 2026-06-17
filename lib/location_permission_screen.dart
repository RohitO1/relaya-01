import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'services/location_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;
  const LocationPermissionScreen({super.key, required this.onPermissionGranted});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoading = false;
  String _errorMsg = '';

  Future<void> _requestLocation() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    final success = await locationService.fetchLiveLocation(forceReverseGeocode: true);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onPermissionGranted();
      } else {
        setState(() {
          _errorMsg = 'Location permission denied or GPS is turned off. Please enable location services to proceed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5F1F8), // Soft blue background
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Map Graphic
                      SizedBox(
                        height: 250,
                        width: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Container(
                                  color: const Color(0xFFD8EFDE), // Soft green map base
                                  // Add some abstract paths or simply use an icon overlay to represent a map
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 50, left: 20,
                                        child: _buildMapLine(100, 3, -0.5),
                                      ),
                                      Positioned(
                                        top: 150, right: 30,
                                        child: _buildMapLine(120, 2, 0.4),
                                      ),
                                      Positioned(
                                        bottom: 60, left: 40,
                                        child: _buildMapLine(80, 2, -0.2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Map Pins
                            Positioned(top: 20, right: 60, child: _buildPin(Icons.person, const Color(0xFF86B3D1))),
                            Positioned(top: 80, left: 20, child: _buildPin(Icons.face, const Color(0xFF86B3D1), size: 40)),
                            Positioned(bottom: 90, right: 40, child: _buildPin(Icons.sentiment_very_satisfied, const Color(0xFF86B3D1), size: 45)),
                            Positioned(bottom: 40, left: 60, child: _buildPin(Icons.person_2, const Color(0xFF86B3D1), size: 60)),
                            Center(child: _buildPin(Icons.my_location, const Color(0xFF0D5987), size: 50)),
                          ],
                        ),
                      ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 40),
                      
                      Text(
                        'Allow Relaya to use your location to find you matches',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'You won\'t be able to match with people otherwise',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8F9DA6),
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
                      
                      if (_errorMsg.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            _errorMsg,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ).animate().shakeX(),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              color: Colors.white,
              width: double.infinity,
              child: GestureDetector(
                onTap: _isLoading ? null : _requestLocation,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5987), // Deep blue
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Allow Location',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  Widget _buildPin(IconData icon, Color color, {double size = 50}) {
    return Container(
      width: size, height: size * 1.2,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds);
  }

  Widget _buildMapLine(double width, double height, double rotate) {
    return Transform.rotate(
      angle: rotate,
      child: Container(
        width: width, height: height,
        color: const Color(0xFFB1D8CB),
      ),
    );
  }
}
