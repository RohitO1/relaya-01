// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_helper.dart';

class WebImageHelper implements ImageHelper {
  @override
  Future<String?> pickAndUpload({
    required BuildContext context,
    String? folder,
  }) async {
    final completer = html.FileUploadInputElement();
    completer.accept = 'image/*';
    completer.click();

    await completer.onChange.first;
    if (completer.files == null || completer.files!.isEmpty) return null;

    final file = completer.files![0];
    final reader = html.FileReader();
    
    // First read as ArrayBuffer for ProImageEditor
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    
    final arrayBuffer = reader.result as List<int>;
    final Uint8List originalBytes = Uint8List.fromList(arrayBuffer);

    Uint8List? editedBytes;

    if (context.mounted) {
      bool popped = false;
      editedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (editorContext) => ProImageEditor.memory(
            originalBytes,
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

    if (editedBytes == null) return null;

    // Optional: Downscale logic can be done using ImageElement and CanvasElement
    // similar to previous logic, but ProImageEditor generally outputs optimized bytes.
    // However, if we want to upload to Supabase as well (matching mobile logic)
    // we can attempt the upload here:
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Get extension from filename, default to jpg
      final filenameParts = file.name.split('.');
      final ext = filenameParts.length > 1 ? filenameParts.last.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), 'jpg') : 'jpg';
      final bucketFolder = folder ?? 'avatars';
      final fileName = '$bucketFolder/$uid-$timestamp.$ext';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            editedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      debugPrint('Image uploaded to Supabase Storage: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase Storage upload failed ($e). Falling back to base64.');
      final String base64Image = base64Encode(editedBytes);
      return 'data:image/jpeg;base64,$base64Image';
    }
  }
}

ImageHelper getImageHelper() => WebImageHelper();
