import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    final res = await s.from('profiles').select('id, visibility, explore_status').limit(1);
    print("Success profiles visibility and explore_status: $res");
  } catch (e) {
    print("Error profiles visibility/explore_status: $e");
  }
}