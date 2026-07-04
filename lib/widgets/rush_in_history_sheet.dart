import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/doodle_theme.dart';
import '../rush_in_consumer_detail_view.dart';

void showRushInHistorySheet(BuildContext context, String uid) {
  final doodle = isDoodleMode(context);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: doodle
            ? DoodleDecorations.card(color: DoodleColors.cream, borderColor: DoodleColors.brown)
            : const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: doodle ? DoodleColors.brown.withValues(alpha: 0.3) : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Activity & History',
              style: doodle ? DoodleFonts.heading(fontSize: 20, color: DoodleColors.brown) : GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All rush-ins hosted and joined',
              style: doodle ? DoodleFonts.body(fontSize: 12, color: DoodleColors.brown.withValues(alpha: 0.7)) : GoogleFonts.inter(
                fontSize: 12, color: Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: () async {
                  // Fetch Hosted Rush-ins
                  final hostedRes = await Supabase.instance.client
                      .from('activities')
                      .select('*, profiles!activities_user_id_fkey(name, avatar_url)')
                      .eq('user_id', uid)
                      .eq('is_rush_in', true);
                  
                  // Fetch Joined Rush-ins
                  final reqsRes = await Supabase.instance.client
                      .from('requests')
                      .select('target_id')
                      .eq('sender_id', uid)
                      .eq('status', 'approved')
                      .inFilter('target_type', ['rush_in', 'activity']);
                      
                  final targetIds = (reqsRes as List).map((r) => r['target_id'].toString()).toList();
                  List<dynamic> joinedRes = [];
                  if (targetIds.isNotEmpty) {
                    final acts = await Supabase.instance.client
                        .from('activities')
                        .select('*, profiles!activities_user_id_fkey(name, avatar_url)')
                        .inFilter('id', targetIds)
                        .eq('is_rush_in', true);
                    joinedRes = acts as List;
                  }

                  // Fetch members count for all these rush-ins
                  final allIds = [...(hostedRes as List).map((e) => e['id'].toString()), ...targetIds];
                  final Map<String, int> membersCount = {};
                  if (allIds.isNotEmpty) {
                    final allReqs = await Supabase.instance.client
                        .from('requests')
                        .select('target_id, status')
                        .inFilter('target_id', allIds)
                        .eq('status', 'approved');
                    for (var r in (allReqs as List)) {
                      final tId = r['target_id'].toString();
                      membersCount[tId] = (membersCount[tId] ?? 0) + 1; // including host if they're not in the table doesn't matter, we just count approved requests.
                    }
                  }

                  List<Map<String, dynamic>> combined = [];
                  for (final r in hostedRes) {
                    final m = Map<String, dynamic>.from(r);
                    m['relation'] = 'hosted';
                    m['members_count'] = (membersCount[m['id'].toString()] ?? 0) + 1; // +1 for host
                    combined.add(m);
                  }
                  for (final r in joinedRes) {
                    final m = Map<String, dynamic>.from(r);
                    if (!combined.any((x) => x['id'] == m['id'])) {
                      m['relation'] = 'joined';
                      m['members_count'] = (membersCount[m['id'].toString()] ?? 0) + 1; // +1 for host
                      combined.add(m);
                    }
                  }
                  
                  combined.sort((a, b) {
                    final dtA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final dtB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return dtB.compareTo(dtA);
                  });
                  
                  return combined;
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: doodle ? DoodleColors.brown.withValues(alpha: 0.4) : Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              'No activity found',
                              style: doodle ? DoodleFonts.body(fontSize: 14, color: DoodleColors.brown) : GoogleFonts.inter(fontSize: 14, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  final now = DateTime.now();
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final act = list[i];
                      final isHosted = act['relation'] == 'hosted';
                      
                      // Status logic
                      final actStr = act['activity_time'] as String? ?? act['created_at'] as String?;
                      final expStr = act['expires_at'] as String?;
                      final start = actStr != null ? DateTime.tryParse(actStr)?.toLocal() : null;
                      final end = expStr != null ? DateTime.tryParse(expStr)?.toLocal() : start?.add(Duration(hours: act['duration_hours'] as int? ?? 6));
                      
                      String statusLabel = 'UNKNOWN';
                      Color sColor = Colors.white38;
                      if (start != null && end != null) {
                        if (now.isBefore(start)) {
                          statusLabel = 'UPCOMING';
                          sColor = const Color(0xFF22C55E); // green
                        } else if (now.isBefore(end)) {
                          statusLabel = 'STARTED';
                          sColor = const Color(0xFFEF4444); // red
                        } else {
                          statusLabel = 'ENDED';
                          sColor = Colors.white38;
                        }
                      }

                      final title = act['title']?.toString() ?? 'Untitled';
                      final membersCount = act['members_count'] ?? 0;
                      
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (context.mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => RushInConsumerDetailView(activity: act, onInteraction: () {})));
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: doodle
                              ? DoodleDecorations.card(color: DoodleColors.paper, borderColor: DoodleColors.cardBorder, radius: 14)
                              : BoxDecoration(
                                  color: const Color(0xFF16161D),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isHosted 
                                      ? const Color(0xFFFF6B00).withValues(alpha: 0.1) 
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isHosted ? Icons.campaign : Icons.group,
                                  color: isHosted ? const Color(0xFFFF6B00) : const Color(0xFF3B82F6),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: doodle ? DoodleFonts.body(fontSize: 15, color: DoodleColors.textPrimary) : GoogleFonts.inter(
                                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          isHosted ? 'Hosted' : 'Joined',
                                          style: doodle ? DoodleFonts.body(fontSize: 12, color: DoodleColors.brown.withValues(alpha: 0.8)) : GoogleFonts.inter(
                                            fontSize: 12, color: Colors.white54,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Icon(Icons.people, size: 12, color: doodle ? DoodleColors.brown.withValues(alpha: 0.6) : Colors.white54),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$membersCount Members',
                                          style: doodle ? DoodleFonts.body(fontSize: 12, color: DoodleColors.brown.withValues(alpha: 0.8)) : GoogleFonts.inter(
                                            fontSize: 12, color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: sColor.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: sColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
