// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    // 1. Fetch profiles where lat is currently null
    final data = await s.from('profiles').select();
    int updated = 0;
    
    for (var p in data) {
      if (p['lat'] == null) {
        // Base coordinate (approx Jhansi, India) + slight random offset
        final offsetLat = 25.4484 + (updated * 0.012); 
        final offsetLng = 78.5685 + (updated * 0.008);
        
        await s.from('profiles').update({
          'lat': offsetLat,
          'lng': offsetLng
        }).eq('id', p['id']);
        updated++;
      }
    }
    print("Coordinates successfully injected for $updated dummy profiles!");
  } catch (e) {
    print("Script Error: $e");
  }
}