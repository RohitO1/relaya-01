import 'dart:io';

void main() {
  final file = File('lib/bolroom/bolroom_profile_screen.dart');
  var content = file.readAsStringSync();
  
  final idx = content.indexOf('  Widget _buildVoiceEffectsSection()');
  int depth = 0;
  bool started = false;
  int end = -1;
  for (int i = idx; i < content.length; i++) {
    if (content[i] == '{') { depth++; started = true; }
    else if (content[i] == '}') {
      depth--;
      if (started && depth == 0) { end = i + 1; break; }
    }
  }
  
  // Print current section  
  print(content.substring(idx, end));
}
