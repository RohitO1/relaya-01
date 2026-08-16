import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../main.dart'; // To get CosmicBackgroundPainter if needed

// ────────────────────────────────────────────────────────────────
// Helper functions for displaying profile details
// ────────────────────────────────────────────────────────────────
bool hasLifestyle(Map<String, dynamic> p) {
  return (p['drinking']?.toString().isNotEmpty ?? false) ||
      (p['smoking']?.toString().isNotEmpty ?? false) ||
      (p['weed']?.toString().isNotEmpty ?? false) ||
      (p['exercise']?.toString().isNotEmpty ?? false) ||
      (p['diet']?.toString().isNotEmpty ?? false);
}

bool hasMoreAboutMe(Map<String, dynamic> p) {
  return (p['education']?.toString().isNotEmpty ?? false) ||
      (p['job_title']?.toString().isNotEmpty ?? false) ||
      (p['zodiac']?.toString().isNotEmpty ?? false) ||
      (p['religion']?.toString().isNotEmpty ?? false) ||
      (p['relationship_type']?.toString().isNotEmpty ?? false);
}

Widget buildProfileSection(String title, IconData icon, List<Widget> children) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

Widget buildDetailRow(IconData icon, String text, {String? subtitle}) {
  Color iconColor = Colors.white54;
  if (icon == Icons.location_on_outlined) {
    iconColor = const Color(0xFFFF6B00);
  } else if (icon == Icons.height) {
    iconColor = const Color(0xFFFACC15);
  } else if (icon == Icons.person_outline) {
    iconColor = const Color(0xFFFF3D00);
  } else if (icon == Icons.search) {
    iconColor = const Color(0xFF3B82F6);
  } else if (icon == Icons.wine_bar_outlined) {
    iconColor = const Color(0xFFEF4444);
  } else if (icon == Icons.smoking_rooms_outlined) {
    iconColor = const Color(0xFF9CA3AF);
  } else if (icon == Icons.grass_outlined) {
    iconColor = const Color(0xFF10B981);
  } else if (icon == Icons.fitness_center_outlined) {
    iconColor = const Color(0xFFF97316);
  } else if (icon == Icons.restaurant_outlined) {
    iconColor = const Color(0xFFEAB308);
  } else if (icon == Icons.school_outlined) {
    iconColor = const Color(0xFFFF7E40);
  } else if (icon == Icons.work_outline) {
    iconColor = const Color(0xFF06B6D4);
  } else if (icon == Icons.auto_awesome_outlined) {
    iconColor = const Color(0xFFD946EF);
  } else if (icon == Icons.church_outlined) {
    iconColor = const Color(0xFF38D9A9);
  } else if (icon == Icons.favorite_border) {
    iconColor = const Color(0xFFF43F5E);
  } else {
    iconColor = const Color(0xFFFF6B00);
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildPill(String text,
    {bool isHighlight = false, bool isInterest = false, bool isSmall = false}) {
  Color pillColor = isHighlight ? const Color(0xFF38D9A9) : Colors.white70;
  Color bgColor = isHighlight
      ? const Color(0xFF38D9A9).withValues(alpha: 0.1)
      : Colors.white.withValues(alpha: 0.05);
  Color borderColor = isHighlight
      ? const Color(0xFF38D9A9).withValues(alpha: 0.3)
      : Colors.white.withValues(alpha: 0.08);
  IconData? icon;

  if (isInterest) {
    final lower = text.toLowerCase();
    if (lower.contains('study')) {
      icon = Icons.menu_book;
      pillColor = const Color(0xFF3B82F6);
    } else if (lower.contains('fit') || lower.contains('gym')) {
      icon = Icons.fitness_center;
      pillColor = const Color(0xFFEF4444);
    } else if (lower.contains('music')) {
      icon = Icons.music_note;
      pillColor = const Color(0xFFFF7E40);
    } else if (lower.contains('start') || lower.contains('busin')) {
      icon = Icons.rocket_launch;
      pillColor = const Color(0xFFF59E0B);
    } else if (lower.contains('travel')) {
      icon = Icons.flight;
      pillColor = const Color(0xFF06B6D4);
    } else if (lower.contains('game') || lower.contains('gaming')) {
      icon = Icons.sports_esports;
      pillColor = const Color(0xFF10B981);
    } else if (lower.contains('photo')) {
      icon = Icons.camera_alt;
      pillColor = const Color(0xFFFF3D00);
    } else if (lower.contains('cook') || lower.contains('food')) {
      icon = Icons.restaurant;
      pillColor = const Color(0xFFF97316);
    } else if (lower.contains('art') || lower.contains('paint')) {
      icon = Icons.palette;
      pillColor = const Color(0xFFD946EF);
    } else if (lower.contains('tech') || lower.contains('code')) {
      icon = Icons.memory;
      pillColor = const Color(0xFF6366F1);
    } else if (lower.contains('dance')) {
      icon = Icons.nightlife;
      pillColor = const Color(0xFFEAB308);
    } else if (lower.contains('read') || lower.contains('book')) {
      icon = Icons.auto_stories;
      pillColor = const Color(0xFF14B8A6);
    } else {
      icon = Icons.local_fire_department;
      pillColor = const Color(0xFFFF6B00);
    }

    bgColor = pillColor.withValues(alpha: 0.15);
    borderColor = pillColor.withValues(alpha: 0.4);
  }

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isSmall ? 10 : 14,
      vertical: isSmall ? 4 : 8,
    ),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(isSmall ? 12 : 20),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: pillColor, size: isSmall ? 12 : 14),
          SizedBox(width: isSmall ? 4 : 6),
        ],
        Text(text,
            style: TextStyle(
              color: pillColor,
              fontSize: isSmall ? 11 : 13,
              fontWeight:
                  isHighlight || isInterest ? FontWeight.w600 : FontWeight.w500,
            )),
      ],
    ),
  );
}

Widget buildActionButton(
    String text, Color color, BuildContext context, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );
}

// ────────────────────────────────────────────────────────────────
// Message Request Widget — replaces old "Send a Compliment"
// ────────────────────────────────────────────────────────────────
class _MessageRequestWidget extends StatefulWidget {
  final String targetUserId;
  final String targetName;
  final VoidCallback? onSent;

  const _MessageRequestWidget({
    required this.targetUserId,
    required this.targetName,
    this.onSent,
  });

  @override
  State<_MessageRequestWidget> createState() => _MessageRequestWidgetState();
}

class _MessageRequestWidgetState extends State<_MessageRequestWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();

  // null = loading, 'none' = no request sent, 'pending' = request sent awaiting reply, 'accepted' = replied
  String? _requestStatus;
  bool _sending = false;
  final int _maxChars = 280;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _checkStatus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null) {
      setState(() => _requestStatus = 'none');
      return;
    }
    try {
      // Check if I have sent ANY message to target
      final sentRes = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('sender_id', myUid)
          .eq('receiver_id', widget.targetUserId)
          .limit(1);

      if ((sentRes as List).isEmpty) {
        setState(() => _requestStatus = 'none');
        return;
      }

      // Check if target has replied (sent me any message)
      final replyRes = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('sender_id', widget.targetUserId)
          .eq('receiver_id', myUid)
          .limit(1);

      setState(() {
        _requestStatus = (replyRes as List).isNotEmpty ? 'accepted' : 'pending';
      });
    } catch (_) {
      setState(() => _requestStatus = 'none');
    }
  }

  Future<void> _sendRequest() async {
    if (_ctrl.text.trim().isEmpty) return;
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': myUid,
        'receiver_id': widget.targetUserId,
        'text': _ctrl.text.trim(),
        'is_image': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Fire push notification to recipient
      await NotificationService.sendNotification(
        userId: widget.targetUserId,
        type: NotificationType.message,
        title: 'New Message Request ✉️',
        body: 'Someone wants to connect with you.',
      );

      setState(() {
        _sending = false;
        _requestStatus = 'pending';
      });
      widget.onSent
          ?.call(); // Trigger the callback so parent UI updates instantly
    } catch (e) {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requestStatus == null) {
      return const SizedBox(
        height: 80,
        child: Center(
            child: CircularProgressIndicator(
                color: Color(0xFFFF6B00), strokeWidth: 2)),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _requestStatus == 'accepted'
              ? const Color(0xFF22C55E).withValues(alpha: 0.35)
              : _requestStatus == 'pending'
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_requestStatus == 'accepted'
                    ? const Color(0xFF22C55E)
                    : _requestStatus == 'pending'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFFF6B00))
                .withValues(alpha: 0.08),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _requestStatus == 'accepted'
            ? _buildAccepted()
            : _requestStatus == 'pending'
                ? _buildPending()
                : _buildInput(),
      ),
    );
  }

  // ── Status: No request sent yet (input visible)
  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  color: Color(0xFFFF6B00), size: 16),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message Request',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('One message until they reply',
                    style:
                        GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (_, val, __) {
            final count = val.text.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _ctrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                  maxLength: _maxChars,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      const SizedBox.shrink(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write your message to ${widget.targetName}...',
                    hintStyle:
                        GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color:
                              const Color(0xFFFF6B00).withValues(alpha: 0.4)),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count/$_maxChars',
                  style: GoogleFonts.inter(
                    color: count > _maxChars * 0.85
                        ? const Color(0xFFF59E0B)
                        : Colors.white24,
                    fontSize: 10,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _sending ? null : _sendRequest,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: _sending
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)]),
              color: _sending ? Colors.white10 : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _sending
                  ? null
                  : [
                      BoxShadow(
                          color:
                              const Color(0xFFFF6B00).withValues(alpha: 0.35),
                          blurRadius: 12)
                    ],
            ),
            alignment: Alignment.center,
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('Send Request',
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Status: Request sent, awaiting reply
  Widget _buildPending() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) =>
              Opacity(opacity: _pulseAnim.value, child: child),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.schedule_send_rounded,
                color: Color(0xFFF59E0B), size: 28),
          ),
        ),
        const SizedBox(height: 14),
        Text('Request Sent',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Your message is waiting for ${widget.targetName} to accept it. You can start chatting once they reply.',
          style: GoogleFonts.inter(
              color: Colors.white38, fontSize: 12, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Status: Accepted (they replied)
  Widget _buildAccepted() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.mark_chat_read_rounded,
              color: Color(0xFF22C55E), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connected!',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF22C55E),
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                  '${widget.targetName} replied. Open your messages to continue the conversation.',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 11, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Main sheet entry point
// ────────────────────────────────────────────────────────────────

void showMessageRequestSheet(BuildContext context, Map<String, dynamic> p,
    {VoidCallback? onSent}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header: Avatar & Name
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)]),
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF16161E),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.network(
                    p['avatar_url']?.toString() ??
                        'https://picsum.photos/seed/${p['id']}/100',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p['name']?.toString() ?? 'User',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Direct Request',
              style: GoogleFonts.inter(
                color: const Color(0xFFFF6B00),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 28),

            _MessageRequestWidget(
              targetUserId:
                  p['user_id']?.toString() ?? p['id']?.toString() ?? '',
              targetName: p['name']?.toString() ?? 'User',
              onSent: onSent,
            ),
          ],
        ),
      ),
    ),
  );
}

void showFullProfileSheet(BuildContext context, Map<String, dynamic> p) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D12),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CosmicBackgroundPainter(0.5),
                    ),
                  ),
                  ListView(
                    controller: scroll,
                    padding: EdgeInsets.zero,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      // Large Photo
                      Container(
                        height: 420,
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          image: (p['avatar'] != null &&
                                  p['avatar'].toString().isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(p['avatar']),
                                  fit: BoxFit.cover)
                              : (p['avatar_url'] != null &&
                                      p['avatar_url'].toString().isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(p['avatar_url']),
                                      fit: BoxFit.cover)
                                  : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${p['name'] ?? 'User'}, ',
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text('${p['age'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),

                      // About Me
                      if ((p['bio']?.toString().isNotEmpty ?? false) ||
                          (p['about']?.toString().isNotEmpty ?? false))
                        buildProfileSection(
                            'About me', Icons.format_quote_rounded, [
                          Text(p['bio'] ?? p['about'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.5)),
                        ]),

                      // Essentials
                      buildProfileSection(
                          'Essentials', Icons.assignment_outlined, [
                        buildDetailRow(Icons.location_on_outlined,
                            '${p['distance'] ?? '< 1 miles'} away'),
                        if (p['height_cm'] != null && p['height_cm'] > 0)
                          buildDetailRow(Icons.height, '${p['height_cm']} cm'),
                        if (p['gender'] != null &&
                            p['gender'].toString().isNotEmpty)
                          buildDetailRow(Icons.person_outline, p['gender']),
                        if (p['match_gender'] != null &&
                            p['match_gender'].toString().isNotEmpty)
                          buildDetailRow(
                              Icons.search, 'Looking for ${p['match_gender']}'),
                      ]),

                      // Personality Prompt
                      if ((p['personality_traits'] as List?)?.isNotEmpty ??
                          false)
                        buildProfileSection(
                            'My personality', Icons.psychology_outlined, [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (p['personality_traits'] as List)
                                .map<Widget>((t) =>
                                    buildPill(t.toString(), isHighlight: true))
                                .toList(),
                          )
                        ]),

                      // Lifestyle
                      if (hasLifestyle(p))
                        buildProfileSection(
                            'Lifestyle', Icons.local_cafe_outlined, [
                          if (p['drinking'] != null &&
                              p['drinking'].toString().isNotEmpty)
                            buildDetailRow(
                                Icons.wine_bar_outlined, p['drinking'],
                                subtitle: 'Drinking'),
                          if (p['smoking'] != null &&
                              p['smoking'].toString().isNotEmpty)
                            buildDetailRow(
                                Icons.smoking_rooms_outlined, p['smoking'],
                                subtitle: 'Smoking'),
                          if (p['weed'] != null &&
                              p['weed'].toString().isNotEmpty)
                            buildDetailRow(Icons.grass_outlined, p['weed'],
                                subtitle: 'Cannabis'),
                          if (p['exercise'] != null &&
                              p['exercise'].toString().isNotEmpty)
                            buildDetailRow(
                                Icons.fitness_center_outlined, p['exercise'],
                                subtitle: 'Workout'),
                          if (p['diet'] != null &&
                              p['diet'].toString().isNotEmpty)
                            buildDetailRow(Icons.restaurant_outlined, p['diet'],
                                subtitle: 'Diet'),
                        ]),

                      // More about me
                      if (hasMoreAboutMe(p))
                        buildProfileSection(
                            'More about me', Icons.info_outline, [
                          if (p['education'] != null &&
                              p['education'].toString().isNotEmpty)
                            buildDetailRow(
                                Icons.school_outlined, p['education'],
                                subtitle: 'Education'),
                          if (p['job_title'] != null &&
                              p['job_title'].toString().isNotEmpty)
                            buildDetailRow(Icons.work_outline, p['job_title'],
                                subtitle: 'Work'),
                          if (p['zodiac'] != null &&
                              p['zodiac'].toString().isNotEmpty)
                            buildDetailRow(
                                Icons.auto_awesome_outlined, p['zodiac'],
                                subtitle: 'Zodiac'),
                          if (p['religion'] != null &&
                              p['religion'].toString().isNotEmpty)
                            buildDetailRow(Icons.church_outlined, p['religion'],
                                subtitle: 'Religion'),
                          if (p['relationship_type'] != null &&
                              p['relationship_type'].toString().isNotEmpty)
                            buildDetailRow(
                                Icons.favorite_border, p['relationship_type'],
                                subtitle: 'Looking for'),
                        ]),

                      // Interests
                      if ((p['interests'] as List?)?.isNotEmpty ?? false)
                        buildProfileSection(
                            'Interests', Icons.grid_view_rounded, [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (p['interests'] as List)
                                .map<Widget>((t) =>
                                    buildPill(t.toString(), isInterest: true))
                                .toList(),
                          )
                        ]),

                      const SizedBox(height: 32),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
