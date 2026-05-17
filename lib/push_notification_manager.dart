import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

class PushNotificationManager {
  static final PushNotificationManager _instance = PushNotificationManager._internal();
  factory PushNotificationManager() => _instance;
  PushNotificationManager._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip if still using dummy/placeholder credentials
      final opts = DefaultFirebaseOptions.currentPlatform;
      if (opts.apiKey.startsWith('dummy-') || opts.projectId.contains('mock')) {
        debugPrint('Firebase Messaging skipped: real credentials not configured yet.');
        return;
      }

      // Safely initialize with the real firebase options
      await Firebase.initializeApp(
        options: opts,
      );

      final messaging = FirebaseMessaging.instance;

      // 1. Request Permission from user (shows prompt on iOS, required for Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission for push notifications');
        
        // 2. Get the device token for this device
        String? token = await messaging.getToken();
        if (token != null) {
          debugPrint('FCM Device Token retrieving: $token');
          await _saveTokenToSupabase(token);
        }

        // 3. Listen to token refreshes
        messaging.onTokenRefresh.listen(_saveTokenToSupabase);

        // 4. Listen to foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Received a foreground message: ${message.messageId}');
        });
      } else {
        debugPrint('User declined or has not accepted permission');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Firebase Messaging setup skipped. Error: $e');
      // Fails gracefully if Firebase isn\'t configured yet.
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Upsert the token into the user_fcm_tokens table
      await Supabase.instance.client.from('user_fcm_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id'); // We assume one active token per user ID for simplicity
      debugPrint('Token synced to Supabase successfully.');
    } catch (e) {
      debugPrint('Error syncing token to Supabase: $e');
    }
  }
}
