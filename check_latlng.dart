// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    final res = await s.from('profiles').update({'lat': 25.4484, 'lng': 78.5685}).eq('id', 'e2679258-4b43-44da-9379-de554eff1e5b').select();
    print("Update Response: $res");
  } catch (e) {
    print("Update Error: $e");
  }
}