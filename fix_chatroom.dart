import 'dart:io';

void main() {
  final file = File('lib/chatroom_live_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    '      } else {\n        _engine?.setAudioEffectPreset(AudioEffectPreset.roomAcoustics3dVoice);',
    '      } else {\n        _engine?.setAudioEffectPreset(AudioEffectPreset.audioEffectOff);\n        _engine?.setLocalVoicePitch(1.0);'
  );
  
  content = content.replaceFirst(
    'AudioEffectPreset effect = AudioEffectPreset.roomAcoustics3dVoice;',
    'AudioEffectPreset effect = AudioEffectPreset.audioEffectOff;'
  );
  
  content = content.replaceFirst(
    'effect = AudioEffectPreset.roomAcoustics3dVoice; // off/default',
    'effect = AudioEffectPreset.audioEffectOff; // off/default'
  );
  
  final cStart = content.indexOf('      case \'radiodj\':');
  if (cStart > -1) {
    final cEnd = content.indexOf('break;', cStart) + 'break;'.length;
    final replacement = content.substring(cStart, cEnd) + '\n      case \'custom\':\n        effect = AudioEffectPreset.audioEffectOff;\n        _engine!.setLocalVoicePitch(_myVoicePitch);\n        break;';
    content = content.substring(0, cStart) + replacement + content.substring(cEnd);
  }
  
  file.writeAsStringSync(content);
  print('Done chatroom_live_screen.dart');
}
