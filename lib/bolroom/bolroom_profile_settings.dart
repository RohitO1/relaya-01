// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bolroom_theme.dart';
import '../services/doodle_theme.dart';

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
    final doodle = isDoodleMode(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: doodle ? DoodleDecorations.card() : _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Change Avatar', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Icon(Icons.chevron_right, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : BolroomTheme.textMuted, size: 18),
        ]),
        SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: BolroomTheme.avatarPresets.entries.map((e) {
            final sel = avatarKey == e.key;
            return GestureDetector(
              onTap: () { onChanged(e.key); HapticFeedback.lightImpact(); },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: doodle ? (sel ? DoodleColors.orange.withValues(alpha: 0.2) : DoodleColors.paper) : (e.value['color'] as Color).withValues(alpha: sel ? 0.35 : 0.12),
                    border: Border.all(color: sel ? (doodle ? DoodleColors.orange : BolroomTheme.purple) : Colors.transparent, width: 2),
                  ),
                  child: Center(child: Text(e.value['icon'] as String, style: TextStyle(fontSize: 16))),
                ),
                SizedBox(height: 4),
                Text(e.value['label'] as String, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 9).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 8, fontWeight: FontWeight.w600)),
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
    final doodle = isDoodleMode(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: doodle ? DoodleDecorations.card() : _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Voice Modulator', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Icon(Icons.chevron_right, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : BolroomTheme.textMuted, size: 18),
        ]),
        SizedBox(height: 12),
        // Waveform visual
        SizedBox(
          height: 40,
          child: CustomPaint(painter: _WaveformPainter(color: doodle ? DoodleColors.blue : BolroomTheme.purple), size: Size.infinite),
        ),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: doodle
            ? BoxDecoration(color: DoodleColors.cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: DoodleColors.brown.withValues(alpha: 0.3)))
            : BoxDecoration(color: BolroomTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: BolroomTheme.borderSubtle)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: modulator, dropdownColor: doodle ? DoodleColors.paper : BolroomTheme.card,
            style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 12),
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
    final doodle = isDoodleMode(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: doodle ? DoodleDecorations.card() : _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Aura Color Picker', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Icon(Icons.chevron_right, color: doodle ? DoodleColors.brown.withValues(alpha: 0.5) : BolroomTheme.textMuted, size: 18),
        ]),
        SizedBox(height: 14),
        Center(child: SizedBox(
          width: 90, height: 90,
          child: Stack(alignment: Alignment.center, children: [
            // Color wheel ring
            CustomPaint(painter: _ColorWheelPainter(doodle: doodle), size: Size(90, 90)),
            // Center orb showing selected color
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: doodle && auraColor == '#7856FF' ? DoodleColors.orange : _parseHex(auraColor), // Default doodle aura
                boxShadow: [BoxShadow(color: (doodle && auraColor == '#7856FF' ? DoodleColors.orange : _parseHex(auraColor)).withValues(alpha: 0.4), blurRadius: 10)],
                border: doodle ? Border.all(color: DoodleColors.brown, width: 2) : null,
              ),
            ),
          ]),
        )),
        SizedBox(height: 10),
        // Quick-pick dots
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['#7856FF','#E8457A','#00D4B8','#FFB347','#4E8BFF'].map((hex) {
          final sel = auraColor == hex;
          final c = doodle && hex == '#7856FF' ? DoodleColors.orange : _parseHex(hex);
          return GestureDetector(
            onTap: () { onChanged(hex); HapticFeedback.lightImpact(); },
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: c,
                border: Border.all(color: sel ? (doodle ? DoodleColors.brown : Colors.white) : Colors.transparent, width: 2),
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
  final bool doodle;
  _ColorWheelPainter({this.doodle = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..shader = SweepGradient(colors: doodle ? [
        DoodleColors.orange, DoodleColors.blue, DoodleColors.brown,
        DoodleColors.orange, DoodleColors.cream, DoodleColors.paper,
        DoodleColors.orange, DoodleColors.orange,
      ] : [
        Color(0xFFFF0000), Color(0xFFFF8800), Color(0xFFFFFF00),
        Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF),
        Color(0xFFFF00FF), Color(0xFFFF0000),
      ]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 6, paint);
    
    if (doodle) {
      canvas.drawCircle(center, radius - 6 + 5, Paint()..color = DoodleColors.brown..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(center, radius - 6 - 5, Paint()..color = DoodleColors.brown..style = PaintingStyle.stroke..strokeWidth = 2);
    }
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
    final doodle = isDoodleMode(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: doodle ? DoodleDecorations.card() : _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lock_outline, color: doodle ? DoodleColors.brown : BolroomTheme.gold, size: 16),
          SizedBox(width: 6),
          Text('Privacy Vault', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hide online status', style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('You will appear offline to others', style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 10) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 10)),
          ])),
          SizedBox(
            height: 28,
            child: Switch(
              value: hideOnline, onChanged: onChanged,
              activeThumbColor: doodle ? DoodleColors.cream : BolroomTheme.purple,
              activeTrackColor: doodle ? DoodleColors.blue : BolroomTheme.purple.withValues(alpha: 0.4),
              inactiveThumbColor: doodle ? DoodleColors.brown : null,
              inactiveTrackColor: doodle ? DoodleColors.paper : null,
              trackOutlineColor: doodle ? WidgetStateProperty.all(DoodleColors.brown) : null,
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
    final doodle = isDoodleMode(context);
    final names = title == 'Followers'
      ? ['@MysticDusk', '@SilentEcho', '@NightPulse']
      : ['@DarkSpecter', '@LunarWhisper', '@EclipseSoul'];
    final times = ['1h ago', '3h ago', '1d ago'];
    final icons = doodle ? ['🦊', '🐱', '🐶'] : ['🌑', '🦊', '🌌'];

    return Container(
      padding: EdgeInsets.all(14),
      decoration: doodle ? DoodleDecorations.card(color: title == 'Followers' ? DoodleColors.cream : DoodleColors.paper) : _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Spacer(),
          Text(_fmt(count), style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 14).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 12),
        ...List.generate(3, (i) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: doodle
                ? BoxDecoration(shape: BoxShape.circle, color: DoodleColors.orange.withValues(alpha: 0.2), border: Border.all(color: DoodleColors.orange))
                : BoxDecoration(shape: BoxShape.circle, color: BolroomTheme.purple.withValues(alpha: 0.12)),
              child: Center(child: Text(icons[i], style: TextStyle(fontSize: 14))),
            ),
            SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(names[i], style: doodle ? DoodleFonts.body(color: DoodleColors.brown, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(times[i], style: doodle ? DoodleFonts.body(color: DoodleColors.brown.withValues(alpha: 0.7), fontSize: 10) : GoogleFonts.inter(color: BolroomTheme.textMuted, fontSize: 9)),
            ])),
          ]),
        )),
        GestureDetector(
          onTap: onViewAll,
          child: Row(children: [
            Text('View all ${title.toLowerCase()}', style: doodle ? DoodleFonts.body(color: DoodleColors.blue, fontSize: 12).copyWith(fontWeight: FontWeight.bold) : GoogleFonts.inter(color: BolroomTheme.purple, fontSize: 11, fontWeight: FontWeight.w600)),
            Spacer(),
            Icon(Icons.arrow_forward, color: doodle ? DoodleColors.blue : BolroomTheme.purple, size: 14),
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
