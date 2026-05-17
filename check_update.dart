// ignore_for_file: avoid_print
import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    final res = await s.from('posts').update({'content': 'test'}).eq('id', '00000000-0000-0000-0000-000000000000').select();
    print("Update Response: $res");
  } catch (e) {
    print("Update Error: $e");
  }
}