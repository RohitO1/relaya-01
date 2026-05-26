// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'companion_service.dart';
import 'companion_booking_screen.dart';

/// Full companion profile view (Section 1.2 + 2.1).
class CompanionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> companion;
  const CompanionDetailScreen({super.key, required this.companion});

  @override
  State<CompanionDetailScreen> createState() => _CompanionDetailScreenState();
}

class _CompanionDetailScreenState extends State<CompanionDetailScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;

  Map<String, dynamic> get c => widget.companion;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      _reviews = await CompanionService.getReviews(c['id']);
    } catch (_) {}
    if (mounted) setState(() => _loadingReviews = false);
  }

  void _bookSession(String type) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CompanionBookingScreen(companion: c, sessionType: type)));
  }

  @override
  Widget build(BuildContext context) {
    final photos = (c['photos'] as List?)?.cast<String>() ?? [];
    final tags = (c['tags'] as List?)?.cast<String>() ?? [];
    final languages = (c['languages'] as List?)?.cast<String>() ?? [];
    final isVirtual = c['is_virtual_enabled'] == true;
    final isPhysical = c['is_physical_enabled'] == true;
    final rating = (c['overall_rating'] ?? 0).toDouble();
    final totalSessions = c['total_sessions'] ?? 0;
    final responseRate = c['response_rate_percent'] ?? 0;
    final isVerified = c['is_id_verified'] == true;
    final status = c['status'] ?? 'ACTIVE';
    final isPaused = status == 'PAUSED';

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: CustomScrollView(
        slivers: [
          // Photo header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF050508),
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isNotEmpty
                  ? PageView.builder(
                      itemCount: photos.length,
                      itemBuilder: (_, i) => Image.network(photos[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF15151A))),
                    )
                  : Container(color: const Color(0xFF15151A), child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white24))),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Name + verified badge
                Row(children: [
                  Expanded(child: Text(c['display_name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                  if (isVerified) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, color: Color(0xFF10B981), size: 14), SizedBox(width: 4), Text('Verified', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))]),
                  ),
                ]),
                const SizedBox(height: 4),
                if (c['city'] != null) Text('${c['city']}${c['region'] != null ? ', ${c['region']}' : ''}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                if (totalSessions < 5) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('🌟 New Companion', style: TextStyle(color: Colors.blue, fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row (Section 1.2 COMPANION STATS)
                Row(children: [
                  _statChip('⭐ ${rating.toStringAsFixed(1)}', 'Rating'),
                  _statChip('$totalSessions', 'Sessions'),
                  _statChip('$responseRate%', 'Response'),
                ]),
                const SizedBox(height: 20),

                // Short bio
                if (c['bio_short'] != null) ...[
                  Text(c['bio_short'], style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                  const SizedBox(height: 16),
                ],

                // About Me
                if (c['bio_long'] != null) ...[
                  const Text('About Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(c['bio_long'], style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.6)),
                  const SizedBox(height: 20),
                ],

                // Tags
                if (tags.isNotEmpty) ...[
                  const Text('Interests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFF7E40).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(t, style: const TextStyle(color: Color(0xFFFF7E40), fontSize: 12)),
                  )).toList()),
                  const SizedBox(height: 20),
                ],

                // Languages
                if (languages.isNotEmpty) ...[
                  const Text('Languages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: languages.map((l) => Chip(label: Text(l, style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.white10)).toList()),
                  const SizedBox(height: 20),
                ],

                // Session types + rates
                const Text('Sessions Offered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (isVirtual) _sessionCard('Virtual Meet', Icons.videocam, const Color(0xFFFF7E40), '₹${(c['virtual_rate_per_hour'] ?? 0)}/hr', '${c['virtual_min_duration_minutes'] ?? 30}-${c['virtual_max_duration_minutes'] ?? 120} min'),
                if (isPhysical) _sessionCard('Physical Meet', Icons.people, const Color(0xFF10B981), '₹${(c['physical_rate_per_hour'] ?? 0)}/hr', '${c['travel_radius_km'] ?? 10}km radius'),
                const SizedBox(height: 20),

                // Reviews
                const Text('Reviews', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_loadingReviews)
                  const Center(child: CircularProgressIndicator())
                else if (_reviews.isEmpty)
                  const Text('No reviews yet', style: TextStyle(color: Colors.white38))
                else
                  ..._reviews.take(5).map((r) => _reviewCard(r)),

                const SizedBox(height: 100), // Bottom padding for FAB
              ]),
            ),
          ),
        ],
      ),

      // Book buttons
      bottomNavigationBar: isPaused
          ? Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF050508),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Text('This companion is currently paused and not accepting bookings.', style: TextStyle(color: Colors.amber), textAlign: TextAlign.center),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF050508),
              child: Row(children: [
                if (isVirtual)
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _bookSession('VIRTUAL'),
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Virtual', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7E40), foregroundColor: Colors.white, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  )),
                if (isVirtual && isPhysical) const SizedBox(width: 12),
                if (isPhysical)
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _bookSession('PHYSICAL'),
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text('Physical', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  )),
              ]),
            ),
    );
  }

  Widget _statChip(String value, String label) {
    return Expanded(child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    ));
  }

  Widget _sessionCard(String title, IconData icon, Color color, String rate, String detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(detail, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ])),
        Text(rate, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    );
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ...List.generate(5, (i) => Icon(i < (r['overall_rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 14)),
          const Spacer(),
          Text(r['reviewer_role'] ?? '', style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ]),
        if (r['written_review'] != null) ...[
          const SizedBox(height: 6),
          Text(r['written_review'], style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ]),
    );
  }
}
