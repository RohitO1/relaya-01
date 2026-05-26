// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'image_helper.dart';
import '../widgets/image_crop_screen.dart';

class MobileImageHelper implements ImageHelper {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pickAndUpload({
    required BuildContext context,
    String? folder,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 92,
    );

    if (file == null) return null;
    if (!context.mounted) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5) {
      final headerStr = String.fromCharCodes(bytes.sublist(0, 5).toList()).toLowerCase();
      if (headerStr == '<?xml' || headerStr == '<svg ' || headerStr == '<html') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SVG or XML files are not supported. Please select a JPG or PNG image.'),
              backgroundColor: Color(0xFFE11D48),
            ),
          );
        }
        return null;
      }
    }

    // ── Step 1: Custom 1:1 crop screen ─────────────────────────────────────
    final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageCropScreen(imageFile: File(file.path)),
      ),
    );

    if (croppedBytes == null) return null; // user cancelled crop
    if (!context.mounted) return null;

    // ── Step 2: Optional pro image editor (filters / stickers) ─────────────
    bool popped = false;
    final Uint8List? finalBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => ProImageEditor.memory(
          croppedBytes,
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

    // If user closed the editor without saving, fall back to the cropped bytes
    final Uint8List uploadBytes = finalBytes ?? croppedBytes;

    // ── Step 3: Upload to Supabase Storage ──────────────────────────────────
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bucketFolder = folder ?? 'avatars';
      final fileName = '$bucketFolder/$uid-$timestamp.png';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            uploadBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      debugPrint('Image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase upload failed ($e). Using base64 fallback.');
      final base64Image = base64Encode(uploadBytes);
      return 'data:image/png;base64,$base64Image';
    }
  }
}

ImageHelper getImageHelper() => MobileImageHelper();
