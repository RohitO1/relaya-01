// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'companion_service.dart';
import 'companion_review_screen.dart';
import 'companion_video_room_screen.dart';

/// My Sessions screen — shows both booker and companion bookings.
/// Implements Section 3.3 state machine display + Section 4.2 countdown.
class CompanionMySessionsScreen extends StatefulWidget {
  const CompanionMySessionsScreen({super.key});

  @override
  State<CompanionMySessionsScreen> createState() => _CompanionMySessionsScreenState();
}

class _CompanionMySessionsScreenState extends State<CompanionMySessionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _bookerSessions = [];
  List<Map<String, dynamic>> _companionSessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _bookerSessions = await CompanionService.getMyBookingsAsBooker();
      _companionSessions = await CompanionService.getMyBookingsAsCompanion();
    } catch (e) {
      debugPrint('Load sessions error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050508),
        title: const Text('My Sessions', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFFF7E40),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'As Booker'),
            Tab(text: 'As Companion'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildSessionList(_bookerSessions, isCompanion: false),
                _buildSessionList(_companionSessions, isCompanion: true),
              ],
            ),
    );
  }

  Widget _buildSessionList(List<Map<String, dynamic>> sessions, {required bool isCompanion}) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.calendar_today_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            isCompanion ? 'No sessions as companion yet' : 'No bookings yet',
            style: const TextStyle(color: Colors.white38),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFF7E40),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (_, i) => _SessionCard(
          booking: sessions[i],
          isCompanion: isCompanion,
          onRefresh: _load,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isCompanion;
  final VoidCallback onRefresh;

  const _SessionCard({
    required this.booking,
    required this.isCompanion,
    required this.onRefresh,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED': return const Color(0xFF10B981);
      case 'ACTIVE': return Colors.green;
      case 'PENDING_CONFIRMATION': return Colors.amber;
      case 'COMPLETED': return Colors.blue;
      case 'REVIEWED': return const Color(0xFFFF7E40);
      case 'CANCELLED_BY_BOOKER':
      case 'CANCELLED_BY_COMPANION': return Colors.red;
      case 'DISPUTED': return Colors.orange;
      case 'NO_SHOW_BOOKER':
      case 'NO_SHOW_COMPANION': return Colors.deepOrange;
      default: return Colors.white38;
    }
  }

  String _statusLabel(String status) {
    return status.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] ?? 'UNKNOWN';
    final startUtc = DateTime.tryParse(booking['scheduled_start_utc'] ?? '');
    final startLocal = startUtc?.toLocal();
    final sessionType = booking['session_type'] ?? 'VIRTUAL';
    final duration = booking['duration_minutes'] ?? 0;
    final total = (booking['total_charged'] ?? 0).toDouble();

    // Countdown: show if CONFIRMED and within 24h
    final showCountdown = status == 'CONFIRMED' && startLocal != null &&
        startLocal.difference(DateTime.now()).inHours <= 24 &&
        startLocal.isAfter(DateTime.now());

    // Companion action buttons for PENDING_CONFIRMATION
    final needsResponse = isCompanion && status == 'PENDING_CONFIRMATION';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'ACTIVE' ? Colors.green.withValues(alpha: 0.4) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                  sessionType == 'VIRTUAL' ? Icons.videocam : Icons.people,
                  color: sessionType == 'VIRTUAL' ? const Color(0xFFFF7E40) : const Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  sessionType == 'VIRTUAL' ? 'Virtual Meet' : 'Physical Meet',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              if (startLocal != null)
                Text(
                  '${_dayName(startLocal.weekday)}, ${startLocal.day}/${startLocal.month}/${startLocal.year} · ${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              const SizedBox(height: 4),
              Row(children: [
                Text('$duration min', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 12),
                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),

              // ── Countdown (Section 4.2 — T-24h card pulse) ──
              if (showCountdown) ...[
                const SizedBox(height: 10),
                _CountdownWidget(targetTime: startLocal),
              ],

              // ── Active: pulsing join button ──
              if (status == 'ACTIVE') ...[
                const SizedBox(height: 10),
                _JoinButton(booking: booking, isCompanion: isCompanion),
              ],
            ]),
          ),

          // ── Companion action bar (accept/decline) ──
          if (needsResponse)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(children: [
                Expanded(child: TextButton.icon(
                  onPressed: () => _respondToBooking(context, 'DECLINE'),
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: const Text('Decline', style: TextStyle(color: Colors.red)),
                )),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(child: TextButton.icon(
                  onPressed: () => _respondToBooking(context, 'ACCEPT'),
                  icon: const Icon(Icons.check, color: Color(0xFF10B981), size: 18),
                  label: const Text('Accept', style: TextStyle(color: Color(0xFF10B981))),
                )),
              ]),
            ),

          // ── Cancel button (booker, non-terminal states) ──
          if (!isCompanion && (status == 'PENDING_CONFIRMATION' || status == 'CONFIRMED'))
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
              child: TextButton.icon(
                onPressed: () => _cancelByBooker(context),
                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                label: const Text('Cancel Booking', style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ),

          // ── Review button (COMPLETED, no review yet) ──
          if (status == 'COMPLETED')
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CompanionReviewScreen(booking: booking, isCompanion: isCompanion)),
                ).then((_) => onRefresh()),
                icon: const Icon(Icons.star_outline, color: Color(0xFFFF7E40), size: 16),
                label: const Text('Leave Review', style: TextStyle(color: Color(0xFFFF7E40), fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _respondToBooking(BuildContext context, String action) async {
    try {
      await CompanionService.respondToBooking(booking['id'], action);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(action == 'ACCEPT' ? 'Booking confirmed!' : 'Booking declined.'),
        backgroundColor: action == 'ACCEPT' ? Colors.green : Colors.red,
      ));
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _cancelByBooker(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cancel Booking?', style: TextStyle(color: Colors.white)),
        content: const Text('This will cancel your booking. Refund amount depends on timing.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cancel')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final refund = await CompanionService.cancelByBooker(booking['id']);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cancelled. Refund: ₹${refund.toStringAsFixed(0)}'),
            backgroundColor: Colors.orange,
          ));
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _dayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}

/// Live countdown widget for upcoming sessions.
class _CountdownWidget extends StatefulWidget {
  final DateTime targetTime;
  const _CountdownWidget({required this.targetTime});

  @override
  State<_CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<_CountdownWidget> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _tick();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      _tick();
      return mounted;
    });
  }

  void _tick() {
    setState(() => _remaining = widget.targetTime.difference(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer, color: Colors.amber, size: 14),
        const SizedBox(width: 6),
        Text(
          'Starts in ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ]),
    );
  }
}

/// Join button — navigates to video room screen.
class _JoinButton extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isCompanion;
  const _JoinButton({required this.booking, required this.isCompanion});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _joinRoom(context),
        icon: const Icon(Icons.videocam, size: 18),
        label: const Text('Join Session', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Future<void> _joinRoom(BuildContext context) async {
    try {
      final videoRoom = await CompanionService.getVideoRoom(booking['id']);
      if (videoRoom == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video room not ready yet')));
        return;
      }
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CompanionVideoRoomScreen(
            booking: booking,
            videoRoom: videoRoom,
            isCompanion: isCompanion,
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
