// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'companion_service.dart';

/// Review screen — Section 9 of the spec.
/// Blind review: neither party sees the other's review until both submit.
class CompanionReviewScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool isCompanion;

  const CompanionReviewScreen({super.key, required this.booking, required this.isCompanion});

  @override
  State<CompanionReviewScreen> createState() => _CompanionReviewScreenState();
}

class _CompanionReviewScreenState extends State<CompanionReviewScreen> {
  int _rating = 0;
  String? _punctuality; // 'Yes' | 'No' | 'Late but notified'
  String? _wouldBookAgain; // 'Yes' | 'Maybe' | 'No'
  final _reviewCtrl = TextEditingController();
  final _privateCtrl = TextEditingController();
  bool _submitting = false;

  bool get _isBooker => !widget.isCompanion;
  int get _maxReviewChars => _isBooker ? 500 : 200;

  @override
  Widget build(BuildContext context) {
    final otherName = _isBooker
        ? (widget.booking['companion_name'] ?? 'Companion')
        : (widget.booking['booker_name'] ?? 'Booker');

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Review ${_isBooker ? "Companion" : "Booker"}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFFF7E40).withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Color(0xFFFF7E40), size: 30),
              ),
              const SizedBox(height: 8),
              Text('How was your session with $otherName?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Reviews are blind — neither party sees the other\'s review until both submit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 24),

          // Star rating (required)
          const Text('Overall Rating *', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 40,
                ),
              ),
            )),
          ),
          const SizedBox(height: 24),

          // Punctuality (for booker reviewing companion)
          if (_isBooker) ...[
            const Text('Was the companion punctual?', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choiceRow(['Yes', 'No', 'Late but notified'], _punctuality, (v) => setState(() => _punctuality = v)),
            const SizedBox(height: 20),
          ],

          // Respectful (for companion reviewing booker)
          if (!_isBooker) ...[
            const Text('Was the booker respectful?', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choiceRow(['Yes', 'No'], _punctuality, (v) => setState(() => _punctuality = v)),
            const SizedBox(height: 20),
          ],

          // Would book again
          Text(
            _isBooker ? 'Would you book again?' : 'Would you accept a booking again?',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _choiceRow(['Yes', 'Maybe', 'No'], _wouldBookAgain, (v) => setState(() => _wouldBookAgain = v)),
          const SizedBox(height: 20),

          // Written review (optional)
          Text('Written Review (optional, max $_maxReviewChars chars)',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewCtrl,
            maxLength: _maxReviewChars,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          // Private feedback to platform (booker only — Section 9.1)
          if (_isBooker) ...[
            const SizedBox(height: 4),
            const Text('Private Feedback to Platform (not shown publicly)',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _privateCtrl,
              maxLength: 500,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Any concerns you want to report privately...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Info about review rules
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Review Rules', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(height: 4),
              Text('• Reviews cannot be edited after submission', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('• 72-hour window from session end', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('• Reviews are moderated before publishing', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 24),

          // Submit
          ElevatedButton(
            onPressed: (_rating == 0 || _submitting) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7E40),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _choiceRow(List<String> options, String? selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isSelected = selected == o;
        return ChoiceChip(
          label: Text(o),
          selected: isSelected,
          onSelected: (_) => onSelect(o),
          selectedColor: const Color(0xFFFF7E40),
          backgroundColor: Colors.white10,
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13),
        );
      }).toList(),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final booking = widget.booking;
      final revieweeId = widget.isCompanion
          ? (booking['booker_id'] ?? '')
          : (booking['companion_user_id'] ?? '');

      await CompanionService.submitReview(
        bookingId: booking['id'],
        revieweeId: revieweeId,
        reviewerRole: widget.isCompanion ? 'COMPANION' : 'BOOKER',
        overallRating: _rating,
        wasPunctual: _punctuality,
        wouldBookAgain: _wouldBookAgain,
        writtenReview: _reviewCtrl.text.trim().isEmpty ? null : _reviewCtrl.text.trim(),
        privateFeedback: _isBooker && _privateCtrl.text.trim().isNotEmpty ? _privateCtrl.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Review submitted! It will be published after the other party reviews.'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    _privateCtrl.dispose();
    super.dispose();
  }
}
