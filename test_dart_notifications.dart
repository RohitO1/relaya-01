import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://zlljvualqfjhbifhgabw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs',
  );

  final client = Supabase.instance.client;

  try {
    print('Testing profiles select...');
    final profile = await client
        .from('profiles')
        .select('notification_settings')
        .limit(1)
        .maybeSingle();
    print('Profile: \$profile');
    
    print('Testing insert...');
    await client.from('notifications').insert({
      'user_id': 'cdcd04ec-d385-496e-8c89-c144b1b7a27f',
      'type': 'system',
      'title': 'Dart Test',
      'body': 'Dart body',
      'payload': {},
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
    print('Insert succeeded!');

  } catch (e, stacktrace) {
    print('Error: \$e');
    print(stacktrace);
  }
}
