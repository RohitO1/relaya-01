// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://zlljvualqfjhbifhgabw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs',
  );
  
  try {
    final data = await supabase.from('text_camps').select();
    print('Total text_camps: ${data.length}');
    for (var i = 0; i < data.length; i++) {
      print('Camp $i: ${data[i]['name']} | location_district: ${data[i]['location_district']} | creator_id: ${data[i]['creator_id']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
