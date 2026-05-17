import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Conditional imports
import 'services/image_helper.dart'
    if (dart.library.html) 'services/image_helper_web.dart'
    if (dart.library.io) 'services/image_helper_mobile.dart';

/// Centralized image upload service for Meetra.
class ImageUploadService {

  /// Pick a single image and upload to Supabase Storage.
  /// Returns the public URL (or Data URI), or null if cancelled/failed.
  static Future<String?> pickAndUpload({
    required BuildContext context,
    String? folder,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 85,
  }) async {
    try {
      final helper = getImageHelper();
      return await helper.pickAndUpload(context: context, folder: folder);
    } catch (e) {
      debugPrint('ImageUploadService error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: ${_friendlyError(e)}'),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }
  }

  /// Update the user's avatar_url in the profiles table.
  static Future<bool> updateProfileAvatar(String url) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': url}).eq('id', uid);
      return true;
    } catch (e) {
      debugPrint('Update avatar error: $e');
      return false;
    }
  }

  static String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Bucket not found')) return 'Bucket missing. Create avatars bucket.';
    if (msg.contains('row-level security')) return 'Permissions error.';
    if (msg.contains('exceeded') || msg.contains('too large')) return 'Image too large.';
    if (msg.contains('MissingPlugin')) return 'Plugin not supported.';
    if (msg.length > 80) return '${msg.substring(0, 80)}...';
    return msg;
  }
}
