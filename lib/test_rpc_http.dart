import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url =
      'https://zlljvualqfjhbifhgabw.supabase.co/rest/v1/rpc/broadcast_nearby_notifications';
  const apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs';

  final body = {
    'p_creator_id': '00000000-0000-0000-0000-000000000000',
    'p_activity_id': '11111111-1111-1111-1111-111111111111',
    'p_title': 'Script Test',
    'p_body': 'Does the RPC work?',
    'p_lat': 28.6139,
    'p_lng': 77.2090,
    'p_radius_km': 1000.0,
    'p_type': 'nearby_activity',
    'p_payload': {'activity_id': '11111111-1111-1111-1111-111111111111'}
  };

  try {
    print('Calling Supabase...');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
  } catch (e) {
    print('Failed: $e');
  }
}
