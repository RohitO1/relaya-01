/// Lightweight LatLng class that replaces google_maps_flutter's LatLng.
/// Keeps the same API so existing code (distance calculations, etc.) works unchanged.
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
