import 'package:flutter/material.dart';

abstract class ImageHelper {
  Future<String?> pickAndUpload({
    required BuildContext context,
    String? folder,
  });
}

ImageHelper getImageHelper() => throw UnsupportedError('Cannot create an image helper');
