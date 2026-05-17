// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../messages_screen.dart';
import '../notifications_screen.dart';

/// Shared header action buttons (messages + notifications) used by all
/// main screens except ProfileScreen.
/// Drop this anywhere in a header Row to get consistent, fully-wired icons.
class AppHeaderActions extends StatefulWidget {
  /// Icon/container colour for the buttons. Defaults to white 10% alpha.
  final Color? containerColor;
  /// Icon colour. Defaults to white.
  final Color? iconColor;
  /// Border colour. Defaults to white 10% alpha.
  final Color? borderColor;
  /// Radius for the icon button container. Defaults to circle (null = circle).
  final double? radius;
  /// Size of the icon inside.
  final double iconSize;
  /// Whether to show the messages button. Defaults to true.
  final bool showMessages;
  /// Whether to show the notifications button. Defaults to true.
  final bool showNotifications;

  const AppHeaderActions({
    super.key,
    this.containerColor,
    this.iconColor,
    this.borderColor,
    this.radius,
    this.iconSize = 20,
    this.showMessages = true,
    this.showNotifications = true,
  });

  @override
  State<AppHeaderActions> createState() => _AppHeaderActionsState();
}

class _AppHeaderActionsState extends State<AppHeaderActions> {
  int _unreadMessages = 0;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _fetchBadgeCounts();
  }

  Future<void> _fetchBadgeCounts() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Unread messages: messages sent to me that are not read
      final msgs = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('receiver_id', uid)
          .eq('is_read', false)
          .limit(99);
      final msgCount = (msgs as List).length;

      // Unread notifications
      final notifs = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('is_read', false)
          .limit(99);
      final notifCount = (notifs as List).length;

      if (mounted) {
        setState(() {
          _unreadMessages = msgCount;
          _unreadNotifs = notifCount;
        });
      }
    } catch (_) {
      // Silently ignore — badges are non-critical
    }
  }

  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    ).then((_) => _fetchBadgeCounts());
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    ).then((_) => _fetchBadgeCounts());
  }

  Widget _btn({required IconData icon, required VoidCallback onTap, int badge = 0}) {
    final bg = widget.containerColor ?? Colors.white.withValues(alpha: 0.08);
    final iconColor = widget.iconColor ?? Colors.white;
    final border = widget.borderColor ?? Colors.white.withValues(alpha: 0.12);

    final container = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        shape: widget.radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.radius != null ? BorderRadius.circular(widget.radius!) : null,
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: iconColor, size: widget.iconSize),
    );

    return GestureDetector(
      onTap: onTap,
      child: badge > 0
          ? Badge(
              label: Text(badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(fontSize: 9)),
              child: container,
            )
          : container,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showMessages)
          _btn(
            icon: Icons.chat_bubble_outline,
            onTap: _openMessages,
            badge: _unreadMessages,
          ),
        if (widget.showMessages && widget.showNotifications) const SizedBox(width: 8),
        if (widget.showNotifications)
          _btn(
            icon: Icons.notifications_outlined,
            onTap: _openNotifications,
            badge: _unreadNotifs,
          ),
      ],
    );
  }
}
