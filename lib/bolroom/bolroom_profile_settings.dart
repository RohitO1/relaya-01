// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bolroom_theme.dart';

/// 2-column grid settings matching the reference image
class BolroomSettingsGrid extends StatelessWidget {
  final String avatarKey;
  final String voiceModulator;
  final String auraColor;
  final bool hideOnline;
  final int followerCount;
  final int followingCount;
  final Function(String) onAvatarChanged;
  final Function(String) onModulatorChanged;
  final Function(String) onAuraChanged;
  final Function(bool) onHideOnlineChanged;
  final VoidCallback onViewFollowers;
  final VoidCallback onViewFollowing;

  const BolroomSettingsGrid({
    super.key, required this.avatarKey, required this.voiceModulator,
    required this.auraColor, required this.hideOnline,
    required this.followerCount, required this.followingCount,
    required this.onAvatarChanged, required this.onModulatorChanged,
    required this.onAuraChanged, required this.onHideOnlineChanged,
    required this.onViewFollowers, required this.onViewFollowing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        // Row 1: Avatar + Voice Modulator
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _AvatarCard(avatarKey: avatarKey, onChanged: onAvatarChanged)),
          SizedBox(width: 12),
          Expanded(child: _VoiceModCard(modulator: voiceModulator, onChanged: onModulatorChanged)),
        ]),
        SizedBox(height: 12),
        // Row 2: Aura Color + Privacy Vault
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _AuraColorCard(auraColor: auraColor, onChanged: onAuraChanged)),
          SizedBox(width: 12),
          Expanded(child: _PrivacyCard(hideOnline: hideOnline, onChanged: onHideOnlineChanged)),
        ]),
        SizedBox(height: 12),
        // Row 3: Followers + Following
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _FollowCard(title: 'Followers', count: followerCount, onViewAll: onViewFollowers)),
          SizedBox(width: 12),
          Expanded(child: _FollowCard(title: 'Following', count: followingCount, onViewAll: onViewFollowing)),
        ]),
      ]),
    );
  }
}

// ── Avatar Card ──
class _AvatarCard extends StatelessWidget {
  final String avatarKey;
  final Function(String) onChanged;
  const _AvatarCard({required this.avatarKey, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Change Avatar', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Icon(Icons.chevron_right, color: BolroomTheme.textMuted, size: 18),
        ]),
        SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:
          BolroomTheme.avatarPresets.entries.take(5).map((e) {
            final sel = avatarKey == e.key;
            return GestureDetector(
              onTap: () { onChanged(e.key); HapticFeedback.lightImpact(); },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (e.value['color'] as Color).withValues(alpha: sel ? 0.35 : 0.12),
                    border: Border.all(color: sel ? BolroomTheme.purple : Colors.transparent, width: 2),
                  ),
                  child: Center(child: Text(e.value['icon'] as String, style: TextStyle(fontSize: 18))),
                ),
                SizedBox(height: 4),
                Text(e.value['label'] as String, style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 8, fontWeight: FontWeight.w600)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Voice Modulator Card with waveform ──
class _VoiceModCard extends StatelessWidget {
  final String modulator;
  final Function(String) onChanged;
  const _VoiceModCard({required this.modulator, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Voice Modulator', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Icon(Icons.chevron_right, color: BolroomTheme.textMuted, size: 18),
        ]),
        SizedBox(height: 12),
        // Waveform visual
        SizedBox(
          height: 40,
          child: CustomPaint(painter: _WaveformPainter(color: BolroomTheme.purple), size: Size.infinite),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: BolroomTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: BolroomTheme.borderSubtle)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: modulator, dropdownColor: BolroomTheme.card,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
            isExpanded: true, isDense: true,
            items: BolroomTheme.voiceModulators.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          )),
        ),
      ]),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final rng = math.Random(42);
    const barCount = 28;
    final barW = size.width / (barCount * 1.6);
    for (int i = 0; i < barCount; i++) {
      final x = i * (size.width / barCount) + barW / 2;
      final h = 8 + rng.nextDouble() * (size.height - 16);
      final y1 = (size.height - h) / 2;
      canvas.drawLine(Offset(x, y1), Offset(x, y1 + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Aura Color Card with color wheel ──
class _AuraColorCard extends StatelessWidget {
  final String auraColor;
  final Function(String) onChanged;
  const _AuraColorCard({required this.auraColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Aura Color Picker', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Icon(Icons.chevron_right, color: BolroomTheme.textMuted, size: 18),
        ]),
        SizedBox(height: 14),
        Center(child: SizedBox(
          width: 90, height: 90,
          child: Stack(alignment: Alignment.center, children: [
            // Color wheel ring
            CustomPaint(painter: _ColorWheelPainter(), size: Size(90, 90)),
            // Center orb showing selected color
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _parseHex(auraColor),
                boxShadow: [BoxShadow(color: _parseHex(auraColor).withValues(alpha: 0.4), blurRadius: 10)],
              ),
            ),
          ]),
        )),
        SizedBox(height: 10),
        // Quick-pick dots
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['#7856FF','#E8457A','#00D4B8','#FFB347','#4E8BFF'].map((hex) {
          final sel = auraColor == hex;
          return GestureDetector(
            onTap: () { onChanged(hex); HapticFeedback.lightImpact(); },
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: _parseHex(hex),
                border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2),
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }

  Color _parseHex(String hex) {
    try { return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return BolroomTheme.purple; }
  }
}

class _ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..shader = SweepGradient(colors: [
        Color(0xFFFF0000), Color(0xFFFF8800), Color(0xFFFFFF00),
        Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF),
        Color(0xFFFF00FF), Color(0xFFFF0000),
      ]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 6, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Privacy Vault Card ──
class _PrivacyCard extends StatelessWidget {
  final bool hideOnline;
  final Function(bool) onChanged;
  const _PrivacyCard({required this.hideOnline, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_outline, color: BolroomTheme.gold, size: 16),
          SizedBox(width: 6),
          Text('Privacy Vault', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hide online status', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('You will appear offline to others', style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 10)),
          ])),
          SizedBox(
            height: 28,
            child: Switch(
              value: hideOnline, onChanged: onChanged,
              activeThumbColor: BolroomTheme.purple,
              activeTrackColor: BolroomTheme.purple.withValues(alpha: 0.4),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Followers/Following Preview Card ──
class _FollowCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onViewAll;
  const _FollowCard({required this.title, required this.count, required this.onViewAll});

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    final names = title == 'Followers'
      ? ['@MysticDusk', '@SilentEcho', '@NightPulse']
      : ['@DarkSpecter', '@LunarWhisper', '@EclipseSoul'];
    final times = ['1h ago', '3h ago', '1d ago'];
    final icons = ['🌑', '🦊', '🌌'];

    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Text(_fmt(count), style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 12),
        ...List.generate(3, (i) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: BolroomTheme.purple.withValues(alpha: 0.12)),
              child: Center(child: Text(icons[i], style: TextStyle(fontSize: 14))),
            ),
            SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(names[i], style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(times[i], style: GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 9)),
            ])),
          ]),
        )),
        GestureDetector(
          onTap: onViewAll,
          child: Row(children: [
            Text('View all ${title.toLowerCase()}', style: GoogleFonts.inter(color: BolroomTheme.purple, fontSize: 11, fontWeight: FontWeight.w600)),
            Spacer(),
            Icon(Icons.arrow_forward, color: BolroomTheme.purple, size: 14),
          ]),
        ),
      ]),
    );
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
  color: BolroomTheme.card,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: BolroomTheme.borderSubtle),
);
