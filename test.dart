import 'dart:typed_data';
void main() {
  final buf = ByteData(4);
  buf.setInt8(0, 1);
  buf.setInt8(1, 2);
  
  final shortView = buf.buffer.asInt16List();
  shortView[0] = 99;
  
  print(buf.getInt8(0));
  print(buf.getInt8(1));
}
