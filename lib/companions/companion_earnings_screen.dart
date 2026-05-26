// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Companion Earnings Dashboard — Section 6.2 of the spec.
class CompanionEarningsScreen extends StatefulWidget {
  const CompanionEarningsScreen({super.key});

  @override
  State<CompanionEarningsScreen> createState() => _CompanionEarningsScreenState();
}

class _CompanionEarningsScreenState extends State<CompanionEarningsScreen> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _transactions = [];

  double _totalEarned = 0;
  double _thisMonth = 0;
  double _pendingPayout = 0;
  double _availableToWithdraw = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _sb.auth.currentUser!.id;

      // Get companion profile
      final profile = await _sb.from('companion_profiles').select().eq('user_id', uid).maybeSingle();
      if (profile == null) { setState(() => _loading = false); return; }
      _profile = profile;

      // Get escrow transactions for this companion
      final companionId = profile['id'];
      final bookings = await _sb
          .from('companion_bookings')
          .select('id, total_charged, session_cost, platform_fee, scheduled_start_utc, duration_minutes, status')
          .eq('companion_id', companionId)
          .inFilter('status', ['COMPLETED', 'REVIEWED', 'ACTIVE'])
          .order('scheduled_start_utc', ascending: false);

      final txList = List<Map<String, dynamic>>.from(bookings);
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      double total = 0, month = 0, pending = 0, available = 0;
      for (final b in txList) {
        final sessionCost = (b['session_cost'] ?? 0).toDouble();
        final platformFee = (b['platform_fee'] ?? 0).toDouble();
        final net = sessionCost - platformFee;
        final start = DateTime.tryParse(b['scheduled_start_utc'] ?? '');
        final status = b['status'] ?? '';

        if (status == 'COMPLETED') {
          // Within 72h → pending escrow, after 72h → available
          if (start != null && DateTime.now().difference(start).inHours < 72) {
            pending += net;
          } else {
            available += net;
          }
        } else if (status == 'REVIEWED') {
          available += net;
          total += net;
          if (start != null && start.isAfter(monthStart)) month += net;
        }
      }

      setState(() {
        _transactions = txList;
        _totalEarned = total;
        _thisMonth = month;
        _pendingPayout = pending;
        _availableToWithdraw = available;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Earnings load error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF050508), body: Center(child: CircularProgressIndicator()));
    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050508),
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Earnings')),
        body: const Center(child: Text('No companion profile found.', style: TextStyle(color: Colors.white54))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFFF7E40),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Overview cards ──
            const Text('Earnings Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _earningsCard('Total Earned', '₹${_totalEarned.toStringAsFixed(0)}', Icons.account_balance_wallet, const Color(0xFFFF7E40)),
                _earningsCard('This Month', '₹${_thisMonth.toStringAsFixed(0)}', Icons.calendar_month, const Color(0xFF10B981)),
                _earningsCard('Pending Payout', '₹${_pendingPayout.toStringAsFixed(0)}', Icons.hourglass_bottom, Colors.amber),
                _earningsCard('Available', '₹${_availableToWithdraw.toStringAsFixed(0)}', Icons.check_circle_outline, Colors.blue),
              ],
            ),
            const SizedBox(height: 8),

            // ── Escrow note ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.lock_clock, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Pending payout is held in escrow for 72h after session. Auto-released if no dispute.', style: TextStyle(color: Colors.amber, fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Withdraw button ──
            ElevatedButton.icon(
              onPressed: _availableToWithdraw > 0 ? _showWithdrawSheet : null,
              icon: const Icon(Icons.arrow_upward),
              label: Text('Withdraw ₹${_availableToWithdraw.toStringAsFixed(0)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // ── Session history ──
            const Text('Session History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No sessions yet', style: TextStyle(color: Colors.white38)),
              ))
            else
              ..._transactions.map((b) => _sessionHistoryRow(b)),

            const SizedBox(height: 20),

            // ── Tax docs ──
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax document download coming soon'))),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Tax Documents'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white12),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }

  Widget _sessionHistoryRow(Map<String, dynamic> b) {
    final start = DateTime.tryParse(b['scheduled_start_utc'] ?? '')?.toLocal();
    final sessionCost = (b['session_cost'] ?? 0).toDouble();
    final platformFee = (b['platform_fee'] ?? 0).toDouble();
    final net = sessionCost - platformFee;
    final status = b['status'] ?? '';
    final duration = b['duration_minutes'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (start != null) Text(
            '${start.day}/${start.month}/${start.year}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text('$duration min · $status', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${net.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
          Text('-₹${platformFee.toStringAsFixed(0)} fee', style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ]),
      ]),
    );
  }

  void _showWithdrawSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Withdraw Earnings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Available: ₹${_availableToWithdraw.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16)),
          const SizedBox(height: 20),
          const Text('Minimum payout: ₹200 · Processing: 1-3 business days', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _withdrawOption(Icons.account_balance, 'Bank Account', 'UPI / NEFT transfer'),
          _withdrawOption(Icons.account_balance_wallet, 'UPI', 'Instant transfer'),
          _withdrawOption(Icons.wallet, 'Wallet', 'Add to in-app wallet'),
        ]),
      ),
    );
  }

  Widget _withdrawOption(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFF7E40).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFFFF7E40), size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title withdrawal coming soon')));
      },
    );
  }
}
