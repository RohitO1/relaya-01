import 'package:supabase/supabase.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://zlljvualqfjhbifhgabw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs'
  );

  try {
    // try to get a single row to see if it works
    final res = await supabase.from('notifications').select().limit(1);
    print('Query success: $res');
  } catch (e) {
    print('Query error: $e');
  }
  
  try {
    // check column info using postgrest
    final res = await supabase.rpc('get_schema_info');
    print('RPC result: $res');
  } catch(e) {
    print('RPC error: $e');
  }
  exit(0);
}
