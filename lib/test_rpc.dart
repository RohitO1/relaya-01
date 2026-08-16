import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zlljvualqfjhbifhgabw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs',
  );

  final supabase = Supabase.instance.client;

  // Login as a test user or just use service role key...
  // Wait, RPC works with auth, but it's SECURITY DEFINER. Let's provide a valid UUID.

  // Let's use the DB anon key. But `broadcast_nearby_notifications` is SECURITY DEFINER, so anyone can call it.

  final creatorId = '00000000-0000-0000-0000-000000000000'; // dummy
  final activityId = '11111111-1111-1111-1111-111111111111'; // dummy

  print('Starting RPC call...');
  try {
    await supabase.rpc('broadcast_nearby_notifications', params: {
      'p_creator_id': creatorId,
      'p_activity_id': activityId,
      'p_title': 'Test Title',
      'p_body': 'Test Body',
      'p_lat': 28.6139, // New Delhi
      'p_lng': 77.2090,
      'p_radius_km': 1000.0, // Big radius
      'p_type': 'nearby_activity',
      'p_payload': {'activity_id': activityId},
    });
    print('RPC call succeeded.');
  } catch (e) {
    print('RPC call failed: $e');
  }
}
