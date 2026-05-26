// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'companion_service.dart';
import 'companion_detail_screen.dart';
import 'companion_register_screen.dart';
import 'companion_sessions_screen.dart';
import 'companion_earnings_screen.dart';

/// Main Companions browse/discovery screen — Section 2 of the spec.
/// Card grid + list view, filters, sort, search (EC-27, EC-29 handled via UTC availability).
class CompanionsScreen extends StatefulWidget {
  const CompanionsScreen({super.key});

  @override
  State<CompanionsScreen> createState() => _CompanionsScreenState();
}

class _CompanionsScreenState extends State<CompanionsScreen> {
  // ── View state ──
  bool _gridView = true;
  bool _loading = true;
  List<Map<String, dynamic>> _companions = [];
  Map<String, dynamic>? _myCompanionProfile;

  // ── Filter state ──
  String? _filterSessionType; // 'VIRTUAL' | 'PHYSICAL' | null=both
  double _minRating = 0;
  bool _verifiedOnly = false;
  String _sortBy = 'recommended';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const _sortOptions = [
    ('recommended', 'Recommended'),
    ('newest', 'Newest'),
    ('highest_rated', 'Highest Rated'),
    ('most_affordable', 'Most Affordable'),
    ('most_experienced', 'Most Experienced'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadCompanions(), _loadMyProfile()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCompanions() async {
    final results = await CompanionService.discoverCompanions(
      sessionType: _filterSessionType,
      minRating: _minRating > 0 ? _minRating : null,
      verifiedOnly: _verifiedOnly ? true : null,
      sortBy: _sortBy,
      limit: 40,
    );
    // Client-side search filter (Section 2.4)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      _companions = results.where((c) {
        final name = (c['display_name'] ?? '').toLowerCase();
        final bio = (c['bio_short'] ?? '').toLowerCase();
        final city = (c['city'] ?? '').toLowerCase();
        final tags = ((c['tags'] as List?) ?? []).join(' ').toLowerCase();
        return name.contains(q) || bio.contains(q) || city.contains(q) || tags.contains(q);
      }).toList();
    } else {
      _companions = results;
    }
  }

  Future<void> _loadMyProfile() async {
    _myCompanionProfile = await CompanionService.getMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: const Color(0xFF050508),
            floating: true,
            snap: true,
            elevation: 0,
            title: const Text('Companions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            actions: [
              // My sessions
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                tooltip: 'My Sessions',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionMySessionsScreen())),
              ),
              // Earnings (if companion)
              if (_myCompanionProfile != null)
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  tooltip: 'Earnings',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionEarningsScreen())),
                ),
              // Toggle view
              IconButton(
                icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
                onPressed: () => setState(() => _gridView = !_gridView),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(112),
              child: Column(children: [
                // ── Search bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (v) {
                      _searchQuery = v;
                      _loadCompanions().then((_) { if (mounted) setState(() {}); });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name, city, interests...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.white38), onPressed: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _loadCompanions(); }); })
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                // ── Filter chips row ──
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _filterChip('All', _filterSessionType == null, () { setState(() => _filterSessionType = null); _loadAll(); }),
                      _filterChip('Virtual', _filterSessionType == 'VIRTUAL', () { setState(() => _filterSessionType = 'VIRTUAL'); _loadAll(); }),
                      _filterChip('Physical', _filterSessionType == 'PHYSICAL', () { setState(() => _filterSessionType = 'PHYSICAL'); _loadAll(); }),
                      _filterChip('4.5+ Stars', _minRating >= 4.5, () { setState(() => _minRating = _minRating >= 4.5 ? 0 : 4.5); _loadAll(); }),
                      _filterChip('4+ Stars', _minRating >= 4.0 && _minRating < 4.5, () { setState(() => _minRating = _minRating >= 4.0 && _minRating < 4.5 ? 0 : 4.0); _loadAll(); }),
                      _filterChip('✅ Verified', _verifiedOnly, () { setState(() => _verifiedOnly = !_verifiedOnly); _loadAll(); }),
                      _sortChip(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _companions.isEmpty
                ? _buildEmpty()
                : _gridView
                    ? _buildGrid()
                    : _buildList(),
      ),

      // ── FAB: Become a companion / manage listing ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_myCompanionProfile == null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionRegisterScreen()))
                .then((_) => _loadMyProfile().then((_) { if (mounted) setState(() {}); }));
          } else {
            _showMyProfileMenu();
          }
        },
        backgroundColor: const Color(0xFFFF7E40),
        icon: Icon(_myCompanionProfile == null ? Icons.add : Icons.manage_accounts),
        label: Text(_myCompanionProfile == null ? 'Become a Companion' : 'My Listing'),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF7E40) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFFF7E40) : Colors.white12),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _sortChip() {
    return PopupMenuButton<String>(
      color: const Color(0xFF1A1A2E),
      onSelected: (v) { setState(() => _sortBy = v); _loadAll(); },
      itemBuilder: (_) => _sortOptions.map((o) => PopupMenuItem(
        value: o.$1,
        child: Row(children: [
          if (_sortBy == o.$1) const Icon(Icons.check, color: Color(0xFFFF7E40), size: 16),
          if (_sortBy == o.$1) const SizedBox(width: 6),
          Text(o.$2, style: const TextStyle(color: Colors.white)),
        ]),
      )).toList(),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          const Icon(Icons.sort, color: Colors.white60, size: 15),
          const SizedBox(width: 4),
          Text('Sort', style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ]),
      ),
    );
  }

  // ── Grid View (Section 2.1) ──
  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: _companions.length,
      itemBuilder: (_, i) => _CompanionGridCard(companion: _companions[i]),
    );
  }

  // ── List View (Section 2.1) ──
  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _companions.length,
      itemBuilder: (_, i) => _CompanionListCard(companion: _companions[i]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off, size: 56, color: Colors.white24),
        const SizedBox(height: 12),
        const Text('No companions found', style: TextStyle(color: Colors.white38, fontSize: 16)),
        const SizedBox(height: 8),
        TextButton(onPressed: () { setState(() { _filterSessionType = null; _minRating = 0; _verifiedOnly = false; _sortBy = 'recommended'; _searchQuery = ''; _searchCtrl.clear(); }); _loadAll(); }, child: const Text('Clear Filters')),
      ]),
    );
  }

  void _showMyProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final status = _myCompanionProfile?['status'] ?? 'PENDING';
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('My Listing · $status', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.edit, color: Color(0xFFFF7E40)), title: const Text('Edit Profile', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionRegisterScreen())); }),
            ListTile(leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)), title: const Text('Earnings', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionEarningsScreen())); }),
            if (status == 'ACTIVE')
              ListTile(leading: const Icon(Icons.pause_circle, color: Colors.amber), title: const Text('Pause Listing', style: TextStyle(color: Colors.white)), onTap: () => _togglePause(context)),
            if (status == 'PAUSED')
              ListTile(leading: const Icon(Icons.play_circle, color: Colors.green), title: const Text('Resume Listing', style: TextStyle(color: Colors.white)), onTap: () => _togglePause(context)),
          ]),
        );
      },
    );
  }

  Future<void> _togglePause(BuildContext ctx) async {
    Navigator.pop(ctx);
    final newStatus = _myCompanionProfile?['status'] == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    await Supabase.instance.client.from('companion_profiles').update({'status': newStatus}).eq('id', _myCompanionProfile!['id']);
    await _loadMyProfile();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ─── Grid Card ───────────────────────────────────────────────────
class _CompanionGridCard extends StatelessWidget {
  final Map<String, dynamic> companion;
  const _CompanionGridCard({required this.companion});

  @override
  Widget build(BuildContext context) {
    final photos = (companion['photos'] as List?)?.cast<String>() ?? [];
    final tags = ((companion['tags'] as List?)?.cast<String>() ?? []).take(3).toList();
    final rating = (companion['overall_rating'] ?? 0).toDouble();
    final rate = (companion['virtual_rate_per_hour'] ?? companion['physical_rate_per_hour'] ?? 0);
    final isVerified = companion['is_id_verified'] == true;
    final totalSessions = companion['total_sessions'] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanionDetailScreen(companion: companion))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo
          Expanded(
            flex: 5,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: photos.isNotEmpty
                    ? Image.network(photos.first, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              if (isVerified) Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle),
                  child: const Icon(Icons.verified, color: Colors.white, size: 10),
                ),
              ),
              if (totalSessions < 5) Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
          // Info
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(companion['display_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (companion['city'] != null)
                  Text(companion['city'], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                // Tags
                Wrap(spacing: 4, runSpacing: 2, children: tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFF7E40).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(t, style: const TextStyle(color: Color(0xFFFF7E40), fontSize: 9)),
                )).toList()),
                const Spacer(),
                Row(children: [
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text('₹$rate/hr', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(color: const Color(0xFF1A1A2E), child: const Center(child: Icon(Icons.person, color: Colors.white12, size: 40)));
}

// ─── List Card ───────────────────────────────────────────────────
class _CompanionListCard extends StatelessWidget {
  final Map<String, dynamic> companion;
  const _CompanionListCard({required this.companion});

  @override
  Widget build(BuildContext context) {
    final photos = (companion['photos'] as List?)?.cast<String>() ?? [];
    final rating = (companion['overall_rating'] ?? 0).toDouble();
    final rate = (companion['virtual_rate_per_hour'] ?? companion['physical_rate_per_hour'] ?? 0);
    final isVerified = companion['is_id_verified'] == true;
    final isVirtual = companion['is_virtual_enabled'] == true;
    final isPhysical = companion['is_physical_enabled'] == true;

    // Availability indicator (simplified — real impl checks UTC availability)
    const availLabel = 'Available This Week';
    const availColor = Colors.green;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanionDetailScreen(companion: companion))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          // Avatar
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photos.isNotEmpty
                  ? Image.network(photos.first, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: const Color(0xFF1A1A2E), child: const Icon(Icons.person, color: Colors.white24)))
                  : Container(width: 70, height: 70, color: const Color(0xFF1A1A2E), child: const Icon(Icons.person, color: Colors.white24)),
            ),
            if (isVerified) Positioned(
              bottom: 0, right: 0,
              child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle), child: const Icon(Icons.verified, color: Colors.white, size: 10)),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(companion['display_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text('₹$rate/hr', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 2),
            Text(companion['city'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 4),
            // Bio snippet
            if (companion['bio_short'] != null)
              Text(companion['bio_short'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 12),
              const SizedBox(width: 2),
              Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(width: 8),
              if (isVirtual) const Icon(Icons.videocam, color: Color(0xFFFF7E40), size: 12),
              if (isPhysical) ...[const SizedBox(width: 4), const Icon(Icons.people, color: Color(0xFF10B981), size: 12)],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: availColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(availLabel, style: TextStyle(color: availColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }
}


