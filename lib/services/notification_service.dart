import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

enum NotificationType {
  match,
  nearbyActivity,
  approval,
  rejection,
  message,
  system
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.match: return 'match';
      case NotificationType.nearbyActivity: return 'nearby_activity';
      case NotificationType.approval: return 'approval';
      case NotificationType.rejection: return 'rejection';
      case NotificationType.message: return 'message';
      case NotificationType.system: return 'system';
    }
  }
}

class NotificationService {
  static final _supabase = Supabase.instance.client;

  /// Creates a single notification for a specific user
  static Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      // 1. Check user preferences before sending
      final profile = await _supabase
          .from('profiles')
          .select('notification_settings')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null && profile['notification_settings'] != null) {
        final settings = profile['notification_settings'] as Map<String, dynamic>;
        bool shouldNotify = true;

        if (type == NotificationType.match) shouldNotify = settings['matches'] ?? true;
        if (type == NotificationType.nearbyActivity) shouldNotify = settings['nearby_activities'] ?? true;
        if (type == NotificationType.approval || type == NotificationType.rejection) {
          shouldNotify = settings['approvals'] ?? true;
        }
        if (type == NotificationType.message) shouldNotify = settings['messages'] ?? true;

        if (!shouldNotify) {
          debugPrint('Notification suppressed user preferences: $type');
          return;
        }
      }

      // 2. Insert into notifications table
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': type.value,
        'title': title,
        'body': body,
        'payload': payload ?? {},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Notification sent to $userId: $title');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Notifies multiple users about a nearby activity
  /// Simple implementation: notifies users in the same city or broad proximity
  static Future<void> notifyNearbyActivity({
    required String creatorId,
    required String activityId,
    required String title,
    required String locationName,
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    try {
      // Fetch users who are NOT the creator and have nearby_activities enabled
      final List<dynamic> users = await _supabase
          .from('profiles')
          .select('id, notification_settings, lat, lng')
          .neq('id', creatorId);

      for (var user in users) {
        final userId = user['id'];
        final settings = user['notification_settings'] as Map<String, dynamic>?;
        
        if (settings != null && settings['nearby_activities'] == false) continue;

        // Check distance if lat/lng available
        final userLat = user['lat'];
        final userLng = user['lng'];
        
        if (userLat != null && userLng != null) {
          final distance = _calculateDistance(lat, lng, userLat, userLng);
          if (distance <= radiusKm) {
            await sendNotification(
              userId: userId,
              type: NotificationType.nearbyActivity,
              title: 'New Activity Nearby! 📍',
              body: '$title at $locationName',
              payload: {'activity_id': activityId},
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error notifying nearby users: $e');
    }
  }

  // Haversine formula to calculate distance between two coordinates in kilometers
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0; // Earth's radius in km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * 3.1415926535897932 / 180;
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('user_id', userId);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications(String userId) async {
    try {
      final res = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  static Future<int> getUnreadCount(String userId) async {
    try {
      final res = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (res as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}
