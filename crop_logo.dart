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

  // Find where the sloth starts
  int startY = 0;
  bool foundContent = false;
  for (int y = 0; y < h; y++) {
    bool hasPixels = false;
    for (int x = 0; x < w; x++) {
      if (img.getPixel(x, y).a > 10) {
        hasPixels = true;
        break;
      }
    }
    if (hasPixels) {
      foundContent = true;
      startY = y;
      break;
    }
  }

  // Find the gap between sloth and text
  int endY = h - 1;
  int transparentRowsStreak = 0;
  for (int y = startY + 1; y < h; y++) {
    bool hasPixels = false;
    for (int x = 0; x < w; x++) {
      if (img.getPixel(x, y).a > 10) {
        hasPixels = true;
        break;
      }
    }

    if (!hasPixels) {
      transparentRowsStreak++;
    } else {
      // If we found a significant gap and hit text, this is the cutoff
      if (transparentRowsStreak > 20) {
        endY = y - transparentRowsStreak;
        break;
      }
      transparentRowsStreak = 0; // reset
    }
  }

  print('Cropping from Y=0 to Y=\$endY');

  // Crop the top part containing the sloth
  final cropped = copyCrop(img,
      x: 0,
      y: 0,
      width: w,
      height: endY + 20); // give 20px padding at bottom if we can

  // AutoTrim to remove extra transparent space around the sloth exactly
  // Note: copyCrop or trim can be used, but since we want the logo, let's keep it square

  // We will save it precisely as the new icon.
  final out = File('assets/images/meetra_icon.png');
  out.writeAsBytesSync(encodePng(cropped));
  print('Saved as assets/images/meetra_icon.png');
}
