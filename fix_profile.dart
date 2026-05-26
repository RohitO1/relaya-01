import 'dart:io';

void main() {
  final file = File('lib/bolroom/bolroom_profile_screen.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('import \'dart:math\' as math;')) {
    content = 'import \'dart:math\' as math;\n' + content;
  }
  
  final pStart = content.indexOf('await _audioPlayer.setSourceDeviceFile(file.path);');
  if (pStart > -1) {
    final pEnd = content.indexOf('await _audioPlayer.resume();', pStart) + 'await _audioPlayer.resume();'.length;
    final replacement = '''await _audioPlayer.setSourceDeviceFile(file.path);
    final p = VoiceMaskPreset.byId(_voiceMaskPreset) ?? VoiceMaskPreset.all.first;
    final semitones = _voiceMaskPreset == 'custom' ? (_voicePitch * 24 - 12) : p.pitchSemitones;
    final rate = math.pow(2.0, semitones / 12.0).toDouble();
    await _audioPlayer.setPlaybackRate(rate.clamp(0.5, 2.0));
    await _audioPlayer.resume();''';
    content = content.substring(0, pStart) + replacement + content.substring(pEnd);
  }
  
  content = content.replaceAll('if (_isEditingVoiceMask) ...[', '');
  content = content.replaceAll('if (v) _isEditingVoiceMask = true;', '');
  
  final eElse = content.indexOf('] else ...[');
  if (eElse > -1) {
    final searchBlock = 'Active Voice Mask';
    final activeMaskIdx = content.indexOf(searchBlock, eElse);
    if (activeMaskIdx > -1) {
      final eElseEnd = content.indexOf('],', activeMaskIdx);
      if (eElseEnd > -1) {
        content = content.substring(0, eElse) + content.substring(eElseEnd + 2);
      }
    }
  }
  
  file.writeAsStringSync(content);
  print('Done modifying bolroom_profile_screen.dart');
}
