// ignore_for_file: avoid_print
import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    final data = await s.from('profiles').select('id, city, name');
    for (var p in data) {
      print("User: ${p['name']} | City: ${p['city']}");
    }
  } catch (e) {
    print("Error: $e");
  }
}