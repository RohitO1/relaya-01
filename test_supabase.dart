import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient(
    'https://vaamnfscgoisovvdsdph.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYW1uZnNjZ29pc292dmRzZHBoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NTAyMTcsImV4cCI6MjA5NzIyNjIxN30.qHagWqkuaZO_DOqrBWYL-UiCXYSR35vlnbE67Vv3rb4'
  );
  try {
    final res = await supabase.from('profiles').select().limit(1);
    print("Success: $res");
  } catch (e) {
    print("Error: $e");
  }
}
