import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/touch_scale.dart';
import 'messages_screen.dart';
import 'services/notification_service.dart';
import 'main.dart'; // For CosmicBackgroundPainter

// Reuse NotificationType from service if possible, or redefine for UI
enum AppNotificationType { match, nearbyActivity, approval, rejection, message, system }

class NotificationModel {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String timeText;
  final String? avatarUrl;
  final String? senderId;
  final Map<String, dynamic> payload;
  final bool isUnread;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeText,
    required this.payload,
    this.avatarUrl,
    this.senderId,
    this.isUnread = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Matches', 'Nearby', 'Updates', 'Chats'];
  final String _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  AppNotificationType _mapType(String type) {
    switch (type) {
      case 'match': return AppNotificationType.match;
      case 'nearby_activity': return AppNotificationType.nearbyActivity;
      case 'approval': return AppNotificationType.approval;
      case 'rejection': return AppNotificationType.rejection;
      case 'message': return AppNotificationType.message;
      default: return AppNotificationType.system;
    }
  }

  List<NotificationModel> _parseNotifications(List<Map<String, dynamic>> data) {
    return data.map((n) {
      final typeStr = n['type'] as String? ?? 'system';
      final type = _mapType(typeStr);
      final isUnread = n['is_read'] == false;
      final payload = n['payload'] as Map<String, dynamic>? ?? {};
      
      String timeText = 'Just now';
      if (n['created_at'] != null) {
        try {
          final dt = DateTime.parse(n['created_at']).toLocal();
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 60) {
            timeText = '${diff.inMinutes}m ago';
          } else if (diff.inHours < 24) {
            timeText = '${diff.inHours}h ago';
          } else {
            timeText = '${diff.inDays}d ago';
          }
        } catch (_) {}
      }

      String? avatarUrl;
      if (payload['sender_id'] != null) {
        avatarUrl = 'https://picsum.photos/seed/${payload['sender_id']}/300/300';
      }

      return NotificationModel(
        id: n['id'].toString(),
        type: type,
        title: n['title'] ?? 'Notification',
        body: n['body'] ?? '',
        timeText: timeText,
        isUnread: isUnread,
        payload: payload,
        avatarUrl: avatarUrl,
        senderId: payload['sender_id']?.toString(),
      );
    }).toList();
  }

  List<NotificationModel> _filterItems(List<NotificationModel> items) {
    if (_activeFilter == 'All') return items;
    return items.where((n) {
      switch (_activeFilter) {
        case 'Matches': return n.type == AppNotificationType.match;
        case 'Nearby': return n.type == AppNotificationType.nearbyActivity;
        case 'Updates': return n.type == AppNotificationType.approval || n.type == AppNotificationType.rejection;
        case 'Chats': return n.type == AppNotificationType.message;
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF00E5FF), size: 22),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await NotificationService.markAllAsRead(_currentUserId);
              messenger.showSnackBar(
                const SnackBar(content: Text('All marked as read'), backgroundColor: Color(0xFF10B981)),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CosmicBackgroundPainter(0.5),
            ),
          ),
          Column(
            children: [
              _buildFilters(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('notifications')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', _currentUserId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading();
                }
                
                final raw = snapshot.data ?? [];
                final parsed = _parseNotifications(raw);
                final items = _filterItems(parsed);
                
                return _buildList(items);
              },
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TouchScale(
              onTap: () => setState(() {
                  _activeFilter = filter;
                  HapticFeedback.lightImpact();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.15),
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<NotificationModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, color: Colors.white.withValues(alpha: 0.2), size: 60),
            const SizedBox(height: 16),
            const Text("You're all caught up!", style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text("New updates will appear here", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final notif = items[index];
        return _buildNotificationCard(notif);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    IconData icon;
    Color iconColor;
    
    switch (notif.type) {
      case AppNotificationType.match:
        icon = Icons.favorite;
        iconColor = const Color(0xFFF43F5E);
        break;
      case AppNotificationType.nearbyActivity:
        icon = Icons.location_on;
        iconColor = const Color(0xFF00E5FF);
        break;
      case AppNotificationType.approval:
        icon = Icons.check_circle;
        iconColor = const Color(0xFF22C55E);
        break;
      case AppNotificationType.rejection:
        icon = Icons.cancel;
        iconColor = const Color(0xFFEF4444);
        break;
      case AppNotificationType.message:
        icon = Icons.chat_bubble;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case AppNotificationType.system:
        icon = Icons.notifications;
        iconColor = const Color(0xFF3B82F6);
        break;
    }

    return GestureDetector(
      onTap: () async {
        if (notif.isUnread) {
          await NotificationService.markAsRead(notif.id);
        }
        
        // Handle navigation based on type
        if (!mounted) return;
        if (notif.type == AppNotificationType.message || notif.type == AppNotificationType.match) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isUnread ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: notif.isUnread ? iconColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
          boxShadow: notif.isUnread ? [BoxShadow(color: iconColor.withValues(alpha: 0.15), blurRadius: 15)] : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.avatarUrl != null)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: CircleAvatar(backgroundImage: NetworkImage(notif.avatarUrl!), radius: 24),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title, 
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: notif.isUnread ? FontWeight.w800 : FontWeight.w600, 
                            fontSize: 15,
                            letterSpacing: -0.2
                          ),
                        ),
                      ),
                      Text(notif.timeText, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(color: notif.isUnread ? Colors.white70 : Colors.white54, fontSize: 13, height: 1.4),
                  ),
                  if (notif.isUnread) 
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('NEW', style: TextStyle(color: iconColor, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
