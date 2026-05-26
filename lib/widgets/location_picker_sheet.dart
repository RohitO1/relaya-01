// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';

/// A unified, search-driven location picker bottom sheet.
/// Replaces all hardcoded city lists across the app.
///
/// Usage:
/// ```dart
/// showLocationSearchSheet(context);
/// ```
void showLocationSearchSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationSearchSheet(),
  );
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();
  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _fetchingGps = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (val.trim().length < 2) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final results = await locationService.searchLocations(val);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    });
  }

  void _selectLocation(String name, double lat, double lng, {String? district, String? state}) {
    locationService.setLocation(name, lat: lat, lng: lng, district: district, state: state);
    
    final finalDistrict = district ?? (name.split(',').first.trim());
    final finalState = state ?? (name.split(',').length > 1 ? name.split(',')[1].trim() : '');

    // Also save coordinates to Supabase profiles for radius-based rush-in targeting
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      Supabase.instance.client.from('profiles').update({
        'lat': lat,
        'lng': lng,
        'city': name,
        'district': finalDistrict,
        'state': finalState,
      }).eq('id', uid).then((_) {
        debugPrint('Profile location updated: $name ($lat, $lng)');
      }).catchError((e) {
        debugPrint('Failed to update profile location: $e');
      });
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Location set to $name', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFFFF6B00),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _fetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please enable location services'), backgroundColor: Colors.red.shade700),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _fetchingGps = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _fetchingGps = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Reverse geocode to get a human-readable name
      String locationName = 'My Location';
      String? gpsDistrict;
      String? gpsState;
      try {
        final results = await locationService.searchLocations(
          '${position.latitude},${position.longitude}',
        );
        if (results.isNotEmpty) {
          locationName = results.first['name'] ?? 'My Location';
          gpsDistrict = results.first['district'];
          gpsState = results.first['state'];
        }
      } catch (_) {}

      _selectLocation(locationName, position.latitude, position.longitude, district: gpsDistrict, state: gpsState);
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentLoc = locationService.activeLocation;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.explore, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discovery Location', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      if (currentLoc.isNotEmpty)
                        Text('Currently: $currentLoc', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFF6B00))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFFF6B00), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search any city, district, or landmark...',
                        hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searching)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00))),
                  if (_searchCtrl.text.isNotEmpty && !_searching)
                    GestureDetector(
                      onTap: () { _searchCtrl.clear(); setState(() => _results = []); },
                      child: const Icon(Icons.close, color: Colors.white38, size: 18),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Use Current Location button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _fetchingGps ? null : _useCurrentLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFF6B00).withValues(alpha: 0.1), const Color(0xFF3B82F6).withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    _fetchingGps
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)))
                        : const Icon(Icons.my_location, color: Color(0xFFFF6B00), size: 20),
                    const SizedBox(width: 12),
                    Text('Use My Current Location', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B00))),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFFFF6B00), size: 14),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Dynamic content: search results OR popular cities
          Flexible(
            child: _results.isNotEmpty
                ? _buildSearchResults()
                : _searchCtrl.text.isEmpty
                    ? _buildPopularCities()
                    : _searching
                        ? const SizedBox.shrink()
                        : _buildNoResults(),
          ),

          SizedBox(height: bottomInset > 0 ? bottomInset : 20),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
      itemBuilder: (ctx, i) {
        final r = _results[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 18),
          ),
          title: Text(r['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(r['full_name'] ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          onTap: () => _selectLocation(r['name'], r['lat'], r['lng'], district: r['district'], state: r['state']),
        );
      },
    );
  }

  Widget _buildPopularCities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'POPULAR CITIES',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white30),
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: LocationService.popularCities.length,
            itemBuilder: (ctx, i) {
              final city = LocationService.popularCities[i];
              final isActive = locationService.activeLocation == city['name'];
              return GestureDetector(
                onTap: () => _selectLocation(city['name'], city['lat'], city['lng']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isActive ? const Color(0xFFFF6B00).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_city, size: 18, color: isActive ? const Color(0xFFFF6B00) : Colors.white38),
                      const SizedBox(width: 12),
                      Text(city['name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFFFF6B00) : Colors.white70)),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFFFF6B00))),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text('No locations found', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Try a different search term', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}
