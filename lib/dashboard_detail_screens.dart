// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rush_in_consumer_detail_view.dart';

// ─── globals ───────────────────────────────────────────────────────────────
SupabaseClient get _sb => Supabase.instance.client;
String? get _uid => _sb.auth.currentUser?.id;

// ─── design tokens ─────────────────────────────────────────────────────────
const _bg    = Color(0xFF0A0A0F);
const _card  = Color(0xFF141C2E);
const _cyan  = Color(0xFFFF6B00);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _red   = Color(0xFFEF4444);
const _pink  = Color(0xFFFF3D00);
const _rush  = Color(0xFF00BFFF);   // live-rush accent colour

// ─── helpers ───────────────────────────────────────────────────────────────
PreferredSizeWidget _appBar(String t, {List<Widget>? actions}) => AppBar(
  backgroundColor: _bg, elevation: 0,
  leading: const BackButton(color: Colors.white),
  title: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
  actions: actions,
);

Widget _empty(IconData ic, String msg) => Center(
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(ic, size: 56, color: Colors.white10),
    const SizedBox(height: 14),
    Text(msg, style: GoogleFonts.inter(color: Colors.white30, fontSize: 13)),
  ]),
);

// ════════════════════════ 1. ACTIVITY SUMMARY ═══════════════════════════════
class ActivitySummaryScreen extends StatelessWidget {
  const ActivitySummaryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg, appBar: _appBar('Activity Summary'),
    body: FutureBuilder<Map<String, int>>(
      future: _stats(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _cyan));
        final s = snap.data!;
        return ListView(padding: const EdgeInsets.all(20), children: [
          _stile('Activities Hosted', '${s['a']}', Icons.event_note, _cyan),
          _stile('Rush-Ins Created',  '${s['r']}', Icons.flash_on, _pink),
          _stile('Total Participants','${s['p']}', Icons.people, _green),
          _stile('Events Joined',     '${s['j']}', Icons.celebration, _amber),
        ]);
      },
    ),
  );

  Future<Map<String,int>> _stats() async {
    try {
      final all  = await _sb.from('activities').select('id,description').eq('user_id', _uid!);
      final rush = all.where((x) => x['is_rush_in'] == true || (x['description']?.toString().contains('[is_rush_in:true]') ?? false)).length;
      final ids  = all.map((x) => x['id']).toList();
      int pCount = 0;
      if (ids.isNotEmpty) { final p = await _sb.from('requests').select('id').inFilter('target_id', ids).eq('status','approved'); pCount = p.length; }
      final joined = await _sb.from('requests').select('id').eq('sender_id', _uid!).eq('target_type','activity').eq('status','approved');
      return {'a': all.length - rush, 'r': rush, 'p': pCount, 'j': joined.length};
    } catch(_) { return {'a':0,'r':0,'p':0,'j':0}; }
  }

  Widget _stile(String lbl, String val, IconData ic, Color c) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.15))),
    child: Row(children: [
      Container(width:42, height:42, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(ic, color: c, size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Text(lbl, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14))),
      Text(val, style: GoogleFonts.poppins(color: c, fontSize: 22, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ════════════════════════ 2. PARTICIPANT — SENT-REQUEST LIST ════════════════
/// Used for "Activity Alerts" and "Rush-In Alerts" in the participant dashboard.
class SentRequestsScreen extends StatelessWidget {
  final String title;
  final String targetType;   // 'activity' or 'rush_in'
  final IconData icon;
  final Color color;
  const SentRequestsScreen({super.key, required this.title, required this.targetType, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: _appBar(title),
    body: StreamBuilder<List<Map<String,dynamic>>>(
      stream: _sb.from('requests').stream(primaryKey:['id']).eq('sender_id',_uid!).order('created_at', ascending: false),
      builder: (_, snap) {
        final list = (snap.data ?? []).where((r) => r['target_type'] == targetType).toList();
        if (snap.connectionState == ConnectionState.waiting && list.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _cyan));
        }
        if (list.isEmpty) return _empty(icon, 'No $title yet');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) => _ParticipantRequestCard(req: list[i], color: color, icon: icon, targetType: targetType),
        );
      },
    ),
  );
}

class _ParticipantRequestCard extends StatelessWidget {
  final Map<String,dynamic> req;
  final Color color;
  final IconData icon;
  final String targetType;
  const _ParticipantRequestCard({required this.req, required this.color, required this.icon, required this.targetType});

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'pending';
    final sColor = status == 'approved' ? const Color(0xFF10B981) : status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return FutureBuilder<Map<String,dynamic>?>(
      future: _sb.from('activities').select('*').eq('id', req['target_id']).maybeSingle(),
      builder: (_, snap) {
        final act = snap.data;
        final title = act?['title'] as String? ?? 'Untitled';
        final desc  = act?['category'] as String? ?? act?['description'] as String? ?? '...'; // using category or desc as the subtext like 'football'

        return GestureDetector(
          onTap: () {
            if (act != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => RushInConsumerDetailView(activity: act, onInteraction: () {})));
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827), // deep dark background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)), // subtle border
            ),
            child: Row(children: [
              // Icon badge (rounded square)
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.1), // light blue tint like in screenshot
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.radar, color: Color(0xFFFF6B00), size: 24), // @ icon style or radar
              ),
              const SizedBox(width: 16),
              // Title + desc
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(desc,  style: GoogleFonts.inter(fontSize: 12, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 12),
              // Status pill (hollow outline style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent, 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: sColor.withValues(alpha: 0.5)), // slightly thicker outline
                ),
                child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: sColor, letterSpacing: 0.5)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class RushInParticipationsScreen extends StatelessWidget {
  const RushInParticipationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SentRequestsScreen(title: 'Rush-In Alerts', targetType: 'rush_in', icon: Icons.radar, color: _rush);
}

// ════════════════════════ 3. PARTICIPANT — DETAIL VIEW ══════════════════════
/// Shown when a participant taps a request card.
/// Layout matches the screenshot: LIVE RUSH-IN badge, title, description,
/// host row, approval banner + delete button, locked/unlocked location card,
/// Approved Participants section, Public Waitlist section.
class ParticipantActivityDetailScreen extends StatefulWidget {
  final Map<String,dynamic> request;
  final String targetType;
  const ParticipantActivityDetailScreen({super.key, required this.request, required this.targetType});
  @override State<ParticipantActivityDetailScreen> createState() => _PADS();
}
class _PADS extends State<ParticipantActivityDetailScreen> {
  Map<String,dynamic>? _act;
  bool _loading = true;

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final act  = await _sb.from('activities').select('*').eq('id', widget.request['target_id']).maybeSingle();
      if (act != null) {
        if (mounted) setState(() { _act = act; });
      }
    } catch(_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: _bg, appBar: _appBar('Loading...'), body: const Center(child: CircularProgressIndicator(color: _cyan)));
    if (_act == null) return Scaffold(backgroundColor: _bg, appBar: _appBar('Not Found'), body: _empty(Icons.error_outline, 'This event no longer exists'));

    return RushInConsumerDetailView(
      activity: _act!,
      onInteraction: () {},
    );
  }
}

// ════════════════════════ 4. HOST — ACTIVITY DETAIL ═════════════════════════
/// Called when a host taps one of their activities in the management screen.
/// Shows title, description, approve/reject controls per participant, map button.
class HostActivityDetailScreen extends StatefulWidget {
  final Map<String,dynamic> activity;
  const HostActivityDetailScreen({super.key, required this.activity});
  @override State<HostActivityDetailScreen> createState() => _HADS();
}
class _HADS extends State<HostActivityDetailScreen> {
  @override Widget build(BuildContext context) {
    return RushInConsumerDetailView(
      activity: widget.activity,
      onInteraction: () {},
    );
  }
}

/// One row in the Host detail view — shows participant name + approve/reject buttons.
class _HostParticipantCard extends StatefulWidget {
  final Map<String,dynamic> req;
  const _HostParticipantCard({required this.req});
  @override State<_HostParticipantCard> createState() => _HPCState();
}
class _HPCState extends State<_HostParticipantCard> {
  Map<String,dynamic>? _profile;
  bool _busy = false;
  @override void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    try {
      final p = await _sb.from('profiles').select('name,avatar_url').eq('id', widget.req['sender_id']).maybeSingle();
      if (mounted) setState(() => _profile = p);
    } catch(_) {}
  }

  Future<void> _respond(String status) async {
    setState(() => _busy = true);
    try { await _sb.from('requests').update({'status': status}).eq('id', widget.req['id']); }
    catch(e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    if (mounted) setState(() => _busy = false);
  }

  @override Widget build(BuildContext context) {
    final status = widget.req['status'] as String? ?? 'pending';
    final sColor = status == 'approved' ? _green : status == 'rejected' ? _red : _amber;
    final av = _profile?['avatar_url'] as String?;
    final nm = _profile?['name'] as String? ?? 'User';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: sColor.withValues(alpha: 0.2))),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundImage: av != null ? NetworkImage(av) : null,
          backgroundColor: _cyan.withValues(alpha: 0.15),
          child: av == null ? Text(nm[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nm, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: sColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(status.toUpperCase(), style: GoogleFonts.inter(color: sColor, fontSize: 9, fontWeight: FontWeight.w700))),
        ])),
        if (_busy) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _cyan))
        else if (status == 'pending') ...[
          _btn(Icons.check_rounded, _green, () => _respond('approved')),
          const SizedBox(width: 8),
          _btn(Icons.close_rounded, _red, () => _respond('rejected')),
        ] else if (status == 'approved')
          _btn(Icons.close_rounded, _red, () => _respond('rejected'))
        else if (status == 'rejected')
          _btn(Icons.refresh_rounded, _green, () => _respond('approved')),
      ]),
    );
  }

  Widget _btn(IconData ic, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Icon(ic, color: c, size: 18)),
  );
}

// ════════════════════════ 5. STUB SCREENS (profile placeholders) ═════════════
/// These stubs satisfy navigation. Replace with real implementations as needed.

class FollowRequestsScreen extends StatelessWidget {
  const FollowRequestsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Follow Requests', icon: Icons.person_add_alt,
    body: StreamBuilder<List<Map<String,dynamic>>>(
      stream: _sb.from('requests').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (_, snap) {
        final list = (snap.data ?? []).where((r) => r['status'] == 'pending' && r['target_id'] == _uid && r['target_type'] == 'follow').toList();
        if (snap.connectionState == ConnectionState.waiting && list.isEmpty) return const Center(child: CircularProgressIndicator(color: _cyan));
        if (list.isEmpty) return _empty(Icons.people_outline, 'No pending follow requests');
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: list.length,
          itemBuilder: (ctx, i) => _FollowRequestCard(req: list[i]));
      },
    ));
}

class _FollowRequestCard extends StatefulWidget {
  final Map<String,dynamic> req;
  const _FollowRequestCard({required this.req});
  @override State<_FollowRequestCard> createState() => _FRCState();
}
class _FRCState extends State<_FollowRequestCard> {
  Map<String,dynamic>? _p;
  bool _busy = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await _sb.from('profiles').select('name,avatar_url').eq('id', widget.req['sender_id']).maybeSingle();
    if (mounted) setState(() => _p = p);
  }
  Future<void> _act(String s) async { setState(()=>_busy=true); await _sb.from('requests').update({'status':s}).eq('id',widget.req['id']); if (mounted) setState(()=>_busy=false); }
  @override Widget build(BuildContext ctx) {
    final av = _p?['avatar_url'] as String?; final nm = _p?['name'] as String? ?? 'User';
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Row(children: [
        CircleAvatar(radius: 22, backgroundImage: av != null ? NetworkImage(av) : null, backgroundColor: _cyan.withValues(alpha: 0.15), child: av==null ? Text(nm[0], style: const TextStyle(color: Colors.white)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nm, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          Text('Wants to follow you', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
        ])),
        if (_busy) const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:_cyan))
        else ...[
          TextButton(onPressed: () => _act('approved'), child: const Text('Accept', style: TextStyle(color: _green))),
          TextButton(onPressed: () => _act('rejected'), child: const Text('Decline', style: TextStyle(color: _red))),
        ],
      ]));
  }
}

class EventInvitationsScreen extends StatelessWidget {
  const EventInvitationsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Event Invitations', icon: Icons.event,
    body: _empty(Icons.event_note, 'No event invitations'));
}
class SparkMatchesScreen extends StatelessWidget {
  const SparkMatchesScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Spark Matches', icon: Icons.flash_on,
    body: _empty(Icons.bolt, 'No new spark matches'));
}
class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'My Posts', icon: Icons.photo_library,
    body: _empty(Icons.image_not_supported, 'No posts yet'));
}
class SavedCollectionsScreen extends StatelessWidget {
  const SavedCollectionsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Saved Collections', icon: Icons.bookmark,
    body: _empty(Icons.bookmarks_outlined, 'Nothing saved yet'));
}
class ProfileInsightsScreen extends StatelessWidget {
  const ProfileInsightsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Profile Insights', icon: Icons.bar_chart,
    body: _empty(Icons.insights, 'No analytics yet'));
}
class SparkAnalyticsScreen extends StatelessWidget {
  const SparkAnalyticsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Spark Analytics', icon: Icons.trending_up,
    body: _empty(Icons.analytics, 'No spark data yet'));
}
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Blocked Users', icon: Icons.block,
    body: _empty(Icons.person_off, 'No blocked users'));
}
class QRCodeScreen extends StatelessWidget {
  const QRCodeScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'My QR Code', icon: Icons.qr_code_2,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.qr_code_2, size: 120, color: _cyan),
      const SizedBox(height: 16),
      Text(_uid ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 8),
      SelectableText(_uid ?? '', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16),
      TextButton.icon(
        onPressed: () => Clipboard.setData(ClipboardData(text: _uid ?? '')),
        icon: const Icon(Icons.copy, size: 16, color: _cyan), label: const Text('Copy ID', style: TextStyle(color: _cyan)),
      ),
    ])),
  );
}
class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});
  @override Widget build(BuildContext context) => _StubScreen(title: 'Invite Friends', icon: Icons.share,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.group_add, size: 80, color: _cyan),
      const SizedBox(height: 16),
      Text('Share your profile link!', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: _cyan),
        icon: const Icon(Icons.share, color: Colors.black), label: const Text('Share', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () {},
      ),
    ])));
}

/// Generic scaffold used by stub screens
class _StubScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget body;
  const _StubScreen({required this.title, required this.icon, required this.body});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: _bg, appBar: _appBar(title), body: body);
}

// ════════════════════════ 6. OVERLAY HELPER (avoid import issues) ════════════
// Needed to suppress "Overlay" undefined - kept minimal since FlutterMap
// handles its own overlay internally in newer versions.
// (No extra code needed — Overlay widget from Flutter is fine.)
