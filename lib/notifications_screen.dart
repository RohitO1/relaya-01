import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/touch_scale.dart';
import 'messages_screen.dart';
import 'services/notification_service.dart';

// Reuse NotificationType from service if possible, or redefine for UI
enum AppNotificationType { 
  match, nearbyActivity, approval, rejection, message, system,
  bolroomMessage, bolroomSystem, bolroomFollower, bolroomChatroom
}

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
  final bool isBolroomMode;

  const NotificationsScreen({super.key, this.isBolroomMode = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _activeFilter = 'All';
  late final List<String> _filters;
  final String _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.isBolroomMode) {
      _filters = ['All', 'Rooms', 'Followers', 'Messages'];
    } else {
      _filters = ['All', 'Matches', 'Nearby', 'Updates', 'Chats'];
    }
    
    // Automatically mark all unseen notifications as seen when opening the screen
    Future.microtask(() async {
      if (_currentUserId.isNotEmpty) {
        await NotificationService.markAllAsRead(_currentUserId);
      }
    });
  }

  AppNotificationType _mapType(String type) {
    switch (type) {
      case 'match': return AppNotificationType.match;
      case 'nearby_activity': return AppNotificationType.nearbyActivity;
      case 'approval': return AppNotificationType.approval;
      case 'rejection': return AppNotificationType.rejection;
      case 'message': return AppNotificationType.message;
      case 'bolroom_message': return AppNotificationType.bolroomMessage;
      case 'bolroom_system': return AppNotificationType.bolroomSystem;
      case 'bolroom_follower': return AppNotificationType.bolroomFollower;
      case 'bolroom_chatroom': return AppNotificationType.bolroomChatroom;
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
    // 1. Filter by mode (Meetra vs Bolroom)
    items = items.where((n) {
      bool isBolroomType = (n.type == AppNotificationType.bolroomMessage ||
          n.type == AppNotificationType.bolroomSystem ||
          n.type == AppNotificationType.bolroomFollower ||
          n.type == AppNotificationType.bolroomChatroom);
      return widget.isBolroomMode ? isBolroomType : !isBolroomType;
    }).toList();

    // 2. Filter by active category
    if (_activeFilter == 'All') return items;
    return items.where((n) {
      if (widget.isBolroomMode) {
        switch (_activeFilter) {
          case 'Rooms': return n.type == AppNotificationType.bolroomChatroom;
          case 'Followers': return n.type == AppNotificationType.bolroomFollower;
          case 'Messages': return n.type == AppNotificationType.bolroomMessage;
          default: return true;
        }
      } else {
        switch (_activeFilter) {
          case 'Matches': return n.type == AppNotificationType.match;
          case 'Nearby': return n.type == AppNotificationType.nearbyActivity;
          case 'Updates': return n.type == AppNotificationType.approval || n.type == AppNotificationType.rejection;
          case 'Chats': return n.type == AppNotificationType.message;
          default: return true;
        }
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
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
            icon: const Icon(Icons.done_all, color: Color(0xFFFF6B00), size: 22),
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
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1, color: Color(0xFF1E1E24)),
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
                  color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF16161D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF27272A)),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
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
        iconColor = const Color(0xFFFF6B00);
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
        iconColor = const Color(0xFFFF7E40);
        break;
      case AppNotificationType.system:
        icon = Icons.notifications;
        iconColor = const Color(0xFF3B82F6);
        break;
      case AppNotificationType.bolroomMessage:
        icon = Icons.chat_bubble;
        iconColor = const Color(0xFFB983FF);
        break;
      case AppNotificationType.bolroomSystem:
        icon = Icons.settings_system_daydream;
        iconColor = const Color(0xFFFF6B00);
        break;
      case AppNotificationType.bolroomFollower:
        icon = Icons.person_add;
        iconColor = const Color(0xFFFF00FF);
        break;
      case AppNotificationType.bolroomChatroom:
        icon = Icons.headset_mic;
        iconColor = const Color(0xFFB983FF);
        break;
    }

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        NotificationService.deleteNotification(notif.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: GestureDetector(
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isUnread ? const Color(0xFF16161D) : const Color(0xFF0F0F14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notif.isUnread ? const Color(0xFF27272A) : const Color(0xFF1C1C22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notif.avatarUrl != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(notif.avatarUrl!),
                  radius: 18,
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (notif.isUnread) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B00),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  notif.title, 
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontWeight: notif.isUnread ? FontWeight.w700 : FontWeight.w500, 
                                    fontSize: 14,
                                    letterSpacing: -0.2
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(notif.timeText, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: TextStyle(
                        color: notif.isUnread ? Colors.white.withOpacity(0.9) : Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
