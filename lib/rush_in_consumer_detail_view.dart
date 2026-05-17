// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'spark_screen.dart';

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
  final _currentUid = Supabase.instance.client.auth.currentUser!.id;
  bool _isRequesting = false;
  bool _isDeleting = false;
  bool _isLeaving = false;
  Future<Map<String, dynamic>?>? _hostProfileFuture;

  @override
  void initState() {
    super.initState();
    _hostProfileFuture = Supabase.instance.client
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', widget.activity['user_id'])
        .maybeSingle();
  }

  Future<void> _approveRequest(String requestId, String senderId) async {
    final activityTitle = widget.activity['title'] ?? 'an activity';
    try {
      await Supabase.instance.client
          .from('requests')
          .update({'status': 'approved'})
          .eq('id', requestId);
      
      // Notify the user
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUid,
        'receiver_id': senderId,
        'text': 'You have been approved to join "$activityTitle"!',
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved!'), backgroundColor: Color(0xFF10B981)));
      
      // Trigger live update
      widget.onInteraction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectRequest(String requestId, String senderId) async {
    final activityTitle = widget.activity['title'] ?? 'an activity';
    try {
      await Supabase.instance.client
          .from('requests')
          .delete()
          .eq('id', requestId);
      
      // Notify the user
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUid,
        'receiver_id': senderId,
        'text': 'Your request to join "$activityTitle" was declined.',
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected and removed.'), backgroundColor: Colors.grey));
      
      // Trigger live update
      widget.onInteraction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red));
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Request Sent! Host will review.'), backgroundColor: Color(0xFF00E5FF)));
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

  @override
  Widget build(BuildContext context) {
    final act = widget.activity;
    final title = act['title'] ?? 'Rush-In Event';
    final hook = act['hook'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          final timeStr = act['activity_time'] != null 
              ? '${DateTime.parse(act['activity_time']).hour}:${DateTime.parse(act['activity_time']).minute.toString().padLeft(2, '0')}' 
              : 'Anytime';
          final dateStr = act['activity_time'] != null 
              ? '${DateTime.parse(act['activity_time']).day}/${DateTime.parse(act['activity_time']).month}' 
              : 'Today';

          return Stack(
            children: [
              // Ambient backgrounds
              Positioned(top: -100, right: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: (isRushIn ? SparkColors.orange : SparkColors.actPrimary).withValues(alpha: 0.15))))),
              Positioned(bottom: -100, left: -50, child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: (isRushIn ? SparkColors.pink : SparkColors.actSecondary).withValues(alpha: 0.15))))),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(isRushIn ? Icons.bolt : Icons.event, color: isRushIn ? SparkColors.orange : SparkColors.actPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text(isRushIn ? 'LIVE RUSH-IN' : 'SOCIAL EVENT', style: TextStyle(color: isRushIn ? SparkColors.orange : SparkColors.actPrimary, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      if (hook.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('"$hook"', style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 24),

                      if (!isRushIn) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: SparkColors.actPrimary),
                                  const SizedBox(width: 6),
                                  Text('$timeStr • $dateStr', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: SparkColors.actPrimary),
                                  const SizedBox(width: 6),
                                  Text(isRushIn && !iAmApproved ? 'Revealed on approval' : (act['location_name'] ?? 'Somewhere'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      FutureBuilder<Map<String, dynamic>?>(
                        future: _hostProfileFuture,
                        builder: (context, snapshot) {
                          final host = snapshot.data;
                          return GestureDetector(
                            onTap: host != null ? () => _showHostProfileSheet(act['user_id']) : null,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(radius: 24, backgroundImage: _safeImageProvider(host?['avatar_url'] ?? 'https://picsum.photos/seed/${act['user_id']}/200')),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(host?['name'] ?? 'Verified Host', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      const Text('Tap to view organizer profile', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, color: Colors.white24)
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Interactivity & Actions
                      Row(
                        children: [
                          if (isHost)
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                alignment: Alignment.center,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: Colors.white54, size: 18),
                                    SizedBox(width: 8),
                                    Text('You are hosting this', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            )
                          else if (!iAmApproved)
                            Expanded(
                              child: GestureDetector(
                                onTap: iAmPending || _isRequesting ? null : _submitJoinRequest,
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: iAmPending ? null : LinearGradient(colors: isRushIn ? [SparkColors.orange, SparkColors.yellow] : [SparkColors.actPrimary, SparkColors.actSecondary]),
                                    color: iAmPending ? Colors.white.withValues(alpha: 0.1) : null,
                                    border: Border.all(color: iAmPending ? SparkColors.gborder : Colors.transparent),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isRequesting 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(iAmPending ? 'Request Pending...' : (isRushIn ? 'Request to Join' : 'Join Activity'), style: TextStyle(color: iAmPending ? SparkColors.txt2 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            )
                          else 
                             Expanded(
                              child: GestureDetector(
                                onTap: _isLeaving ? null : _leaveActivity,
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isLeaving 
                                    ? const CircularProgressIndicator(color: Color(0xFF10B981))
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                                          SizedBox(width: 8),
                                          Text('Joined (Leave)', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                            
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _isDeleting ? null : _deleteRushIn,
                            child: Container(
                              height: 56, width: 56,
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                              child: _isDeleting ? const CircularProgressIndicator(color: Colors.red) : const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          )
                        ],
                      ),
                      
                      if (iAmApproved) ...[
                        const SizedBox(height: 16),
                        // Location Reveal - only shown when approved
                        Builder(builder: (_) {
                          final lat = act['lat']?.toString() ?? act['latitude']?.toString();
                          final lng = act['lng']?.toString() ?? act['longitude']?.toString();
                          final hasCoords = lat != null && lng != null;

                          return GestureDetector(
                            onTap: hasCoords ? () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => _ApprovedLocationMapScreen(
                                lat: double.parse(lat),
                                lng: double.parse(lng),
                                title: title,
                              )));
                            } : null,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                                boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), blurRadius: 20)],
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 40),
                                  const SizedBox(height: 10),
                                  const Text('LOCATION UNLOCKED', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text(act['location_name'] ?? 'Tap to view on map', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.map, color: Colors.black, size: 18),
                                        SizedBox(width: 8),
                                        Text('VIEW ON MAP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 40),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 20),

                      // Waitlist and Approved Users
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
                                   .select('name, avatar_url')
                                   .eq('id', r['sender_id'])
                                   .maybeSingle(),
                                 builder: (context, snap) {
                                   final name = snap.data?['name']?.split(' ')?.first ?? 'User';
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
                         ListView.builder(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: waitlist.length,
                           itemBuilder: (context, index) {
                             final r = waitlist[index];
                             final isHost = _currentUid == widget.activity['user_id'];
                             return FutureBuilder<Map<String, dynamic>?>(
                               future: Supabase.instance.client
                                 .from('profiles')
                                 .select('name, avatar_url')
                                 .eq('id', r['sender_id'])
                                 .maybeSingle(),
                               builder: (context, snap) {
                                 final profile = snap.data;
                                 final name = profile?['name'] ?? 'Loading...';
                                 final avatar = profile?['avatar_url'] ?? 'https://picsum.photos/seed/${r['sender_id']}/100';

                                 return Container(
                                   margin: const EdgeInsets.only(bottom: 12),
                                   padding: const EdgeInsets.all(12),
                                   decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
                                   child: Row(
                                     children: [
                                       CircleAvatar(radius: 18, backgroundImage: _safeImageProvider(avatar)),
                                       const SizedBox(width: 12),
                                       Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                       if (isHost) ...[
                                         GestureDetector(
                                           onTap: () => _rejectRequest(r['id'].toString(), r['sender_id'].toString()),
                                           child: Container(
                                             padding: const EdgeInsets.all(8),
                                             decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                                             child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         GestureDetector(
                                           onTap: () => _approveRequest(r['id'].toString(), r['sender_id'].toString()),
                                           child: Container(
                                             padding: const EdgeInsets.all(8),
                                             decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
                                             child: const Icon(Icons.check, color: Color(0xFF10B981), size: 16),
                                           ),
                                         ),
                                       ] else
                                         const Icon(Icons.access_time, color: Colors.white38, size: 16),
                                     ],
                                   ),
                                 );
                               }
                             );
                           },
                         ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
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
  bool _fetchingGps = false;
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.lat, widget.lng);
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Color(0xFF00E5FF), size: 18),
                SizedBox(width: 10),
                Text('You are approved to join this Rush-In', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(_isMapDark ? [
                    -1.0, 0.0, 0.0, 0.0, 255.0,
                    0.0, -1.0, 0.0, 0.0, 255.0,
                    0.0, 0.0, -1.0, 0.0, 255.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ] : [
                    1.0, 0.0, 0.0, 0.0, 0.0,
                    0.0, 1.0, 0.0, 0.0, 0.0,
                    0.0, 0.0, 1.0, 0.0, 0.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ]),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: point, initialZoom: 16, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all)),
                    children: [
                      TileLayer(userAgentPackageName: 'com.meetra.app', urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 80,
                            height: 80,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 4)],
                                  ),
                                  child: const Icon(Icons.flash_on, color: Colors.black, size: 22),
                                ),
                                const SizedBox(height: 4),
                                const CustomPaint(
                                  size: Size(12, 8),
                                  painter: _TrianglePainter(Color(0xFF00E5FF)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Neon Wash Overlay
                if (_isMapDark)
                  Container(color: const Color(0xFF4A00E0).withValues(alpha: 0.1)),

                // Theme Toggle & GPS Buttons
                Positioned(
                  top: 16, right: 16,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isMapDark = !_isMapDark),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
                              child: Icon(_isMapDark ? Icons.wb_sunny : Icons.nightlight_round, color: _isMapDark ? Colors.yellow : Colors.blueGrey, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _fetchingGps ? null : () async {
                          setState(() => _fetchingGps = true);
                          try {
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              if (!mounted) return;
                              setState(() => _fetchingGps = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Row(children: [Icon(Icons.location_off, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Please enable location services'))]),
                                backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ));
                              return;
                            }
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) {
                                if (!mounted) return;
                                setState(() => _fetchingGps = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Row(children: [Icon(Icons.not_listed_location, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permission denied'))]),
                                  backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ));
                                return;
                              }
                            }
                            if (permission == LocationPermission.deniedForever) {
                              if (!mounted) return;
                              setState(() => _fetchingGps = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Row(children: [Icon(Icons.settings, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Location permanently denied. Enable in settings.'))]),
                                backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                action: SnackBarAction(label: 'Settings', textColor: Colors.white, onPressed: () => Geolocator.openAppSettings()),
                              ));
                              return;
                            }
                            final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
                            if (!mounted) return;
                            setState(() => _fetchingGps = false);
                            _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Your location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}')]),
                              backgroundColor: const Color(0xFF00E5FF), behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 3),
                            ));
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _fetchingGps = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('Could not get location: $e'))]),
                              backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: const Color(0xFF00E5FF), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), blurRadius: 12)]),
                              child: _fetchingGps
                                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Icon(Icons.my_location, color: Colors.black, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101015),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rush-In Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${widget.lat.toStringAsFixed(5)}, ${widget.lng.toStringAsFixed(5)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))));
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
                    decoration: BoxDecoration(color: const Color(0xFF00E5FF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2))),
                    child: Column(
                      children: [
                        Text('$_hostedActivitiesCount', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 24, fontWeight: FontWeight.bold)),
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


