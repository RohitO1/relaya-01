// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'companion_service.dart';

/// Booking flow screen implementing Section 3 of the spec.
/// Handles both Virtual and Physical session booking.
class CompanionBookingScreen extends StatefulWidget {
  final Map<String, dynamic> companion;
  final String sessionType; // 'VIRTUAL' or 'PHYSICAL'

  const CompanionBookingScreen({super.key, required this.companion, required this.sessionType});

  @override
  State<CompanionBookingScreen> createState() => _CompanionBookingScreenState();
}

class _CompanionBookingScreenState extends State<CompanionBookingScreen> {
  int _step = 0; // 0=config, 1=price, 2=confirm
  bool _submitting = false;

  // Step 1: Session Config
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 60;
  final _noteCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(); // physical only

  // Availability data
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> _blackoutDates = [];
  bool _loadingAvailability = true;

  double get _ratePerHour => widget.sessionType == 'VIRTUAL'
      ? (widget.companion['virtual_rate_per_hour'] ?? 0).toDouble()
      : (widget.companion['physical_rate_per_hour'] ?? 0).toDouble();

  int get _minDuration => widget.sessionType == 'VIRTUAL'
      ? (widget.companion['virtual_min_duration_minutes'] ?? 30)
      : (widget.companion['physical_min_duration_minutes'] ?? 60);

  int get _maxDuration => widget.sessionType == 'VIRTUAL'
      ? (widget.companion['virtual_max_duration_minutes'] ?? 120)
      : 180;

  double get _sessionCost => (_selectedDuration / 60.0) * _ratePerHour;
  double get _platformFee => _sessionCost * 0.15;
  double get _totalCharged => _sessionCost + _platformFee;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      _availability = await CompanionService.getAvailability(widget.companion['id']);
      _blackoutDates = await CompanionService.getBlackoutDates(widget.companion['id']);
    } catch (e) {
      debugPrint('Error loading availability: $e');
    }
    if (mounted) setState(() => _loadingAvailability = false);
  }

  List<int> get _durationOptions {
    final options = <int>[];
    for (var d in [30, 60, 90, 120]) {
      if (d >= _minDuration && d <= _maxDuration) options.add(d);
    }
    if (options.isEmpty) options.add(_minDuration);
    return options;
  }

  bool _isDayAvailable(DateTime day) {
    final dow = day.weekday % 7; // Convert to 0=Sun format
    // Check blackout dates
    for (var b in _blackoutDates) {
      final bDate = DateTime.tryParse(b['date_utc'] ?? '');
      if (bDate != null && bDate.year == day.year && bDate.month == day.month && bDate.day == day.day) {
        return false;
      }
    }
    // Check weekly availability
    if (_availability.isEmpty) return true; // If no availability set, assume all days
    return _availability.any((a) => a['day_of_week'] == dow);
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) return;
    setState(() => _submitting = true);

    try {
      final startLocal = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );
      final startUtc = startLocal.toUtc(); // Section 4.1: store in UTC

      final bookingId = await CompanionService.createBooking(
        companionId: widget.companion['id'],
        sessionType: widget.sessionType,
        scheduledStartUtc: startUtc,
        durationMinutes: _selectedDuration,
        ratePerHour: _ratePerHour,
        bookerNote: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        meetLocation: widget.sessionType == 'PHYSICAL' ? _locationCtrl.text.trim() : null,
        idempotencyKey: 'bk_${DateTime.now().millisecondsSinceEpoch}', // EC-18
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking request sent! Waiting for confirmation.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, bookingId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          widget.sessionType == 'VIRTUAL' ? 'Book Virtual Session' : 'Book Physical Session',
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7E40)),
          ),
        ),
      ),
      body: _loadingAvailability
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _step,
              children: [_buildConfigStep(), _buildPriceStep(), _buildConfirmStep()],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back', style: TextStyle(color: Colors.white70)),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _submitting ? null : () {
                  if (_step == 0) {
                    if (_selectedDate == null || _selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select date and time')));
                      return;
                    }
                    setState(() => _step = 1);
                  } else if (_step == 1) {
                    setState(() => _step = 2);
                  } else {
                    _submit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7E40),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _step == 2 ? 'Confirm & Pay ₹${_totalCharged.toStringAsFixed(0)}' : 'Continue',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Session Configuration ──
  Widget _buildConfigStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Companion info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: (widget.companion['photos'] as List?)?.isNotEmpty == true
                    ? NetworkImage((widget.companion['photos'] as List).first)
                    : null,
                child: (widget.companion['photos'] as List?)?.isNotEmpty != true
                    ? const Icon(Icons.person, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.companion['display_name'] ?? 'Companion', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  Text('₹${_ratePerHour.toStringAsFixed(0)}/hr', style: const TextStyle(color: Color(0xFFFF7E40), fontSize: 14)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Date picker
        const Text('Select Date', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
              selectableDayPredicate: _isDayAvailable,
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF7E40))),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : 'Choose a date',
                  style: TextStyle(color: _selectedDate != null ? Colors.white : Colors.white38),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Time picker
        const Text('Select Time', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 10, minute: 0),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF7E40))),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedTime = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedTime != null ? _selectedTime!.format(context) : 'Choose a time',
                  style: TextStyle(color: _selectedTime != null ? Colors.white : Colors.white38),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Duration selector
        const Text('Duration', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _durationOptions.map((d) {
            final selected = _selectedDuration == d;
            return ChoiceChip(
              label: Text('${d}min'),
              selected: selected,
              onSelected: (_) => setState(() => _selectedDuration = d),
              selectedColor: const Color(0xFFFF7E40),
              backgroundColor: Colors.white10,
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Session note
        const Text('Note to Companion (optional)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          maxLength: 200,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'What would you like to do during this session?',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),

        // Physical: Meeting point
        if (widget.sessionType == 'PHYSICAL') ...[
          const SizedBox(height: 12),
          const Text('Preferred Meeting Area', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _locationCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Near Connaught Place, Delhi',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.location_on, color: Colors.white38),
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 2: Price Breakdown ──
  Widget _buildPriceStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Price Breakdown', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 24),
        _priceRow('Duration', '$_selectedDuration minutes'),
        _priceRow('Rate', '₹${_ratePerHour.toStringAsFixed(0)}/hr'),
        const Divider(color: Colors.white12, height: 32),
        _priceRow('Session Cost', '₹${_sessionCost.toStringAsFixed(0)}'),
        _priceRow('Platform Fee (15%)', '₹${_platformFee.toStringAsFixed(0)}'),
        const Divider(color: Colors.white24, height: 32),
        _priceRow('Total', '₹${_totalCharged.toStringAsFixed(0)}', bold: true),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.lock, color: Color(0xFF10B981), size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Payment held in escrow until session completes. 72-hour dispute window.', style: TextStyle(color: Color(0xFF10B981), fontSize: 12))),
          ]),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: bold ? const Color(0xFFFF7E40) : Colors.white, fontSize: bold ? 18 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // ── Step 3: Confirm ──
  Widget _buildConfirmStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Confirm Booking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 24),
        _confirmRow(Icons.person, 'Companion', widget.companion['display_name'] ?? ''),
        _confirmRow(Icons.calendar_today, 'Date', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
        _confirmRow(Icons.access_time, 'Time', _selectedTime?.format(context) ?? ''),
        _confirmRow(Icons.timer, 'Duration', '$_selectedDuration minutes'),
        _confirmRow(Icons.videocam, 'Type', widget.sessionType == 'VIRTUAL' ? 'Virtual Meet' : 'Physical Meet'),
        _confirmRow(Icons.payment, 'Total', '₹${_totalCharged.toStringAsFixed(0)}'),
        if (_noteCtrl.text.trim().isNotEmpty)
          _confirmRow(Icons.note, 'Note', _noteCtrl.text.trim()),
        if (widget.sessionType == 'PHYSICAL' && _locationCtrl.text.trim().isNotEmpty)
          _confirmRow(Icons.location_on, 'Meeting Area', _locationCtrl.text.trim()),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'By confirming, you agree to the cancellation policy. The companion has 24 hours to accept.',
            style: TextStyle(color: Colors.amber, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }
}
