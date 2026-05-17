// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ─── globals ───────────────────────────────────────────────────────────────
SupabaseClient get _sb => Supabase.instance.client;
String? get _uid => _sb.auth.currentUser?.id;

// ─── design tokens ─────────────────────────────────────────────────────────
const _bg    = Color(0xFF0A0A0F);
const _bg2   = Color(0xFF111827);
const _card  = Color(0xFF141C2E);
const _cyan  = Color(0xFF00E5FF);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _red   = Color(0xFFEF4444);
const _pink  = Color(0xFFEC4899);
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
      final all  = await _sb.from('activities').select('id,is_rush_in').eq('user_id', _uid!);
      final rush = all.where((x) => x['is_rush_in'] == true).length;
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
      future: _sb.from('activities').select('title,description,category').eq('id', req['target_id']).maybeSingle(),
      builder: (_, snap) {
        final act = snap.data;
        final title = act?['title'] as String? ?? 'Untitled';
        final desc  = act?['category'] as String? ?? act?['description'] as String? ?? '...'; // using category or desc as the subtext like 'football'

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantActivityDetailScreen(request: req, targetType: targetType))),
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
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1), // light blue tint like in screenshot
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.radar, color: Color(0xFF00E5FF), size: 24), // @ icon style or radar
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
  Map<String,dynamic>? _host;
  bool _loading = true;

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final act  = await _sb.from('activities').select('*').eq('id', widget.request['target_id']).maybeSingle();
      if (act != null) {
        final host = await _sb.from('profiles').select('id,name,avatar_url,is_ghost_mode').eq('id', act['user_id']).maybeSingle();
        if (mounted) setState(() { _act = act; _host = host; });
      }
    } catch(_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: _bg2, title: const Text('Leave event?', style: TextStyle(color: Colors.white)),
      content: const Text('This will withdraw your request. Are you sure?', style: TextStyle(color: Colors.white60)),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('CONFIRM', style: TextStyle(color: _red)))],
    ));
    if (ok == true) {
      await _sb.from('requests').delete().eq('id', widget.request['id']);
      if (mounted) Navigator.pop(context);
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: _bg, appBar: _appBar('Loading...'), body: const Center(child: CircularProgressIndicator(color: _cyan)));
    if (_act == null) return Scaffold(backgroundColor: _bg, appBar: _appBar('Not Found'), body: _empty(Icons.error_outline, 'This event no longer exists'));

    final status   = widget.request['status'] as String? ?? 'pending';
    final isApproved = status == 'approved';
    final isRush   = _act!['is_rush_in'] == true;
    final sColor   = isApproved ? _green : status == 'rejected' ? _red : _amber;
    final hostName  = _host?['name'] as String? ?? 'Host';
    final hostAvatar = _host?['avatar_url'] as String?;
    final locName   = _act!['location_name'] as String? ?? 'Unknown';
    final lat = double.tryParse(_act!['lat']?.toString() ?? '');
    final lng = double.tryParse(_act!['lng']?.toString() ?? '');

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(''),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), children: [

        // ── Badge ──
        Row(children: [
          Icon(isRush ? Icons.flash_on : Icons.event, color: _rush, size: 14),
          const SizedBox(width: 5),
          Text(isRush ? 'LIVE RUSH-IN' : 'ACTIVITY', style: GoogleFonts.inter(color: _rush, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),

        // ── Title ──
        Text(_act!['title'] as String? ?? 'Untitled',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('"${_act!['description'] as String? ?? ''}"',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 14, fontStyle: FontStyle.italic)),
        const SizedBox(height: 20),

        // ── Host row ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundImage: hostAvatar != null ? NetworkImage(hostAvatar) : null,
              backgroundColor: _cyan.withValues(alpha: 0.2),
              child: hostAvatar == null ? Text(hostName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hostName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              Text('Public Profile', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
            ]),
            const Spacer(),
            const Icon(Icons.verified, color: _green, size: 22),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Approval banner + delete btn ──
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: sColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sColor.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isApproved ? Icons.check_circle : status == 'rejected' ? Icons.cancel : Icons.hourglass_top, color: sColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  isApproved ? 'You are Approved! 🎉' : status == 'rejected' ? 'Request Rejected' : 'Pending Approval...',
                  style: GoogleFonts.poppins(color: sColor, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _delete,
            child: Container(width: 48, height: 48,
              decoration: BoxDecoration(color: _red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withValues(alpha: 0.35))),
              child: const Icon(Icons.delete_outline, color: _red)),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Location card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isApproved ? _bg2 : _bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isApproved ? _cyan.withValues(alpha: 0.4) : Colors.white12),
          ),
          child: Column(children: [
            Icon(Icons.location_on, color: isApproved ? _cyan : Colors.white24, size: 32),
            const SizedBox(height: 8),
            Text(isApproved ? 'LOCATION UNLOCKED' : 'LOCATION LOCKED',
              style: GoogleFonts.inter(color: isApproved ? _cyan : Colors.white24, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
            const SizedBox(height: 4),
            Text(isApproved ? locName : 'Revealed on approval',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            if (isApproved && lat != null && lng != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text('VIEW ON MAP', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  onPressed: () => _openMap(context, lat, lng, locName),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        // ── Approved participants ──
        _sectionHeader('Approved Participants', stream: _sb.from('requests').stream(primaryKey: ['id']).eq('target_id', _act!['id']!).order('created_at'),
          filter: (r) => r['status'] == 'approved'),

        const SizedBox(height: 20),

        // ── Waitlist ──
        _waitlistSection(_act!['id']),
      ]),
    );
  }

  Widget _sectionHeader(String title, {required Stream<List<Map<String,dynamic>>> stream, required bool Function(Map<String,dynamic>) filter}) {
    return StreamBuilder<List<Map<String,dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        final items = (snap.data ?? []).where(filter).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text('${items.length}', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text('None yet', style: GoogleFonts.inter(color: Colors.white30, fontSize: 12))
          else
            _AvatarRow(items: items),
        ]);
      },
    );
  }

  Widget _waitlistSection(String actId) => StreamBuilder<List<Map<String,dynamic>>>(
    stream: _sb.from('requests').stream(primaryKey: ['id']).eq('target_id', actId).order('created_at'),
    builder: (_, snap) {
      final wl = (snap.data ?? []).where((r) => r['status'] == 'pending').toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Public Waitlist', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          Text('${wl.length}', style: GoogleFonts.poppins(color: _amber, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 6),
        if (wl.isEmpty)
          Text('Waitlist is empty.', style: GoogleFonts.inter(color: Colors.white30, fontSize: 12))
        else
          _AvatarRow(items: wl),
      ]);
    },
  );

  void _openMap(BuildContext ctx, double lat, double lng, String label) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.65,
        child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(children: [
            FlutterMap(options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.meetra.app'),
                MarkerLayer(markers: [Marker(point: LatLng(lat, lng), width: 48, height: 48,
                  child: const Icon(Icons.location_on, color: _cyan, size: 48))]),
              ]),
            Positioned(top: 12, left: 16,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)))),
          ])),
      ),
    );
  }
}

// Small avatar row widget reused in participant detail
class _AvatarRow extends StatelessWidget {
  final List<Map<String,dynamic>> items;
  const _AvatarRow({required this.items});
  @override Widget build(BuildContext context) {
    final shown = items.take(6).toList();
    return Row(children: [
      for (final r in shown)
        FutureBuilder<Map<String,dynamic>?>(
          future: Supabase.instance.client.from('profiles').select('avatar_url,name').eq('id', r['sender_id']).maybeSingle(),
          builder: (_, s) {
            final av = s.data?['avatar_url'] as String?;
            final nm = s.data?['name'] as String? ?? '?';
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(radius: 20, backgroundImage: av != null ? NetworkImage(av) : null,
                backgroundColor: _cyan.withValues(alpha: 0.2),
                child: av == null ? Text(nm[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)) : null),
            );
          },
        ),
      if (items.length > 6) Padding(padding: const EdgeInsets.only(left: 4),
        child: Text('+${items.length - 6}', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12))),
    ]);
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
  final _key = GlobalKey<ScaffoldState>();

  void _openMap(BuildContext ctx) {
    final lat = double.tryParse(widget.activity['lat']?.toString() ?? '');
    final lng = double.tryParse(widget.activity['lng']?.toString() ?? '');
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No location set')));
      return;
    }
    final loc = widget.activity['location_name'] as String? ?? 'Event';
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.65,
        child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: FlutterMap(options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.meetra.app'),
              MarkerLayer(markers: [Marker(point: LatLng(lat, lng), width: 48, height: 48, child: const Icon(Icons.location_on, color: _green, size: 48))]),
              SimpleAttributionWidget(source: Text(loc, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
        )));
  }

  @override Widget build(BuildContext context) {
    final act    = widget.activity;
    final actId  = act['id'];
    final isRush = act['is_rush_in'] == true;

    return Scaffold(
      key: _key,
      backgroundColor: _bg,
      appBar: _appBar('Manage ${isRush ? 'Rush-In' : 'Activity'}', actions: [
        IconButton(icon: const Icon(Icons.map_outlined, color: _cyan), onPressed: () => _openMap(context)),
      ]),
      body: CustomScrollView(slivers: [

        // ── Header info ──
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isRush ? Icons.flash_on : Icons.event, color: _rush, size: 14),
            const SizedBox(width: 5),
            Text(isRush ? 'LIVE RUSH-IN' : 'ACTIVITY', style: GoogleFonts.inter(color: _rush, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          Text(act['title'] as String? ?? 'Untitled', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(act['description'] as String? ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),

          // Location chip
          Row(children: [
            const Icon(Icons.location_on, color: _cyan, size: 14),
            const SizedBox(width: 4),
            Expanded(child: Text(act['location_name'] as String? ?? 'No location', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 20),

          const Text('REQUESTS & PARTICIPANTS', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
        ]))),

        // ── Live participant stream ──
        StreamBuilder<List<Map<String,dynamic>>>(
          stream: _sb.from('requests').stream(primaryKey: ['id']).eq('target_id', actId).order('created_at', ascending: false),
          builder: (_, snap) {
            final reqs = snap.data ?? [];
            if (snap.connectionState == ConnectionState.waiting && reqs.isEmpty) {
              return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: _cyan)));
            }
            if (reqs.isEmpty) {
              return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32), child: _empty(Icons.group_off, 'No participants yet')));
            }
            return SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _HostParticipantCard(req: reqs[i]),
              childCount: reqs.length,
            ));
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
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
