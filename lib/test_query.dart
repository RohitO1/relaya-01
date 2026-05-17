// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  
  try {
    final data = await supabase.from('profiles').select();
    print('Total profiles: ${data.length}');
    if (data.isNotEmpty) {
      print('Sample Profile 1: ${data.first}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
