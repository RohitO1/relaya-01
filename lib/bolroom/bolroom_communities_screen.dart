// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bolroom_theme.dart';
import 'bolroom_community_detail_screen.dart';

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
  List<String> categories = ["All", "Gaming", "Tech", "Music", "Art", "Memes"];

  static const Color bgColor = Color(0xFF090710);
  static const Color cardColor = Color(0xFF13101E);
  static const Color borderColor = Color(0xFF231D38);
  static const Color purplePrimary = Color(0xFFB983FF);
  static const Color purpleDark = Color(0xFF7B2CBF);
  static const Color textMuted = Color(0xFF8E8B99);

  static LinearGradient neonGradient = const LinearGradient(
    colors: [Color(0xFFD433FF), Color(0xFF7B2CBF), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final comms = await _sb.from('bolroom_communities').select('*').order('member_count', ascending: false).limit(100);
      List<dynamic> joined = [];
      if (_myId.isNotEmpty && _myId != 'null' && _myId.contains('-')) {
        final res = await _sb.from('bolroom_community_members').select('community_id').eq('user_id', _myId);
        joined = res as List<dynamic>;
      }
      if (mounted) {
        setState(() {
          _communities = List<Map<String, dynamic>>.from(comms);
          _joinedIds = joined.map((e) => e['community_id'].toString()).toSet();
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
    List<Map<String, dynamic>> filtered = _communities.where((c) {
      bool matchesSearch = (c['name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesCat = selectedCategory == 0 || c['category'] == categories[selectedCategory];
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: purplePrimary, strokeWidth: 2))
            : Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader("Communities", Icons.add_circle_outline),
                      _buildSearchBar("Discover communities...", (val) {
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
                                decoration: BoxDecoration(
                                  color: isSelected ? purpleDark.withValues(alpha: 0.3) : cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? purplePrimary : borderColor,
                                  ),
                                ),
                                child: Text(
                                  categories[index],
                                  style: TextStyle(
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

                      // Trending Section (Only show if no search/filter)
                      if (searchQuery.isEmpty && selectedCategory == 0 && _communities.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 20, top: 10, bottom: 10),
                          child: Text("Trending Hubs", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 20),
                          child: Row(
                            children: _communities.take(3).map((c) => _buildTrendingCard(c)).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // List of Communities
                      Expanded(
                        child: filtered.isEmpty 
                          ? Center(child: Text("No communities found", style: TextStyle(color: textMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildCommunityTile(filtered[index]);
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

  Widget _buildHeader(String title, IconData actionIcon) {
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
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showCreate,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(color: purplePrimary.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)
                ]
              ),
              child: Icon(actionIcon, color: purplePrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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

  Widget _buildTrendingCard(Map<String, dynamic> c) {
    final bannerHex = c['banner_color'] ?? '#7856FF';
    Color bannerColor = purplePrimary;
    try { bannerColor = Color(int.parse('FF${bannerHex.toString().replaceFirst('#', '')}', radix: 16)); } catch (_) {}
    
    final bool isJoined = _joinedIds.contains(c['id'].toString());

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(c['icon'] ?? '💬', style: const TextStyle(fontSize: 20)),
              ),
              GestureDetector(
                onTap: () => _toggleJoin(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: isJoined ? null : neonGradient,
                    color: isJoined ? bgColor : null,
                    border: isJoined ? Border.all(color: borderColor) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(isJoined ? "Joined" : "Join", style: TextStyle(color: isJoined ? textMuted : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(c['name'] ?? 'Hub', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text("${c['member_count'] ?? 0} Members", style: const TextStyle(color: textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCommunityTile(Map<String, dynamic> com) {
    final cid = com['id'].toString();
    final bool isJoined = _joinedIds.contains(cid);
    
    final bannerHex = com['banner_color'] ?? '#7856FF';
    Color bannerColor = purplePrimary;
    try { bannerColor = Color(int.parse('FF${bannerHex.toString().replaceFirst('#', '')}', radix: 16)); } catch (_) {}

    return GestureDetector(
      onTap: () {
        if (isJoined) Navigator.push(context, BolroomTheme.slideRoute(BolroomCommunityDetailScreen(community: com)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Hexagon Community Icon
            SizedBox(
              width: 60,
              height: 65,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipPath(
                    clipper: HexagonClipper(),
                    child: Container(color: bannerColor),
                  ),
                  ClipPath(
                    clipper: HexagonClipper(),
                    child: Container(
                      width: 56,
                      height: 61,
                      color: bgColor,
                      child: Center(child: Text(com['icon'] ?? '💬', style: const TextStyle(fontSize: 20))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(com['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(com['description'] ?? 'No description.', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.people, color: purplePrimary, size: 14),
                      const SizedBox(width: 4),
                      Text("${com['member_count'] ?? 0}", style: const TextStyle(color: purplePrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  )
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _toggleJoin(com),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isJoined ? const Color(0xFF00FF00).withValues(alpha: 0.1) : purplePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isJoined ? const Color(0xFF00FF00).withValues(alpha: 0.25) : purplePrimary.withValues(alpha: 0.25)),
                ),
                child: Text(isJoined ? 'Joined' : 'Join', style: TextStyle(color: isJoined ? const Color(0xFF00FF00) : purplePrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreate() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String cat = 'General';
    String icon = '💬';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Container(
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: borderColor)),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, left: 20, right: 20, top: 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 22),
          Text('Create Community', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('Start a new anonymous community', style: TextStyle(color: textMuted, fontSize: 12)),
          SizedBox(height: 22),
          TextField(controller: nameCtrl, style: TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(hintText: 'Community name...', hintStyle: TextStyle(color: textMuted), filled: true, fillColor: cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: purplePrimary.withValues(alpha: 0.4))))),
          SizedBox(height: 12),
          TextField(controller: descCtrl, style: TextStyle(color: Colors.white, fontSize: 14), maxLines: 2,
            decoration: InputDecoration(hintText: 'Description...', hintStyle: TextStyle(color: textMuted), filled: true, fillColor: cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: purplePrimary.withValues(alpha: 0.4))))),
          SizedBox(height: 16),
          Text('CATEGORY', style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: BolroomTheme.communityCategories.map((c) {
            final sel = cat == c['name'];
            return GestureDetector(
              onTap: () => setSheet(() { cat = c['name']!; icon = c['icon']!; }),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? purplePrimary.withValues(alpha: 0.12) : cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? purplePrimary.withValues(alpha: 0.4) : borderColor),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c['icon']!, style: TextStyle(fontSize: 14)),
                  SizedBox(width: 5),
                  Text(c['name']!, style: TextStyle(color: sel ? purplePrimary : textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }).toList()),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await _sb.from('bolroom_communities').insert({
                  'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim(),
                  'category': cat, 'icon': icon, 'creator_id': _myId,
                });
                _loadData();
                Navigator.pop(ctx);
              } catch (e) { debugPrint('Create community: $e'); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: purplePrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: Text('Create Community', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          )),
        ]),
      )),
    );
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
