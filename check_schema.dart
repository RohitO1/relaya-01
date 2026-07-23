import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    final res = await s.from('rush_in_messages').select().limit(1);
    print("Success: $res");
  } catch (e) {
    print("Error: $e");
  }
}