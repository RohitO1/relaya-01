import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;


// =============================================================================
// MEETRA ADMIN CONTROL — Comprehensive Management Dashboard
// Inspired by modern SaaS admin panels, adapted for mobile.
// =============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  SupabaseClient? _adminClient;
  bool _isLoading = true;
  bool _isProcessing = false;
  int _selectedIndex = 0; // Drawer nav index

  // ── Data stores ──
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _rushIns = [];
  List<Map<String, dynamic>> _companions = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _chatrooms = [];
  List<Map<String, dynamic>> _chatroomMembers = [];

  // ── Navigation items ──
  static const _navItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.people_alt_rounded, 'label': 'Users'},
    {'icon': Icons.event_rounded, 'label': 'Activities'},
    {'icon': Icons.flash_on_rounded, 'label': 'Rush-Ins'},
    {'icon': Icons.volunteer_activism_rounded, 'label': 'Companions'},
    {'icon': Icons.swap_horiz_rounded, 'label': 'Requests'},
    {'icon': Icons.storefront_rounded, 'label': 'Seller Apps'},
    {'icon': Icons.message_rounded, 'label': 'Messages'},
    {'icon': Icons.mic_rounded, 'label': 'BolRooms'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  // ── Colors ──
  static const _bg = Color(0xFF0A0A12);
  static const _card = Color(0xFF12121E);
  static const _cardBorder = Color(0xFF1E1E30);
  static const _accent = Color(0xFF00E5FF);
  static const _accentPink = Color(0xFFFF007F);
  static const _accentGreen = Color(0xFF10B981);
  static const _accentPurple = Color(0xFF8B5CF6);
  static const _accentOrange = Color(0xFFF59E0B);
  static const _accentRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _checkAdminKey();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH & INIT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _checkAdminKey() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = prefs.getString('supabase_admin_key');
    if (cachedKey != null && cachedKey.isNotEmpty) {
      _initAdminClient(cachedKey);
    } else {
      if (mounted) setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptForAdminKey());
    }
  }

  void _initAdminClient(String key) {
    try {
      _adminClient = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', key);
      _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Failed to initialize admin client.', isError: true);
    }
  }

  Future<void> _fetchAllData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final client = _adminClient ?? Supabase.instance.client;

      final pData = await client.from('profiles').select().order('name', ascending: true);
      final aData = await client.from('activities').select().order('created_at', ascending: false);
      final cData = await client.from('companions').select().order('created_at', ascending: false);

      List rData = [];
      try { rData = await client.from('requests').select().order('created_at', ascending: false); } catch (_) {}

      List mData = [];
      try { mData = await client.from('messages').select().order('created_at', ascending: false).limit(100); } catch (_) {}

      List crData = [];
      try { crData = await client.from('chatrooms').select().order('created_at', ascending: false); } catch (_) {}

      List cmData = [];
      try { cmData = await client.from('chatroom_members').select(); } catch (_) {}

      final acts = List<Map<String, dynamic>>.from(aData);

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(pData);
          _activities = acts.where((e) => e['is_rush_in'] != true).toList();
          _rushIns = acts.where((e) => e['is_rush_in'] == true).toList();
          _companions = List<Map<String, dynamic>>.from(cData);
          _requests = List<Map<String, dynamic>>.from(rData);
          _messages = List<Map<String, dynamic>>.from(mData);
          _chatrooms = List<Map<String, dynamic>>.from(crData);
          _chatroomMembers = List<Map<String, dynamic>>.from(cmData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Data fetch failed: $e', isError: true);
      }
    }
  }

  Future<void> _promptForAdminKey() async {
    final ctrl = TextEditingController();
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: _accent, size: 24),
            SizedBox(width: 10),
            Text('Admin Authorization', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your Supabase Service Role Key to unlock administrative control over all data layers.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'service_role key...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true, fillColor: Colors.black38,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.key_rounded, color: Colors.white24, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); if (mounted) Navigator.pop(context); },
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('supabase_admin_key', val);
                if (ctx.mounted) Navigator.pop(ctx);
                _initAdminClient(val);
              }
            },
            child: const Text('Authorize', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _nukeUser(String uid) async {
    final ok = await _confirmAction('Delete User?', 'This will permanently erase the user identity and all their associated data from every table.');
    if (!ok || _adminClient == null) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      await _adminClient!.from('messages').delete().or('sender_id.eq.$uid,receiver_id.eq.$uid');
      await _adminClient!.from('requests').delete().eq('sender_id', uid);
      await _adminClient!.from('hidden_feed').delete().eq('user_id', uid);
      final userActs = await _adminClient!.from('activities').select('id').eq('user_id', uid);
      for (var act in userActs) {
        await _adminClient!.from('requests').delete().eq('target_id', act['id']);
        await _adminClient!.from('hidden_feed').delete().eq('rush_in_id', act['id']);
      }
      try { await _adminClient!.from('user_fcm_tokens').delete().eq('user_id', uid); } catch (_) {}
      try { await _adminClient!.from('posts').delete().eq('user_id', uid); } catch (_) {}
      final userComps = await _adminClient!.from('companions').select('id').eq('user_id', uid);
      for (var comp in userComps) {
        await _adminClient!.from('requests').delete().eq('target_id', comp['id']);
      }
      await _adminClient!.from('companions').delete().eq('user_id', uid);
      await _adminClient!.from('activities').delete().eq('user_id', uid);
      await _adminClient!.from('profiles').delete().eq('id', uid);
      await _adminClient!.auth.admin.deleteUser(uid);
      if (mounted) _showSnack('User permanently deleted.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _nukeActivity(String actId) async {
    final ok = await _confirmAction('Delete Activity?', 'This permanently removes the activity and all associated requests.');
    if (!ok || _adminClient == null) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      await _adminClient!.from('requests').delete().eq('target_id', actId);
      await _adminClient!.from('hidden_feed').delete().eq('rush_in_id', actId);
      await _adminClient!.from('activities').delete().eq('id', actId);
      if (mounted) _showSnack('Activity deleted.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _nukeCompanion(String compId) async {
    final ok = await _confirmAction('Delete Companion?', 'This permanently removes the companion listing.');
    if (!ok || _adminClient == null) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      await _adminClient!.from('requests').delete().eq('target_id', compId);
      await _adminClient!.from('companions').delete().eq('id', compId);
      if (mounted) _showSnack('Companion listing deleted.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleActivityStatus(String actId, bool currentStatus) async {
    if (_adminClient == null) return;
    try {
      await _adminClient!.from('activities').update({'is_active': !currentStatus}).eq('id', actId);
      if (mounted) _showSnack(currentStatus ? 'Activity deactivated.' : 'Activity activated.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Status toggle failed: $e', isError: true);
    }
  }

  Future<void> _toggleCompanionStatus(String compId, bool currentStatus) async {
    if (_adminClient == null) return;
    try {
      await _adminClient!.from('companions').update({'is_active': !currentStatus}).eq('id', compId);
      if (mounted) _showSnack(currentStatus ? 'Companion deactivated.' : 'Companion activated.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Status toggle failed: $e', isError: true);
    }
  }

  Future<void> _deleteRequest(String reqId) async {
    if (_adminClient == null) return;
    try {
      await _adminClient!.from('requests').delete().eq('id', reqId);
      if (mounted) _showSnack('Request deleted.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    }
  }

  Future<void> _updateRequestStatus(String reqId, String newStatus) async {
    if (_adminClient == null) return;
    try {
      await _adminClient!.from('requests').update({'status': newStatus}).eq('id', reqId);
      if (mounted) _showSnack('Request $newStatus.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Update failed: $e', isError: true);
    }
  }

  Future<void> _clearAllMessages() async {
    final ok = await _confirmAction('Purge ALL Messages?', 'This will permanently delete every message in the database. This action cannot be undone.');
    if (!ok || _adminClient == null) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      await _adminClient!.from('messages').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      if (mounted) _showSnack('All messages purged.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Purge failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _getUserName(String uid) {
    final p = _profiles.where((p) => p['id'] == uid).toList();
    return p.isNotEmpty ? (p.first['name'] ?? 'Unknown') : uid.substring(0, 8);
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? _accentRed : _accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<bool> _confirmAction(String title, String body) async {
    if (!mounted) return false;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _accentRed, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
        ]),
        content: Text(body, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD — Main Scaffold
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _accent)));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white70),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(children: [
          const Icon(Icons.shield_rounded, color: _accent, size: 20),
          const SizedBox(width: 8),
          Text((_navItems[_selectedIndex]['label'] as String).toUpperCase(),
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white38), onPressed: _fetchAllData, tooltip: 'Refresh'),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildBody(),
          if (_isProcessing) Container(
            color: Colors.black87,
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: _accentRed),
              SizedBox(height: 16),
              Text('Processing...', style: TextStyle(color: Colors.white70, fontFamily: 'monospace')),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildDashboard();
      case 1: return _buildUsersSection();
      case 2: return _buildActivitiesSection();
      case 3: return _buildRushInsSection();
      case 4: return _buildCompanionsSection();
      case 5: return _buildRequestsSection();
      case 6: return _buildSellerApplicationsSection();
      case 7: return _buildMessagesSection();
      case 8: return _buildBolRoomsSection();
      case 9: return _buildSettingsSection();
      default: return _buildDashboard();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DRAWER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D18),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: const Row(children: [
                Icon(Icons.shield_rounded, color: _accent, size: 28),
                SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ADMIN CONTROL', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  Text('Meetra Management', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ]),
            ),
            const Divider(color: _cardBorder, height: 1),

            // CORE section
            _drawerSectionLabel('CORE'),
            _drawerItem(0),
            _drawerItem(1, badge: _profiles.length),

            // CONTENT section
            _drawerSectionLabel('CONTENT'),
            _drawerItem(2, badge: _activities.length),
            _drawerItem(3, badge: _rushIns.length),
            _drawerItem(4, badge: _companions.length),
            _drawerItem(8, badge: _chatrooms.length),

            // GOVERNANCE section
            _drawerSectionLabel('GOVERNANCE'),
            _drawerItem(5, badge: _requests.length),
            _drawerItem(6, badge: _messages.length),
            _drawerItem(7),

            const Spacer(),
            const Divider(color: _cardBorder, height: 1),

            // Admin user footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: _accent.withValues(alpha: 0.2),
                  child: const Icon(Icons.person_rounded, color: _accent, size: 18)),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Admin Root', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('SUPER ADMIN', style: TextStyle(color: _accent, fontSize: 9, letterSpacing: 1)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _drawerItem(int index, {int? badge}) {
    final selected = _selectedIndex == index;
    final item = _navItems[index];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? _accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(item['icon'] as IconData, color: selected ? _accent : Colors.white54, size: 20),
        title: Text(item['label'] as String, style: TextStyle(color: selected ? _accent : Colors.white70, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        trailing: badge != null && badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: selected ? _accent.withValues(alpha: 0.2) : Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: TextStyle(color: selected ? _accent : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          : null,
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context); // close drawer
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 0 — DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboard() {
    final now = DateTime.now();
    final liveRushIns = _rushIns.where((r) {
      final exp = r['expires_at'];
      if (exp == null) return false;
      try { return DateTime.parse(exp).isAfter(now); } catch (_) { return false; }
    }).length;

    final activeActivities = _activities.where((a) => a['is_active'] == true).length;
    final activeCompanions = _companions.where((c) => c['is_active'] == true).length;
    final completedOnboarding = _profiles.where((p) => p['onboarding_complete'] == true).length;

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stat Cards ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('Total Users', _profiles.length.toString(), Icons.people_alt_rounded, _accent, '+${_profiles.length}'),
              _statCard('Activities', activeActivities.toString(), Icons.event_rounded, _accentGreen, '${_activities.length} total'),
              _statCard('Rush-Ins Live', liveRushIns.toString(), Icons.flash_on_rounded, _accentPink, '${_rushIns.length} total'),
              _statCard('Companions', activeCompanions.toString(), Icons.volunteer_activism_rounded, _accentPurple, '${_companions.length} total'),
              _statCard('Requests', _requests.length.toString(), Icons.swap_horiz_rounded, _accentOrange, 'all time'),
              _statCard('Messages', _messages.length.toString(), Icons.message_rounded, const Color(0xFF06B6D4), 'last 100'),
            ],
          ),

          const SizedBox(height: 20),

          // ── User Breakdown ──
          _sectionCard(
            title: 'User Breakdown',
            subtitle: 'Onboarding completion status',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Donut chart
                SizedBox(
                  width: 100, height: 100,
                  child: CustomPaint(painter: _DonutPainter(
                    completedOnboarding.toDouble(),
                    _profiles.length.toDouble(),
                  )),
                ),
                const SizedBox(width: 24),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _legendItem(_accentGreen, 'Onboarded', completedOnboarding, _profiles.isEmpty ? 0 : ((completedOnboarding / _profiles.length) * 100).round()),
                  const SizedBox(height: 12),
                  _legendItem(Colors.white24, 'Pending', _profiles.length - completedOnboarding, _profiles.isEmpty ? 0 : (((_profiles.length - completedOnboarding) / _profiles.length) * 100).round()),
                ])),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // ── City Distribution ──
          _sectionCard(
            title: 'City Distribution',
            subtitle: 'Where are your users?',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCityBars(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Interest Heatmap ──
          _sectionCard(
            title: 'Popular Interests',
            subtitle: 'Most selected interests across all users',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildInterestChips(),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(sub, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        child,
      ]),
    );
  }

  Widget _legendItem(Color color, String label, int count, int pct) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const Spacer(),
      Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(width: 6),
      Text('$pct%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildCityBars() {
    final Map<String, int> cityMap = {};
    for (var p in _profiles) {
      final city = (p['city'] ?? 'Unknown').toString().trim();
      if (city.isNotEmpty) cityMap[city] = (cityMap[city] ?? 0) + 1;
    }
    if (cityMap.isEmpty) return const Text('No city data', style: TextStyle(color: Colors.white38));
    final sorted = cityMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    final colors = [_accent, _accentPink, _accentGreen, _accentPurple, _accentOrange];

    return Column(children: sorted.take(5).toList().asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final pct = maxVal > 0 ? entry.value / maxVal : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(width: 70, child: Text(entry.key, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white10, color: colors[idx % colors.length], minHeight: 8),
          )),
          const SizedBox(width: 8),
          Text('${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      );
    }).toList());
  }

  Widget _buildInterestChips() {
    final Map<String, int> iMap = {};
    for (var p in _profiles) {
      final interests = p['interests'];
      if (interests is List) {
        for (var i in interests) { iMap[i.toString()] = (iMap[i.toString()] ?? 0) + 1; }
      }
    }
    if (iMap.isEmpty) return const Text('No interest data', style: TextStyle(color: Colors.white38));
    final sorted = iMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [_accent, _accentPink, _accentGreen, _accentPurple, _accentOrange, const Color(0xFF06B6D4)];

    return Wrap(spacing: 8, runSpacing: 8, children: sorted.take(10).toList().asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final c = colors[idx % colors.length];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.3))),
        child: Text('${entry.key} (${entry.value})', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — USERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildUsersSection() {
    if (_profiles.isEmpty) return _emptyState('No users found');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _profiles.length,
      itemBuilder: (ctx, i) {
        final p = _profiles[i];
        final uid = p['id'].toString();
        final name = p['name'] ?? 'Unknown';
        final city = p['city'] ?? '—';
        final age = p['age']?.toString() ?? '—';
        final onboarded = p['onboarding_complete'] == true;
        final avatar = p['avatar_url'] ?? 'https://picsum.photos/seed/$uid/100';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatar)),
            title: Row(children: [
              Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: onboarded ? _accentGreen.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(onboarded ? 'ACTIVE' : 'PENDING', style: TextStyle(color: onboarded ? _accentGreen : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
            subtitle: Text('$city · Age $age · ${uid.substring(0, 8)}...', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            iconColor: Colors.white38,
            collapsedIconColor: Colors.white24,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Divider(color: _cardBorder),
                  if (p['bio'] != null) ...[
                    Text('Bio: ${p['bio']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                  ],
                  if (p['gender'] != null) Text('Gender: ${p['gender']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  if (p['personality'] != null) Text('Personality: ${p['personality']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  if (p['interests'] is List) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 4, runSpacing: 4, children: (p['interests'] as List).map((i) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(i.toString(), style: const TextStyle(color: _accent, fontSize: 10)),
                      )).toList()),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    _actionChip('View ID', Icons.copy_rounded, Colors.white38, () {
                      _showSnack('ID: $uid');
                    }),
                    const SizedBox(width: 8),
                    _actionChip('Delete', Icons.delete_forever_rounded, _accentRed, () => _nukeUser(uid)),
                  ]),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — ACTIVITIES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActivitiesSection() {
    if (_activities.isEmpty) return _emptyState('No activities found');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activities.length,
      itemBuilder: (ctx, i) => _activityTile(_activities[i]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — RUSH-INS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRushInsSection() {
    if (_rushIns.isEmpty) return _emptyState('No rush-ins found');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rushIns.length,
      itemBuilder: (ctx, i) => _activityTile(_rushIns[i], isRushIn: true),
    );
  }

  Widget _activityTile(Map<String, dynamic> act, {bool isRushIn = false}) {
    final actId = act['id'].toString();
    final title = act['title'] ?? 'Untitled';
    final isActive = act['is_active'] == true;
    final hostName = _getUserName(act['user_id']?.toString() ?? '');
    final location = act['location_name'] ?? '—';
    final category = act['category'] ?? '';
    final created = _timeAgo(act['created_at']);
    final isGhost = act['is_ghost_mode'] == true;

    String statusText = isActive ? 'ACTIVE' : 'INACTIVE';
    Color statusColor = isActive ? _accentGreen : Colors.white38;

    if (isRushIn) {
      final exp = act['expires_at'];
      if (exp != null) {
        try {
          final expTime = DateTime.parse(exp);
          if (expTime.isBefore(DateTime.now())) {
            statusText = 'EXPIRED';
            statusColor = _accentRed;
          } else {
            statusText = 'LIVE';
            statusColor = _accentPink;
          }
        } catch (_) {}
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (isRushIn ? _accentPink : _accentGreen).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isRushIn ? Icons.flash_on_rounded : Icons.event_rounded,
            color: isRushIn ? _accentPink : _accentGreen, size: 20),
        ),
        title: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        subtitle: Text('$hostName · $location · $created', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white24,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(color: _cardBorder),
              Text('Category: $category', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (act['description'] != null) Text('Desc: ${act['description']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (isRushIn) ...[
                Text('Participants: ${act['participant_limit'] ?? '—'}  ·  Duration: ${act['duration_hours'] ?? '—'}h', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text('Ghost Mode: ${isGhost ? 'ON' : 'OFF'}  ·  Entry: ${act['entry_type'] ?? 'free'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
              if (act['lat'] != null) Text('Coords: ${act['lat']}, ${act['lng']}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
              const SizedBox(height: 12),
              Row(children: [
                _actionChip(isActive ? 'Deactivate' : 'Activate', isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  isActive ? _accentOrange : _accentGreen, () => _toggleActivityStatus(actId, isActive)),
                const SizedBox(width: 8),
                _actionChip('Delete', Icons.delete_forever_rounded, _accentRed, () => _nukeActivity(actId)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4 — COMPANIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCompanionsSection() {
    if (_companions.isEmpty) return _emptyState('No companions found');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _companions.length,
      itemBuilder: (ctx, i) {
        final c = _companions[i];
        final compId = c['id'].toString();
        final name = c['name'] ?? 'Unknown';
        final compTitle = c['title'] ?? '—';
        final city = c['city'] ?? '—';
        final isActive = c['is_active'] == true;
        final rate = c['hourly_rate']?.toString() ?? '0';
        final currency = c['currency'] ?? 'INR';
        final avatar = c['avatar_url'] ?? 'https://picsum.photos/seed/$compId/100';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatar)),
            title: Row(children: [
              Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? _accentGreen.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: isActive ? _accentGreen : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
            subtitle: Text('$compTitle · $city · $rate $currency/hr', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            iconColor: Colors.white38,
            collapsedIconColor: Colors.white24,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Divider(color: _cardBorder),
                  if (c['bio'] != null) Text('Bio: ${c['bio']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  if (c['offering'] != null) Text('Offering: ${c['offering']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('Experience: ${c['experience'] ?? '—'}  ·  Rating: ${c['rating'] ?? 0}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  if (c['skills'] is List) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 4, runSpacing: 4, children: (c['skills'] as List).map((s) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(s.toString(), style: const TextStyle(color: _accentPurple, fontSize: 10)),
                      )).toList()),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    _actionChip(isActive ? 'Deactivate' : 'Activate', isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      isActive ? _accentOrange : _accentGreen, () => _toggleCompanionStatus(compId, isActive)),
                    const SizedBox(width: 8),
                    _actionChip('Delete', Icons.delete_forever_rounded, _accentRed, () => _nukeCompanion(compId)),
                  ]),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5 — REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRequestsSection() {
    if (_requests.isEmpty) return _emptyState('No requests found');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _requests.length,
      itemBuilder: (ctx, i) {
        final r = _requests[i];
        final reqId = r['id'].toString();
        final senderName = _getUserName(r['sender_id']?.toString() ?? '');
        final status = r['status']?.toString() ?? 'pending';
        final targetType = r['target_type']?.toString() ?? '—';
        final created = _timeAgo(r['created_at']);
        final message = r['message']?.toString() ?? '';

        Color statusColor = Colors.white38;
        if (status == 'pending') statusColor = _accentOrange;
        if (status == 'approved') statusColor = _accentGreen;
        if (status == 'rejected') statusColor = _accentRed;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.swap_horiz_rounded, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('$senderName → $targetType', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
            if (message.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('"$message"', style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
            Text(created, style: const TextStyle(color: Colors.white24, fontSize: 10)),
            const SizedBox(height: 10),
            Row(children: [
              if (status == 'pending') ...[
                _actionChip('Approve', Icons.check_rounded, _accentGreen, () => _updateRequestStatus(reqId, 'approved')),
                const SizedBox(width: 6),
                _actionChip('Reject', Icons.close_rounded, _accentOrange, () => _updateRequestStatus(reqId, 'rejected')),
                const SizedBox(width: 6),
              ],
              _actionChip('Delete', Icons.delete_rounded, _accentRed, () => _deleteRequest(reqId)),
            ]),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6 — MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessagesSection() {
    return Column(children: [
      // Purge bar
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: _accentRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentRed.withValues(alpha: 0.2))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _accentRed, size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text('Danger Zone: Purge all messages', style: TextStyle(color: Colors.white54, fontSize: 12))),
          GestureDetector(
            onTap: _clearAllMessages,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _accentRed, borderRadius: BorderRadius.circular(8)),
              child: const Text('PURGE ALL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
      // Message list
      Expanded(
        child: _messages.isEmpty
          ? _emptyState('No messages found')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final senderName = _getUserName(m['sender_id']?.toString() ?? '');
                final receiverName = _getUserName(m['receiver_id']?.toString() ?? '');
                final text = m['text']?.toString() ?? '';
                final isImage = m['is_image'] == true;
                final created = _timeAgo(m['created_at']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(senderName, style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 12)),
                      const Text(' → ', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      Text(receiverName, style: const TextStyle(color: _accentPink, fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      Text(created, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ]),
                    const SizedBox(height: 4),
                    Text(isImage ? '📷 [Image]' : text, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                );
              },
            ),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7 — SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsSection() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Admin Session',
          subtitle: 'Manage your admin authorization',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _settingsRow('Status', 'Authorized', _accentGreen),
              const SizedBox(height: 12),
              _settingsRow('Client', _adminClient != null ? 'Connected' : 'Disconnected', _adminClient != null ? _accentGreen : _accentRed),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _accentRed.withValues(alpha: 0.15), foregroundColor: _accentRed, padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Clear Admin Key & Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('supabase_admin_key');
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Database Summary',
          subtitle: 'Quick overview of all table sizes',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _settingsRow('profiles', '${_profiles.length} rows', Colors.white54),
              _settingsRow('activities', '${_activities.length} rows', Colors.white54),
              _settingsRow('rush_ins', '${_rushIns.length} rows', Colors.white54),
              _settingsRow('companions', '${_companions.length} rows', Colors.white54),
              _settingsRow('requests', '${_requests.length} rows', Colors.white54),
              _settingsRow('messages', '${_messages.length} rows', Colors.white54),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Re-Authorize',
          subtitle: 'Enter a new service role key',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _accent.withValues(alpha: 0.15), foregroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Change Service Role Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('supabase_admin_key');
                  _promptForAdminKey();
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _settingsRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _actionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_rounded, color: Colors.white.withValues(alpha: 0.1), size: 64),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: Colors.white30, fontSize: 14)),
    ]));
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTION 8 — BOLROOMS
  // ═══════════════════════════════════════════════════════════════
  // BolRoom colors (reuse class-level static consts: _accent, _accentPurple etc)

  String _brGetRoomUid(dynamic id) {
    if (id == null) return '#000000';
    final str = id.toString().replaceAll('-', '');
    return '#${str.substring(0, math.min(6, str.length)).toUpperCase()}';
  }

  String _brGetTopic(dynamic t) => (t ?? 'Topic').toString().split('|').first.trim();
  String _brGetLoc(dynamic t) {
    final p = (t ?? '').toString().split('|');
    return p.length > 1 ? p.last.trim() : 'Unknown';
  }

  Future<void> _deleteChatroom(String roomId) async {
    final ok = await _confirmAction('Delete BolRoom?', 'This will permanently remove this chatroom and all its member records.');
    if (!ok || _adminClient == null) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      try { await _adminClient!.from('chatroom_members').delete().eq('room_id', roomId); } catch (_) {}
      await _adminClient!.from('chatrooms').delete().eq('id', roomId);
      if (mounted) _showSnack('BolRoom deleted.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAllChatrooms() async {
    final ok = await _confirmAction('Delete ALL BolRooms?', 'This will permanently wipe every chatroom and all member records. This action cannot be undone.');
    if (!ok || _adminClient == null) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      try { await _adminClient!.from('chatroom_members').delete().neq('id', '00000000-0000-0000-0000-000000000000'); } catch (_) {}
      await _adminClient!.from('chatrooms').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      if (mounted) _showSnack('All BolRooms purged.');
      await _fetchAllData();
    } catch (e) {
      if (mounted) _showSnack('Purge failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildBolRoomsSection() {
    if (_chatrooms.isEmpty) return _emptyState('No BolRooms found');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _card,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _accentPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.mic_rounded, color: _accentPurple, size: 14),
                  const SizedBox(width: 4),
                  Text('${_chatrooms.length} Room${_chatrooms.length == 1 ? '' : 's'}', style: const TextStyle(color: _accentPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _deleteAllChatrooms,
                icon: const Icon(Icons.delete_sweep_rounded, color: _accentRed, size: 16),
                label: const Text('Purge All', style: TextStyle(color: _accentRed, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(color: _cardBorder, height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAllData,
            color: _accent,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _chatrooms.length,
              itemBuilder: (ctx, i) {
                final room = _chatrooms[i];
                final roomId = room['id'].toString();
                final roomUid = _brGetRoomUid(room['id']);
                final roomName = room['name'] ?? 'Untitled Room';
                final topic = _brGetTopic(room['topic']);
                final location = _brGetLoc(room['topic']);
                final hostId = room['host_id']?.toString() ?? '';
                final hostName = room['host_name'] ?? 'Unknown';
                final hostAvatar = room['host_avatar'];
                final createdAt = room['created_at']?.toString() ?? '';
                final members = _chatroomMembers.where((m) => m['room_id']?.toString() == roomId).toList();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_accentPurple.withValues(alpha: 0.3), _accent.withValues(alpha: 0.15)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mic_rounded, color: _accent, size: 22),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(roomUid, style: const TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text(topic, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(width: 6),
                        const Icon(Icons.location_on, color: _accentPink, size: 10),
                        const SizedBox(width: 2),
                        Expanded(child: Text(location, style: const TextStyle(color: Colors.white38, fontSize: 10), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    iconColor: Colors.white38,
                    collapsedIconColor: Colors.white24,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: _cardBorder),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _accentOrange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _accentOrange.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _accentOrange.withValues(alpha: 0.2),
                                    backgroundImage: hostAvatar != null ? NetworkImage(hostAvatar) : null,
                                    child: hostAvatar == null ? const Icon(Icons.person, color: _accentOrange, size: 16) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(color: _accentOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('HOST', style: TextStyle(color: _accentOrange, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(hostName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        ]),
                                        Text('ID: ${hostId.length > 8 ? '${hostId.substring(0, 8)}...' : hostId}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              _brDetailChip(Icons.tag, 'UID', roomUid, _accent),
                              const SizedBox(width: 8),
                              _brDetailChip(Icons.category_rounded, 'Topic', topic, _accentPurple),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              _brDetailChip(Icons.location_on, 'Location', location, _accentPink),
                              const SizedBox(width: 8),
                              _brDetailChip(Icons.access_time_rounded, 'Created', _timeAgo(createdAt), _accentGreen),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              _brDetailChip(Icons.people_rounded, 'Participants', '${members.length}', const Color(0xFF06B6D4)),
                              const SizedBox(width: 8),
                              _brDetailChip(Icons.fingerprint_rounded, 'Room ID', '${roomId.substring(0, 8)}...', Colors.white38),
                            ]),
                            if (members.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('PARTICIPANTS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              const SizedBox(height: 8),
                              ...members.map((m) {
                                final mn = m['user_name'] ?? m['display_name'] ?? 'Unknown';
                                final mi = m['user_id']?.toString() ?? '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
                                  child: Row(children: [
                                    CircleAvatar(radius: 12, backgroundColor: _accent.withValues(alpha: 0.15),
                                      child: Text(mn.isNotEmpty ? mn[0].toUpperCase() : '?', style: const TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(mn, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                    Text(mi.length > 8 ? '${mi.substring(0, 8)}...' : mi, style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace')),
                                  ]),
                                );
                              }),
                            ],
                            const SizedBox(height: 16),
                            Row(children: [
                              _actionChip('Copy Room ID', Icons.copy_rounded, Colors.white38, () => _showSnack('Room ID: $roomId')),
                              const SizedBox(width: 8),
                              _actionChip('Delete Room', Icons.delete_forever_rounded, _accentRed, () => _deleteChatroom(roomId)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _brDetailChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(label.toUpperCase(), style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DONUT CHART PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _DonutPainter extends CustomPainter {
  final double completed;
  final double total;
  _DonutPainter(this.completed, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const stroke = 12.0;

    // Background ring
    canvas.drawCircle(center, radius, Paint()..color = Colors.white10..style = PaintingStyle.stroke..strokeWidth = stroke);

    // Completed arc
    if (total > 0) {
      final sweep = (completed / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false,
        Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round,
      );
    }

    // Center text
    final tp = TextPainter(
      text: TextSpan(text: '${total.toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 - 4));

    final tp2 = TextPainter(
      text: const TextSpan(text: 'USERS', style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(center.dx - tp2.width / 2, center.dy + 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// SELLER APPLICATION MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════

extension _SellerAdminExtensions on _AdminDashboardScreenState {
  Widget _buildSellerApplicationsSection() {
    final apps = _requests.where((r) => r['target_type'] == 'seller_application').toList();
    if (apps.isEmpty) return _emptyState('No seller applications found');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        final r = apps[i];
        final rid = r['id'].toString();
        final uid = r['sender_id'].toString();
        final status = r['status'] ?? 'pending';
        final payload = r['payload'] ?? {};
        final bizName = payload['business_name'] ?? 'Unknown Business';
        final category = payload['category'] ?? 'General';
        final desc = payload['description'] ?? 'No description';

        final isApproved = status == 'approved';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: const Color(0xFF12121E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E1E30))),
          child: ExpansionTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.1), child: const Icon(Icons.storefront_rounded, color: Color(0xFF00E5FF), size: 20)),
            title: Text(bizName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Category: $category · Applied by ${_getUserName(uid)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isApproved ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status.toUpperCase(), style: TextStyle(color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BUSINESS DESCRIPTION', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 20),
                    if (!isApproved) Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                            onPressed: () async {
                              final ok = await _confirmAction('Approve Seller?', 'This will grant the user verified seller status and allow them to list commercial packages.');
                              if (ok) {
                                try {
                                  // Approval logic
                                  await Supabase.instance.client.from('profiles').update({'is_seller': true}).eq('id', uid);
                                  await _updateRequestStatus(rid, 'approved');
                                } catch (e) {
                                  _showSnack('Approval failed: $e', isError: true);
                                }
                              }
                            },
                            child: const Text('APPROVE & VERIFY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444)),
                          onPressed: () => _updateRequestStatus(rid, 'declined'),
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
  }
}
