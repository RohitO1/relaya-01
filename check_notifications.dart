import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('https://zlljvualqfjhbifhgabw.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs');
  
  try {
    print('Checking notifications...');
    final notifications = await supabase.from('notifications').select().limit(5);
    print('Recent notifications: ${notifications.length}');
    for (var n in notifications) {
      print('- ${n['type']}: ${n['title']} -> ${n['body']} (user: ${n['user_id']})');
    }

    print('\nChecking FCM tokens...');
    final tokens = await supabase.from('user_fcm_tokens').select().limit(5);
    print('FCM Tokens: ${tokens.length}');
    for (var t in tokens) {
      print('- User: ${t['user_id']}, Token: ${t['fcm_token'].substring(0, t['fcm_token'].length > 20 ? 20 : t['fcm_token'].length)}...');
    }
  } catch (e) {
    print('Error: $e');
  }
}
