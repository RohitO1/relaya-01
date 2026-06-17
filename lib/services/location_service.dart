import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final ValueNotifier<String> activeLocationNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> activeDistrictNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> activeStateNotifier = ValueNotifier<String>('');
  
  // Coordinate State Tracking
  double? _activeLat;
  double? _activeLng;
  double? get activeLat => _activeLat;
  double? get activeLng => _activeLng;
  
  // Listeners can attach to this if they care specifically when the MAP coordinates change
  final ValueNotifier<int> coordinatesUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLocationGrantedNotifier = ValueNotifier<bool>(false);

  String get activeLocation => activeLocationNotifier.value;
  String get activeDistrict => activeDistrictNotifier.value;
  String get activeState => activeStateNotifier.value;

  /// Popular cities shown below the search bar for quick access
  static const List<Map<String, dynamic>> popularCities = [
    {'name': 'Mumbai', 'lat': 19.0760, 'lng': 72.8777},
    {'name': 'Delhi NCR', 'lat': 28.7041, 'lng': 77.1025},
    {'name': 'Bangalore', 'lat': 12.9716, 'lng': 77.5946},
    {'name': 'Hyderabad', 'lat': 17.3850, 'lng': 78.4867},
    {'name': 'Chennai', 'lat': 13.0827, 'lng': 80.2707},
    {'name': 'Kolkata', 'lat': 22.5726, 'lng': 88.3639},
    {'name': 'Pune', 'lat': 18.5204, 'lng': 73.8567},
    {'name': 'Jaipur', 'lat': 26.9124, 'lng': 75.7873},
    {'name': 'Lucknow', 'lat': 26.8467, 'lng': 80.9462},
    {'name': 'Ahmedabad', 'lat': 23.0225, 'lng': 72.5714},
    {'name': 'Chandigarh', 'lat': 30.7333, 'lng': 76.7794},
    {'name': 'Indore', 'lat': 22.7196, 'lng': 75.8577},
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we explicitly saved map coordinates first
    if (prefs.containsKey('current_map_lat') && prefs.containsKey('current_map_lng')) {
      _activeLat = prefs.getDouble('current_map_lat');
      _activeLng = prefs.getDouble('current_map_lng');
      final savedName = prefs.getString('current_map_name') ?? 'Map Location';
      activeLocationNotifier.value = savedName;
      activeDistrictNotifier.value = prefs.getString('current_map_district') ?? (savedName.split(',').first.trim());
      activeStateNotifier.value = prefs.getString('current_map_state') ?? (savedName.split(',').length > 1 ? savedName.split(',')[1].trim() : '');
    } else {
      // First try to grab saved locations from old array format
      final savedLocRaw = prefs.getString('saved_locations');
      if (savedLocRaw != null && savedLocRaw.isNotEmpty) {
        try {
          final List<dynamic> locList = jsonDecode(savedLocRaw);
          if (locList.isNotEmpty) {
            final firstLoc = locList.first;
            final nameStr = firstLoc['name']?.toString() ?? '';
            activeLocationNotifier.value = nameStr;
            activeDistrictNotifier.value = nameStr.split(',').first.trim();
            activeStateNotifier.value = nameStr.split(',').length > 1 ? nameStr.split(',')[1].trim() : '';
            _activeLat = (firstLoc['lat'] as num?)?.toDouble();
            _activeLng = (firstLoc['lng'] as num?)?.toDouble();
          }
        } catch (e) {
          debugPrint('LocationService Error: $e');
        }
      }
    }
    
    // Check if permission is already granted and auto-fetch
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        // Run in background without blocking init
        fetchLiveLocation(forceReverseGeocode: false).catchError((e) { debugPrint('Auto-fetch error: $e'); return false; });
      }
    }
    
    coordinatesUpdateNotifier.value++;
  }

  String sanitizeDistrict(String rawDistrict, String fullName) {
    String d = rawDistrict.trim();
    final invalidWords = ['institute', 'engineering', 'technology', 'university', 'college', 'school', 'hospital', 'station', 'airport', 'park', 'road', 'street', 'building', 'apartment', 'nagar', 'sector', 'colony', 'shop', 'mall', 'hotel', 'temple', 'house', 'office'];
    
    bool isInvalid = d.isEmpty || d.length > 25 || invalidWords.any((w) => d.toLowerCase().contains(w));
    
    if (isInvalid && fullName.isNotEmpty) {
      final parts = fullName.split(',').map((p) => p.trim()).toList();
      for (final p in parts) {
        if (p.isNotEmpty && p.length <= 25 && !invalidWords.any((w) => p.toLowerCase().contains(w))) {
          if (RegExp(r'^\d+$').hasMatch(p)) continue;
          if (p.toLowerCase() == 'india') continue;
          return p;
        }
      }
    }
    return d.isEmpty ? 'Unknown' : d;
  }

  /// Search for locations using Nominatim (OpenStreetMap) API.
  /// Returns a list of results with 'name', 'full_name', 'district', 'state', 'lat', 'lng'.
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=8&addressdetails=1&countrycodes=in',
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'MeetraApp/1.0 (contact@meetra.app)',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        return data.map<Map<String, dynamic>>((it) {
          final displayName = it['display_name']?.toString() ?? '';
          final addr = it['address'] as Map<String, dynamic>? ?? {};
          final rawDistrict = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? addr['county'] ?? addr['state_district'] ?? addr['district'] ?? '';
          final district = sanitizeDistrict(rawDistrict.toString(), displayName);
          final state = addr['state'] ?? '';
          return {
            'name': displayName.split(',').first.trim(),
            'full_name': displayName,
            'district': district,
            'state': state.toString().trim(),
            'lat': double.tryParse(it['lat']?.toString() ?? '') ?? 0.0,
            'lng': double.tryParse(it['lon']?.toString() ?? '') ?? 0.0,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('LocationService search error: $e');
    }
    return [];
  }

  /// Returns a Map containing minLat, maxLat, minLng, maxLng based on the current location and user Match Radius.
  /// Used for efficient Bounding Box queries in Supabase.
  Future<Map<String, double>?> getBoundingBoxAsync() async {
    if (_activeLat == null || _activeLng == null) return null;
    
    final prefs = await SharedPreferences.getInstance();
    // Default to 50km if match radius isn't set
    final radiusKm = prefs.getDouble('matchRadius') ?? 50.0;
    
    // Rough approximation: 1 degree of latitude is ~111 kilometers
    final latOffset = radiusKm / 111.0;
    
    // Longitude offset scales with latitude (cos function)
    final lngOffset = radiusKm / (111.0 * cos(_activeLat! * pi / 180.0));
    
    return {
      'minLat': _activeLat! - latOffset,
      'maxLat': _activeLat! + latOffset,
      'minLng': _activeLng! - lngOffset,
      'maxLng': _activeLng! + lngOffset,
    };
  }

  void setLocation(String newLocation, {double? lat, double? lng, String? district, String? state}) async {
    _activeLat = lat ?? _activeLat;
    _activeLng = lng ?? _activeLng;
    
    if (activeLocationNotifier.value != newLocation) {
      activeLocationNotifier.value = newLocation;
    }
    
    final rawDistrict = district ?? (newLocation.split(',').first.trim());
    final finalDistrict = sanitizeDistrict(rawDistrict, newLocation);
    final finalState = state ?? (newLocation.split(',').length > 1 ? newLocation.split(',')[1].trim() : '');
    
    activeDistrictNotifier.value = finalDistrict;
    activeStateNotifier.value = finalState;
    
    if (lat != null && lng != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('current_map_lat', lat);
      await prefs.setDouble('current_map_lng', lng);
      await prefs.setString('current_map_name', newLocation);
      await prefs.setString('current_map_district', finalDistrict);
      await prefs.setString('current_map_state', finalState);
      coordinatesUpdateNotifier.value++;

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        try {
          await Supabase.instance.client.from('profiles').update({
            'lat': lat,
            'lng': lng,
            'city': finalDistrict,
          }).eq('id', uid);
          debugPrint('LocationService: Instantly synced new location ($finalDistrict) to DB');
        } catch (_) {}
      }
    }
  }

  /// Syncs the cached location to the database if live GPS is unavailable.
  Future<void> syncCachedLocationToDb() async {
    if (_activeLat == null || _activeLng == null) return;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final currentCity = activeDistrictNotifier.value.isNotEmpty ? activeDistrictNotifier.value : 'Unknown';
      await Supabase.instance.client.from('profiles').update({
        'lat': _activeLat,
        'lng': _activeLng,
        'city': currentCity,
      }).eq('id', uid);
      debugPrint('LocationService: Synced cached location to DB ($_activeLat, $_activeLng)');
    } catch (e) {
      debugPrint('LocationService: Failed to sync cached location: $e');
    }
  }
  /// Haversine formula to calculate distance in km
  double calculateDistanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0; 
    final double dLat = (lat2 - lat1) * pi / 180.0;
    final double dLon = (lon2 - lon1) * pi / 180.0;
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * 
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    return R * c;
  }

  /// Reverse Geocode using Nominatim API to get District/City name from Lat/Lng
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=10&addressdetails=1'
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'MeetraApp/1.0 (contact@meetra.app)',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final displayName = data['display_name']?.toString() ?? '';
        final rawDistrict = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? addr['county'] ?? addr['state_district'] ?? addr['district'] ?? '';
        final state = addr['state'] ?? '';
        final sanitized = sanitizeDistrict(rawDistrict.toString(), displayName);
        return state.toString().isNotEmpty ? '$sanitized, $state' : sanitized;
      }
    } catch (e) {
      debugPrint('LocationService reverseGeocode error: $e');
    }
    return null;
  }

  /// Fetches live GPS location, requests permission if needed, and reverse geocodes
  /// if the user has moved more than 5km from the last cached location.
  Future<bool> fetchLiveLocation({bool forceReverseGeocode = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      isLocationGrantedNotifier.value = false;
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        isLocationGrantedNotifier.value = false;
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      isLocationGrantedNotifier.value = false;
      return false;
    }

    // We do NOT set isLocationGrantedNotifier to true yet.
    // We must successfully fetch the position first to be absolutely sure they didn't block it at the prompt.
    
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      double distanceKm = 0.0;
      if (_activeLat != null && _activeLng != null) {
        distanceKm = calculateDistanceInKm(_activeLat!, _activeLng!, position.latitude, position.longitude);
      }

      // If we moved > 5km, or don't have a cached location name, or forced -> Reverse Geocode
      if (forceReverseGeocode || distanceKm > 5.0 || activeLocationNotifier.value.isEmpty || activeLocationNotifier.value == 'Map Location') {
        String? newLocationName = await reverseGeocode(position.latitude, position.longitude);
        if (newLocationName != null) {
          setLocation(newLocationName, lat: position.latitude, lng: position.longitude);
        } else {
          // Fallback to update coords only if API fails
          setLocation(activeLocationNotifier.value.isNotEmpty ? activeLocationNotifier.value : 'Current Location', lat: position.latitude, lng: position.longitude);
        }
      } else {
        // Just update coordinates silently without hitting API
        setLocation(activeLocationNotifier.value, lat: position.latitude, lng: position.longitude);
      }
      
      isLocationGrantedNotifier.value = true;
      return true;
    } catch (e) {
      debugPrint('LocationService fetchLiveLocation error: $e');
      isLocationGrantedNotifier.value = false;
      return false;
    }
  }
}

final locationService = LocationService();
