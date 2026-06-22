import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient(
    'https://tkcdzuthjrxpfczqathy.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrY2R6dXRoanJ4cGZjenFhdGh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MDc2MzAsImV4cCI6MjA5MTQ4MzYzMH0.RSwwJlPUxvvF2K8ZTER54WXuq91H-wgNW105JnzxJv8'
  );
  try {
    final res = await supabase.from('profiles').select().limit(1);
    print("Success 3: $res");
  } catch (e) {
    print("Error 3: $e");
  }
}
