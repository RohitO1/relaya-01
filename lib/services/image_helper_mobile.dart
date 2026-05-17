import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'image_helper.dart';

class MobileImageHelper implements ImageHelper {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pickAndUpload({
    required BuildContext context,
    String? folder,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, // Increased max width/height to allow better quality editing
      maxHeight: 1200,
      imageQuality: 90,
    );

    if (file == null) return null;

    Uint8List? finalBytes;

    if (context.mounted) {
      bool popped = false;
      finalBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (editorContext) => ProImageEditor.file(
            File(file.path),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List bytes) async {
                if (!popped) {
                  popped = true;
                  Navigator.pop(editorContext, bytes);
                }
              },
              onCloseEditor: (_) {
                if (!popped) {
                  popped = true;
                  Navigator.pop(editorContext, null);
                }
              },
            ),
          ),
        ),
      );
    }

    if (finalBytes == null) return null;

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = file.name.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), 'jpg');
      final bucketFolder = folder ?? 'avatars';
      final fileName = '$bucketFolder/$uid-$timestamp.$ext';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            finalBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get the public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      debugPrint('Image uploaded to Supabase Storage: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase Storage upload failed ($e). Falling back to base64.');
      // Fallback: return base64 data URI so the app still works locally
      // when the Supabase Storage bucket is not configured.
      final String base64Image = base64Encode(finalBytes);
      return 'data:image/jpeg;base64,$base64Image';
    }
  }
}

ImageHelper getImageHelper() => MobileImageHelper();
