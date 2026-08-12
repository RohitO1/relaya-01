import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://tkcdzuthjrxpfczqathy.supabase.co');
  final supabaseKey = const String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');

  final s = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    final res = await s
        .from('messages')
        .select()
        .order('created_at', ascending: false)
        .limit(10);
    print("Success: $res");
  } catch (e) {
    print("Error: $e");
  }
}
