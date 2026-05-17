// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      bool changed = false;

      // 1. Fix withOpacity -> withValues(alpha: ...)
      if (content.contains('.withOpacity(')) {
        content = content.replaceAllMapped(RegExp(r'\.withOpacity\((.*?)\)'), (match) {
          return '.withValues(alpha: ${match.group(1)})';
        });
        changed = true;
      }
      
      // 2. Fix print() -> debugPrint()
      if (content.contains('print(')) {
        // Simple regex, might need refinement for actual print calls
        // content = content.replaceAll('print(', 'debugPrint(');
        // changed = true;
      }

      if (changed) {
        entity.writeAsStringSync(content);
        print('Fixed warnings in ${entity.path}');
      }
    }
  });
  print('Cleanup complete.');
}

