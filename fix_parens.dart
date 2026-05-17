// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final files = [
    'lib/chatroom_live_screen.dart',
    'lib/bolroom/bolroom_voice_screen.dart',
  ];
  
  for (final path in files) {
    final file = File(path);
    var content = file.readAsStringSync();
    
    // Fix: Border.all(color: X.withOpacity(0.3),\n  ->  Border.all(color: X.withOpacity(0.3)),\n
    // The regex removed the closing ) of Border.all()
    content = content.replaceAllMapped(
      RegExp(r'Border\.all\(color: ([^)]+)\.withOpacity\(0\.3\),(\s*)\n'),
      (m) => 'Border.all(color: ${m.group(1)}.withOpacity(0.3)),${m.group(2)}\n',
    );
    
    file.writeAsStringSync(content);
    print('Fixed $path');
  }
}

