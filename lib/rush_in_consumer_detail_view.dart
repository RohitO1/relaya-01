// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';
import 'services/notification_service.dart';

ImageProvider _safeImageProvider(String url) {
  if (url.startsWith('data:image')) {
    final b64 = url.split(',').last;
    return MemoryImage(base64Decode(b64));
  }
  return NetworkImage(url);
}

class RushInConsumerDetailView extends StatefulWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onInteraction; // To trigger a discovery refresh upstream

  const RushInConsumerDetailView({
    super.key,
    required this.activity,
    required this.onInteraction,
  });

  @override
  State<RushInConsumerDetailView> createState() => _RushInConsumerDetailViewState();
}

class _RushInConsumerDetailViewState extends State<RushInConsumerDetailView> {
  String get _currentUid => Supabase.instance.client.auth.currentUser?.id ?? '';
  bool _isRequesting = false;
  bool _isDeleting = false;
  bool _isLeaving = false;
  Future<Map<String, dynamic>?>? _hostProfileFuture;

  // Profile cache so waitlist rows never re-fetch stale FutureBuilder data
  final Map<String, Map<String, dynamic>> _profileCache = {};
  // Per-row loading state: requestId → true while approve/reject is in-flight
  final Map<String, bool> _rowLoading = {};

  Future<void> _loadProfilesForRequests(List<Map<String, dynamic>> requests) async {
    final ids = requests.map((r) => r['sender_id'].toString()).toSet()
        .where((id) => !_profileCache.containsKey(id)).toList();
    if (ids.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('profiles').select('id,name,full_name,avatar_url').inFilter('id', ids);
      if (mounted) {
        setState(() {
          for (final r in (rows as List)) {
            _profileCache[r['id'].toString()] = Map<String, dynamic>.from(r);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _hostProfileFuture = Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', widget.activity['user_id'])
        .maybeSingle();
  }

  Future<void> _approveRequest(String requestId, String senderId) async {
    if (_rowLoading[requestId] == true) return;
    setState(() => _rowLoading[requestId] = true);
    final activityTitle = widget.activity['title'] ?? 'an activity';
    try {
      await Supabase.instance.client
          .from('requests')
          .update({'status': 'approved'})
          .eq('id', requestId);
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUid,
        'receiver_id': senderId,
        'text': 'You have been approved to join "$activityTitle"!',
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Send notification to the approved user
      await NotificationService.sendNotification(
        userId: senderId,
        type: NotificationType.approval,
        title: 'Request Approved!',
        body: 'You have been approved to join "$activityTitle"!',
        payload: {'activity_id': widget.activity['id']},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved!'), backgroundColor: Color(0xFF10B981)));
      widget.onInteraction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _rowLoading.remove(requestId));
    }
  }

  Future<void> _rejectRequest(String requestId, String senderId) async {
    if (_rowLoading[requestId] == true) return;
    setState(() => _rowLoading[requestId] = true);
    final activityTitle = widget.activity['title'] ?? 'an activity';
    try {
      await Supabase.instance.client.from('requests').delete().eq('id', requestId);
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUid,
        'receiver_id': senderId,
        'text': 'Your request to join "$activityTitle" was declined.',
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send notification to the rejected user
      await NotificationService.sendNotification(
        userId: senderId,
        type: NotificationType.rejection,
        title: 'Request Declined',
        body: 'Your request to join "$activityTitle" was declined.',
        payload: {'activity_id': widget.activity['id']},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected.'), backgroundColor: Colors.grey));
      widget.onInteraction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _rowLoading.remove(requestId));
    }
  }

  Future<void> _leaveActivity() async {
    final activityId = widget.activity['id'];
    final activityTitle = widget.activity['title'] ?? 'Untitled Activity';
    final hostId = widget.activity['user_id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101015),
        title: const Text('Leave Activity?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to leave this activity? The host will be notified.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('LEAVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLeaving = true);
    try {
      // 1. Delete the request
      await Supabase.instance.client
          .from('requests')
          .delete()
          .eq('sender_id', _currentUid)
          .eq('target_id', activityId);

      // 2. Notify the host about the vacancy and waitlist
      final notificationText = 'VACANCY: A participant has left your activity "$activityTitle". Check your waitlist to approve a new member!';
      
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUid,
        'receiver_id': hostId,
        'text': notificationText,
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify the host
      await NotificationService.sendNotification(
        userId: hostId,
        type: NotificationType.system,
        title: 'Vacancy Available',
        body: notificationText,
        payload: {'activity_id': activityId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have left the activity.'), backgroundColor: Colors.amber));
      
      widget.onInteraction();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Leave failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to leave: $e'), backgroundColor: Colors.red));
        setState(() => _isLeaving = false);
      }
    }
  }

  Future<void> _submitJoinRequest() async {
    setState(() => _isRequesting = true);
    try {
      final actId = widget.activity['id'];
      
      // Check if already requested
      final existing = await Supabase.instance.client
          .from('requests')
          .select()
          .eq('sender_id', _currentUid)
          .eq('target_id', actId)
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already requested to join!'), backgroundColor: Colors.amber));
      } else {
        await Supabase.instance.client.from('requests').insert({
          'sender_id': _currentUid,
          'target_id': actId,
          'target_type': 'activity',
          'status': 'pending',
          'message': 'Let me in to this Rush-In! ⚡'
        });

        // Notify the host
        final hostId = widget.activity['user_id'];
        final actTitle = widget.activity['title'] ?? 'your activity';
        if (hostId != null) {
          await NotificationService.sendNotification(
            userId: hostId,
            type: NotificationType.approval,
            title: 'New Join Request!',
            body: 'Someone requested to join "$actTitle".',
            payload: {'activity_id': actId},
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Request Sent! Host will review.'), backgroundColor: Color(0xFFFF6B00)));
        widget.onInteraction(); // Notify parent to remove from feed
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _deleteRushIn() async {
    final activityId = widget.activity['id'];
    final activityTitle = widget.activity['title'] ?? 'Untitled Activity';
    final isHost = _currentUid == widget.activity['user_id'];

    if (isHost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF101015),
          title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
          content: const Text('This will notify all participants and permanently delete the activity from everyone\'s feed. Proceed?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isDeleting = true);
    try {
      if (isHost) {
        // 1. Fetch all participants to notify them
        final List<dynamic> participants = await Supabase.instance.client
            .from('requests')
            .select('sender_id')
            .eq('target_id', activityId);

        if (participants.isNotEmpty) {
          debugPrint('NOTIFYING ${participants.length} PARTICIPANTS...');
          final notificationText = 'ACTIVITY CANCELLED: The host has deleted the activity "$activityTitle".';
          
          final messagesToInsert = participants.map((p) => {
            'sender_id': _currentUid,
            'receiver_id': p['sender_id'],
            'text': notificationText,
            'is_image': false,
            'created_at': DateTime.now().toIso8601String(),
          }).toList();

          await Supabase.instance.client.from('messages').insert(messagesToInsert);

          for (final p in participants) {
            await NotificationService.sendNotification(
              userId: p['sender_id'],
              type: NotificationType.system,
              title: 'Activity Cancelled',
              body: notificationText,
              payload: {'activity_id': activityId},
            );
          }
        }

        // 2. Delete all associated requests
        await Supabase.instance.client
            .from('requests')
            .delete()
            .eq('target_id', activityId);
            
        // 3. Delete the activity itself
        await Supabase.instance.client
            .from('activities')
            .delete()
            .eq('id', activityId);
            
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity deleted and participants notified.'), backgroundColor: Colors.redAccent));
      } else {
        // Participant Soft Delete (Hide from feed)
        await Supabase.instance.client.from('hidden_feed').insert({
          'user_id': _currentUid,
          'rush_in_id': activityId, 
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity removed from your feed.'), backgroundColor: Colors.white24));
      }
      
      widget.onInteraction();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Deletion failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e'), backgroundColor: Colors.red));
        setState(() => _isDeleting = false);
      }
    }
  }

  Widget _buildAttendeesOverlap(List<Map<String, dynamic>> approvedRequests) {
    if (approvedRequests.isEmpty) {
      return Text(
        'No participants yet. Be the first to join!',
        style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14),
      );
    }
    List<Widget> children = [];
    int maxShow = 5;
    for (int i = 0; i < approvedRequests.length && i < maxShow; i++) {
      final req = approvedRequests[i];
      final avatar = req['sender_avatar']?.toString() ?? 'https://picsum.photos/seed/user$i/200';
      children.add(
        Align(
          widthFactor: 0.7,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF000000), width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: _safeImageProvider(avatar),
            ),
          ),
        ),
      );
    }
    if (approvedRequests.length > maxShow) {
      children.add(
        Align(
          widthFactor: 0.7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF000000), width: 2),
            ),
            child: Text(
              '+${approvedRequests.length - maxShow}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: children);
  }

  // ── Tabbed Attendee Modal ─────────────────────────────────────────────────
  void _showAttendeesModal(
    List<Map<String, dynamic>> approvedRequests,
    List<Map<String, dynamic>> pendingRequests,
    bool isHost,
  ) {
    // Pre-load all profiles we'll need
    _loadProfilesForRequests([...approvedRequests, ...pendingRequests]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0E14),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Column(
                  children: [
                    // ── Drag handle ──
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Manage Participants',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Tabs ──
                    TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      indicatorColor: const Color(0xFFFF7A00),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(text: 'APPROVED (${approvedRequests.length})'),
                        Tab(text: 'WAITLIST (${pendingRequests.length})'),
                      ],
                    ),

                    // ── Tab Content ──
                    Expanded(
                      child: TabBarView(
                        children: [
                          // ── APPROVED TAB ──
                          approvedRequests.isEmpty
                              ? _buildEmptyTabState('No approved attendees yet.', Icons.people_alt_outlined)
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                  itemCount: approvedRequests.length,
                                  itemBuilder: (_, i) {
                                    final r = approvedRequests[i];
                                    final sid = r['sender_id'].toString();
                                    final rid = r['id'].toString();
                                    final cached = _profileCache[sid];
                                    final name = cached?['name'] ?? cached?['full_name'] ?? 'User';
                                    String avatar = cached?['avatar_url'] ?? 'https://picsum.photos/seed/$sid/200';
                                    if (avatar.isNotEmpty && !avatar.startsWith('http') && !avatar.startsWith('data:')) {
                                      avatar = 'https://picsum.photos/seed/$sid/200';
                                    }
                                    return _buildAttendeeRow(
                                      name: name,
                                      avatar: avatar,
                                      label: 'Approved',
                                      labelColor: const Color(0xFF10B981),
                                      isHost: isHost,
                                      trailing: isHost
                                          ? _pillButton(
                                              label: 'Remove',
                                              color: const Color(0xFFEF4444),
                                              onTap: () async {
                                                await _rejectRequest(rid, sid);
                                                if (mounted) setSheet(() {});
                                              },
                                            )
                                          : null,
                                    );
                                  },
                                ),

                          // ── WAITLIST TAB ──
                          pendingRequests.isEmpty
                              ? _buildEmptyTabState('No candidates in the waitlist.', Icons.hourglass_empty_outlined)
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                  itemCount: pendingRequests.length,
                                  itemBuilder: (_, i) {
                                    final r = pendingRequests[i];
                                    final sid = r['sender_id'].toString();
                                    final rid = r['id'].toString();
                                    final cached = _profileCache[sid];
                                    final name = cached?['name'] ?? cached?['full_name'] ?? 'User';
                                    String avatar = cached?['avatar_url'] ?? 'https://picsum.photos/seed/$sid/200';
                                    if (avatar.isNotEmpty && !avatar.startsWith('http') && !avatar.startsWith('data:')) {
                                      avatar = 'https://picsum.photos/seed/$sid/200';
                                    }
                                    final isLoading = _rowLoading[rid] == true;
                                    return _buildAttendeeRow(
                                      name: name,
                                      avatar: avatar,
                                      label: 'Pending',
                                      labelColor: const Color(0xFFFF9F0A),
                                      isHost: isHost,
                                      trailing: isHost
                                          ? isLoading
                                              ? const SizedBox(
                                                  width: 20, height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    _pillButton(
                                                      label: 'Accept',
                                                      color: const Color(0xFF10B981),
                                                      icon: Icons.check,
                                                      onTap: () async {
                                                        await _approveRequest(rid, sid);
                                                        if (mounted) setSheet(() {});
                                                      },
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _pillButton(
                                                      label: 'Decline',
                                                      color: const Color(0xFFEF4444),
                                                      icon: Icons.close,
                                                      onTap: () async {
                                                        await _rejectRequest(rid, sid);
                                                        if (mounted) setSheet(() {});
                                                      },
                                                    ),
                                                  ],
                                                )
                                          : null,
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyTabState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white12, size: 52),
          const SizedBox(height: 14),
          Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAttendeeRow({
    required String name,
    required String avatar,
    required String label,
    required Color labelColor,
    required bool isHost,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: avatar.startsWith('data:')
                  ? Image.memory(base64Decode(avatar.split(',').last), fit: BoxFit.cover)
                  : Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.2),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF7A00),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[ Icon(icon, color: color, size: 12), const SizedBox(width: 4) ],
            Text(label, style: GoogleFonts.plusJakartaSans(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }



  Widget _buildActionButton({
    required bool isHost,
    required bool iAmApproved,
    required bool iAmPending,
    required VoidCallback onJoin,
    required VoidCallback onViewMap,
    required VoidCallback onManage,
  }) {
    String text = 'Join Event';
    VoidCallback? onPressed = onJoin;
    bool isGradient = true;

    if (isHost) {
      text = 'Manage Participants';
      onPressed = onManage;
    } else if (iAmApproved) {
      text = 'View Exact Location';
      onPressed = onViewMap;
    } else if (iAmPending) {
      text = 'Request Pending...';
      onPressed = null;
      isGradient = false;
    }

    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: isGradient ? [
          BoxShadow(
            color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ] : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isGradient ? Colors.transparent : Colors.white10,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Ink(
          decoration: isGradient ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A00), Color(0xFFFF5E00)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ) : BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.activity;
    final title = act['title'] ?? 'Rush-In Event';
    final hook = act['hook'] ?? '';
    final description = _cleanDescription(act['description'] ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure luxury black
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('requests')
            .stream(primaryKey: ['id'])
            .eq('target_id', act['id']),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];
          
          bool iAmApproved = requests.any((r) => r['sender_id'] == _currentUid && r['status'] == 'approved');
          bool iAmPending = requests.any((r) => r['sender_id'] == _currentUid && r['status'] == 'pending');

          // Bucket constraints for public waitlist
          final approvedList = requests.where((r) => r['status'] == 'approved').toList();
          final waitlist = requests.where((r) => r['status'] == 'pending').toList();

          final isRushIn = act['is_rush_in'] == true;
          final isHost = _currentUid == act['user_id'];
          
          // Remaining time calculation
          final timeStr = act['activity_time'] != null 
              ? '${DateTime.parse(act['activity_time']).hour}:${DateTime.parse(act['activity_time']).minute.toString().padLeft(2, '0')}' 
              : 'Anytime';
          final dateStr = act['activity_time'] != null 
              ? '${DateTime.parse(act['activity_time']).day}/${DateTime.parse(act['activity_time']).month}' 
              : 'Today';

          final targetTime = act['activity_time'] != null
              ? DateTime.parse(act['activity_time'])
              : null;
          String remainingStr = '2h left';
          if (targetTime != null) {
            final diff = targetTime.difference(DateTime.now());
            if (diff.isNegative) {
              remainingStr = 'Ended';
            } else if (diff.inHours > 0) {
              remainingStr = '${diff.inHours}h left';
            } else {
              remainingStr = '${diff.inMinutes}m left';
            }
          }

          return Stack(
            children: [
              // Ambient backgrounds
              Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: (isRushIn ? const Color(0xFFFF6B00) : const Color(0xFFFF3D00)).withValues(alpha: 0.15))))),
              Positioned(bottom: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: (isRushIn ? const Color(0xFFFF1E46) : const Color(0xFFFF007F)).withValues(alpha: 0.15))))),

              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: const Color(0xFF000000), // Solid black when pinned
                    elevation: 0,
                    pinned: true,
                    stretch: true,
                    expandedHeight: 360,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildBannerImageWidget(_getEventImageUrl(act)),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black54, Colors.transparent, Color(0xFF000000)],
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                stops: [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                          // Overlaid tag pill
                          Positioned(
                            bottom: 20,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF1E46).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFF1E46).withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF1E46),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isRushIn ? 'Rush-in • $remainingStr' : 'Social • $dateStr',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFFF1E46),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    titleSpacing: 0,
                    title: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                              ),
                            ),
                            Text(
                              'Event Details',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                if (isHost)
                                  GestureDetector(
                                    onTap: _isDeleting ? null : _deleteRushIn,
                                    child: Container(
                                      width: 40, height: 40,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                      ),
                                      child: _isDeleting
                                          ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                          : const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    ),
                                  )
                                else ...[
                                  GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: const Icon(Icons.bookmark_border, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Link copied!'), backgroundColor: Colors.blueGrey),
                                    );
                                  },
                                  child: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Text(
                      (act['category']?.toString() ?? (isRushIn ? 'RUSH-IN' : 'SOCIAL')).toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF00B2FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (hook.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('"$hook"', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic)),
                    ],
                    
                    const SizedBox(height: 20),

                    // Detail list
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF7A00), size: 18),
                        const SizedBox(width: 12),
                        Text(
                          isRushIn ? 'Ends in $remainingStr' : '$dateStr at $timeStr',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: (iAmApproved || isHost) ? () {
                        final lat = act['lat']?.toString() ?? act['latitude']?.toString();
                        final lng = act['lng']?.toString() ?? act['longitude']?.toString();
                        if (lat != null && lng != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => _ApprovedLocationMapScreen(
                            lat: double.parse(lat), lng: double.parse(lng), title: act['title'] ?? 'Event',
                          )));
                        }
                      } : null,
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: (iAmApproved || isHost) ? const Color(0xFFFF7A00) : Colors.white38, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isRushIn && !iAmApproved && !isHost ? 'Revealed on approval' : (act['location_name'] ?? 'Somewhere'),
                              style: GoogleFonts.plusJakartaSans(color: (iAmApproved || isHost) ? Colors.white : Colors.white38, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (iAmApproved || isHost) const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, color: Color(0xFFFF7A00), size: 18),
                        const SizedBox(width: 12),
                        Text(
                          '${approvedList.length + 1} people going',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // Host Profile Section
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _hostProfileFuture,
                      builder: (context, hostSnapshot) {
                        final host = hostSnapshot.data;
                        final hostName = host?['name'] ?? host?['full_name'] ?? 'Host';
                        final hostAvatar = host?['avatar_url']?.toString() ?? 'https://picsum.photos/seed/host/200';
                        return GestureDetector(
                          onTap: host != null ? () => _showHostProfileSheet(act['user_id']) : null,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0E12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.4), width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundImage: _safeImageProvider(hostAvatar),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hosted by',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hostName,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white54),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Attendees Section — tappable
                    GestureDetector(
                      onTap: () => _showAttendeesModal(approvedList, waitlist, isHost),
                      child: Row(
                        children: [
                          Text('Attendees', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFF7A00).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text('${approvedList.length + waitlist.length}', style: const TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showAttendeesModal(approvedList, waitlist, isHost),
                      child: _buildAttendeesOverlap(approvedList),
                    ),

                    const SizedBox(height: 24),

                    // About Section
                    Text(
                      'About',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description.isNotEmpty ? description : 'Join us for an unforgettable experience!',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    
                    const SizedBox(height: 30),

                    // Inline lists for Hosts ONLY
                    if (isHost) ...[
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           const Text('Approved Participants', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                           Text('${approvedList.length}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ]
                      ),
                      const SizedBox(height: 12),
                      if (approvedList.isEmpty)
                         const Text('No approved participants yet.', style: TextStyle(color: Colors.white38, fontSize: 13))
                      else
                         SizedBox(
                           height: 80,
                           child: ListView.builder(
                             scrollDirection: Axis.horizontal,
                             itemCount: approvedList.length,
                             itemBuilder: (context, index) {
                               final r = approvedList[index];
                               return FutureBuilder<Map<String, dynamic>?>(
                                 future: Supabase.instance.client
                                   .from('profiles')
                                   .select()
                                   .eq('id', r['sender_id'])
                                   .maybeSingle(),
                                 builder: (context, snap) {
                                   final name = snap.data?['name']?.split(' ')?.first ?? snap.data?['full_name']?.split(' ')?.first ?? 'User';
                                   final avatar = snap.data?['avatar_url'] ?? 'https://picsum.photos/seed/${r['sender_id']}/100';
                                   return Container(
                                     margin: const EdgeInsets.only(right: 12),
                                     width: 60,
                                     child: Column(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         CircleAvatar(radius: 24, backgroundImage: _safeImageProvider(avatar)),
                                         const SizedBox(height: 4),
                                         Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
                                       ],
                                     ),
                                   );
                                 }
                               );
                             },
                           ),
                         ),

                      const SizedBox(height: 30),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           const Text('Public Waitlist', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                           Text('${waitlist.length}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                        ]
                      ),
                      const SizedBox(height: 12),
                      if (waitlist.isEmpty)
                         const Text('Waitlist is empty.', style: TextStyle(color: Colors.white38, fontSize: 13))
                      else
                         Builder(builder: (_) {
                           // Pre-load missing profiles into cache
                           _loadProfilesForRequests(waitlist);
                           return ListView.builder(
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             itemCount: waitlist.length,
                             itemBuilder: (context, index) {
                               final r = waitlist[index];
                               final rid = r['id'].toString();
                               final sid = r['sender_id'].toString();
                               final cached = _profileCache[sid];
                               final name = cached?['name'] ?? cached?['full_name'] ?? 'User';
                               final avatar = cached?['avatar_url'] ?? 'https://picsum.photos/seed/$sid/100';
                               final loading = _rowLoading[rid] == true;
                               return GestureDetector(
                                 onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: sid))),
                                 child: Container(
                                   margin: const EdgeInsets.only(bottom: 12),
                                   padding: const EdgeInsets.all(12),
                                   decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
                                   child: Row(
                                     children: [
                                       CircleAvatar(radius: 18, backgroundImage: _safeImageProvider(avatar)),
                                       const SizedBox(width: 12),
                                       Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                       if (loading)
                                         const SizedBox(width: 36, height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))))
                                       else ...[
                                         GestureDetector(
                                           onTap: () => _rejectRequest(rid, sid),
                                           child: Container(
                                             padding: const EdgeInsets.all(8),
                                             decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                                             child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         GestureDetector(
                                           onTap: () => _approveRequest(rid, sid),
                                           child: Container(
                                             padding: const EdgeInsets.all(8),
                                             decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
                                             child: const Icon(Icons.check, color: Color(0xFF10B981), size: 16),
                                           ),
                                         ),
                                       ],
                                     ],
                                   ),
                                 ),
                               );
                             },
                           );
                         }),
                    ],

                    const SizedBox(height: 120), // Prevent overlap with bottom sticky button
                  ],
                ),
              ),
            ),
          ],
        ),

              // ── Sticky Bottom Action Button ──
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95), Colors.black],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                  child: _buildActionButton(
                    isHost: isHost,
                    iAmApproved: iAmApproved,
                    iAmPending: iAmPending,
                    onJoin: _showJoinConfirmSheet,
                    onViewMap: () {
                      final lat = act['lat']?.toString() ?? act['latitude']?.toString();
                      final lng = act['lng']?.toString() ?? act['longitude']?.toString();
                      if (lat != null && lng != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => _ApprovedLocationMapScreen(
                          lat: double.parse(lat),
                          lng: double.parse(lng),
                          title: title,
                        )));
                      }
                    },
                    onManage: () => _showAttendeesModal(approvedList, waitlist, isHost),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  String _getEventImageUrl(Map<String, dynamic> act) {
    final directUrl = act['image_url']?.toString();
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }
    final desc = act['description']?.toString() ?? '';
    if (desc.contains('[image_url:')) {
      final startIndex = desc.indexOf('[image_url:') + '[image_url:'.length;
      final endIndex = desc.indexOf(']', startIndex);
      if (endIndex != -1) {
        return desc.substring(startIndex, endIndex);
      }
    }
    return 'https://picsum.photos/seed/${act['id'] ?? 'rushin'}/800/400';
  }

  String _cleanDescription(String desc) {
    return desc.replaceAll(RegExp(r'\n?\[[a-zA-Z0-9_]+:.*?\]'), '').trim();
  }

  Widget _buildBannerImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final b64 = imageUrl.substring(imageUrl.indexOf(',') + 1);
        return Image.memory(base64Decode(b64), fit: BoxFit.cover);
      } catch (e) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFFF007F), Color(0xFFFF7E40)]),
          ),
        );
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFF007F), Color(0xFFFF7E40)]),
        ),
      ),
    );
  }

  void _showHostProfileSheet(String hostUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101015),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _HostProfileSheet(hostUid: hostUid),
    );
  }

  /// Animated drag-to-dismiss join confirmation sheet
  void _showJoinConfirmSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.42,
        minChildSize: 0.1,
        maxChildSize: 0.55,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.2)),
          ),
          child: ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 20), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const Icon(Icons.flash_on, color: Color(0xFFFF7A00), size: 40),
            const SizedBox(height: 16),
            Text('Join this Event?', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.activity['title'] ?? '', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _submitJoinRequest();
                },
                child: Text('Send Join Request', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
          ]),
        ),
      ),
    );
  }

}




// ════════════════════════════════════════════════════════════════════
// APPROVED LOCATION MAP SCREEN
// Shown to participants once they are approved. Reveals the exact pin.
// ════════════════════════════════════════════════════════════════════
class _ApprovedLocationMapScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String title;
  const _ApprovedLocationMapScreen({required this.lat, required this.lng, required this.title});

  @override
  State<_ApprovedLocationMapScreen> createState() => _ApprovedLocationMapScreenState();
}

class _ApprovedLocationMapScreenState extends State<_ApprovedLocationMapScreen> {
  bool _isMapDark = true;
  bool _autoFollow = true;
  final MapController _mapController = MapController();

  LatLng? _myLocation;
  double _speedKmh = 0.0;
  double _distanceMeters = 0.0;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    bool svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2),
    ).listen((pos) {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, widget.lat, widget.lng);
      setState(() {
        _myLocation = loc;
        _speedKmh = (pos.speed * 3.6).clamp(0, 300);
        _distanceMeters = dist;
      });
      if (_autoFollow) {
        _mapController.move(loc, _mapController.camera.zoom);
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  String _formatDist(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openDirections() async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.lat},${widget.lng}&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventPoint = LatLng(widget.lat, widget.lng);
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(_isMapDark ? Icons.wb_sunny : Icons.nightlight_round, color: _isMapDark ? Colors.yellow : Colors.blueGrey),
            onPressed: () => setState(() => _isMapDark = !_isMapDark),
          ),
          // Auto-follow toggle
          IconButton(
            icon: Icon(_autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed, color: _autoFollow ? const Color(0xFFFF6B00) : Colors.white54),
            onPressed: () => setState(() => _autoFollow = !_autoFollow),
          ),
        ],
      ),
      body: Column(children: [
        // Status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
          child: const Row(children: [
            Icon(Icons.verified, color: Color(0xFFFF6B00), size: 16),
            SizedBox(width: 8),
            Text('You are approved — live location active', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        ),

        // Map
        Expanded(
          child: GestureDetector(
            onPanDown: (_) => setState(() => _autoFollow = false),
            child: Stack(children: [
              ColorFiltered(
                colorFilter: ColorFilter.matrix(_isMapDark ? [
                  -1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0,
                ] : [
                  1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,
                ]),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _myLocation ?? eventPoint,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(userAgentPackageName: 'com.meetra.app', urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'),
                    MarkerLayer(markers: [
                      // Event pin
                      Marker(
                        point: eventPoint, width: 80, height: 80,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00), borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: const Color(0xFFFF6B00).withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 4)],
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.black, size: 22),
                          ),
                          const CustomPaint(size: Size(12, 8), painter: _TrianglePainter(Color(0xFFFF6B00))),
                        ]),
                      ),
                      // Live user dot
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!, width: 56, height: 56,
                          child: Stack(alignment: Alignment.center, children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                              ),
                            ),
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, color: const Color(0xFF3B82F6),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)],
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  ],
                ),
              ),
              if (_isMapDark) Container(color: const Color(0xFFFF5C00).withValues(alpha: 0.08)),

              // Auto-follow badge
              if (!_autoFollow)
                Positioned(
                  top: 12, left: 0, right: 0,
                  child: Center(child: GestureDetector(
                    onTap: () {
                      setState(() => _autoFollow = true);
                      if (_myLocation != null) _mapController.move(_myLocation!, 15);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.4))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.gps_fixed, color: Color(0xFFFF6B00), size: 14),
                        SizedBox(width: 6),
                        Text('Tap to re-center', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  )),
                ),
            ]),
          ),
        ),

        // ── Live HUD ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          color: const Color(0xFF0A0A0F),
          child: Column(children: [
            // Distance + Speed row
            Row(children: [
              Expanded(child: _hudTile(
                icon: Icons.directions_walk, color: const Color(0xFF10B981),
                label: 'Distance', value: _myLocation == null ? '—' : _formatDist(_distanceMeters),
              )),
              const SizedBox(width: 12),
              Expanded(child: _hudTile(
                icon: Icons.speed, color: const Color(0xFF3B82F6),
                label: 'Speed', value: _myLocation == null ? '—' : '${_speedKmh.toStringAsFixed(0)} km/h',
              )),
              const SizedBox(width: 12),
              // Center on event
              GestureDetector(
                onTap: () { setState(() => _autoFollow = false); _mapController.move(eventPoint, 17); },
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: const Color(0xFFFF6B00).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3))),
                  child: const Icon(Icons.flash_on, color: Color(0xFFFF6B00), size: 22),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // Directions button
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.directions, color: Colors.white, size: 20),
                label: const Text('Get Directions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: _openDirections,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _hudTile({required IconData icon, required Color color, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}


class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width / 2, size.height)..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════════
// HOST PROFILE SHEET — Organizer Reputation & Stats
// ════════════════════════════════════════════════════════════════════
class _HostProfileSheet extends StatefulWidget {
  final String hostUid;
  const _HostProfileSheet({required this.hostUid});

  @override
  State<_HostProfileSheet> createState() => _HostProfileSheetState();
}

class _HostProfileSheetState extends State<_HostProfileSheet> {
  Map<String, dynamic>? _profile;
  int _hostedActivitiesCount = 0;
  int _reputationScore = 100;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHostData();
  }

  Future<void> _fetchHostData() async {
    try {
      final p = await Supabase.instance.client.from('profiles').select().eq('id', widget.hostUid).maybeSingle();
      final acts = await Supabase.instance.client.from('activities').select('id').eq('user_id', widget.hostUid);
      
      // Calculate reputation: (Approved / Total Requests) across their activities
      int approved = 0;
      int total = 0;
      if (acts.isNotEmpty) {
        final actIds = acts.map((e) => e['id']).toList();
        final reqs = await Supabase.instance.client.from('requests').select('status').inFilter('target_id', actIds);
        total = reqs.length;
        approved = reqs.where((r) => r['status'] == 'approved').length;
      }
      
      if (mounted) {
        setState(() {
          _profile = p;
          _hostedActivitiesCount = acts.length;
          _reputationScore = total > 0 ? ((approved / total) * 100).round() : 100;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))));
    }
    if (_profile == null) {
      return const SizedBox(height: 300, child: Center(child: Text('Profile not found', style: TextStyle(color: Colors.white54))));
    }

    final name = _profile!['name'] ?? _profile!['full_name'] ?? 'Organizer';
    final avatar = _profile!['avatar_url'] ?? 'https://picsum.photos/seed/${widget.hostUid}/200';
    final bio = _profile!['bio']?.toString() ?? '';
    final city = _profile!['city']?.toString() ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(margin: const EdgeInsets.only(top: 12, bottom: 24), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            
            // Header
            Row(
              children: [
                CircleAvatar(radius: 36, backgroundImage: _safeImageProvider(avatar)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [const Icon(Icons.location_on, color: Colors.white38, size: 14), const SizedBox(width: 4), Text(city, style: const TextStyle(color: Colors.white54, fontSize: 13))]),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, color: Color(0xFF10B981), size: 14), SizedBox(width: 4), Text('Verified Host', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11))]),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // Bio
            if (bio.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16)),
                child: Text('"$bio"', style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 24),
            ],

            // Stats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFF6B00).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.2))),
                    child: Column(
                      children: [
                        Text('$_hostedActivitiesCount', style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Activities Hosted', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2))),
                    child: Column(
                      children: [
                        Text('$_reputationScore%', style: const TextStyle(color: Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Organizer Rating', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


