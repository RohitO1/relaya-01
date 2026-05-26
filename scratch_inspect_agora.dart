import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

void main() {
  final file = File('agora_fields.txt');
  final sink = file.openWrite();
  
  sink.writeln('AudioRecordingConfiguration Properties:');
  final config = AudioRecordingConfiguration(filePath: 'test.wav');
  sink.writeln('filePath: ${config.filePath}');
  sink.writeln('sampleRate: ${config.sampleRate}');
  // codec field removed - not available in this Agora SDK version
  sink.writeln('fileRecordingType: ${config.fileRecordingType}');
  sink.writeln('quality: ${config.quality}');
  
  sink.close();
  print('Done writing');
}
