// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'messages_screen.dart';
import 'rush_in_consumer_detail_view.dart';
// import 'experience_screen.dart'; // Disabled as per user instruction
import 'services/notification_service.dart';
import 'widgets/skeleton_loaders.dart';

// ════════════════════════════════════════════════════════════════════
// NEW: CENTRAL MANAGEMENT DASHBOARD
// ════════════════════════════════════════════════════════════════════
class MainDashboardScreen extends StatelessWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Management Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage your hostings, requests, and network easily from one place.', style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 30),
            _buildManagementCard(
              context: context,
              title: 'Events & Experiences',
              desc: 'Manage requests and details for events you are hosting.',
              icon: Icons.event,
              color: const Color(0xFF38D9A9),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityManagementScreen())),
            ),
            _buildManagementCard(
              context: context,
              title: 'Rush-Ins',
              desc: 'Track and manage your urgent live activities.',
              icon: Icons.flash_on,
              color: const Color(0xFFFF007F),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RushInManagementScreen())),
            ),
            _buildManagementCard(
              context: context,
              title: 'Companion Status',
              desc: 'View your Companion profile and connection requests.',
              icon: Icons.volunteer_activism,
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionManagementScreen())),
            ),
            _buildManagementCard(
              context: context,
              title: 'My Network Hub (Outgoing)',
              desc: 'Monitor connection and follow requests you have sent.',
              icon: Icons.hub_outlined,
              color: const Color(0xFFFF7E40),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkHubScreen())),
            ),
            _buildManagementCard(
              context: context,
              title: 'Follow Requests',
              desc: 'Approve or deny incoming follow requests.',
              icon: Icons.person_add_alt,
              color: const Color(0xFF38D9A9),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomingFollowRequestsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard({
    required BuildContext context,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF101015),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 1. ACTIVITY MANAGEMENT SCREEN (WITH TABS)
// ════════════════════════════════════════════════════════════════════
class ActivityManagementScreen extends StatelessWidget {
  const ActivityManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF050508),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('My Hosted Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF6B00),
            labelColor: Color(0xFFFF6B00),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'UPCOMING'),
              Tab(text: 'LIVE'),
              Tab(text: 'PAST'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActivityListHelper(filterState: 'upcoming', isRushIn: false),
            _ActivityListHelper(filterState: 'live', isRushIn: false),
            _ActivityListHelper(filterState: 'past', isRushIn: false),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 2. RUSH-IN MANAGEMENT SCREEN (WITH TABS)
// ════════════════════════════════════════════════════════════════════
class RushInManagementScreen extends StatelessWidget {
  const RushInManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF050508),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('My Rush-Ins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF007F),
            labelColor: Color(0xFFFF007F),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'LIVE (24H)'),
              Tab(text: 'PAST'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActivityListHelper(filterState: 'live', isRushIn: true),
            _ActivityListHelper(filterState: 'past', isRushIn: true),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// HELPER: FETCHES ACTIVITIES & RUSH-INS BASED ON TAB LIFECYCLE
// ════════════════════════════════════════════════════════════════════
class _ActivityListHelper extends StatefulWidget {
  final String filterState; 
  final bool isRushIn;

  const _ActivityListHelper({required this.filterState, required this.isRushIn});

  @override
  State<_ActivityListHelper> createState() => _ActivityListHelperState();
}

class _ActivityListHelperState extends State<_ActivityListHelper> {
  final Set<String> _processingIds = {};

  Future<void> _handleActivityDeletion(Map<String, dynamic> act) async {
    final activityId = act['id'];
    final activityTitle = act['title'] ?? 'Untitled Activity';
    final hostId = Supabase.instance.client.auth.currentUser!.id;
    
    // Immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifying participants and deleting...'), duration: Duration(milliseconds: 700)));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101015),
        title: const Text('Confirm Deletion'),
        content: const Text('This will notify all participants and permanently delete the activity. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _processingIds.add(activityId.toString()));
      try {
        // 1. Fetch all participants to notify them
        final List<dynamic> participants = await Supabase.instance.client
            .from('requests')
            .select('sender_id')
            .eq('target_id', activityId);

        if (participants.isNotEmpty) {
          debugPrint('NOTIFYING ${participants.length} PARTICIPANTS...');
          final notificationText = 'ACTIVITY CANCELLED: The host has deleted the activity "$activityTitle".';
          
          // Send messages to all participants
          final messagesToInsert = participants.map((p) => <String, dynamic>{
            'sender_id': hostId,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity deleted and participants notified.'), backgroundColor: Colors.green));
      } on PostgrestException catch (pe) {
        debugPrint('SUPABASE DELETE ERROR: ${pe.message} (${pe.code})');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database Error: ${pe.message}'), backgroundColor: Colors.red));
      } catch (e) {
        debugPrint('GENERAL DELETE ERROR: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unknown Error: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _processingIds.remove(activityId.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('activities')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SkeletonLoaders.genericListSkeleton();
        }

        final allActivities = snapshot.data ?? [];
        final now = DateTime.now();

        final filteredList = allActivities.where((act) {
          final activityIsRushIn = act['is_rush_in'] == true;
          if (widget.isRushIn != activityIsRushIn) return false;
          final actTime = DateTime.parse(act['activity_time']).toLocal();
          var expiresAt = act['expires_at'] != null ? DateTime.parse(act['expires_at']).toLocal() : null;
          if (widget.isRushIn && expiresAt == null) expiresAt = actTime.add(const Duration(hours: 24));

          if (widget.filterState == 'upcoming') return actTime.isAfter(now) && !widget.isRushIn;
          
          // Grace period: Stay in "Live" for 24 hours after completion/start
          final liveWindowEnd = widget.isRushIn 
              ? expiresAt!.add(const Duration(hours: 24)) 
              : actTime.add(const Duration(hours: 24));
          
          final isCurrentlyLive = widget.isRushIn 
              ? now.isBefore(liveWindowEnd) 
              : (now.isAfter(actTime) && now.isBefore(liveWindowEnd));

          if (widget.filterState == 'live') return isCurrentlyLive;
          
          if (widget.filterState == 'past') {
            // It's past if it's already ended its live/grace period window
            return now.isAfter(liveWindowEnd);
          }
          return false;
        }).toList();

        if (filteredList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.isRushIn ? Icons.flash_on : Icons.map, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text('No ${widget.filterState} ${widget.isRushIn ? 'Rush-Ins' : 'Activities'}', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final act = filteredList[index];
            final isDeleting = _processingIds.contains(act['id'].toString());
            
            return Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RushInConsumerDetailView(activity: act, onInteraction: () {})));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), 
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: widget.isRushIn ? const Color(0xFFFF6B00).withValues(alpha: 0.5) : const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicator & Expiration
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: widget.isRushIn ? const Color(0xFFFF6B00) : const Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isRushIn ? 'LIVE RUSH-IN NEARBY' : 'MANAGED ACTIVITY',
                                  style: TextStyle(
                                    color: widget.isRushIn ? const Color(0xFFFF6B00) : const Color(0xFF3B82F6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              act['expires_at'] != null && widget.filterState == 'live'
                                  ? 'Expires in ${DateTime.parse(act['expires_at']).toLocal().difference(now).inHours}h'
                                  : 'No expiration',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Title
                        Padding(
                          padding: const EdgeInsets.only(right: 30), // leave room for floating delete btn
                          child: Text(
                            act['title'] ?? 'Untitled',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Bottom Row: Avatar & Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 1),
                                  image: DecorationImage(
                                    image: NetworkImage('https://api.dicebear.com/7.x/notionists/png?seed=${Supabase.instance.client.auth.currentUser?.id ?? 'host'}'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5), // Indigo blue
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.open_in_new, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text('View Details', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // FLOATING DELETE BUTTON (Top Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: isDeleting ? null : () => _handleActivityDeletion(act),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDeleting ? Colors.black45 : const Color(0xFFE11D48).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDeleting ? Colors.white10 : const Color(0xFFE11D48).withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: isDeleting 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.delete_outline, color: Color(0xFFE11D48), size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 3. COMPANION MANAGEMENT SCREEN
// ════════════════════════════════════════════════════════════════════
class CompanionManagementScreen extends StatefulWidget {
  const CompanionManagementScreen({super.key});

  @override
  State<CompanionManagementScreen> createState() => _CompanionManagementScreenState();
}

class _CompanionManagementScreenState extends State<CompanionManagementScreen> {
  final _uid = Supabase.instance.client.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Companion Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: Supabase.instance.client
            .from('companions')
            .stream(primaryKey: ['id'])
            .eq('user_id', _uid)
            .map((rows) => rows.isNotEmpty ? rows.first : null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SkeletonLoaders.genericListSkeleton();
          }

          final comp = snapshot.data;

          if (comp == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volunteer_activism, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  const Text('You are not a Companion yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Register in the Events tab to get started', style: TextStyle(color: Colors.white30, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.volunteer_activism, color: Colors.white),
                    label: const Text('Become a Companion', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          }

          final isActive = comp['is_active'] == true;
          final companionId = comp['id']?.toString() ?? '';
          final verificationStatus = comp['verification_status'] as String? ?? 'unverified';
          final hasProofs = (comp['proof_images'] as List?)?.isNotEmpty == true;

          Color verifyColor = Colors.white38;
          IconData verifyIcon = Icons.help_outline;
          String verifyLabel = 'Unverified';
          if (verificationStatus == 'verified') { verifyColor = const Color(0xFF10B981); verifyIcon = Icons.verified; verifyLabel = 'Verified ✓'; }
          else if (verificationStatus == 'pending') { verifyColor = const Color(0xFFFBBF24); verifyIcon = Icons.hourglass_top; verifyLabel = 'Verification Pending'; }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Status Card ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isActive
                      ? [const Color(0xFF10B981).withValues(alpha: 0.2), const Color(0xFF050508)]
                      : [Colors.white10, const Color(0xFF050508)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.white24),
                ),
                child: Column(
                  children: [
                    Icon(isActive ? Icons.visibility : Icons.visibility_off,
                        color: isActive ? const Color(0xFF10B981) : Colors.white54, size: 40),
                    const SizedBox(height: 16),
                    Text(isActive ? 'Your Listing is LIVE' : 'Your Listing is HIDDEN',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      isActive ? 'Users can discover you and send connect requests.' : 'You will not appear in the Companions feed.',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Active Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      activeThumbColor: const Color(0xFF10B981),
                      value: isActive,
                      onChanged: (val) async {
                        await Supabase.instance.client
                            .from('companions')
                            .update({'is_active': val})
                            .eq('id', comp['id']);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Verification Status Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: verifyColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: verifyColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: verifyColor.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(verifyIcon, color: verifyColor, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(verifyLabel, style: TextStyle(color: verifyColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        verificationStatus == 'verified' ? 'Your credentials have been reviewed.' :
                        verificationStatus == 'pending' ? 'Your proof images are under review. Usually takes 24 hours.' :
                        hasProofs ? 'Your proofs are uploaded but not yet reviewed.' : 'Add proof images in your listing to get verified.',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ])),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Incoming Connection Requests Card ──
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('requests')
                    .stream(primaryKey: ['id'])
                    .eq('target_id', companionId),
                builder: (ctx, reqSnap) {
                  final allReqs = (reqSnap.data ?? []).where((r) => r['target_type'] == 'companion').toList();
                  final pendingCount = allReqs.where((r) => r['status'] == 'pending').length;

                  return GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Companion feature is currently disabled.')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101015),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: pendingCount > 0
                              ? const Color(0xFFFF7E40).withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                        boxShadow: pendingCount > 0
                            ? [BoxShadow(color: const Color(0xFFFF7E40).withValues(alpha: 0.1), blurRadius: 20)]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFFFF7E40).withValues(alpha: 0.15), shape: BoxShape.circle),
                                child: const Icon(Icons.people_alt, color: Color(0xFFFF7E40)),
                              ),
                              if (pendingCount > 0)
                                Positioned(
                                  top: -4, right: -4,
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                                    child: Center(child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Connection Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  pendingCount > 0 ? '$pendingCount new request${pendingCount > 1 ? 's' : ''} waiting for review' : 'No pending requests',
                                  style: TextStyle(color: pendingCount > 0 ? const Color(0xFFFF7E40) : Colors.white38, fontSize: 12),
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

              const SizedBox(height: 16),

              // ── Total Stats ──
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('requests')
                    .stream(primaryKey: ['id'])
                    .eq('target_id', companionId),
                builder: (ctx, statsSnap) {
                  final all = (statsSnap.data ?? []).where((r) => r['target_type'] == 'companion').toList();
                  final approved = all.where((r) => r['status'] == 'approved').length;
                  final total = all.length;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF101015), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCol('$total', 'Total Requests', Colors.white54),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.08)),
                        _statCol('$approved', 'Accepted', const Color(0xFF10B981)),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.08)),
                        _statCol(total > 0 ? '${((approved / total) * 100).round()}%' : '—', 'Accept Rate', const Color(0xFFFF6B00)),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCol(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// 4. MY NETWORK HUB (OUTGOING REQUESTS)
// ════════════════════════════════════════════════════════════════════
class NetworkHubScreen extends StatelessWidget {
  const NetworkHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF050508),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Outgoing Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF7E40),
            labelColor: Color(0xFFFF7E40),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'PENDING / DECLINED'),
              Tab(text: 'APPROVED'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NetworkHubListHelper(approvedOnly: false),
            _NetworkHubListHelper(approvedOnly: true),
          ],
        ),
      ),
    );
  }
}

class _NetworkHubListHelper extends StatelessWidget {
  final bool approvedOnly;
  const _NetworkHubListHelper({required this.approvedOnly});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('requests')
          .stream(primaryKey: ['id'])
          .eq('sender_id', uid)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return SkeletonLoaders.genericListSkeleton();
        
        final allRequests = snapshot.data ?? [];
        final requests = allRequests.where((r) => approvedOnly ? r['status'] == 'approved' : r['status'] != 'approved').toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hub_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text(approvedOnly ? 'No active connections yet' : 'No pending requests', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _NetworkHubCard(request: requests[index]);
          },
        );
      },
    );
  }
}

class _NetworkHubCard extends StatefulWidget {
  final Map<String, dynamic> request;
  const _NetworkHubCard({required this.request});

  @override
  State<_NetworkHubCard> createState() => _NetworkHubCardState();
}

class _NetworkHubCardState extends State<_NetworkHubCard> {
  Map<String, dynamic>? _targetData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTargetData();
  }

  Future<void> _fetchTargetData() async {
    final targetId = widget.request['target_id'];
    final targetType = widget.request['target_type'];

    if (targetId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Treat 'activity', 'rush_in', 'rush-in' all as activity type
      final isActivityType = targetType == 'activity' || 
                             targetType == 'rush_in' ||
                             targetType == 'rush-in';
      
      if (isActivityType) {
        // Step 1: Fetch ALL activity columns (needed by RushInConsumerDetailView)
        final actData = await Supabase.instance.client
            .from('activities')
            .select('*')
            .eq('id', targetId)
            .maybeSingle();

        if (actData == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // Step 2: Fetch the host profile separately
        final hostId = actData['user_id']?.toString();
        Map<String, dynamic>? profileData;
        if (hostId != null) {
          profileData = await Supabase.instance.client
              .from('profiles')
              .select('name, avatar_url, city')
              .eq('id', hostId)
              .maybeSingle();
        }

        // Merge into one map with a 'profiles' sub-key
        final merged = Map<String, dynamic>.from(actData);
        merged['profiles'] = profileData;
        if (mounted) setState(() { _targetData = merged; _isLoading = false; });

      } else if (targetType == 'companion') {
        final data = await Supabase.instance.client
            .from('companions')
            .select('*')
            .eq('id', targetId) // Try as companion id
            .maybeSingle();
            
        if (data != null) {
          if (mounted) setState(() { _targetData = data; _isLoading = false; });
        } else {
          // Fallback: targetId was a user ID, let's try finding their companion profile
          final byUserId = await Supabase.instance.client
              .from('companions')
              .select('*')
              .eq('user_id', targetId)
              .maybeSingle();
              
          if (byUserId != null) {
            if (mounted) setState(() { _targetData = byUserId; _isLoading = false; });
          } else {
            // Absolute fallback to just profile
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('*')
                .eq('id', targetId)
                .maybeSingle();
            if (mounted) setState(() { _targetData = profile; _isLoading = false; });
          }
        }
      } else {
        // Unknown type — try activity as a fallback
        final actData = await Supabase.instance.client
            .from('activities')
            .select('*')
            .eq('id', targetId)
            .maybeSingle();
        if (actData != null) {
          final hostId = actData['user_id']?.toString();
          Map<String, dynamic>? profileData;
          if (hostId != null) {
            profileData = await Supabase.instance.client
                .from('profiles')
                .select('name, avatar_url, city')
                .eq('id', hostId)
                .maybeSingle();
          }
          final merged = Map<String, dynamic>.from(actData);
          merged['profiles'] = profileData;
          if (mounted) setState(() { _targetData = merged; _isLoading = false; });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('[NetworkHub] Error fetching target data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.request['status'] as String;
    final isDeletedByHost = status == 'deleted_by_host';
    final targetType = widget.request['target_type'];

    if (isDeletedByHost) {
      return _buildDismissableCard(
        title: 'Activity Cancelled',
        msg: 'The host has deleted this activity.',
        color: const Color(0xFFE11D48),
        icon: Icons.error_outline,
      );
    }

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF101015),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    if (_targetData == null) {
      return _buildDismissableCard(
        title: 'Connection Unavailable',
        msg: 'This item no longer exists.',
        color: Colors.grey,
        icon: Icons.visibility_off,
      );
    }

    bool isRushIn = false;
    Color themeColor = const Color(0xFFFF7E40);
    IconData typeIcon = Icons.calendar_today;
    String typeLabel = 'Activity';
    String hostName = 'Host';
    String hostAvatar = 'https://picsum.photos/200';
    String title = '';
    String hook = widget.request['message'] ?? '';
    String location = '';
    String? hostId;

    final isActivityType = targetType == 'activity' ||
                           targetType == 'rush_in' ||
                           targetType == 'rush-in' ||
                           _targetData!.containsKey('is_rush_in'); // fallback path

    if (isActivityType) {
      isRushIn = _targetData!['is_rush_in'] == true;
      final profile = _targetData!['profiles'] as Map<String, dynamic>?;
      hostName = profile?['name'] ?? 'Host';
      hostAvatar = profile?['avatar_url'] ?? 'https://picsum.photos/seed/${_targetData!['user_id']}/200';
      title = _targetData!['title'] ?? 'Activity';
      hook = _targetData!['hook'] ?? hook;
      location = _targetData!['location_name'] ?? profile?['city'] ?? 'Location TBA';
      hostId = _targetData!['user_id']?.toString();

      if (isRushIn) {
        themeColor = const Color(0xFFFF6B00);
        typeIcon = Icons.bolt;
        typeLabel = 'Rush-In';
      } else {
        themeColor = const Color(0xFFC084FC);
        typeIcon = Icons.calendar_month;
        typeLabel = 'Activity';
      }
    } else if (targetType == 'companion') {
      themeColor = const Color(0xFF10B981);
      typeIcon = Icons.handshake;
      typeLabel = 'Companion';
      hostName = _targetData!['name'] ?? 'Companion';
      hostAvatar = _targetData!['avatar_url'] ?? 'https://picsum.photos/seed/${_targetData!['id']}/200';
      title = 'Companion Connect';
      location = _targetData!['city'] ?? 'Location TBA';
      hostId = _targetData!['id']?.toString();
    }

    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    void openDetailView() {
      if (_targetData == null) return;
      if (isActivityType) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RushInConsumerDetailView(
          activity: _targetData!,
          onInteraction: () {},
        )));
      } else if (targetType == 'companion') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Companion details are currently unavailable.')),
        );
      }
    }

    return GestureDetector(
      onTap: openDetailView,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF101015),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isApproved ? themeColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
          boxShadow: isApproved ? [BoxShadow(color: themeColor.withValues(alpha: 0.1), blurRadius: 20)] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isApproved ? themeColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(typeIcon, color: themeColor, size: 14),
                      const SizedBox(width: 8),
                      Text(typeLabel.toUpperCase(), style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)),
                    ],
                  ),
                  if (isApproved)
                    const Row(children: [
                      Text('APPROVED & READY', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: Color(0xFF10B981), size: 16),
                    ])
                  else if (isRejected)
                    const Text('DECLINED', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 11))
                  else
                    Text('WAITING FOR HOST...', style: TextStyle(color: Colors.amber.withValues(alpha: 0.8), fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(hostAvatar),
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('with $hostName', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.white38),
                              const SizedBox(width: 4),
                              Text(location, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ],
                        if (hook.isNotEmpty && isApproved) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                            child: Text('"$hook"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70, fontSize: 12)),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Row
            if (isApproved && hostId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor.withValues(alpha: 0.15),
                          foregroundColor: themeColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.chat_bubble, size: 18),
                        label: const Text('Open Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(
                            targetUserId: hostId!,
                            name: hostName,
                            avatarUrl: hostAvatar,
                            isUnlocked: true,
                          )));
                        }
                      ),
                    ),
                    if (isActivityType) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: openDetailView,
                        child: Container(
                          height: 48, width: 48,
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.info_outline, color: themeColor),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissableCard({required String title, required String msg, required Color color, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.from('requests').delete().eq('id', widget.request['id']);
            },
            child: const Text('DISMISS', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// UTILITIES: INCOMING REQUESTS MANAGER
// ════════════════════════════════════════════════════════════════════
class _RequestsManagerScreen extends StatefulWidget {
  final String targetId;
  final String title;

  const _RequestsManagerScreen({required this.targetId, required this.title});

  @override
  State<_RequestsManagerScreen> createState() => _RequestsManagerScreenState();
}

class _RequestsManagerScreenState extends State<_RequestsManagerScreen> {
  bool _isProcessing = false;

  Future<void> _handleRequestAction(String requestId, String status, {
    required String senderId,
    required String activityTitle,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final hostId = Supabase.instance.client.auth.currentUser!.id;

      // 1. Update request status
      await Supabase.instance.client
          .from('requests')
          .update({'status': status})
          .eq('id', requestId);

      // 2. Notify the participant
      final notifyText = status == 'approved'
          ? '✅ You\'re approved for "$activityTitle"! Tap "My Join Requests" to see the location.'
          : '❌ Sorry, your request for "$activityTitle" was not approved.';

      await Supabase.instance.client.from('messages').insert({
        'sender_id': hostId,
        'receiver_id': senderId,
        'text': notifyText,
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Send structured notification
      NotificationService.sendNotification(
        userId: senderId,
        type: status == 'approved' ? NotificationType.approval : NotificationType.rejection,
        title: status == 'approved' ? 'Request Approved! 🎉' : 'Request Declined',
        body: status == 'approved' 
          ? 'You\'re approved for "$activityTitle"! Check your Network Hub for details.'
          : 'Sorry, your request for "$activityTitle" was not approved.',
        payload: {'activity_title': activityTitle},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Participant Approved and Notified! ✅' : 'Request Declined and Notified ❌'),
            backgroundColor: status == 'approved' ? const Color(0xFF10B981) : const Color(0xFFE11D48),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF050508),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF6B00),
            labelColor: Color(0xFFFF6B00),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'PENDING'),
              Tab(text: 'APPROVED'),
            ],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('requests')
              .stream(primaryKey: ['id'])
              .eq('target_id', widget.targetId)
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SkeletonLoaders.genericListSkeleton();
            }
            
            final allRequests = snapshot.data ?? [];
            final pendingRequests = allRequests.where((r) => r['status'] == 'pending').toList();
            final approvedRequests = allRequests.where((r) => r['status'] == 'approved').toList();

            return TabBarView(
              children: [
                _buildRequestList(pendingRequests, true),
                _buildRequestList(approvedRequests, false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests, bool isPendingTab) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPendingTab ? Icons.inbox : Icons.check_circle_outline, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(isPendingTab ? 'No pending requests' : 'No approved participants', style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final isPending = req['status'] == 'pending';
        
        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('profiles')
              .select('name, avatar_url')
              .eq('id', req['sender_id'])
              .maybeSingle(),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            final displayName = profile?['name'] ?? 'Loading...';
            final avatarUrl = profile?['avatar_url'] ?? 'https://picsum.photos/seed/${req['sender_id']}/100';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101015),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPending ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatarUrl)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isPending ? Colors.amber : const Color(0xFF10B981)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(req['status'].toString().toUpperCase(), style: TextStyle(
                          color: isPending ? Colors.amber : const Color(0xFF10B981), 
                          fontWeight: FontWeight.bold, fontSize: 10
                        )),
                      ),
                    ],
                  ),
                  if (req['message'] != null && req['message'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('"${req['message']}"', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  if (isPending)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48).withValues(alpha: 0.1), 
                              foregroundColor: const Color(0xFFE11D48), 
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isProcessing ? null : () => _handleRequestAction(
                              req['id'], 'rejected',
                              senderId: req['sender_id'],
                              activityTitle: widget.title,
                            ), 
                            child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981), 
                              foregroundColor: Colors.white, 
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isProcessing ? null : () => _handleRequestAction(
                              req['id'], 'approved',
                              senderId: req['sender_id'],
                              activityTitle: widget.title,
                            ), 
                            child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFFFF6B00),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message Participant', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(
                            targetUserId: req['sender_id'],
                            name: displayName,
                            avatarUrl: avatarUrl,
                            isUnlocked: true,
                          )));
                        }
                      ),
                    )
                ],
              ),
            );
          }
        );
      },
    );
  }
}


// ════════════════════════════════════════════════════════════════════
// MY FEED POSTS SCREEN
// ════════════════════════════════════════════════════════════════════
class MyFeedPostsScreen extends StatefulWidget {
  const MyFeedPostsScreen({super.key});

  @override
  State<MyFeedPostsScreen> createState() => _MyFeedPostsScreenState();
}

class _MyFeedPostsScreenState extends State<MyFeedPostsScreen> {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  Widget _buildSafeImage(String url) {
    if (url.startsWith('data:image')) {
      final b64 = url.split(',').last;
      return Image.memory(base64Decode(b64), height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const SizedBox.shrink());
    }
    return Image.network(url, height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Feed Posts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: currentUserId == null
          ? const Center(child: Text("Not logged in", style: TextStyle(color: Colors.white)))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('posts')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', currentUserId!)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SkeletonLoaders.genericListSkeleton();
                }
                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return const Center(
                    child: Text('No posts found. Start sharing in the feed!', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (_, i) {
                    final rp = posts[i];
                    final postId = rp['id'];
                    final createdAt = rp['created_at'] as String? ?? '';
                    final contentRaw = rp['content'] as String? ?? '';
                    String postContent = contentRaw;
                    String? imageUrl;
                    String interestTag = '';
                    
                    if (contentRaw.startsWith('{')) {
                      try {
                        final data = jsonDecode(contentRaw);
                        postContent = data['text'] ?? '';
                        imageUrl = data['image_url'];
                        if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;
                        interestTag = data['interest'] ?? '';
                      } catch (_) {}
                    }
                    
                    String formattedDate = '';
                    if (createdAt.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(createdAt).toLocal();
                        formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(dt);
                      } catch (_) {}
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151520),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: _buildSafeImage(imageUrl),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        interestTag.isNotEmpty ? interestTag : 'General',
                                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (postContent.isNotEmpty)
                                  Text(
                                    postContent,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: const Color(0xFF151520),
                                            title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
                                            content: const Text('This will permanently delete your post.', style: TextStyle(color: Colors.white70)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            final response = await Supabase.instance.client.from('posts').delete().eq('id', postId).select();
                                            if (mounted) {
                                              if (response.isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('BLOCKED BY SUPABASE: You need to add a "DELETE" RLS policy to the posts table in your Supabase Dashboard!', style: TextStyle(fontWeight: FontWeight.bold)),
                                                    backgroundColor: Color(0xFFEF4444),
                                                    duration: Duration(seconds: 5),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Post deleted successfully'), backgroundColor: Color(0xFF10B981)),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Failed to delete: $e'), backgroundColor: const Color(0xFFEF4444)),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                            SizedBox(width: 6),
                                            Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
// --------------------------------------------------------------------
// 5. INCOMING FOLLOW REQUESTS
// --------------------------------------------------------------------
class IncomingFollowRequestsScreen extends StatelessWidget {
  const IncomingFollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        title: const Text('Follow Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('requests')
            .stream(primaryKey: ['id'])
            .eq('target_id', uid)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return SkeletonLoaders.genericListSkeleton();
          
          final allRequests = snapshot.data ?? [];
          final requests = allRequests.where((r) => r['target_type'] == 'follow' && r['status'] == 'pending').toList();
          
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 60, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  const Text('No pending follow requests', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return _IncomingFollowCard(request: req);
            },
          );
        },
      ),
    );
  }
}

class _IncomingFollowCard extends StatefulWidget {
  final Map<String, dynamic> request;
  const _IncomingFollowCard({required this.request});
  @override
  State<_IncomingFollowCard> createState() => _IncomingFollowCardState();
}

class _IncomingFollowCardState extends State<_IncomingFollowCard> {
  Map<String, dynamic>? _senderData;

  @override
  void initState() {
    super.initState();
    _fetchSender();
  }

  Future<void> _fetchSender() async {
    try {
      final senderId = widget.request['sender_id'];
      final data = await Supabase.instance.client.from('profiles').select('name, full_name, avatar_url').eq('id', senderId).maybeSingle();
      if (mounted && data != null) {
        setState(() => _senderData = data);
      }
    } catch (_) {}
  }

  Future<void> _handleDecision(String status) async {
    try {
      if (status == 'declined') {
        await Supabase.instance.client.from('requests').delete().eq('id', widget.request['id']);
      } else {
        await Supabase.instance.client.from('requests').update({'status': status}).eq('id', widget.request['id']);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_senderData == null) return const SizedBox();
    
    final name = _senderData!['name'] ?? _senderData!['full_name'] ?? 'User';
    final avatar = _senderData!['avatar_url']?.toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14))),
          Row(
            children: [
              GestureDetector(
                onTap: () => _handleDecision('approved'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF38D9A9), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Approve', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _handleDecision('declined'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Deny', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
