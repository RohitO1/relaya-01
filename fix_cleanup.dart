import 'dart:io';

void main() {
  final file = File('lib/bolroom/bolroom_profile_screen.dart');
  var c = file.readAsStringSync();

  // The new function ends at the closing '}' of _buildVoiceEffectsSection
  // (our new one, line ~1451). But right after it there is leftover code:
  //   }),\n  ], ...' from the old else block.
  // Strategy: find the clean function end, then find start of next known good method
  // and remove the garbage in between.

  // Find end of new _buildVoiceEffectsSection  
  final marker1 = '    );\n  }); // END OLD LEFTOVERS FROM EDIT'; // not present
  // Use brace depth on new function
  final fnStart = c.indexOf('  Widget _buildVoiceEffectsSection()');
  int depth = 0;
  bool started = false;
  int fnEnd = -1;
  for (int i = fnStart; i < c.length; i++) {
    if (c[i] == '{') { depth++; started = true; }
    else if (c[i] == '}') {
      depth--;
      if (started && depth == 0) { fnEnd = i + 1; break; }
    }
  }
  print('New function ends at: ' + fnEnd.toString());
  print('After function: ' + c.substring(fnEnd, fnEnd + 200));
  
  // Find the next clean function: _showVoiceMaskingSheet
  final nextFnMarker = '  void _showVoiceMaskingSheet()';
  final nextFnStart = c.indexOf(nextFnMarker);
  print('Next function starts at: ' + nextFnStart.toString());
  
  // Remove the garbage between fnEnd and nextFnStart
  if (fnEnd > -1 && nextFnStart > -1 && nextFnStart > fnEnd) {
    c = c.substring(0, fnEnd) + '\n\n' + c.substring(nextFnStart);
    file.writeAsStringSync(c);
    print('Removed ' + (nextFnStart - fnEnd).toString() + ' chars of garbage');
  }
}
