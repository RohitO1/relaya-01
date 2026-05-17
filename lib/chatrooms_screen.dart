// ignore_for_file: duplicate_ignore, unused_element, unused_local_variable, deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_brace_in_string_interps, avoid_print, unused_field, prefer_final_fields
// ignore_for_file: prefer_final_fields, unused_field, curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chatroom_live_screen.dart';
import 'services/notification_service.dart';

class BolRoomColors {
  static const bg = Color(0xFF0C0914);
  static const searchBg = Color(0xFF151121);
  static const searchBorder = Color(0xFF262136);
  static const accent = Color(0xFFFF2D78);
  static const cyan = Color(0xFF00F0FF);
  static const purple = Color(0xFF9D4EDD);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFA19EAD);
  
  // Backward compatibility for chatroom_live_screen.dart
  static const card = Color(0xFF111827);
  static const cardHover = Color(0xFF1E293B);
  static const gold = Color(0xFFFFB347);
  static const text = Color(0xFFF0F6FC);
  static const muted = Color(0xFF8B949E);
  static const glass = Color(0x18FFFFFF);
}

class ChatroomsScreen extends StatefulWidget {
  const ChatroomsScreen({super.key});
  @override
  State<ChatroomsScreen> createState() => _ChatroomsScreenState();
}

class _ChatroomsScreenState extends State<ChatroomsScreen> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  int _unreadCount = 0;
  RealtimeChannel? _notifSub;

  String _getRoomUid(dynamic id) {
    if (id == null) return '#000000';
    final str = id.toString().replaceAll('-', '');
    return '#${str.substring(0, math.min(6, str.length)).toUpperCase()}';
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
      backgroundColor: const Color(0xFF151121),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.1, left: 24, right: 24),
      duration: const Duration(seconds: 2),
    ));
  }

  String _getTopic(dynamic t) => (t ?? 'Topic').toString().split('|').first.trim();
  String _getLoc(dynamic t) {
    final p = (t ?? '').toString().split('|');
    if (p.length > 1) {
      final loc = p.last.trim();
      if (loc.isNotEmpty && !loc.toLowerCase().contains('could not') && !loc.toLowerCase().contains('error') && !loc.toLowerCase().contains('denied')) return loc;
    }
    return 'Global';
  }

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _loadUnreadCount();
    _setupNotifListener();
    _sb.channel('public:chatrooms').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'chatrooms',
      callback: (_) => _loadRooms(),
    ).subscribe();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_notifSub != null) _sb.removeChannel(_notifSub!);
    _sb.removeChannel(_sb.channel('public:chatrooms'));
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final res = await _sb.from('chatrooms').select('*').order('created_at', ascending: false).limit(50);
      if (mounted) setState(() { _rooms = List<Map<String,dynamic>>.from(res); _loading = false; });
    } catch (e) {
      debugPrint('Load rooms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    final count = await NotificationService.getUnreadCount(uid);
    if (mounted) setState(() => _unreadCount = count);
  }

  void _setupNotifListener() {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    
    _notifSub = _sb
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => _loadUnreadCount(),
        )
        .subscribe();
  }

  void _showNotificationsSheet() {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationsSheet(userId: uid),
    ).then((_) {
      _loadUnreadCount();
    });
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _CreateRoomModal(onCreated: (room) {
        BolRoomManager.openRoom(context,
          roomId: room['id'].toString(), roomName: room['name'] ?? 'Untitled', topic: room['topic'] ?? 'General',
          hostId: room['host_id']?.toString() ?? '', hostName: room['host_name'] ?? 'Host',
        );
      }),
    );
  }

  void _joinRoom(Map<String, dynamic> room) {
    HapticFeedback.lightImpact();
    BolRoomManager.openRoom(context,
      roomId: room['id'].toString(), roomName: room['name'] ?? 'Untitled', topic: room['topic'] ?? 'General',
      hostId: room['host_id']?.toString() ?? '', hostName: room['host_name'] ?? 'Host',
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredRooms = _rooms.where((r) {
      if (query.isEmpty) return true;
      final name = (r['name'] ?? '').toString().toLowerCase();
      final uid = _getRoomUid(r['id']).toLowerCase();
      return name.contains(query) || uid.contains(query);
    }).toList();

    final now = DateTime.now();
    final liveRooms = filteredRooms.where((r) => r['scheduled_at'] == null || DateTime.tryParse(r['scheduled_at']?.toString() ?? '')?.isBefore(now) == true).toList();
    final scheduledRooms = filteredRooms.where((r) {
      if (r['scheduled_at'] == null) return false;
      final t = DateTime.tryParse(r['scheduled_at'].toString());
      return t != null && t.isAfter(now);
    }).toList();

    final featuredRooms = liveRooms.take(2).toList();
    final bannerRoom = liveRooms.length > 2 ? liveRooms[2] : null;
    final trendingRooms = liveRooms.length > 3 ? liveRooms.skip(3).toList() : liveRooms.toList();

    return Scaffold(
      backgroundColor: BolRoomColors.bg,
      body: SafeArea(
        child: _loading 
          ? const Center(child: CircularProgressIndicator(color: BolRoomColors.cyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildCategories(),
                  const SizedBox(height: 32),
                  if (featuredRooms.isNotEmpty) _buildFeaturedRooms(featuredRooms),
                  if (scheduledRooms.isNotEmpty) _buildScheduledSection(scheduledRooms),
                  if (bannerRoom != null) _buildLiveBanner(bannerRoom),
                  if (trendingRooms.isNotEmpty) _buildTrendingRooms(trendingRooms),
                  if (_rooms.isEmpty && !_loading) _emptyState(),
                  const SizedBox(height: 80), // space for FAB
                ],
              ),
            ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GOOD MORNING ✦', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.5)),
            GestureDetector(
              onTap: _showNotificationsSheet,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: BolRoomColors.searchBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.notifications_none, color: Colors.white, size: 18),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                      ),
                    ),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Text('Discover', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.1)),
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(colors: [BolRoomColors.accent, BolRoomColors.cyan]).createShader(bounds),
              child: Text('Rooms', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.1)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: BolRoomColors.searchBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BolRoomColors.searchBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: BolRoomColors.textSecondary.withValues(alpha: 0.6), size: 20),
          hintText: 'Search rooms, topics, or UID...',
          hintStyle: GoogleFonts.inter(color: BolRoomColors.textSecondary.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final cats = [
      {'icon': '🔥', 'label': 'Trending', 'active': true},
      {'icon': '🎵', 'label': 'Music', 'active': false},
      {'icon': '🎮', 'label': 'Gaming', 'active': false},
      {'icon': '💼', 'label': 'Business', 'active': false},
      {'icon': '🚀', 'label': 'Crypto', 'active': false},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: cats.map((c) {
          final active = c['active'] as bool;
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: active ? const Color(0xFF7856FF).withValues(alpha: 0.15) : BolRoomColors.searchBg,
              border: Border.all(color: active ? const Color(0xFF7856FF) : BolRoomColors.searchBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Text(c['icon'] as String, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(c['label'] as String, style: GoogleFonts.inter(color: active ? Colors.white : BolRoomColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturedRooms(List<Map<String, dynamic>> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF7856FF), size: 22),
            const SizedBox(width: 8),
            Text('Happening now', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: List.generate(rooms.length, (i) {
              final room = rooms[i];
              return GestureDetector(
                onTap: () => _joinRoom(room),
                child: Container(
                  width: 280, height: 185,
                  margin: const EdgeInsets.only(right: 18),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7856FF), Color(0xFF4C1D95)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: const Color(0xFF7856FF).withValues(alpha: 0.25), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('LIVE', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ]),
                          ),
                          if (room['game_mode'] != null && room['game_mode'].toString().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF3DCFA0), Color(0xFF0099CC)]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.sports_esports, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text('GAME', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ]),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                            child: Text(_getTopic(room['topic']), style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(room['name'] ?? 'Space Name', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Overlapping avatars like X
                          SizedBox(
                            width: 60,
                            height: 28,
                            child: Stack(
                              children: [
                                _avatarCircle('👨‍💻', const Color(0xFFE2E8F0), 0),
                                Positioned(left: 14, child: _avatarCircle('👩‍🚀', const Color(0xFFFFD166), 1)),
                                Positioned(left: 28, child: _avatarCircle('🕺', const Color(0xFF06D6A0), 2)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${room['listener_count'] ?? (100 + i*42)} listening',
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.mic, color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text('Host: ${room['host_name'] ?? 'User'}', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 100 * i)).slideX(begin: 0.05, end: 0);
            }),
          ),
        ),
      ],
    );
  }

  Widget _avatarCircle(String emoji, Color bg, int zIndex) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg, border: Border.all(color: const Color(0xFF4C1D95), width: 2)),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
    );
  }

  Widget _buildAvatarCircle(String emoji, Color bg) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 12))),
    );
  }

  Widget _buildLiveBanner(Map<String, dynamic> room) {
    return GestureDetector(
      onTap: () => _joinRoom(room),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: BolRoomColors.searchBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BolRoomColors.cyan.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: BolRoomColors.cyan, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.mic, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room['name'] ?? 'Voice Room Live', style: GoogleFonts.inter(color: BolRoomColors.cyan, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(child: Text('${_getTopic(room['topic'])} • ${math.Random().nextInt(300) + 10} listening', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      const Icon(Icons.location_on, color: BolRoomColors.accent, size: 10),
                      const SizedBox(width: 2),
                      Flexible(child: Text(_getLoc(room['topic']), style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: BolRoomColors.cyan, borderRadius: BorderRadius.circular(12)),
              child: Text('Tap In', style: GoogleFonts.inter(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildTrendingRooms(List<Map<String, dynamic>> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('Trending Now', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(rooms.length, (i) {
          final room = rooms[i];
          final icons = [
            {'icon': '🚀', 'bg': const Color(0xFF3B1E4A), 'tag': '🔥 HOT', 'tagColor': const Color(0xFF6B1B2F), 'tagText': const Color(0xFFFF4D4D)},
            {'icon': '🎨', 'bg': const Color(0xFF14453D), 'tag': '✨ NEW', 'tagColor': const Color(0xFF1B4D36), 'tagText': const Color(0xFF00FF88)},
            {'icon': '🎮', 'bg': const Color(0xFF4A2B2B), 'tag': '⭐ TOP', 'tagColor': const Color(0xFF4A3E1B), 'tagText': const Color(0xFFFFD700)},
            {'icon': '🧘‍♂️', 'bg': const Color(0xFF1B3A5A), 'tag': '✨ NEW', 'tagColor': const Color(0xFF1B4D36), 'tagText': const Color(0xFF00FF88)},
          ];
          final style = icons[i % icons.length];
          return GestureDetector(
            onTap: () => _joinRoom(room),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BolRoomColors.searchBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BolRoomColors.searchBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: style['bg'] as Color, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(style['icon'] as String, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room['name'] ?? 'Room Name', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00E5CC), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Flexible(child: Text('${room['listener_count'] ?? 0} listening • ${_getTopic(room['topic'])}', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            const Icon(Icons.location_on, color: BolRoomColors.accent, size: 10),
                            const SizedBox(width: 2),
                            Flexible(child: Text(_getLoc(room['topic']), style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: style['tagColor'] as Color, borderRadius: BorderRadius.circular(8)),
                    child: Text(style['tag'] as String, style: GoogleFonts.inter(color: style['tagText'] as Color, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 50 * i)).slideY(begin: 0.1, end: 0);
        }),
      ],
    );
  }

  // ── SCHEDULED SPACES SECTION ──
  Widget _buildScheduledSection(List<Map<String, dynamic>> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.schedule, color: Color(0xFF9D4EDD), size: 18),
          const SizedBox(width: 8),
          Text('Scheduled', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        ...rooms.map((room) {
          final scheduledAt = DateTime.tryParse(room['scheduled_at']?.toString() ?? '');
          final diff = scheduledAt?.difference(DateTime.now());
          String countdown = 'Soon';
          if (diff != null) {
            if (diff.inDays > 0) countdown = 'in ${diff.inDays}d ${diff.inHours % 24}h';
            else if (diff.inHours > 0) countdown = 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
            else countdown = 'in ${diff.inMinutes}m';
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BolRoomColors.searchBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: const Color(0xFF9D4EDD).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.calendar_today, color: Color(0xFF9D4EDD), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(room['name'] ?? 'Scheduled Space', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('@${room['host_name'] ?? 'host'} • $countdown', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                ])),
                GestureDetector(
                  onTap: () => _showToast('Reminder set! 🔔'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF9D4EDD), borderRadius: BorderRadius.circular(20)),
                    child: Text('Remind me', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _emptyState() {
    return Center(child: Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [BolRoomColors.cyan.withValues(alpha: 0.12), Colors.transparent]),
          border: Border.all(color: BolRoomColors.cyan.withValues(alpha: 0.15))),
          child: const Icon(Icons.headset_mic, size: 48, color: BolRoomColors.cyan))
            .animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.06,1.06), duration: 2.seconds),
        const SizedBox(height: 24),
        Text('No active rooms', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Be the first to go live! 🎙️', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 14)),
      ]),
    ));
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: _showCreateModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: [BolRoomColors.cyan, BolRoomColors.purple]),
          boxShadow: [BoxShadow(color: BolRoomColors.cyan.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add, color: Colors.black, size: 22),
          const SizedBox(width: 8),
          Text('Create Room', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }
}

// ==========================================
// CREATE ROOM MODAL
// ==========================================
class _CreateRoomModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onCreated;
  const _CreateRoomModal({required this.onCreated});
  @override
  State<_CreateRoomModal> createState() => _CreateRoomModalState();
}

class _CreateRoomModalState extends State<_CreateRoomModal> {
  final _nameCtrl = TextEditingController();
  String _topic = 'Bollywood';
  String _speakPermission = 'everyone'; // 'everyone' | 'followers' | 'invite_only'
  String? _gameMode; // null = normal room, 'truth_dare' = game room
  bool _isScheduled = false;
  DateTime? _scheduledAt;
  bool _creating = false;
  String _location = 'Fetching location...';
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _location = 'Location services disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _location = 'Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _location = 'Location permanently denied');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)));
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&addressdetails=1'),
        headers: {'User-Agent': 'MeetraApp/1.0'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['address'] ?? {};
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'] ?? '';
        final district = address['state_district'] ?? address['county'] ?? '';
        final state = address['state'] ?? '';
        
        // Prefer city + state, fallback to district + state
        String locStr = '';
        if (city.toString().trim().isNotEmpty) {
          locStr = [city, state].where((e) => e.toString().trim().isNotEmpty).join(', ');
        } else {
          locStr = [district, state].where((e) => e.toString().trim().isNotEmpty).join(', ');
        }
        if (locStr.isEmpty) locStr = 'Unknown Location';
        
        if (mounted) setState(() {
          _location = locStr;
          _locationFetched = true;
        });
      } else {
        if (mounted) setState(() { _location = 'Global'; _locationFetched = true; });
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
      if (mounted) setState(() { _location = 'Global'; _locationFetched = true; });
    }
  }

  final _topics = [
    {'name': 'Bollywood', 'emoji': '🎬'},
    {'name': 'Gaming', 'emoji': '🎮'},
    {'name': 'Tech', 'emoji': '💻'},
    {'name': 'Startup', 'emoji': '🚀'},
    {'name': 'Music', 'emoji': '🎵'},
    {'name': 'Shayari', 'emoji': '✨'},
    {'name': 'Relationships', 'emoji': '❤️'},
    {'name': 'Cricket', 'emoji': '🏏'},
    {'name': 'Career', 'emoji': '💼'},
    {'name': 'Chit Chat', 'emoji': '💬'},
  ];

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _creating = true);
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _creating = false); return; }

    String hName = 'Host';
    String? hAvatar;
    try {
      final p = await sb.from('profiles').select('name, full_name, avatar_url').eq('id', uid).maybeSingle();
      if (p != null) { hName = p['name'] ?? p['full_name'] ?? 'Host'; hAvatar = p['avatar_url']; }
    } catch (_) {}

    try {
      final res = await sb.from('chatrooms').insert({
        'name': _nameCtrl.text.trim(),
        'topic': '$_topic | $_location',
        'host_id': uid, 'host_name': hName, 'host_avatar': hAvatar,
        'speak_permission': _speakPermission,
        'game_mode': _gameMode,
        'scheduled_at': _isScheduled && _scheduledAt != null ? _scheduledAt!.toUtc().toIso8601String() : null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      // Give the host credit for creating a room in their BolRoom profile
      try {
        final profile = await sb.from('bolroom_profiles').select('rooms_hosted').eq('id', uid).maybeSingle();
        final int currentCount = profile?['rooms_hosted'] ?? 0;
        await sb.from('bolroom_profiles').update({'rooms_hosted': currentCount + 1}).eq('id', uid);
      } catch (e) {
        debugPrint('Failed to increment rooms_hosted: $e');
      }

      if (mounted) {
        Navigator.pop(context);
        // Only navigate into room if going live now (not scheduled)
        if (!_isScheduled || _scheduledAt == null) widget.onCreated(res);
        else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Space scheduled for ${DateFormat('MMM d, h:mm a').format(_scheduledAt!)}'),
            backgroundColor: const Color(0xFF9D4EDD),
          ));
        }
      }
    } catch (e) {
      debugPrint('Create room error: $e');
      if (mounted) { setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    }
  }

  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now.add(const Duration(hours: 1)), firstDate: now, lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF9D4EDD))), child: child!));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF9D4EDD))), child: child!));
    if (time == null || !mounted) return;
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: BolRoomColors.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: BolRoomColors.searchBorder),
        boxShadow: [BoxShadow(color: BolRoomColors.purple.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, -10))]),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, left: 24, right: 24, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: BolRoomColors.searchBorder, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 24),
        Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: BolRoomColors.cyan.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.mic, color: BolRoomColors.cyan, size: 24)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Start a BolRoom', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, color: BolRoomColors.accent, size: 12),
              const SizedBox(width: 4),
              Text(_location, style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ]),
        const SizedBox(height: 32),
        Text('ROOM NAME', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(hintText: 'e.g. Late Night Vibes ✨', hintStyle: TextStyle(color: BolRoomColors.textSecondary.withValues(alpha: 0.5)),
            filled: true, fillColor: BolRoomColors.searchBg, prefixIcon: Icon(Icons.edit, color: BolRoomColors.textSecondary.withValues(alpha: 0.5), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BolRoomColors.cyan)))),
        const SizedBox(height: 28),
        Text('TOPIC', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: _topics.map((t) {
          final selected = _topic == t['name'];
          return GestureDetector(onTap: () => setState(() => _topic = t['name']!),
            child: AnimatedContainer(duration: 200.ms, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? BolRoomColors.cyan.withValues(alpha: 0.15) : BolRoomColors.searchBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? BolRoomColors.cyan : BolRoomColors.searchBorder, width: 1.5),
                boxShadow: selected ? [BoxShadow(color: BolRoomColors.cyan.withValues(alpha: 0.2), blurRadius: 12)] : []),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t['emoji']!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(t['name']!, style: GoogleFonts.inter(color: selected ? BolRoomColors.cyan : BolRoomColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ])));
        }).toList()),
        const SizedBox(height: 28),
        // ── GAME MODE ──
        Text('GAME MODE', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text('Add a party game to your voice room', style: GoogleFonts.inter(color: BolRoomColors.textSecondary.withValues(alpha: 0.6), fontSize: 10)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _gameChip(null, '🚫 None'),
          _gameChip('truth_dare', '🍾 Truth or Dare'),
          _gameChip('two_truths', '🎭 Two Truths, One Lie'),
          _gameChip('blind_date', '🔥 Blind Date'),
        ]),
        const SizedBox(height: 28),
        // ── SPEAK PERMISSION ──
        Text('WHO CAN SPEAK', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _permissionChip('everyone', '🌐 Everyone'),
          _permissionChip('followers', '👥 Followers'),
          _permissionChip('invite_only', '🔒 Invite Only'),
        ]),
        const SizedBox(height: 28),
        // ── SCHEDULE TOGGLE ──
        Row(children: [
          Expanded(child: Text('Schedule for later', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          Switch(value: _isScheduled, onChanged: (v) => setState(() { _isScheduled = v; if (v && _scheduledAt == null) _pickScheduleTime(); }), activeTrackColor: const Color(0xFF9D4EDD)),
        ]),
        if (_isScheduled) ...[const SizedBox(height: 8),
          GestureDetector(onTap: _pickScheduleTime, child: Container(
            padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF9D4EDD).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: Color(0xFF9D4EDD), size: 18),
              const SizedBox(width: 12),
              Text(_scheduledAt != null ? DateFormat('MMM d, y  h:mm a').format(_scheduledAt!) : 'Tap to choose time',
                style: GoogleFonts.inter(color: const Color(0xFF9D4EDD), fontWeight: FontWeight.w600)),
            ]),
          )),
        ],
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          onPressed: _creating ? null : _create,
          child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: _isScheduled ? [const Color(0xFF9D4EDD), const Color(0xFF5B2DBF)] : [BolRoomColors.accent, BolRoomColors.purple]),
            boxShadow: [BoxShadow(color: (_isScheduled ? const Color(0xFF9D4EDD) : BolRoomColors.accent).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
            alignment: Alignment.center,
            child: _creating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_isScheduled ? Icons.schedule : Icons.bolt, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(_isScheduled ? 'Schedule Space' : 'Go Live', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ])))),
      ]),
    );
  }

  Widget _permissionChip(String value, String label) {
    final selected = _speakPermission == value;
    return GestureDetector(
      onTap: () => setState(() => _speakPermission = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF9D4EDD).withValues(alpha: 0.15) : BolRoomColors.searchBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF9D4EDD) : BolRoomColors.searchBorder, width: 1.5),
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? const Color(0xFF9D4EDD) : BolRoomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _gameChip(String? value, String label) {
    final selected = _gameMode == value;
    return GestureDetector(
      onTap: () => setState(() => _gameMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3DCFA0).withValues(alpha: 0.15) : BolRoomColors.searchBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF3DCFA0) : BolRoomColors.searchBorder, width: 1.5),
          boxShadow: selected ? [BoxShadow(color: const Color(0xFF3DCFA0).withValues(alpha: 0.15), blurRadius: 8)] : [],
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? const Color(0xFF3DCFA0) : BolRoomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  final String userId;
  const _NotificationsSheet({required this.userId});

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    NotificationService.markAllAsRead(widget.userId);
  }

  Future<void> _load() async {
    final res = await NotificationService.fetchNotifications(widget.userId);
    if (mounted) setState(() { _notifs = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BolRoomColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.only(top: 12),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notifications', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: BolRoomColors.cyan))
              : _notifs.isEmpty 
                ? Center(child: Text('No notifications yet.', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 16)))
                : ListView.builder(
                    itemCount: _notifs.length,
                    itemBuilder: (context, index) {
                      final n = _notifs[index];
                      final isRead = n['is_read'] == true;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: isRead ? BolRoomColors.searchBg : BolRoomColors.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            n['type'] == 'message' ? Icons.person_add : Icons.notifications,
                            color: isRead ? Colors.white54 : BolRoomColors.accent,
                          ),
                        ),
                        title: Text(n['title'] ?? 'Notification', style: GoogleFonts.inter(color: Colors.white, fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(n['body'] ?? '', style: GoogleFonts.inter(color: BolRoomColors.textSecondary, fontSize: 13)),
                        trailing: Text(
                          _formatTime(n['created_at']),
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}


