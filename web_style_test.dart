import 'dart:convert';
void main() {
  const String _darkMapStyle = '''[{"elementType": "geometry", "stylers": [{"color": "#242f3e"}]}]''';
  try {
    jsonDecode(_darkMapStyle);
    print("Valid JSON");
  } catch (e) {
    print("Invalid JSON: $e");
  }
}
