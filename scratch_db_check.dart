import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  final res = await supabase.from('profiles').select('name, avatar_url').limit(10);
  for (var r in res) {
    print("${r['name']}: ${r['avatar_url']}");
  }
}
