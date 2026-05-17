// ignore_for_file: avoid_print
import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj');
  try {
    final data = await s.from('profiles').select();
    int updated = 0;
    
    for (var p in data) {
      final city = p['city']?.toString().toLowerCase() ?? '';
      double? lat;
      double? lng;
      
      if (city.contains('kanpur')) {
        lat = 26.4499; lng = 80.3319;
      } else if (city.contains('jalaun')) {
        lat = 26.1445; lng = 79.3178;
      } else if (city.contains('gwalior')) {
        lat = 26.2183; lng = 78.1828;
      } else if (city.contains('jhansi')) {
        lat = 25.4484; lng = 78.5685;
      } else if (city.contains('lucknow')) {
        lat = 26.8467; lng = 80.9462;
      } else if (city.contains('delhi')) {
        lat = 28.7041; lng = 77.1025;
      } else if (city.contains('mumbai')) {
        lat = 19.0760; lng = 72.8777;
      }
      
      if (lat != null && lng != null) {
        await s.from('profiles').update({
          'lat': lat,
          'lng': lng
        }).eq('id', p['id']);
        updated++;
      }
    }
    print("Accurate geographic coordinates successfully assigned to $updated cities!");
  } catch (e) {
    print("Script Error: $e");
  }
}

