import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/images/Sloth_Master_Transparent.png');
  final img = decodeImage(file.readAsBytesSync());
  if (img == null) {
    print('Failed to load image');
    return;
  }

  int h = img.height;
  int w = img.width;
  print('Image dimensions: \$w x \$h');

  List<String> profile = [];
  for (int y = 0; y < h; y += (h / 40).round()) {
    int solidPixels = 0;
    for (int x = 0; x < w; x++) {
      final pixel = img.getPixel(x, y);
      if (pixel.a > 10) solidPixels++;
    }
    profile.add('Y \$y: ' + ('#' * (solidPixels * 50 ~/ w)));
  }

  print(profile.join('\n'));
}
