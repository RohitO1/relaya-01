import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class KnockListScreen extends StatefulWidget {
  final int initialTabIndex; // 0 = Received, 1 = Sent
  const KnockListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<KnockListScreen> createState() => _KnockListScreenState();
}

class _KnockListScreenState extends State<KnockListScreen>
    with SingleTickerProviderStateMixin {
  final _uid = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = true;
  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _sent = [];
  late TabController _tabController;

  static const _orange = Color(0xFFFF6B00);
  static const _deep = Color(0xFF060608);
  static const _cardAccent = Color(0xFF141416);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _fetchKnocks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchKnocks() async {
    if (_uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final receivedData = await Supabase.instance.client
          .from('requests')
          .select('id, status, created_at, sender_id, answers')
          .eq('target_id', _uid!)
          .eq('target_type', 'profile')
          .order('created_at', ascending: false);

      final sentData = await Supabase.instance.client
          .from('requests')
          .select('id, status, created_at, target_id, answers')
          .eq('sender_id', _uid!)
          .eq('target_type', 'profile')
          .order('created_at', ascending: false);

      final Set<String> profileIds = {};
      for (final r in receivedData)
        if (r['sender_id'] != null) profileIds.add(r['sender_id'].toString());
      for (final r in sentData)
        if (r['target_id'] != null) profileIds.add(r['target_id'].toString());

      Map<String, dynamic> profilesMap = {};
      if (profileIds.isNotEmpty) {
        final List profilesList = await Supabase.instance.client
            .from('profiles')
            .select('id, name, full_name, age, city, avatar_url, visibility')
            .inFilter('id', profileIds.toList());
        for (final p in profilesList) {
          profilesMap[p['id'].toString()] = p;
        }
      }

      List<Map<String, dynamic>> recList = [];
      for (final r in receivedData) {
        if (r['sender_id'] == null) continue;
        final p = profilesMap[r['sender_id'].toString()];
        if (p != null) {
          recList.add({'request': r, 'profile': p});
        }
      }

      List<Map<String, dynamic>> sentList = [];
      for (final r in sentData) {
        if (r['target_id'] == null) continue;
        final p = profilesMap[r['target_id'].toString()];
        if (p != null) {
          sentList.add({'request': r, 'profile': p});
        }
      }

      if (mounted) {
        setState(() {
          _received = recList;
          _sent = sentList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching knock lists: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _sanitizeAvatarUrl(dynamic raw) {
    if (raw == null) return '';
    final url = raw.toString();
    if (url.startsWith('http') || url.startsWith('data:image')) return url;
    return '';
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
        ]
            .animate(interval: 100.ms)
            .fadeIn()
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> item, bool isReceived) {
    final req = item['request'];
    final p = item['profile'];
    final name =
        (p['name'] ?? p['full_name'] ?? 'User').toString().split(' ')[0];
    final avatar = _sanitizeAvatarUrl(p['avatar_url']);
    final city = p['city']?.toString() ?? '';
    final age = p['age']?.toString() ?? '';
    final status = req['status']?.toString() ?? 'pending';

    Color statusColor = Colors.white54;
    String statusText = status.toUpperCase();
    if (status == 'approved') {
      statusColor = const Color(0xFF00E676);
      statusText = isReceived ? 'CONNECTED' : 'ACCEPTED';
    } else if (status == 'declined') {
      statusColor = const Color(0xFFFF3060);
      statusText = 'NOT NOW';
    } else if (status == 'pending') {
      statusColor = _orange;
      statusText = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardAccent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
              image: avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null,
            ),
            child: avatar.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.white24)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$name${age.isNotEmpty ? ', $age' : ''}',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (city.isNotEmpty)
                  Text(city,
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.outfit(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Knock Studio',
          style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _orange,
          labelColor: _orange,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _received.isEmpty
                    ? _buildEmptyState('No received knocks yet.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _received.length,
                        itemBuilder: (ctx, i) => _buildTile(_received[i], true)
                            .animate()
                            .fadeIn(delay: (i * 50).ms)
                            .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
                      ),
                _sent.isEmpty
                    ? _buildEmptyState('No sent knocks yet.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sent.length,
                        itemBuilder: (ctx, i) => _buildTile(_sent[i], false)
                            .animate()
                            .fadeIn(delay: (i * 50).ms)
                            .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
                      ),
              ],
            ),
    );
  }
}
