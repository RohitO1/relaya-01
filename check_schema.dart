// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    await s.from('posts').insert({'content': 'test', 'user_id': '00000000-0000-0000-0000-000000000000'});
    print("Success");
  } catch (e) {
    print("Error: $e");
  }
}