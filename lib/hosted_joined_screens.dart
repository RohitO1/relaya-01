// ignore_for_file: use_build_context_synchronously
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';
import 'services/notification_service.dart';
import 'rush_in_consumer_detail_view.dart';
import 'services/doodle_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (matches profile_screen.dart palette)
// ─────────────────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF0A0A0F);
const _card   = Color(0xFF141C2E);
const _cyan   = Color(0xFFFF6B00);
const _green  = Color(0xFF22C55E);
const _amber  = Color(0xFFF59E0B);
const _red    = Color(0xFFEF4444);
const _violet = Color(0xFFFF7E40);

SupabaseClient get _sb => Supabase.instance.client;
String get _uid => _sb.auth.currentUser!.id;


// ═══════════════════════════════════════════════════════════════════════════════
// 1.  HOSTED BY YOU — category picker
// ═══════════════════════════════════════════════════════════════════════════════
class HostedByYouScreen extends StatelessWidget {
  const HostedByYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PremiumBackground(
      glowColor: _cyan,
      child: Scaffold(
        backgroundColor: isDoodleMode(context) ? DoodleColors.cream : Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text('Hosted by You',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
        children: [
          Text('Select a category to manage participants',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          _CategoryCard(
            icon: Icons.flash_on, title: 'Rush-Ins',
            subtitle: 'Manage your live rush-in participants', color: _cyan,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _HostedCategoryScreen(
                    isRushIn: true, title: 'Rush-In', color: _cyan, icon: Icons.flash_on))),
          ),
          _CategoryCard(
            icon: Icons.event, title: 'Activities',
            subtitle: 'Manage your activity participants', color: _violet,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _HostedCategoryScreen(
                    isRushIn: false, title: 'Activity', color: _violet, icon: Icons.event))),
          ),
          _CategoryCard(
            icon: Icons.celebration, title: 'Events',
            subtitle: 'Manage your event participants', color: _amber,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _HostedCategoryScreen(
                    isRushIn: false, isEvent: true, title: 'Event', color: _amber, icon: Icons.celebration))),
          ),
          _CategoryCard(
            icon: Icons.volunteer_activism, title: 'Companionship',
            subtitle: 'Manage companion requests', color: _green,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _CompanionHostedScreen())),
          ),
        ],
      ),
    ));
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// HOSTED CATEGORY — LIST OF YOUR CREATIONS
// ═══════════════════════════════════════════════════════════════════════════════
class _HostedCategoryScreen extends StatefulWidget {
  final bool isRushIn;
  final bool isEvent;
  final String title;
  final Color color;
  final IconData icon;
  const _HostedCategoryScreen({
    required this.isRushIn, this.isEvent = false,
    required this.title, required this.color, required this.icon,
  });
  @override State<_HostedCategoryScreen> createState() => _HCSState();
}

class _HCSState extends State<_HostedCategoryScreen> {
  List<Map<String, dynamic>> _myCreations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCreations();
  }

  Future<void> _fetchCreations() async {
    try {
      final all = await _sb.from('activities')
          .select('id, title, description, location_name, activity_time, category, created_at')
          .eq('user_id', _uid)
          .order('created_at', ascending: false);
      final filtered = (all as List).where((a) {
        final isRushIn = a['is_rush_in'] == true || (a['description']?.toString().contains('[is_rush_in:true]') ?? false);
        if (widget.isRushIn) return isRushIn;
        if (widget.isEvent) return !isRushIn && a['category'] == 'event';
        return !isRushIn && a['category'] != 'event';
      }).map<Map<String, dynamic>>((a) => Map<String, dynamic>.from(a)).toList();
      if (mounted) setState(() { _myCreations = filtered; _loading = false; });
    } catch (e) {
      debugPrint('Error fetching creations: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumBackground(
      glowColor: widget.color,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [widget.color.withValues(alpha: 0.25), widget.color.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(widget.icon, color: widget.color, size: 16),
            ),
            const SizedBox(width: 10),
            Text('${widget.title} — Hosted',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
          ]),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: widget.color))
            : _myCreations.isEmpty
                ? _emptyState(widget.icon, 'You haven\'t hosted any ${widget.title.toLowerCase()}s yet')
                : RefreshIndicator(
                    color: widget.color,
                    onRefresh: _fetchCreations,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _myCreations.length + 1, // +1 for header
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16, left: 4),
                            child: Text('Your ${widget.title}s · ${_myCreations.length} hosted',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                          );
                        }
                        return _CreationCard(
                          creation: _myCreations[i - 1],
                          color: widget.color,
                          icon: widget.icon,
                          title: widget.title,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// CREATION CARD — shows individual hosting with live participant counts
// ═══════════════════════════════════════════════════════════════════════════════
class _CreationCard extends StatefulWidget {
  final Map<String, dynamic> creation;
  final Color color;
  final IconData icon;
  final String title;
  const _CreationCard({required this.creation, required this.color, required this.icon, required this.title});
  @override State<_CreationCard> createState() => _CCState();
}

class _CCState extends State<_CreationCard> {
  int _pendingCount = 0;
  int _approvedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final id = widget.creation['id'].toString();
      final reqs = await _sb.from('requests').select('status').eq('target_id', id);
      int pending = 0, approved = 0;
      for (final r in (reqs as List)) {
        if (r['status'] == 'pending') pending++;
        if (r['status'] == 'approved') approved++;
      }
      if (mounted) setState(() { _pendingCount = pending; _approvedCount = approved; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cr = widget.creation;
    final cTitle = cr['title'] as String? ?? 'Untitled';
    final desc = cr['description'] as String? ?? '';
    final locName = cr['location_name'] as String? ?? '';

    // Date formatting
    String dateStr = '';
    final timeStr = cr['activity_time'] as String?;
    if (timeStr != null) {
      final dt = DateTime.tryParse(timeStr)?.toLocal();
      if (dt != null) {
        final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year} · ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      }
    }

    final bool hasPending = _pendingCount > 0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _CreationParticipantScreen(
            activityId: cr['id'].toString(),
            activityTitle: cTitle,
            color: widget.color,
            icon: widget.icon,
            categoryTitle: widget.title,
          ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.color.withValues(alpha: hasPending ? 0.3 : 0.1)),
        ),
        child: Column(children: [
          // ── Header with gradient ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [widget.color.withValues(alpha: 0.08), Colors.transparent],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.color.withValues(alpha: 0.2), widget.color.withValues(alpha: 0.06)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cTitle,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (desc.isNotEmpty)
                  Text(desc,
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              // Pending badge
              if (hasPending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('$_pendingCount new', style: GoogleFonts.inter(color: _amber, fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: widget.color.withValues(alpha: 0.4), size: 20),
            ]),
          ),

          // ── Info chips + participant counts ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              // Location + date
              Expanded(child: Wrap(spacing: 8, runSpacing: 6, children: [
                if (locName.isNotEmpty)
                  _miniChip(Icons.location_on, locName, _cyan),
                if (dateStr.isNotEmpty)
                  _miniChip(Icons.schedule, dateStr, _amber),
              ])),
              // Participant counts
              _countBadge(Icons.hourglass_top, _pendingCount, _amber),
              const SizedBox(width: 8),
              _countBadge(Icons.check_circle, _approvedCount, _green),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _miniChip(IconData ic, String text, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(ic, size: 11, color: c.withValues(alpha: 0.6)),
    const SizedBox(width: 3),
    Text(text, style: GoogleFonts.inter(fontSize: 10, color: c.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);

  Widget _countBadge(IconData ic, int count, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ic, size: 12, color: c.withValues(alpha: 0.7)),
      const SizedBox(width: 4),
      Text('$count', style: GoogleFonts.inter(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    ]),
  );
}


// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PARTICIPANT SCREEN — Requests / Approved for ONE specific creation
// ═══════════════════════════════════════════════════════════════════════════════
class _CreationParticipantScreen extends StatelessWidget {
  final String activityId;
  final String activityTitle;
  final Color color;
  final IconData icon;
  final String categoryTitle;
  const _CreationParticipantScreen({
    required this.activityId, required this.activityTitle,
    required this.color, required this.icon, required this.categoryTitle,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: _PremiumBackground(
        glowColor: color,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: const BackButton(color: Colors.white),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activityTitle,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('$categoryTitle · Participants',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
            ]),
            bottom: TabBar(
              indicatorColor: color,
              indicatorWeight: 3,
              labelColor: color,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.hourglass_top, size: 14), SizedBox(width: 6), Text('REQUESTS'),
                ])),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, size: 14), SizedBox(width: 6), Text('APPROVED'),
                ])),
              ],
            ),
          ),
          body: TabBarView(children: [
            _LiveParticipantStream(activityIds: [activityId], status: 'pending', color: color, icon: icon),
            _LiveParticipantStream(activityIds: [activityId], status: 'approved', color: color, icon: icon),
          ]),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// LIVE PARTICIPANT STREAM — real-time across all devices
// ═══════════════════════════════════════════════════════════════════════════════
class _LiveParticipantStream extends StatelessWidget {
  final List<String> activityIds;
  final String status; // 'pending' or 'approved'
  final Color color;
  final IconData icon;
  const _LiveParticipantStream({required this.activityIds, required this.status, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    // Stream ALL requests, then filter client-side for our activity IDs + status
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb.from('requests').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: color));
        }

        final allReqs = snapshot.data ?? [];
        final filtered = allReqs.where((r) =>
            activityIds.contains(r['target_id']?.toString()) &&
            r['status'] == status
        ).toList();

        if (filtered.isEmpty) {
          return _emptyState(icon, status == 'pending'
              ? 'No pending requests right now'
              : 'No approved participants yet');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ParticipantProfileCard(
            req: filtered[i],
            color: color,
            isPending: status == 'pending',
          ),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// PARTICIPANT PROFILE CARD — with approve/reject + view full profile
// ═══════════════════════════════════════════════════════════════════════════════
class _ParticipantProfileCard extends StatefulWidget {
  final Map<String, dynamic> req;
  final Color color;
  final bool isPending;
  const _ParticipantProfileCard({required this.req, required this.color, required this.isPending});
  @override State<_ParticipantProfileCard> createState() => _PPCState();
}

class _PPCState extends State<_ParticipantProfileCard> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _activity;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final senderId = widget.req['sender_id'] as String? ?? '';
      final targetId = widget.req['target_id'] as String? ?? '';
      final futures = await Future.wait([
        _sb.from('profiles').select('id, name, avatar_url, bio').eq('id', senderId).maybeSingle(),
        _sb.from('activities').select('title').eq('id', targetId).maybeSingle(),
      ]);
      if (mounted) {
        setState(() {
        _profile = futures[0];
        _activity = futures[1];
      });
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _busy = true);
    try {
      await _sb.from('requests').update({'status': newStatus}).eq('id', widget.req['id']);
      
      if (newStatus == 'approved') {
        final senderId = widget.req['sender_id'] as String?;
        final actTitle = _activity?['title'] as String? ?? 'Activity';
        if (senderId != null) {
          NotificationService.sendNotification(
            userId: senderId,
            type: NotificationType.approval,
            title: 'Request Approved! 🎉',
            body: 'Your request to join $actTitle has been approved!',
            payload: {'request_id': widget.req['id'], 'target_id': widget.req['target_id']},
          );
        }
      } else if (newStatus == 'rejected') {
        final senderId = widget.req['sender_id'] as String?;
        final actTitle = _activity?['title'] as String? ?? 'Activity';
        if (senderId != null) {
          NotificationService.sendNotification(
            userId: senderId,
            type: NotificationType.rejection,
            title: 'Request Declined 😔',
            body: 'Your request to join $actTitle was declined.',
            payload: {'request_id': widget.req['id'], 'target_id': widget.req['target_id']},
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _viewProfile() {
    final userId = widget.req['sender_id'] as String?;
    if (userId == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['name'] as String? ?? 'Loading...';
    final avatar = _profile?['avatar_url'] as String?;
    final bio = _profile?['bio'] as String? ?? '';
    final actTitle = _activity?['title'] as String? ?? '';
    final message = widget.req['message'] as String? ?? 'Wants to join';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // ── Main row: Avatar + Info + Actions ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Tappable avatar → opens full profile
              GestureDetector(
                onTap: _viewProfile,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                      backgroundColor: widget.color.withValues(alpha: 0.15),
                      child: avatar == null
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                          : null,
                    ),
                    // Small "view profile" indicator
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: _cyan, shape: BoxShape.circle,
                          border: Border.all(color: _card, width: 2),
                        ),
                        child: const Icon(Icons.open_in_new, size: 8, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Name + bio + activity title
              Expanded(
                child: GestureDetector(
                  onTap: _viewProfile,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (bio.isNotEmpty)
                      Text(bio,
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (actTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          Icon(Icons.subdirectory_arrow_right, size: 12, color: widget.color.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(actTitle,
                              style: GoogleFonts.inter(color: widget.color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),

              // Action buttons
              if (_busy)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _cyan))
              else if (widget.isPending) ...[
                _actionBtn(Icons.check_rounded, _green, 'Approve', () => _updateStatus('approved')),
                const SizedBox(width: 8),
                _actionBtn(Icons.close_rounded, _red, 'Reject', () => _updateStatus('rejected')),
              ] else ...[
                // Show APPROVED badge + revoke option
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: Text('APPROVED', style: GoogleFonts.inter(color: _green, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                _actionBtn(Icons.undo_rounded, _amber, 'Revoke', () => _updateStatus('pending')),
              ],
            ]),
          ),

          // ── Message strip ──
          if (message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(children: [
                const Icon(Icons.message_outlined, size: 13, color: Colors.white24),
                const SizedBox(width: 8),
                Expanded(child: Text('"$message"',
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                // View full profile button
                GestureDetector(
                  onTap: _viewProfile,
                  child: Text('View Profile →',
                      style: GoogleFonts.inter(color: _cyan, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData ic, Color c, String tooltip, VoidCallback onTap) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Icon(ic, color: c, size: 18),
      ),
    ),
  );
}


// ═══════════════════════════════════════════════════════════════════════════════
// COMPANION HOSTED — direct companion requests targeting current user
// ═══════════════════════════════════════════════════════════════════════════════
class _CompanionHostedScreen extends StatelessWidget {
  const _CompanionHostedScreen();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: _PremiumBackground(
        glowColor: _green,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: const BackButton(color: Colors.white),
            title: Text('Companionship — Hosted',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
            bottom: TabBar(
              indicatorColor: _green,
              labelColor: _green,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [Tab(text: 'REQUESTS'), Tab(text: 'APPROVED')],
            ),
          ),
          body: const TabBarView(children: [
            _CompanionStream(status: 'pending'),
            _CompanionStream(status: 'approved'),
          ]),
        ),
      ),
    );
  }
}

class _CompanionStream extends StatelessWidget {
  final String status;
  const _CompanionStream({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb.from('requests').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (_, snap) {
        final list = (snap.data ?? []).where((r) =>
            r['target_type'] == 'companion' &&
            r['target_id'] == _uid &&
            r['status'] == status
        ).toList();

        if (snap.connectionState == ConnectionState.waiting && list.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        if (list.isEmpty) {
          return _emptyState(Icons.volunteer_activism,
              status == 'pending' ? 'No pending companion requests' : 'No approved companions');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) => _ParticipantProfileCard(req: list[i], color: _green, isPending: status == 'pending'),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// 2.  JOINED BY YOU — category picker
// ═══════════════════════════════════════════════════════════════════════════════
class JoinedByYouScreen extends StatelessWidget {
  const JoinedByYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PremiumBackground(
      glowColor: _cyan,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text('Joined by You',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
        children: [
          Text('Select a category to see your participation status',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          _CategoryCard(
            icon: Icons.flash_on, title: 'Rush-Ins',
            subtitle: 'Rush-ins you requested to join', color: _cyan,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _JoinedCategoryScreen(
                    targetType: 'activity', filterRushIn: true,
                    title: 'Rush-Ins', color: _cyan, icon: Icons.flash_on))),
          ),
          _CategoryCard(
            icon: Icons.event, title: 'Activities',
            subtitle: 'Activities you signed up for', color: _violet,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _JoinedCategoryScreen(
                    targetType: 'activity', filterRushIn: false,
                    title: 'Activities', color: _violet, icon: Icons.event))),
          ),
          _CategoryCard(
            icon: Icons.celebration, title: 'Events',
            subtitle: 'Events you registered for', color: _amber,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _JoinedCategoryScreen(
                    targetType: 'activity', filterEvent: true,
                    title: 'Events', color: _amber, icon: Icons.celebration))),
          ),
          _CategoryCard(
            icon: Icons.volunteer_activism, title: 'Companionship',
            subtitle: 'Companion requests you sent', color: _green,
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _JoinedCategoryScreen(
                    targetType: 'companion',
                    title: 'Companionship', color: _green, icon: Icons.volunteer_activism))),
          ),
        ],
      ),
    ));
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// JOINED CATEGORY — 3-TAB LAYOUT: Past / Upcoming / Pending
// ═══════════════════════════════════════════════════════════════════════════════
class _JoinedCategoryScreen extends StatelessWidget {
  final String targetType;    // 'activity' or 'companion'
  final bool filterRushIn;    // true = show only rush-ins
  final bool filterEvent;     // true = show only events
  final String title;
  final Color color;
  final IconData icon;
  const _JoinedCategoryScreen({
    required this.targetType, this.filterRushIn = false, this.filterEvent = false,
    required this.title, required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: _PremiumBackground(
        glowColor: color,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: const BackButton(color: Colors.white),
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text('$title — Joined',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
          ]),
          bottom: TabBar(
            indicatorColor: color,
            indicatorWeight: 3,
            labelColor: color,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: const [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: 14), SizedBox(width: 5), Text('PAST'),
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.upcoming, size: 14), SizedBox(width: 5), Text('UPCOMING'),
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.hourglass_top, size: 14), SizedBox(width: 5), Text('PENDING'),
              ])),
            ],
          ),
        ),
        body: TabBarView(children: [
          // Past: approved + activity_time in the past
          _JoinedTabContent(
            targetType: targetType, filterRushIn: filterRushIn, filterEvent: filterEvent,
            tabType: 'past', color: color, icon: icon,
          ),
          // Upcoming: approved + activity_time in the future
          _JoinedTabContent(
            targetType: targetType, filterRushIn: filterRushIn, filterEvent: filterEvent,
            tabType: 'upcoming', color: color, icon: icon,
          ),
          // Pending: status == pending
          _JoinedTabContent(
            targetType: targetType, filterRushIn: filterRushIn, filterEvent: filterEvent,
            tabType: 'pending', color: color, icon: icon,
          ),
        ]),
      ),
    ));
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// TAB CONTENT — streams requests and filters by tab type
// ═══════════════════════════════════════════════════════════════════════════════
class _JoinedTabContent extends StatelessWidget {
  final String targetType;
  final bool filterRushIn;
  final bool filterEvent;
  final String tabType; // 'past', 'upcoming', 'pending'
  final Color color;
  final IconData icon;
  const _JoinedTabContent({
    required this.targetType, this.filterRushIn = false, this.filterEvent = false,
    required this.tabType, required this.color, required this.icon,
  });

  String get _emptyMsg {
    switch (tabType) {
      case 'past':     return 'No past events to show';
      case 'upcoming': return 'No upcoming events yet';
      case 'pending':  return 'No pending requests';
      default:         return 'Nothing here';
    }
  }

  IconData get _emptyIcon {
    switch (tabType) {
      case 'past':     return Icons.history_toggle_off;
      case 'upcoming': return Icons.event_available;
      case 'pending':  return Icons.hourglass_empty;
      default:         return icon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb.from('requests').stream(primaryKey: ['id']).eq('sender_id', _uid).order('created_at', ascending: false),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Center(child: CircularProgressIndicator(color: color));
        }

        // Filter by target_type
        final byType = (snap.data ?? []).where((r) {
          if (targetType == 'companion') return r['target_type'] == 'companion';
          return r['target_type'] == 'activity' || r['target_type'] == 'rush_in';
        }).toList();

        // For pending tab: just filter by status
        if (tabType == 'pending') {
          final pending = byType.where((r) => r['status'] == 'pending').toList();
          if (pending.isEmpty) return _emptyState(_emptyIcon, _emptyMsg);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (_, i) => _JoinedEnrichedCard(
              req: pending[i], color: color, icon: icon, tabType: tabType,
              targetType: targetType, filterRushIn: filterRushIn, filterEvent: filterEvent,
            ),
          );
        }

        // For past/upcoming: status == approved, then filter by time
        final approved = byType.where((r) => r['status'] == 'approved').toList();
        if (approved.isEmpty) return _emptyState(_emptyIcon, _emptyMsg);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: approved.length,
          itemBuilder: (_, i) => _JoinedEnrichedCard(
            req: approved[i], color: color, icon: icon, tabType: tabType,
            targetType: targetType, filterRushIn: filterRushIn, filterEvent: filterEvent,
          ),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// ENRICHED JOINED CARD — shows title, host, date, participants, status
// ═══════════════════════════════════════════════════════════════════════════════
class _JoinedEnrichedCard extends StatefulWidget {
  final Map<String, dynamic> req;
  final Color color;
  final IconData icon;
  final String tabType;
  final String targetType;
  final bool filterRushIn;
  final bool filterEvent;
  const _JoinedEnrichedCard({
    required this.req, required this.color, required this.icon, required this.tabType,
    required this.targetType, this.filterRushIn = false, this.filterEvent = false,
  });
  @override State<_JoinedEnrichedCard> createState() => _JECState();
}

class _JECState extends State<_JoinedEnrichedCard> {
  Map<String, dynamic>? _activity;
  Map<String, dynamic>? _host;
  int _participantCount = 0;
  bool _hidden = false; // for time/type filtering

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final targetId = widget.req['target_id'] as String? ?? '';
      if (widget.targetType == 'companion') {
        // For companion, target_id is a user ID
        final profile = await _sb.from('profiles').select('name, avatar_url').eq('id', targetId).maybeSingle();
        if (mounted) {
          setState(() {
          _activity = {'title': profile?['name'] ?? 'User', 'description': 'Companion request'};
          _host = profile;
        });
        }
        return;
      }

      // For activities/rush-ins/events
      final act = await _sb.from('activities').select('*').eq('id', targetId).maybeSingle();
      if (act == null) { if (mounted) setState(() => _hidden = true); return; }

      // Apply rush-in/event filter
      if (widget.filterRushIn && act['is_rush_in'] != true) { if (mounted) setState(() => _hidden = true); return; }
      if (!widget.filterRushIn && !widget.filterEvent && act['is_rush_in'] == true) { if (mounted) setState(() => _hidden = true); return; }
      if (widget.filterEvent && act['category'] != 'event') { if (mounted) setState(() => _hidden = true); return; }

      // Apply time filter for past/upcoming
      if (widget.tabType == 'past' || widget.tabType == 'upcoming') {
        final timeStr = act['activity_time'] as String?;
        if (timeStr != null) {
          final actTime = DateTime.tryParse(timeStr);
          if (actTime != null) {
            final now = DateTime.now();
            if (widget.tabType == 'past' && actTime.isAfter(now)) { if (mounted) setState(() => _hidden = true); return; }
            if (widget.tabType == 'upcoming' && actTime.isBefore(now)) { if (mounted) setState(() => _hidden = true); return; }
          }
        }
      }

      // Fetch host profile
      final hostId = act['user_id'] as String? ?? '';
      final host = await _sb.from('profiles').select('name, avatar_url').eq('id', hostId).maybeSingle();

      // Count approved participants
      final approvedReqs = await _sb.from('requests').select('id').eq('target_id', targetId).eq('status', 'approved');
      final count = (approvedReqs as List).length;

      if (mounted) {
        setState(() {
        _activity = act;
        _host = host;
        _participantCount = count;
      });
      }
    } catch (e) {
      debugPrint('_JoinedEnrichedCard load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    if (_activity == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
        child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))),
      );
    }

    final title = _activity!['title'] as String? ?? 'Untitled';
    final desc = _activity!['description'] as String? ?? '';
    final locName = _activity!['location_name'] as String? ?? '';
    final hostName = _host?['name'] as String? ?? 'Host';
    final hostAvatar = _host?['avatar_url'] as String?;
    final status = widget.req['status'] as String? ?? 'pending';

    // Status styling
    Color sColor;
    String statusLabel;
    IconData statusIcon;
    switch (widget.tabType) {
      case 'past':
        sColor = Colors.white38;
        statusLabel = 'ATTENDED';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'upcoming':
        sColor = _green;
        statusLabel = 'CONFIRMED';
        statusIcon = Icons.event_available;
        break;
      default:
        sColor = _amber;
        statusLabel = status == 'pending' ? 'PENDING' : status.toUpperCase();
        statusIcon = Icons.hourglass_top;
    }

    // Date formatting
    String dateStr = '';
    final timeStr = _activity!['activity_time'] as String?;
    if (timeStr != null) {
      final dt = DateTime.tryParse(timeStr)?.toLocal();
      if (dt != null) {
        final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year} · ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      }
    }

    return GestureDetector(
      onTap: () {
        if (widget.targetType == 'companion') {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: widget.req['target_id'])));
        } else {
          if (_activity != null) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => RushInConsumerDetailView(activity: _activity!, onInteraction: () {})));
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.color.withValues(alpha: 0.12)),
        ),
        child: Column(children: [
          // ── Top section: status badge + icon ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [widget.color.withValues(alpha: 0.08), Colors.transparent],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.color.withValues(alpha: 0.2), widget.color.withValues(alpha: 0.06)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sColor.withValues(alpha: 0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, color: sColor, size: 12),
                  const SizedBox(width: 4),
                  Text(statusLabel, style: GoogleFonts.inter(color: sColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ]),
              ),
            ]),
          ),

          // ── Middle section: description + location + date ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (desc.isNotEmpty)
                Text(desc, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              if (desc.isNotEmpty) const SizedBox(height: 10),
              // Info chips row
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (locName.isNotEmpty)
                  _infoChip(Icons.location_on, locName, _cyan),
                if (dateStr.isNotEmpty)
                  _infoChip(Icons.schedule, dateStr, _amber),
                _infoChip(Icons.people, '$_participantCount joined', _green),
              ]),
            ]),
          ),

          // ── Bottom: Host row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: hostAvatar != null ? NetworkImage(hostAvatar) : null,
                backgroundColor: widget.color.withValues(alpha: 0.15),
                child: hostAvatar == null
                    ? Text(hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Hosted by $hostName',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11))),
              Icon(Icons.arrow_forward_ios, size: 12, color: widget.color.withValues(alpha: 0.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData ic, String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ic, size: 11, color: c.withValues(alpha: 0.7)),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(fontSize: 10, color: c.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}


// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _CategoryCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
        ]),
      ),
    );
  }
}

Widget _emptyState(IconData ic, String msg) => Center(
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: -5,
            )
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withValues(alpha: 0.1), Colors.transparent],
                radius: 0.8,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(ic, size: 48, color: Colors.white38),
          ),
          const SizedBox(height: 24),
          Text(msg, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
        ]),
      ),
    ),
  ),
);

class _PremiumBackground extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  const _PremiumBackground({required this.child, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _bg),
        Positioned(
          top: -100, right: -50,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, color: glowColor.withValues(alpha: 0.15)),
          ),
        ),
        Positioned(
          bottom: -50, left: -100,
          child: Container(
            width: 350, height: 350,
            decoration: BoxDecoration(shape: BoxShape.circle, color: glowColor.withValues(alpha: 0.08)),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),
        child,
      ],
    );
  }
}

