import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum NotificationType {
  match,
  nearbyActivity,
  approval,
  rejection,
  message,
  compliment,
  system,
  bolroomMessage,
  bolroomSystem,
  bolroomFollower,
  bolroomChatroom,
  knock,
  knock_accepted,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.match:
        return 'match';
      case NotificationType.nearbyActivity:
        return 'nearby_activity';
      case NotificationType.approval:
        return 'approval';
      case NotificationType.rejection:
        return 'rejection';
      case NotificationType.message:
        return 'message';
      case NotificationType.compliment:
        return 'compliment';
      case NotificationType.system:
        return 'system';
      case NotificationType.bolroomMessage:
        return 'bolroom_message';
      case NotificationType.bolroomSystem:
        return 'bolroom_system';
      case NotificationType.bolroomFollower:
        return 'bolroom_follower';
      case NotificationType.bolroomChatroom:
        return 'bolroom_chatroom';
      case NotificationType.knock:
        return 'knock';
      case NotificationType.knock_accepted:
        return 'knock_accepted';
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
      try {
        final profile = await _supabase
            .from('profiles')
            .select('notification_settings')
            .eq('id', userId)
            .maybeSingle();

        if (profile != null && profile['notification_settings'] != null) {
          final settings =
              profile['notification_settings'] as Map<String, dynamic>;
          bool shouldNotify = true;

          if (type == NotificationType.match)
            shouldNotify = settings['matches'] ?? true;
          if (type == NotificationType.nearbyActivity)
            shouldNotify = settings['nearby_activities'] ?? true;
          if (type == NotificationType.approval ||
              type == NotificationType.rejection) {
            shouldNotify = settings['approvals'] ?? true;
          }
          if (type == NotificationType.message ||
              type == NotificationType.compliment)
            shouldNotify = settings['messages'] ?? true;

          if (!shouldNotify) {
            debugPrint('Notification suppressed user preferences: $type');
            return;
          }
        }
      } catch (e) {
        debugPrint(
            'Warning: Could not fetch notification_settings. Proceeding to send anyway. Error: $e');
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
      try {
        await Supabase.instance.client
            .from('debug_logs')
            .insert({'message': 'Error sending notification: $e'});
      } catch (_) {}
    }
  }

  static Future<void> notifyNearbyActivity({
    required String creatorId,
    required String activityId,
    required String title,
    required String locationName,
    required String hostName,
    required double lat,
    required double lng,
    required bool isRushIn,
    required String activityCity,
    double radiusKm = 5.0,
    bool isAnonymous = false,
  }) async {
    try {
      debugPrint(
          '[NotifBlast] Starting notification blast via RPC. isRushIn=$isRushIn radius=${radiusKm}km lat=$lat lng=$lng');

      final resolvedLocation =
          await _resolveLocationName(locationName, lat, lng);
      debugPrint('[NotifBlast] Resolved location: $resolvedLocation');

      final String notificationTitle;
      final String notificationBody;
      if (isRushIn) {
        notificationTitle = isAnonymous
            ? 'New Rush-in Nearby! ⚡'
            : '$hostName created a Rush-in! ⚡';
        notificationBody = isAnonymous
            ? 'Someone created a rush-in near $resolvedLocation'
            : '$title near $resolvedLocation';
      } else {
        notificationTitle = isAnonymous
            ? 'New Activity Nearby! 📍'
            : '$hostName created an Activity! 📅';
        notificationBody = isAnonymous
            ? 'Someone created an activity near $resolvedLocation'
            : '$title near $resolvedLocation';
      }

      await _supabase.rpc('broadcast_nearby_notifications', params: {
        'p_creator_id': creatorId,
        'p_activity_id': activityId,
        'p_title': notificationTitle,
        'p_body': notificationBody,
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_type': 'nearby_activity',
        'p_payload': {'activity_id': activityId},
      });

      debugPrint('[NotifBlast] Done initiating blast via RPC.');
    } catch (e) {
      debugPrint('[NotifBlast] Fatal error: $e');
    }
  }

  /// Resolves a human-readable landmark name for the notification.
  /// If [locationName] already looks like a specific place (not just a city),
  /// returns it as-is. Otherwise, reverse-geocodes [lat]/[lng] to find the
  /// nearest landmark (hospital, park, road, etc.).
  static Future<String> _resolveLocationName(
      String locationName, double lat, double lng) async {
    // If a specific location was already provided, use it directly
    if (locationName.trim().isNotEmpty) {
      // Check if it looks like a generic city-level name (e.g. "Lucknow, UP")
      // Heuristic: if it contains a comma and is short, it's probably just a city
      final parts = locationName.split(',');
      final firstPart = parts.first.trim();
      // If the first part alone is reasonably specific (>3 words or no comma), keep it
      if (parts.length <= 1 || firstPart.split(' ').length > 2) {
        return locationName.trim();
      }
    }

    // Reverse-geocode the pin to find the nearest landmark
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final res = await http.get(url, headers: {'User-Agent': 'MeetraApp/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        // Try to find a specific landmark in priority order
        final landmark = data['name'] ??
            address['amenity'] ??
            address['building'] ??
            address['shop'] ??
            address['leisure'] ??
            address['historic'] ??
            address['tourism'];

        if (landmark != null && landmark.toString().trim().isNotEmpty) {
          return landmark.toString().trim();
        }

        // Fall back to road + neighbourhood
        final road = address['road'] ?? address['pedestrian'];
        final area =
            address['neighbourhood'] ?? address['suburb'] ?? address['village'];
        if (road != null) {
          return area != null ? '$road, $area' : road.toString();
        }
        if (area != null) return area.toString();
      }
    } catch (e) {
      debugPrint('Reverse geocode for notification failed: $e');
    }

    // Last resort: return whatever was originally passed
    return locationName.trim().isNotEmpty ? locationName.trim() : 'your area';
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('user_id', userId);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications(
      String userId) async {
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
