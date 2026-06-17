// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  
  try {
    final data = await supabase.from('text_camps').select();
    print('Total text_camps: ${data.length}');
    for (var i = 0; i < data.length; i++) {
      print('Camp $i: ${data[i]['name']} | location_district: ${data[i]['location_district']} | creator_id: ${data[i]['creator_id']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
