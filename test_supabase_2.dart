import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient(
    'https://hjgnikbzvdljrmmoobre.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ25pa2J6dmRsanJtbW9vYnJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNDU5MTIsImV4cCI6MjA5NTgyMTkxMn0.XG5ogcEUCnZ0PVN9XyhCpi5c4Q70HUBgyCw9vQuL4qw'
  );
  try {
    final res = await supabase.from('profiles').select().limit(1);
    print("Success 2: $res");
  } catch (e) {
    print("Error 2: $e");
  }
}
