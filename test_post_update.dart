import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://tkcdzuthjrxpfczqathy.supabase.co',
    anonKey: 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj',
  );

  try {
    final client = Supabase.instance.client;
    await client.auth.signInAnonymously();

    final testPost = await client.from('posts').select().limit(1).maybeSingle();
    debugPrint('Current post: $testPost');

    if (testPost != null) {
      final String contentRaw = testPost['content'] ?? '{}';
      Map<String, dynamic> data = {};
      try {
         data = jsonDecode(contentRaw.startsWith('{') ? contentRaw : '{"text": "$contentRaw"}');
      } catch(e) {
        debugPrint('JSON decode error: $e');
      }
      
      data['comments'] = ['Backend Test Comment'];
      
      await client.from('posts').update({'content': jsonEncode(data)}).eq('id', testPost['id']);
      debugPrint('Update successful');
    }
  } catch (e) {
    debugPrint('Error: $e');
  }
}
