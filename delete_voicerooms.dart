import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://tkcdzuthjrxpfczqathy.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrY2R6dXRoanJ4cGZjenFhdGh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MDc2MzAsImV4cCI6MjA5MTQ4MzYzMH0.RSwwJlPUxvvF2K8ZTER54WXuq91H-wgNW105JnzxJv8'
  );
  
  try {
    print("Fetching existing chatrooms...");
    final rooms = await supabase.from('chatrooms').select('id');
    print("Found ${rooms.length} chatrooms.");
    
    if (rooms.isNotEmpty) {
      print("Deleting chatrooms...");
      for (var room in rooms) {
        await supabase.from('chatrooms').delete().eq('id', room['id']);
        print("Deleted room ${room['id']}");
      }
      print("All voicerooms deleted successfully.");
    } else {
      print("No voicerooms found to delete.");
    }
  } catch (e) {
    print("Error deleting chatrooms: $e");
  }
}
