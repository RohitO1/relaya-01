// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bolroom_theme.dart';
import 'bolroom_community_detail_screen.dart';
import '../services/location_service.dart';
import '../services/doodle_theme.dart';

class BolroomCommunitiesScreen extends StatefulWidget {
  const BolroomCommunitiesScreen({super.key});
  @override
  State<BolroomCommunitiesScreen> createState() => _BolroomCommunitiesScreenState();
}

class _BolroomCommunitiesScreenState extends State<BolroomCommunitiesScreen> {
  final _sb = Supabase.instance.client;
  String get _myId => _sb.auth.currentUser?.id ?? '';
  List<Map<String, dynamic>> _communities = [];
  Set<String> _joinedIds = {};
  bool _loading = true;
  String searchQuery = "";
  
  int selectedCategory = 0;
  List<String> categories = ["All", "Local", "Gaming", "Tech", "Music", "Art", "Memes"];

  Map<String, Map<String, dynamic>> _lastMessages = {};
  Map<String, String> _lastSeenMessageIds = {};
  RealtimeChannel? _communityMsgChannel;

  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color purpleDark = Color(0xFF7B2CBF);
  static const Color textMuted = Color(0xFF8E8B99);

  // ignore: unused_field
  static LinearGradient neonGradient = const LinearGradient(
    colors: [Color(0xFFD433FF), Color(0xFF7B2CBF), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
    locationService.activeDistrictNotifier.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    if (_communityMsgChannel != null) {
      _sb.removeChannel(_communityMsgChannel!);
    }
    locationService.activeDistrictNotifier.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _subscribeRealtime() {
    _communityMsgChannel = _sb.channel('all_community_msgs').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'bolroom_community_messages',
      callback: (payload) {
        if (payload.newRecord.isNotEmpty && mounted) {
          final newMsg = payload.newRecord;
          final cid = newMsg['community_id'].toString();
          setState(() {
            _lastMessages[cid] = newMsg;
          });
        }
      },
    );
    _communityMsgChannel!.subscribe();
  }

  Future<void> _loadData() async {
    try {
      final locSvc = LocationService();
      var commsQuery = _sb.from('bolroom_communities').select('*');
      final comms = await commsQuery.order('member_count', ascending: false).limit(100);
      List<dynamic> joined = [];
      if (_myId.isNotEmpty && _myId != 'null' && _myId.contains('-')) {
        final res = await _sb.from('bolroom_community_members').select('community_id').eq('user_id', _myId);
        joined = res as List<dynamic>;
      }

      // Load last messages
      final msgsRes = await _sb.from('bolroom_community_messages').select('*').order('created_at', ascending: false).limit(500);
      final List<Map<String, dynamic>> msgs = List<Map<String, dynamic>>.from(msgsRes);
      final Map<String, Map<String, dynamic>> lastMsgsMap = {};
      for (var msg in msgs) {
        final cid = msg['community_id'].toString();
        if (!lastMsgsMap.containsKey(cid)) {
          lastMsgsMap[cid] = msg;
        }
      }

      // Load last seen message IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> lastSeen = {};
      for (var com in comms) {
        final cid = com['id'].toString();
        final seenId = prefs.getString('seen_msg_$cid');
        if (seenId != null) {
          lastSeen[cid] = seenId;
        }
      }

      if (mounted) {
        setState(() {
          _communities = List<Map<String, dynamic>>.from(comms);
          _joinedIds = joined.map((e) => e['community_id'].toString()).toSet();
          _lastMessages = lastMsgsMap;
          _lastSeenMessageIds = lastSeen;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load communities: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleJoin(Map<String, dynamic> comm) async {
    final cid = comm['id'].toString();
    HapticFeedback.lightImpact();
    try {
      if (_joinedIds.contains(cid)) {
        await _sb.from('bolroom_community_members').delete().eq('community_id', cid).eq('user_id', _myId);
        await _sb.from('bolroom_communities').update({'member_count': (comm['member_count'] ?? 1) - 1}).eq('id', cid);
        setState(() => _joinedIds.remove(cid));
      } else {
        await _sb.from('bolroom_community_members').insert({'community_id': cid, 'user_id': _myId});
        await _sb.from('bolroom_communities').update({'member_count': (comm['member_count'] ?? 0) + 1}).eq('id', cid);
        setState(() => _joinedIds.add(cid));
      }
      _loadData();
    } catch (e) { debugPrint('Toggle join: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    List<Map<String, dynamic>> filtered = _communities.where((c) {
      final cid = c['id'].toString();
      final bool isJoinedOrCreated = _joinedIds.contains(cid) || c['creator_id'] == _myId;
      if (isJoinedOrCreated) return false;

      bool matchesSearch = (c['name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());
      
      final currentCat = categories[selectedCategory];
      bool matchesCat = true;
      if (currentCat == "Local") {
        final loc = locationService.activeDistrict.toLowerCase().trim();
        final cLoc = (c['district'] ?? '').toString().toLowerCase().trim();
        if (loc.isEmpty || loc == 'unknown') {
          matchesCat = false;
        } else {
          matchesCat = cLoc.contains(loc) || loc.contains(cLoc);
        }
      } else if (currentCat != "All") {
        matchesCat = c['category'] == currentCat;
      }
      
      return matchesSearch && matchesCat;
    }).toList();

    // Sort surfing list: Local first, then member count descending
    final activeLoc = locationService.activeDistrict.toLowerCase().trim();
    filtered.sort((a, b) {
      if (categories[selectedCategory] == "All" && activeLoc.isNotEmpty && activeLoc != 'unknown') {
        final aLoc = (a['district'] ?? '').toString().toLowerCase().trim();
        final bLoc = (b['district'] ?? '').toString().toLowerCase().trim();
        final aIsLocal = aLoc.contains(activeLoc) || activeLoc.contains(aLoc);
        final bIsLocal = bLoc.contains(activeLoc) || activeLoc.contains(bLoc);
        
        if (aIsLocal && !bIsLocal) return -1;
        if (!aIsLocal && bIsLocal) return 1;
      }
      return (b['member_count'] ?? 0).compareTo(a['member_count'] ?? 0);
    });

    return Scaffold(
      backgroundColor: doodle ? DoodleColors.paper : bgColor,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: doodle ? DoodleColors.brown : purplePrimary, strokeWidth: 2))
            : Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader("Communities", Icons.add_circle_outline, doodle),
                      _buildSearchBar("Discover communities...", doodle, (val) {
                        setState(() => searchQuery = val);
                      }),
                      
                      // Categories
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: List.generate(categories.length, (index) {
                            bool isSelected = selectedCategory == index;
                            return GestureDetector(
                              onTap: () => setState(() => selectedCategory = index),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: doodle
                                  ? BoxDecoration(
                                      color: isSelected ? DoodleColors.cream : DoodleColors.paper,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: DoodleColors.brown, width: isSelected ? 2 : 1),
                                      boxShadow: isSelected ? [BoxShadow(color: DoodleColors.brown, offset: const Offset(2, 2))] : [],
                                    )
                                  : BoxDecoration(
                                      color: isSelected ? purpleDark.withValues(alpha: 0.3) : cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? purplePrimary : borderColor,
                                      ),
                                    ),
                                child: Text(
                                  categories[index],
                                  style: doodle
                                    ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 13).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
                                    : TextStyle(
                                        color: isSelected ? Colors.white : textMuted,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Joined/Created Section (Only show if no search/filter)
                      if (searchQuery.isEmpty && selectedCategory == 0)
                        Builder(builder: (ctx) {
                          final joinedOrCreated = _communities.where((c) {
                            final cid = c['id'].toString();
                            return _joinedIds.contains(cid) || c['creator_id'] == _myId;
                          }).toList();
                          if (joinedOrCreated.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
                                child: Text("Joined by you or Created by", style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18) : const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 20),
                                child: Row(
                                  children: joinedOrCreated.map((c) => _buildTrendingCard(c, doodle)).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }),

                      // List of Communities (Surfing list)
                      Expanded(
                        child: filtered.isEmpty 
                          ? Center(child: Text("No communities found", style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 16) : const TextStyle(color: textMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildCommunityTile(filtered[index], doodle);
                              },
                            ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(String title, IconData actionIcon, bool doodle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: doodle
                    ? DoodleDecorations.card()
                    : BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                  child: Icon(Icons.arrow_back_ios_new, color: doodle ? DoodleColors.brown : Colors.white, size: 18),
                ),
              ),
              Text(
                title,
                style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 32) : const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showCreate,
            child: Container(
              width: 44,
              height: 44,
              decoration: doodle
                ? DoodleDecorations.card()
                : BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)
                    ]
                  ),
              child: Icon(actionIcon, color: doodle ? DoodleColors.blue : purplePrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint, bool doodle, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: doodle
          ? DoodleDecorations.input().copyWith(
              color: DoodleColors.cream,
            )
          : BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
        child: TextField(
          onChanged: onChanged,
          style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: Colors.white),
          decoration: doodle
            ? InputDecoration(
                hintText: hint,
                hintStyle: DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14),
                prefixIcon: Icon(Icons.search, color: DoodleColors.brown.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              )
            : InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
        ),
      ),
    );
  }

  Widget _buildTrendingCard(Map<String, dynamic> c, bool doodle) {
    final bannerHex = c['banner_color'] ?? '#7856FF';
    Color bannerColor = purplePrimary;
    try { bannerColor = Color(int.parse('FF${bannerHex.toString().replaceFirst('#', '')}', radix: 16)); } catch (_) {}
    
    final bool isCreator = c['creator_id'] == _myId;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, BolroomTheme.slideRoute(BolroomCommunityDetailScreen(community: c))).then((_) => _loadData());
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.transparent, // transparent, no background card effect
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Circular Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: doodle
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCreator ? DoodleColors.orange.withValues(alpha: 0.12) : bannerColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: isCreator ? DoodleColors.orange : bannerColor,
                          width: 2,
                        ),
                      )
                    : BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCreator ? Colors.amber.withValues(alpha: 0.12) : bannerColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: isCreator ? Colors.amber.withValues(alpha: 0.3) : bannerColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                  child: Center(
                    child: Text(c['icon'] ?? '💬', style: const TextStyle(fontSize: 22)),
                  ),
                ),
                if (isCreator)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: doodle
                      ? BoxDecoration(
                          color: DoodleColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DoodleColors.orange.withValues(alpha: 0.3)),
                        )
                      : BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: doodle ? DoodleColors.orange : Colors.amber, size: 10),
                        const SizedBox(width: 2),
                        Text("Host", style: doodle ? DoodleFonts.body(color: DoodleColors.orange, fontSize: 10).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: doodle
                      ? BoxDecoration(
                          color: DoodleColors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DoodleColors.blue.withValues(alpha: 0.25)),
                        )
                      : BoxDecoration(
                          color: const Color(0xFF00FF00).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00FF00).withValues(alpha: 0.25)),
                        ),
                    child: Text("Joined", style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 10).copyWith(fontWeight: FontWeight.bold) : const TextStyle(color: Color(0xFF00FF00), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(c['name'] ?? 'Hub', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 16) : const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text("${c['member_count'] ?? 0} Members", style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12) : const TextStyle(color: textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityTile(Map<String, dynamic> com, bool doodle) {
    final cid = com['id'].toString();
    final bool isJoined = _joinedIds.contains(cid);
    
    final bannerHex = com['banner_color'] ?? '#7856FF';
    Color bannerColor = purplePrimary;
    try { bannerColor = Color(int.parse('FF${bannerHex.toString().replaceFirst('#', '')}', radix: 16)); } catch (_) {}

    final lastMsg = _lastMessages[cid];
    final bool hasUnread = lastMsg != null && _lastSeenMessageIds[cid] != lastMsg['id'].toString();
    
    final String lastMsgText = lastMsg != null 
        ? "${lastMsg['anon_name']}: ${lastMsg['text']}" 
        : (com['description'] ?? 'No description.');

    final String timeStr = lastMsg != null ? _getRelativeTime(lastMsg['created_at']) : "";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, BolroomTheme.slideRoute(BolroomCommunityDetailScreen(community: com))).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent, // transparent background
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Circular Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: doodle
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: bannerColor.withValues(alpha: 0.12),
                        border: Border.all(color: bannerColor, width: 2),
                      )
                    : BoxDecoration(
                        shape: BoxShape.circle,
                        color: bannerColor.withValues(alpha: 0.12),
                        border: Border.all(color: bannerColor.withValues(alpha: 0.3), width: 1.5),
                      ),
                  child: Center(
                    child: Text(com['icon'] ?? '💬', style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              com['name'] ?? '',
                              style: doodle
                                ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 18).copyWith(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600)
                                : TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: doodle
                                ? DoodleFonts.body(color: hasUnread ? DoodleColors.blue : DoodleColors.brown.withValues(alpha: 0.6), fontSize: 12).copyWith(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)
                                : TextStyle(
                                    color: hasUnread ? purplePrimary : textMuted,
                                    fontSize: 12,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              lastMsgText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: doodle
                                ? DoodleFonts.body(color: hasUnread ? DoodleColors.brown : DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14).copyWith(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)
                                : TextStyle(
                                    color: hasUnread ? Colors.white : textMuted,
                                    fontSize: 13,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                            ),
                          ),
                          if (hasUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: doodle ? DoodleColors.blue : purplePrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.people, color: doodle ? DoodleColors.brown.withValues(alpha: 0.6) : purplePrimary, size: 14),
                          const SizedBox(width: 4),
                          Text("${com['member_count'] ?? 0} members", style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 12) : const TextStyle(color: textMuted, fontSize: 11)),
                          if (com['is_private'] == true) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.lock_outline, color: doodle ? DoodleColors.brown.withValues(alpha: 0.6) : textMuted, size: 12),
                            const SizedBox(width: 2),
                            Text("Private", style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.6), fontSize: 11) : const TextStyle(color: textMuted, fontSize: 10)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _toggleJoin(com),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: doodle
                      ? BoxDecoration(
                          color: isJoined ? DoodleColors.blue.withValues(alpha: 0.1) : DoodleColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isJoined ? DoodleColors.blue.withValues(alpha: 0.5) : DoodleColors.orange.withValues(alpha: 0.5)),
                        )
                      : BoxDecoration(
                          color: isJoined ? const Color(0xFF00FF00).withValues(alpha: 0.1) : purplePrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isJoined ? const Color(0xFF00FF00).withValues(alpha: 0.25) : purplePrimary.withValues(alpha: 0.25)),
                        ),
                    child: Text(isJoined ? 'Joined' : 'Join', style: doodle ? DoodleFonts.body(color: isJoined ? DoodleColors.blue : DoodleColors.orange, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : TextStyle(color: isJoined ? const Color(0xFF00FF00) : purplePrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            doodle ? Container(height: 2, color: DoodleColors.brown.withValues(alpha: 0.1)) : Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          ],
        ),
      ),
    );
  }

  void _showCreate() {
    final doodle = isDoodleMode(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String cat = 'General';
    String icon = '💬';
    bool isPrivate = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Container(
        decoration: doodle
          ? BoxDecoration(color: DoodleColors.paper, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: DoodleColors.brown, width: 2))
          : BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: borderColor)),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, left: 20, right: 20, top: 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 22),
          Text('Create Community', style: doodle ? DoodleFonts.heading(color: DoodleColors.brown, fontSize: 24) : const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Start a new anonymous community', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 14) : const TextStyle(color: textMuted, fontSize: 12)),
          const SizedBox(height: 22),
          Container(
            decoration: doodle ? DoodleDecorations.input() : null,
            child: TextField(controller: nameCtrl, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 15) : const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(hintText: 'Community name...', hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 15) : const TextStyle(color: textMuted), filled: !doodle, fillColor: doodle ? Colors.transparent : cardColor,
                border: doodle ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderColor)),
                enabledBorder: doodle ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderColor)),
                focusedBorder: doodle ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: purplePrimary.withValues(alpha: 0.4))),
                contentPadding: doodle ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14) : null,
            )),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: doodle ? DoodleDecorations.input() : null,
            child: TextField(controller: descCtrl, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14) : const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2,
              decoration: InputDecoration(hintText: 'Description...', hintStyle: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.5), fontSize: 14) : const TextStyle(color: textMuted), filled: !doodle, fillColor: doodle ? Colors.transparent : cardColor,
                border: doodle ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderColor)),
                enabledBorder: doodle ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderColor)),
                focusedBorder: doodle ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: purplePrimary.withValues(alpha: 0.4))),
                contentPadding: doodle ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14) : null,
            )),
          ),
          const SizedBox(height: 16),
          Text('CATEGORY', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5) : const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: BolroomTheme.communityCategories.map((c) {
            final sel = cat == c['name'];
            return GestureDetector(
              onTap: () => setSheet(() { cat = c['name']!; icon = c['icon']!; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: doodle
                  ? BoxDecoration(
                      color: sel ? DoodleColors.cream : DoodleColors.paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: DoodleColors.brown, width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(color: DoodleColors.brown, offset: const Offset(2, 2))] : [],
                    )
                  : BoxDecoration(
                      color: sel ? purplePrimary.withValues(alpha: 0.12) : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? purplePrimary.withValues(alpha: 0.4) : borderColor),
                    ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c['icon']!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(c['name']!, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: sel ? FontWeight.bold : FontWeight.normal) : TextStyle(color: sel ? purplePrimary : textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
          Text('PRIVACY', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.8), fontSize: 12).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5) : const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setSheet(() => isPrivate = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: doodle
                      ? DoodleDecorations.card(color: !isPrivate ? DoodleColors.cream : DoodleColors.paper).copyWith(
                          border: Border.all(color: DoodleColors.brown, width: !isPrivate ? 2 : 1),
                        )
                      : BoxDecoration(
                          color: !isPrivate ? purplePrimary.withValues(alpha: 0.12) : cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: !isPrivate ? purplePrimary : borderColor),
                        ),
                    child: Column(
                      children: [
                        Icon(Icons.public, color: doodle ? (!isPrivate ? DoodleColors.blue : DoodleColors.brown) : (!isPrivate ? purplePrimary : textMuted), size: 20),
                        const SizedBox(height: 4),
                        Text('Public', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : TextStyle(color: !isPrivate ? Colors.white : textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Anyone can join', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 12) : TextStyle(color: !isPrivate ? Colors.white70 : textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setSheet(() => isPrivate = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: doodle
                      ? DoodleDecorations.card(color: isPrivate ? DoodleColors.orange.withValues(alpha: 0.3) : DoodleColors.paper).copyWith(
                          border: Border.all(color: DoodleColors.brown, width: isPrivate ? 2 : 1),
                        )
                      : BoxDecoration(
                          color: isPrivate ? purplePrimary.withValues(alpha: 0.12) : cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isPrivate ? purplePrimary : borderColor),
                        ),
                    child: Column(
                      children: [
                        Icon(Icons.lock, color: doodle ? (isPrivate ? DoodleColors.orange : DoodleColors.brown) : (isPrivate ? purplePrimary : textMuted), size: 20),
                        const SizedBox(height: 4),
                        Text('Private', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : TextStyle(color: isPrivate ? Colors.white : textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Requires approval', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 12) : TextStyle(color: isPrivate ? Colors.white70 : textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final locSvc = LocationService();
                final inserted = await _sb.from('bolroom_communities').insert({
                  'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim(),
                  'category': cat, 'icon': icon, 'creator_id': _myId,
                  'is_private': isPrivate, 'member_count': 1,
                  'district': locSvc.activeDistrict,
                  'state': locSvc.activeState,
                }).select().single();
                
                final newCid = inserted['id'].toString();
                await _sb.from('bolroom_community_members').insert({
                  'community_id': newCid,
                  'user_id': _myId,
                  'role': 'host',
                });
                _loadData();
                Navigator.pop(ctx);
              } catch (e) { debugPrint('Create community: $e'); }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: doodle ? DoodleColors.blue : purplePrimary, 
              foregroundColor: doodle ? DoodleColors.cream : Colors.white, 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(doodle ? 12 : 16),
                side: doodle ? const BorderSide(color: DoodleColors.brown, width: 2) : BorderSide.none,
              ), 
              elevation: 0
            ),
            child: Text('Create Community', style: doodle ? DoodleFonts.body(color: DoodleColors.cream, fontSize: 16).copyWith(fontWeight: FontWeight.bold) : const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          )),
        ]),
      )),
    );
  }

  String _getRelativeTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return "";
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) {
        return "now";
      } else if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m";
      } else if (diff.inHours < 24) {
        return "${diff.inHours}h";
      } else if (diff.inDays < 7) {
        return "${diff.inDays}d";
      } else {
        return "${dt.day}/${dt.month}";
      }
    } catch (_) {
      return "";
    }
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0); 
    path.lineTo(size.width, size.height * 0.25); 
    path.lineTo(size.width, size.height * 0.75); 
    path.lineTo(size.width * 0.5, size.height); 
    path.lineTo(0, size.height * 0.75); 
    path.lineTo(0, size.height * 0.25); 
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
