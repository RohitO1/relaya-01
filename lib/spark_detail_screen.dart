import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'spark_screen.dart';


class SparkDetailScreen extends StatefulWidget {
  final SparkItem item;
  final Function(SparkItem) onJoin;
  final Function(SparkItem) onHide;

  const SparkDetailScreen({
    super.key,
    required this.item,
    required this.onJoin,
    required this.onHide,
  });

  @override
  State<SparkDetailScreen> createState() => _SparkDetailScreenState();
}

class _SparkDetailScreenState extends State<SparkDetailScreen> {
  bool _isBookmarked = false;
  late bool _hasRequested;
  late bool _isApproved;
  List<Map<String, dynamic>> _attendees = [];
  List<Map<String, dynamic>> _waitlist = [];
  bool _loadingParticipants = false;

  @override
  void initState() {
    super.initState();
    _hasRequested = widget.item.hasRequested;
    _isApproved = widget.item.isApproved;
    _fetchParticipants();
  }

  Widget _buildBannerImageWidget(String url) {
    if (url.startsWith('data:')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackBanner(),
        );
      } catch (_) {
        return _buildFallbackBanner();
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackBanner(),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  String _cleanDescription(String desc) {
    return desc.replaceAll(RegExp(r'\n?\[[a-zA-Z0-9_]+:.*?\]'), '').trim();
  }

  String _getEventImageUrl() {
    if (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty) {
      return widget.item.imageUrl!;
    }
    final desc = widget.item.desc;
    if (desc.contains('[image_url:')) {
      final startIndex = desc.indexOf('[image_url:') + '[image_url:'.length;
      final endIndex = desc.indexOf(']', startIndex);
      if (endIndex != -1) {
        return desc.substring(startIndex, endIndex);
      }
    }
    final t = widget.item.title.toLowerCase();
    final d = widget.item.desc.toLowerCase();
    if (t.contains('music') || t.contains('session') || t.contains('party') || t.contains('underground')) {
      return 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&auto=format&fit=crop';
    } else if (t.contains('coffee') || t.contains('cafe') || d.contains('coffee')) {
      return 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&auto=format&fit=crop';
    } else if (t.contains('basketball') || t.contains('sport') || t.contains('gym') || t.contains('run')) {
      return 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=800&auto=format&fit=crop';
    } else if (t.contains('outdoor') || t.contains('hike') || t.contains('nature') || t.contains('camp')) {
      return 'https://images.unsplash.com/photo-1533240332313-0db49b439ad3?w=800&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop';
  }

  Future<void> _fetchParticipants() async {
    if (!mounted) return;
    setState(() => _loadingParticipants = true);
    try {
      final sb = Supabase.instance.client;
      final reqs = await sb.from('requests')
          .select('id, sender_id, status')
          .eq('target_id', widget.item.id);
      
      final List<String> senderIds = [];
      final Map<String, String> requestIds = {};
      final Map<String, String> requestStatuses = {};

      for (final r in reqs as List) {
        final senderId = r['sender_id']?.toString();
        if (senderId != null) {
          senderIds.add(senderId);
          requestIds[senderId] = r['id'].toString();
          requestStatuses[senderId] = r['status']?.toString() ?? 'pending';
        }
      }

      if (senderIds.isEmpty) {
        if (mounted) {
          setState(() {
            _attendees = [];
            _waitlist = [];
            _loadingParticipants = false;
          });
        }
        return;
      }

      final profiles = await sb.from('profiles')
          .select('id, name, full_name, avatar_url')
          .inFilter('id', senderIds);
      
      final List<Map<String, dynamic>> tempAttendees = [];
      final List<Map<String, dynamic>> tempWaitlist = [];

      for (final p in profiles as List) {
        final uid = p['id'].toString();
        final status = requestStatuses[uid];
        final name = p['full_name']?.toString() ?? p['name']?.toString() ?? 'Unknown User';
        final avatar = p['avatar_url']?.toString() ?? '';
        final requestId = requestIds[uid] ?? '';

        final userMap = {
          'id': uid,
          'requestId': requestId,
          'name': name,
          'avatar': avatar,
          'status': status,
        };

        if (status == 'approved') {
          tempAttendees.add(userMap);
        } else if (status == 'pending') {
          tempWaitlist.add(userMap);
        }
      }

      if (mounted) {
        setState(() {
          _attendees = tempAttendees;
          _waitlist = tempWaitlist;
          _loadingParticipants = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching participants: $e');
      if (mounted) {
        setState(() => _loadingParticipants = false);
      }
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      final sb = Supabase.instance.client;
      await sb.from('requests').update({'status': status}).eq('id', requestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request approved successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      
      _fetchParticipants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update request: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeAttendee(String requestId) async {
    try {
      final sb = Supabase.instance.client;
      await sb.from('requests').delete().eq('id', requestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendee removed.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
      
      _fetchParticipants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove attendee: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showParticipantsSheet() {
    final accentColor = widget.item.type == 'rush' ? const Color(0xFFFF6B00) : const Color(0xFFFF3D00);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isUserHost = currentUserId != null && widget.item.hostId == currentUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0C0E14),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Manage Participants', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const CircleAvatar(radius: 14, backgroundColor: Colors.white10, child: Icon(Icons.close, color: Colors.white, size: 16)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DefaultTabController(
                    length: 2,
                    child: Expanded(
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white38,
                            indicatorColor: accentColor,
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabs: [
                              Tab(text: 'APPROVED (${_attendees.length})'),
                              Tab(text: 'WAITLIST (${_waitlist.length})'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _attendees.isEmpty
                                    ? _emptyModalState('No approved attendees yet.', Icons.people_outline)
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: _attendees.length,
                                        itemBuilder: (context, index) {
                                          final user = _attendees[index];
                                          return _buildParticipantTile(user, isUserHost, true, setModalState);
                                        },
                                      ),
                                _waitlist.isEmpty
                                    ? _emptyModalState('No waitlisted candidates.', Icons.hourglass_empty)
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: _waitlist.length,
                                        itemBuilder: (context, index) {
                                          final user = _waitlist[index];
                                          return _buildParticipantTile(user, isUserHost, false, setModalState);
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyModalState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white12, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> user, bool isHost, bool isApprovedTab, StateSetter setModalState) {
    final accentColor = widget.item.type == 'rush' ? const Color(0xFFFF6B00) : const Color(0xFFFF3D00);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: user['avatar'].toString().isNotEmpty
                  ? Image.network(user['avatar'], fit: BoxFit.cover)
                  : Container(
                      color: accentColor.withValues(alpha: 0.2),
                      alignment: Alignment.center,
                      child: Text(
                        user['name'].isNotEmpty ? user['name'][0].toUpperCase() : '?',
                        style: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isApprovedTab ? 'Approved attendee' : 'Waitlisted candidate',
                  style: GoogleFonts.inter(color: isApprovedTab ? const Color(0xFF10B981) : const Color(0xFFFF9F0A), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (isHost) ...[
            if (isApprovedTab)
              GestureDetector(
                onTap: () async {
                  await _removeAttendee(user['requestId']);
                  setModalState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Text('Remove', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              )
            else ...[
              GestureDetector(
                onTap: () async {
                  await _updateRequestStatus(user['requestId'], 'approved');
                  setModalState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Color(0xFF10B981), size: 12),
                      const SizedBox(width: 4),
                      Text('Accept', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await _updateRequestStatus(user['requestId'], 'rejected');
                  setModalState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.close, color: Color(0xFFEF4444), size: 12),
                      const SizedBox(width: 4),
                      Text('Decline', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ],
      ),
    );
  }

  String _getCategoryLabel() {
    final t = widget.item.title.toLowerCase();
    if (t.contains('music') || t.contains('session') || t.contains('dj')) return 'MUSIC';
    if (t.contains('sport') || t.contains('basketball') || t.contains('gym')) return 'SPORTS';
    if (t.contains('coffee') || t.contains('cafe') || t.contains('food')) return 'FOOD & DRINKS';
    if (t.contains('hike') || t.contains('outdoor') || t.contains('camp')) return 'OUTDOOR';
    if (t.contains('study') || t.contains('code') || t.contains('work')) return 'STUDY';
    if (widget.item.type == 'rush') return 'RUSH-IN';
    return 'ACTIVITY';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isRush = item.type == 'rush';
    final accentColor = isRush ? const Color(0xFFFF6B00) : const Color(0xFFFF3D00);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // ANONYMOUS LOGIC: Hide identity if anonymous AND not yet approved
    final bool shouldHideIdentity = item.isAnonymous && !_isApproved;
    final String displayHostName = shouldHideIdentity ? 'Anonymous Host' : item.host;
    final bool isUserHost = currentUserId != null && item.host == currentUserId;

    // LOCATION LOGIC: Hidden for rush-ins & anonymous until approved
    final bool isLocationHidden = (item.isAnonymous || isRush) && !_isApproved && !isUserHost;
    final String displayLocation = isLocationHidden
        ? 'Location Hidden (Join to reveal)'
        : (item.location ?? 'TBD');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Top bar with animated banner
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF000000), // Solid black when collapsed
            elevation: 0,
            pinned: true,
            stretch: true,
            expandedHeight: 380,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBannerImageWidget(_getEventImageUrl()),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent, Color(0xFF000000)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            titleSpacing: 0,
            title: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    Text('Event Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(children: [
                      _circleBtn(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        () => setState(() => _isBookmarked = !_isBookmarked),
                        iconColor: _isBookmarked ? accentColor : Colors.white,
                      ),
                      const SizedBox(width: 10),
                      _circleBtn(Icons.share_outlined, () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied!'), backgroundColor: Colors.blueGrey),
                        );
                      }),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
                SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFF000000),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3D5A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFF3D5A).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFF3D5A), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(
                                isRush ? 'Rush-in • ${item.timer ?? "2h left"}' : 'Activity • Public',
                                style: GoogleFonts.inter(color: const Color(0xFFFF3D5A), fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Category
                        Text(_getCategoryLabel(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF4E8BFF), letterSpacing: 1.5)),
                        const SizedBox(height: 6),

                        // Title
                        Text(item.title.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 20),

                        // Meta rows
                        _buildMetaRow(Icons.calendar_today_outlined, isRush ? 'Ends in ${item.timer ?? "2h left"}' : '${item.date ?? "Today"} at ${item.time ?? "18:00"}'),
                        _buildMetaRow(Icons.location_on_outlined, displayLocation, isAccent: isLocationHidden),
                        _buildMetaRow(Icons.people_outline, '${item.slots} people going'),

                        // Radius for rush-ins
                        if (isRush && item.radius != null)
                          _buildMetaRow(Icons.sensors, '${item.radius} radius'),
                        const SizedBox(height: 8),

                        // Tags
                        if (item.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: item.tags.map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(t, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            )).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Host Card
                        GestureDetector(
                          onTap: shouldHideIdentity ? null : () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing ${item.host}\'s profile'), backgroundColor: accentColor));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0E14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(children: [
                              // Avatar
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: shouldHideIdentity ? const LinearGradient(colors: [Color(0xFF3A3D46), Color(0xFF1E2024)]) : null,
                                  color: !shouldHideIdentity ? const Color(0xFFFF6B00).withValues(alpha: 0.15) : null,
                                ),
                                alignment: Alignment.center,
                                child: shouldHideIdentity
                                    ? const Icon(Icons.theater_comedy, color: Colors.white70, size: 20)
                                    : (item.hostAvatar != null && item.hostAvatar!.startsWith('http')
                                        ? ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.network(item.hostAvatar!, fit: BoxFit.cover, width: 44, height: 44))
                                        : Text(item.host.isNotEmpty ? item.host[0].toUpperCase() : '?', style: GoogleFonts.inter(color: const Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 18))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Hosted by', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(displayHostName, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              ])),
                              if (!shouldHideIdentity) const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Attendees
                        GestureDetector(
                          onTap: _showParticipantsSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Attendees', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    if (_loadingParticipants)
                                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                                    else
                                      Text('View List', style: GoogleFonts.inter(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(children: [
                                  if (shouldHideIdentity) ...[
                                    ...List.generate(
                                      3,
                                      (i) => Align(
                                        widthFactor: 0.7,
                                        child: Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF000000), width: 2.5),
                                            gradient: const LinearGradient(colors: [Color(0xFF333333), Color(0xFF222222)]),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.theater_comedy, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C1C24),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: Text('+??', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ] else if (_attendees.isEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.02),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Text(
                                        'No approved attendees yet.',
                                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                                      ),
                                    ),
                                  ] else ...[
                                    ..._attendees.take(5).map(
                                      (member) => Align(
                                        widthFactor: 0.7,
                                        child: Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF000000), width: 2.5),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(18),
                                            child: member['avatar'] != null && member['avatar'].toString().isNotEmpty
                                                ? Image.network(member['avatar'], fit: BoxFit.cover)
                                                : Container(
                                                    color: accentColor.withValues(alpha: 0.2),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      member['name'].isNotEmpty ? member['name'][0].toUpperCase() : '?',
                                                      style: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_attendees.length > 5) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1C1C24),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                        ),
                                        child: Text('+${_attendees.length - 5}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(width: 8),
                                  if (!shouldHideIdentity && _waitlist.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF3D5A).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFF3D5A).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${_waitlist.length} Pending',
                                        style: GoogleFonts.inter(color: const Color(0xFFFF3D5A), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // About
                        Text('About', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                         Text(
                          _cleanDescription(item.desc).isNotEmpty ? _cleanDescription(item.desc) : 'Join us for an unforgettable experience! This event brings together like-minded people for an evening of great vibes, meaningful connections, and memorable moments.',
                          style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 14, height: 1.6),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // ── Sticky Join Button ──
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: GestureDetector(
              onTap: (_hasRequested || _isApproved) ? null : () {
                widget.onJoin(item);
                setState(() => _hasRequested = true);
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: (_isApproved || _hasRequested) ? null : const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8A00)]),
                  color: _isApproved ? const Color(0xFF10B981) : (_hasRequested ? Colors.white.withValues(alpha: 0.1) : null),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    if (!_hasRequested && !_isApproved) BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _isApproved ? 'Joined ✓' : (_hasRequested ? 'Requested' : 'Join Event'),
                  style: GoogleFonts.inter(color: _hasRequested && !_isApproved ? Colors.white30 : Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 16),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text, {bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: isAccent ? const Color(0xFFFF5C00) : const Color(0xFF9E9E9E), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.inter(color: isAccent ? const Color(0xFFFF5C00) : Colors.white, fontSize: 14, fontWeight: isAccent ? FontWeight.bold : FontWeight.w500))),
      ]),
    );
  }
}
