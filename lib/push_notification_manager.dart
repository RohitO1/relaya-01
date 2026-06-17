import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'main.dart'; // for navigatorKey
import 'rush_in_consumer_detail_view.dart';
import 'bolroom/bolroom_community_detail_screen.dart';
import 'bolroom/bolroom_dm_chat_screen.dart';
import 'chatroom_live_screen.dart'; // for BolRoomManager
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'knocks_list_screen.dart';
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Handling background FCM message: ${message.messageId}");
  } catch (e) {
    debugPrint("Error in background handler: $e");
  }
}

class PushNotificationManager {
  static final PushNotificationManager _instance = PushNotificationManager._internal();
  factory PushNotificationManager() => _instance;
  PushNotificationManager._internal();

  bool _isInitialized = false;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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

      // Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.payload != null) {
            try {
              final payload = Map<String, dynamic>.from(jsonDecode(details.payload!));
              _handleMessage(RemoteMessage(data: payload));
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Create the high importance channel for Android so FCM background messages show in the drawer
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel', // id
            'High Importance Notifications', // name
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
            playSound: true,
          ),
        );
      }

      // 1. Request Permission from user (shows prompt on iOS, required for Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Set foreground notification presentation options (sound, alert, badge)
      await messaging.setForegroundNotificationPresentationOptions(
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

        // Listen to auth state changes to dynamically sync the FCM token to the DB upon authentication/login
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          final session = data.session;
          if (session != null) {
            debugPrint('Supabase Auth State changed: User signed in. Syncing FCM token...');
            final currentToken = await messaging.getToken();
            if (currentToken != null) {
              await _saveTokenToSupabase(currentToken);
            }
          }
        });

        // 4. Listen to foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Received a foreground message: ${message.messageId}');
          _showLocalNotification(message);
        });

        // 5. Listen to background/terminated messages tapping
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
        
        // 6. Check if app was opened from a terminated state via notification
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          // Delay to ensure the Navigator is ready if app is just launching
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessage(initialMessage);
          });
        }
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

  void _handleMessage(RemoteMessage message) async {
    debugPrint('Notification tapped! Data: ${message.data}');
    
    try {
      Map<String, dynamic> payload = {};
      if (message.data.containsKey('payload')) {
        final payloadData = message.data['payload'];
        if (payloadData is String) {
          payload = Map<String, dynamic>.from(jsonDecode(payloadData));
        } else if (payloadData is Map) {
          payload = Map<String, dynamic>.from(payloadData);
        }
      } else {
        payload = Map<String, dynamic>.from(message.data);
      }
      
      final navState = navigatorKey.currentState;
      if (navState == null) {
        debugPrint('navigatorKey is not ready.');
        return;
      }

      if (payload.containsKey('activity_id')) {
        final activityId = payload['activity_id']?.toString();
        if (activityId != null) {
          debugPrint('Navigating to Activity: $activityId');
          final activity = await Supabase.instance.client.from('activities').select().eq('id', activityId).maybeSingle();
          if (activity != null) {
            navState.push(MaterialPageRoute(
              builder: (_) => RushInConsumerDetailView(activity: activity, onInteraction: () {}),
            ));
          }
        }
      } 
      else if (payload.containsKey('bolroom_live') && payload['bolroom_live'] == true) {
        final roomId = payload['room_id']?.toString();
        if (roomId != null) {
          debugPrint('Navigating to BolRoom Live: $roomId');
          final room = await Supabase.instance.client.from('chatrooms').select().eq('id', roomId).maybeSingle();
          final currentCtx = navigatorKey.currentContext;
          if (room != null && currentCtx != null && currentCtx.mounted) {
            BolRoomManager.openRoom(
              currentCtx,
              roomId: room['id'].toString(),
              roomName: room['name']?.toString() ?? 'Room',
              topic: room['topic']?.toString() ?? 'General',
              hostId: room['host_id']?.toString() ?? '',
              hostName: room['host_name']?.toString() ?? 'Host',
            );
          }
        }
      }
      else if (payload.containsKey('bolroom_community') && payload['bolroom_community'] == true) {
        final communityId = payload['community_id']?.toString();
        if (communityId != null) {
          debugPrint('Navigating to BolRoom Community: $communityId');
          final comm = await Supabase.instance.client.from('bolroom_communities').select().eq('id', communityId).maybeSingle();
          if (comm != null) {
            navState.push(MaterialPageRoute(
              builder: (_) => BolroomCommunityDetailScreen(community: comm),
            ));
          }
        }
      }
      else if (payload.containsKey('bolroom_dm') && payload['bolroom_dm'] == true) {
        final convoId = payload['conversation_id']?.toString();
        final senderId = payload['sender_id']?.toString();
        debugPrint('Navigating to BolRoom DM: $convoId');
        if (convoId != null && senderId != null) {
          final profile = await Supabase.instance.client.from('bolroom_profiles').select().eq('id', senderId).maybeSingle();
          navState.push(MaterialPageRoute(
            builder: (_) => BolroomDmChatScreen(
              conversationId: convoId,
              partnerId: senderId,
              partnerName: profile?['anon_name'] ?? 'User',
              partnerAvatarKey: profile?['avatar_key'] ?? 'human_1',
            ),
          ));
        }
      }
      else if (payload.containsKey('request_id') && payload.containsKey('target_id')) {
        final targetId = payload['target_id']?.toString();
        if (targetId != null) {
          debugPrint('Navigating to Approved Target: $targetId');
          final activity = await Supabase.instance.client.from('activities').select().eq('id', targetId).maybeSingle();
          if (activity != null) {
            navState.push(MaterialPageRoute(
              builder: (_) => RushInConsumerDetailView(activity: activity, onInteraction: () {}),
            ));
          }
        }
      }
      else if (payload.containsKey('sender_id')) {
        final senderId = payload['sender_id']?.toString();
        final notifType = message.data['type']?.toString() ?? payload['type']?.toString(); 
        final title = message.notification?.title?.toLowerCase() ?? message.data['title']?.toString().toLowerCase() ?? '';

        if (senderId != null) {
          try {
            if (notifType == 'match' || title.contains('match')) {
              // It's a match notification -> Go to their profile
              debugPrint('Match notification tapped. Navigating to ProfileScreen: $senderId');
              navState.push(MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: senderId),
              ));
            } else if (notifType == 'knock_accepted' || title.contains('knock accepted')) {
              // It's an accepted knock -> Go to ChatDetailScreen
              debugPrint('Knock accepted notification tapped. Navigating to ChatDetailScreen: $senderId');
              final profile = await Supabase.instance.client.from('profiles').select().eq('id', senderId).maybeSingle();
              if (profile != null) {
                navState.push(MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                    targetUserId: senderId,
                    name: profile['name'] ?? 'User',
                    avatarUrl: profile['avatar_url'] ?? '',
                    isUnlocked: true,
                  ),
                ));
              }
            } else if (notifType == 'knock' || title.contains('knock')) {
              // It's a knock notification -> Go to KnocksListScreen
              debugPrint('Knock notification tapped. Navigating to KnocksListScreen.');
              navState.push(MaterialPageRoute(
                builder: (_) => const KnocksListScreen(),
              ));
            } else {
              // It's a chat message -> Go to ChatDetailScreen
              debugPrint('Attempting to fetch sender profile for ChatDetailScreen: $senderId');
              final profile = await Supabase.instance.client.from('profiles').select().eq('id', senderId).maybeSingle();
              if (profile != null) {
                debugPrint('Navigating to ChatDetailScreen: ${profile['name']}');
                navState.push(MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                    targetUserId: senderId,
                    name: profile['name'] ?? 'User',
                    avatarUrl: profile['avatar_url'] ?? '',
                    isUnlocked: true,
                  ),
                ));
              } else {
                debugPrint('Sender profile not found. Navigating to Profile: $senderId');
                navState.push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: senderId),
                ));
              }
            }
          } catch (e) {
            debugPrint('Failed to load sender profile: $e. Fallback to ProfileScreen.');
            navState.push(MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: senderId),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel', // channel id
        'High Importance Notifications', // channel name
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode(message.data),
      );
      debugPrint('Local notification displayed successfully.');
    } catch (e) {
      debugPrint('Error displaying local notification: $e');
    }
  }
}
