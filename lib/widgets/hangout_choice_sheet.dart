import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/doodle_theme.dart';

class HangoutChoiceSheet extends StatefulWidget {
  final String targetName;

  const HangoutChoiceSheet({super.key, required this.targetName});

  @override
  State<HangoutChoiceSheet> createState() => _HangoutChoiceSheetState();
}

class _HangoutChoiceSheetState extends State<HangoutChoiceSheet> {
  String? _selectedActivity;
  String _selectedWhen = 'NOW';

  final List<Map<String, String>> activities = [
    {'icon': '☕', 'label': 'COFFEE'},
    {'icon': '🍕', 'label': 'FOOD'},
    {'icon': '🍛', 'label': 'BIRYANI'},
    {'icon': '🍺', 'label': 'BEER'},
    {'icon': '🍵', 'label': 'CHAI'},
    {'icon': '🌮', 'label': 'STREET'},
    {'icon': '🍸', 'label': 'DRINKS'},
    {'icon': '🚬', 'label': 'SUTTA'},
    {'icon': '🛍️', 'label': 'SHOPPING'},
    {'icon': '🍿', 'label': 'MOVIES'},
    {'icon': '🎮', 'label': 'GAMING'},
    {'icon': '🎶', 'label': 'CHILL'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10101C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'hang with ${widget.targetName}',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
              children: const [
                TextSpan(text: "what's the "),
                TextSpan(text: "move?", style: TextStyle(color: Color(0xFF00E676))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Activities Grid
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACTIVITIES',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final act = activities[index];
              final isSelected = _selectedActivity == act['label'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedActivity = act['label']);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(act['icon']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(
                        act['label']!,
                        style: GoogleFonts.outfit(
                          color: isSelected ? const Color(0xFF00E676) : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // When Selector
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'WHEN?',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWhenOption('NOW', '⚡'),
              const SizedBox(width: 12),
              _buildWhenOption('LATER', '🕒'),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Submit Button
          GestureDetector(
            onTap: () {
              if (_selectedActivity != null) {
                HapticFeedback.heavyImpact();
                final actIcon = activities.firstWhere((a) => a['label'] == _selectedActivity)['icon'];
                final result = "⚡HANGOUT_INVITE|$actIcon|$_selectedActivity|$_selectedWhen";
                Navigator.pop(context, result);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: _selectedActivity != null ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  _selectedActivity != null ? 'SEND HANGOUT' : 'select an activity',
                  style: GoogleFonts.outfit(
                    color: _selectedActivity != null ? Colors.white : Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Just Chat Button
          GestureDetector(
            onTap: () {
              Navigator.pop(context, "CHAT_ONLY");
            },
            child: Container(
              width: double.infinity,
              height: 56,
              color: Colors.transparent,
              child: Center(
                child: Text(
                  'Just chat directly',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildWhenOption(String label, String icon) {
    final isSelected = _selectedWhen == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedWhen = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 80,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected ? const Color(0xFF00E676) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
