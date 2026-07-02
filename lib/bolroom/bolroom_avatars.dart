// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────────────────
// BOLROOM AVATAR REGISTRY
//
// 10 unique anonymous avatar personas.  Each is rendered as a Flutter widget
// using only canvas + shapes, so NO assets, NO network needed.
//
// Each avatar has:
//  • id          – stable key stored in bolroom_profiles.avatar_key
//  • name        – display name in the picker UI
//  • primaryColor  / accentColor – used for the aura ring + bubble
//  • build()     – renders the avatar face at any given size
// ──────────────────────────────────────────────────────────────────────────────

class BolroomAvatar {
  final String id;
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Widget Function(double size) build;

  const BolroomAvatar({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.build,
  });
}

class BolroomAvatars {
  BolroomAvatars._();

  // ── 10 avatar definitions ─────────────────────────────────────────────────
  static final List<BolroomAvatar> all = [
    // 1. Shadow Phantom
    BolroomAvatar(
      id: 'shadow_phantom',
      name: 'Shadow Phantom',
      primaryColor: const Color(0xFF7B2CBF),
      accentColor: const Color(0xFF2D1B69),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _ShadowPhantomPainter(),
      ),
    ),
    // 2. Neon Fox
    BolroomAvatar(
      id: 'neon_fox',
      name: 'Neon Fox',
      primaryColor: const Color(0xFFFF6B00),
      accentColor: const Color(0xFFFF8C00),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _NeonFoxPainter(),
      ),
    ),
    // 3. Glitch Ghost
    BolroomAvatar(
      id: 'glitch_ghost',
      name: 'Glitch Ghost',
      primaryColor: const Color(0xFF00FFFF),
      accentColor: const Color(0xFF0088FF),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _GlitchGhostPainter(),
      ),
    ),
    // 4. Cosmic Cat
    BolroomAvatar(
      id: 'cosmic_cat',
      name: 'Cosmic Cat',
      primaryColor: const Color(0xFFFF2D7E),
      accentColor: const Color(0xFFAA00FF),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _CosmicCatPainter(),
      ),
    ),
    // 5. Digital Oni
    BolroomAvatar(
      id: 'digital_oni',
      name: 'Digital Oni',
      primaryColor: const Color(0xFFFF4655),
      accentColor: const Color(0xFF8B0000),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _DigitalOniPainter(),
      ),
    ),
    // 6. Lunar Panda
    BolroomAvatar(
      id: 'lunar_panda',
      name: 'Lunar Panda',
      primaryColor: const Color(0xFFE8E8E8),
      accentColor: const Color(0xFF555577),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _LunarPandaPainter(),
      ),
    ),
    // 7. Void Serpent
    BolroomAvatar(
      id: 'void_serpent',
      name: 'Void Serpent',
      primaryColor: const Color(0xFF00FF88),
      accentColor: const Color(0xFF004422),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _VoidSerpentPainter(),
      ),
    ),
    // 8. Storm Raven
    BolroomAvatar(
      id: 'storm_raven',
      name: 'Storm Raven',
      primaryColor: const Color(0xFF4FC3F7),
      accentColor: const Color(0xFF1A237E),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _StormRavenPainter(),
      ),
    ),
    // 9. Solar Kitsune
    BolroomAvatar(
      id: 'solar_kitsune',
      name: 'Solar Kitsune',
      primaryColor: const Color(0xFFFFD700),
      accentColor: const Color(0xFFFF8C00),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _SolarKitsunePainter(),
      ),
    ),
    // 10. Phantom Monk
    BolroomAvatar(
      id: 'phantom_monk',
      name: 'Phantom Monk',
      primaryColor: const Color(0xFFD4A017),
      accentColor: const Color(0xFF5C3D11),
      build: (size) => _AvatarPainterWidget(
        size: size,
        painter: _PhantomMonkPainter(),
      ),
    ),
  ];

  /// Look up by id (returns null if not found)
  static BolroomAvatar? byId(String? id) =>
      id == null ? null : all.firstWhere((a) => a.id == id, orElse: () => all.first);

  /// Pick a random avatar deterministically based on userId
  static BolroomAvatar forUser(String userId) {
    if (userId.isEmpty) return all.first;
    final code = userId.codeUnits.fold<int>(0, (p, e) => p + e);
    return all[code % all.length];
  }

  // ── Shared service helpers ────────────────────────────────────────────────

  static const _prefKey = 'bolroom_avatar_key';

  /// Load avatar key from Supabase bolroom_profiles (falls back to SharedPrefs)
  static Future<String> loadAvatarKey(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('bolroom_profiles')
          .select('avatar_key')
          .eq('id', userId)
          .maybeSingle();
      final key = row?['avatar_key'] as String?;
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    // Fallback: SharedPreferences (offline)
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? forUser(userId).id;
  }

  /// Save avatar key to Supabase + SharedPreferences
  static Future<void> saveAvatarKey(String userId, String avatarKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, avatarKey);
    try {
      await Supabase.instance.client
          .from('bolroom_profiles')
          .update({'avatar_key': avatarKey, 'avatar_url': null})
          .eq('id', userId);
    } catch (e) {
      debugPrint('saveAvatarKey: $e');
    }
  }

  /// Get display avatar widget (custom avatar OR network photo, prioritises photo)
  static Widget buildAvatar({
    required double size,
    required String? avatarUrl,
    required String? avatarKey,
    required String userId,
    Color? auraOverride,
  }) {
    // If has a real network photo, show that
    if (avatarUrl != null && avatarUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildCustomAvatarCircle(size, avatarKey, userId, auraOverride),
        ),
      );
    }
    return _buildCustomAvatarCircle(size, avatarKey, userId, auraOverride);
  }

  static Widget _buildCustomAvatarCircle(
      double size, String? avatarKey, String userId, Color? auraOverride) {
    final avatar = byId(avatarKey) ?? forUser(userId);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: avatar.accentColor,
        child: avatar.build(size),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED BOLROOM AVATAR WIDGET (ring + glow + avatar face)
// ──────────────────────────────────────────────────────────────────────────────

class BolroomAvatarWidget extends StatelessWidget {
  final double size;
  final String? avatarUrl;
  final String? avatarKey;
  final String userId;
  final bool showRing;
  final bool isOnline;

  const BolroomAvatarWidget({
    super.key,
    required this.size,
    this.avatarUrl,
    this.avatarKey,
    required this.userId,
    this.showRing = true,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = BolroomAvatars.byId(avatarKey) ?? BolroomAvatars.forUser(userId);
    final ringColor = avatarUrl != null && avatarUrl!.startsWith('http')
        ? const Color(0xFF7B2CBF)
        : avatar.primaryColor;

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: showRing
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [ringColor, avatar.accentColor, ringColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.45),
                      blurRadius: size * 0.25,
                      spreadRadius: 2,
                    )
                  ],
                )
              : const BoxDecoration(shape: BoxShape.circle),
          child: Padding(
            padding: EdgeInsets.all(size * 0.03),
            child: BolroomAvatars.buildAvatar(
              size: size,
              avatarUrl: avatarUrl,
              avatarKey: avatarKey,
              userId: userId,
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: size * 0.04,
            bottom: size * 0.04,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF090710),
                  width: size * 0.025,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// AVATAR PICKER SHEET
// ──────────────────────────────────────────────────────────────────────────────

class BolroomAvatarPickerSheet extends StatefulWidget {
  final String userId;
  final String? currentAvatarKey;
  final Function(String key) onSelected;

  const BolroomAvatarPickerSheet({
    super.key,
    required this.userId,
    this.currentAvatarKey,
    required this.onSelected,
  });

  @override
  State<BolroomAvatarPickerSheet> createState() =>
      _BolroomAvatarPickerSheetState();
}

class _BolroomAvatarPickerSheetState extends State<BolroomAvatarPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentAvatarKey ??
        BolroomAvatars.forUser(widget.userId).id;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF231D38), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Choose Your Avatar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your anonymous identity in Bolrooms',
            style: TextStyle(color: Color(0xFF8E8B99), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // 2-row grid of 5 avatars each
          ...List.generate((BolroomAvatars.all.length / 5).ceil(), (rowIdx) {
            final start = rowIdx * 5;
            final end = min(start + 5, BolroomAvatars.all.length);
            final rowAvatars = BolroomAvatars.all.sublist(start, end);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rowAvatars.map((av) {
                  final isSelected = _selected == av.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = av.id),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.all(isSelected ? 3 : 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? SweepGradient(colors: [
                                    av.primaryColor,
                                    av.accentColor,
                                    av.primaryColor
                                  ])
                                : null,
                            color:
                                isSelected ? null : const Color(0xFF231D38),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: av.primaryColor
                                          .withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: Container(
                              width: 54,
                              height: 54,
                              color: av.accentColor,
                              child: av.build(54),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          av.name,
                          style: TextStyle(
                            color: isSelected
                                ? av.primaryColor
                                : const Color(0xFF8E8B99),
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),

          const SizedBox(height: 8),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                widget.onSelected(_selected);
                Navigator.pop(context);
              },
              child: const Text(
                'Set as My Avatar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// INTERNAL WIDGET WRAPPER
// ──────────────────────────────────────────────────────────────────────────────

class _AvatarPainterWidget extends StatelessWidget {
  final double size;
  final CustomPainter painter;

  const _AvatarPainterWidget({required this.size, required this.painter});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: painter, size: Size(size, size));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 10 AVATAR PAINTERS
// Each fills a square canvas that is then ClipOval'd
// ──────────────────────────────────────────────────────────────────────────────

// 1. Shadow Phantom — hooded figure with glowing eyes
class _ShadowPhantomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    // Background
    p.color = const Color(0xFF1A0833);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Hood
    p.color = const Color(0xFF0D0520);
    final hood = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..quadraticBezierTo(w * 0.0, h * 0.2, w * 0.1, h * 0.7)
      ..lineTo(w * 0.9, h * 0.7)
      ..quadraticBezierTo(w * 1.0, h * 0.2, w * 0.5, h * 0.08);
    canvas.drawPath(hood, p);

    // Face shadow
    p.color = const Color(0xFF160626);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.42, height: h * 0.3), p);

    // Glowing eyes
    final eyeGlow = Paint()
      ..color = const Color(0xFF7B2CBF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(w * 0.38, h * 0.42), w * 0.05, eyeGlow);
    canvas.drawCircle(Offset(w * 0.62, h * 0.42), w * 0.05, eyeGlow);

    p.color = const Color(0xFFBB00FF);
    canvas.drawCircle(Offset(w * 0.38, h * 0.42), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.62, h * 0.42), w * 0.03, p);

    // Robe bottom
    p.color = const Color(0xFF0D0520);
    final robe = Path()
      ..moveTo(w * 0.1, h * 0.7)
      ..lineTo(w * 0.0, h * 1.0)
      ..lineTo(w * 1.0, h * 1.0)
      ..lineTo(w * 0.9, h * 0.7);
    canvas.drawPath(robe, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 2. Neon Fox
class _NeonFoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.color = const Color(0xFF1C0A00);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Fox body/face (circle)
    p.color = const Color(0xFFE85000);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.6, height: h * 0.5), p);

    // Ears
    final earL = Path()
      ..moveTo(w * 0.22, h * 0.38)
      ..lineTo(w * 0.10, h * 0.12)
      ..lineTo(w * 0.38, h * 0.3);
    p.color = const Color(0xFFE85000);
    canvas.drawPath(earL, p);
    final earR = Path()
      ..moveTo(w * 0.78, h * 0.38)
      ..lineTo(w * 0.90, h * 0.12)
      ..lineTo(w * 0.62, h * 0.3);
    canvas.drawPath(earR, p);

    // Inner ear
    p.color = const Color(0xFFFF9060);
    final innerL = Path()
      ..moveTo(w * 0.25, h * 0.36)
      ..lineTo(w * 0.17, h * 0.19)
      ..lineTo(w * 0.36, h * 0.30);
    canvas.drawPath(innerL, p);
    final innerR = Path()
      ..moveTo(w * 0.75, h * 0.36)
      ..lineTo(w * 0.83, h * 0.19)
      ..lineTo(w * 0.64, h * 0.30);
    canvas.drawPath(innerR, p);

    // Mask
    p.color = const Color(0xFFF0F0F0);
    final mask = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.36, height: h * 0.3));
    canvas.drawPath(mask, p);

    // Eyes (neon)
    final eyeGlow = Paint()..color = const Color(0xFFFF6B00)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(w * 0.38, h * 0.5), w * 0.055, eyeGlow);
    canvas.drawCircle(Offset(w * 0.62, h * 0.5), w * 0.055, eyeGlow);
    p.color = Colors.black;
    canvas.drawCircle(Offset(w * 0.38, h * 0.5), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.62, h * 0.5), w * 0.03, p);

    // Nose
    p.color = const Color(0xFF1C0A00);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.6), width: w * 0.08, height: h * 0.04), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 3. Glitch Ghost
class _GlitchGhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.color = const Color(0xFF001F2E);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Ghost shape
    final glow = Paint()..color = const Color(0xFF00FFFF).withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.45), width: w * 0.7, height: h * 0.7), glow);

    p.color = const Color(0xFF00DDDD).withValues(alpha: 0.8);
    final ghost = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.54, height: h * 0.48))
      ..moveTo(w * 0.23, h * 0.6)
      ..lineTo(w * 0.23, h * 0.88)
      ..quadraticBezierTo(w * 0.32, h * 0.78, w * 0.38, h * 0.88)
      ..quadraticBezierTo(w * 0.44, h * 0.78, w * 0.50, h * 0.88)
      ..quadraticBezierTo(w * 0.56, h * 0.78, w * 0.62, h * 0.88)
      ..quadraticBezierTo(w * 0.68, h * 0.78, w * 0.77, h * 0.88)
      ..lineTo(w * 0.77, h * 0.6);
    canvas.drawPath(ghost, p);

    // Glitch bars
    p.color = const Color(0xFFFF00FF).withValues(alpha: 0.3);
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.35, w * 0.15, h * 0.02), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.55, h * 0.38, w * 0.1, h * 0.015), p);

    // Eyes (X marks)
    p
      ..color = const Color(0xFF001F2E)
      ..strokeWidth = w * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Left eye
    canvas.drawLine(Offset(w * 0.37, h * 0.35), Offset(w * 0.43, h * 0.41), p);
    canvas.drawLine(Offset(w * 0.43, h * 0.35), Offset(w * 0.37, h * 0.41), p);
    // Right eye
    canvas.drawLine(Offset(w * 0.57, h * 0.35), Offset(w * 0.63, h * 0.41), p);
    canvas.drawLine(Offset(w * 0.63, h * 0.35), Offset(w * 0.57, h * 0.41), p);
    p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 4. Cosmic Cat
class _CosmicCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.shader = const LinearGradient(colors: [Color(0xFF1A0030), Color(0xFF2D006E)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)
        .createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Body
    p.color = const Color(0xFF9900CC);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.57), width: w * 0.65, height: h * 0.55), p);

    // Ears
    final earL = Path()..moveTo(w * 0.23, h * 0.38)..lineTo(w * 0.16, h * 0.14)..lineTo(w * 0.38, h * 0.3)..close();
    final earR = Path()..moveTo(w * 0.77, h * 0.38)..lineTo(w * 0.84, h * 0.14)..lineTo(w * 0.62, h * 0.3)..close();
    p.color = const Color(0xFFBB00FF);
    canvas.drawPath(earL, p); canvas.drawPath(earR, p);
    p.color = const Color(0xFFFF2D7E);
    final il = Path()..moveTo(w * 0.26, h * 0.36)..lineTo(w * 0.21, h * 0.20)..lineTo(w * 0.36, h * 0.3)..close();
    final ir = Path()..moveTo(w * 0.74, h * 0.36)..lineTo(w * 0.79, h * 0.20)..lineTo(w * 0.64, h * 0.3)..close();
    canvas.drawPath(il, p); canvas.drawPath(ir, p);

    // Eyes
    final eyeG = Paint()..color = const Color(0xFFFF2D7E)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.37, h * 0.5), width: w * 0.1, height: h * 0.12), eyeG);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.63, h * 0.5), width: w * 0.1, height: h * 0.12), eyeG);
    p.color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.37, h * 0.5), width: w * 0.07, height: h * 0.09), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.63, h * 0.5), width: w * 0.07, height: h * 0.09), p);
    p.color = Colors.black;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.37, h * 0.5), width: w * 0.03, height: h * 0.07), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.63, h * 0.5), width: w * 0.03, height: h * 0.07), p);

    // Nose + mouth
    p.color = const Color(0xFFFF2D7E);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 0.08, height: h * 0.05), p);
    p..color = const Color(0xFFFF2D7E)..strokeWidth = w * 0.02..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.64), width: w * 0.2, height: h * 0.1), 0.2, 2.7, false, p);
    p.style = PaintingStyle.fill;

    // Whiskers
    p..color = Colors.white.withValues(alpha: 0.4)..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.18, h * 0.6), Offset(w * 0.42, h * 0.63), p);
    canvas.drawLine(Offset(w * 0.18, h * 0.65), Offset(w * 0.42, h * 0.65), p);
    canvas.drawLine(Offset(w * 0.82, h * 0.6), Offset(w * 0.58, h * 0.63), p);
    canvas.drawLine(Offset(w * 0.82, h * 0.65), Offset(w * 0.58, h * 0.65), p);
    p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 5. Digital Oni
class _DigitalOniPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.color = const Color(0xFF1A0000);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Head
    p.color = const Color(0xFFCC2200);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.7, height: h * 0.65), const Radius.circular(20)), p);

    // Horns
    final hornL = Path()..moveTo(w * 0.28, h * 0.22)..lineTo(w * 0.22, h * 0.04)..lineTo(w * 0.36, h * 0.2)..close();
    final hornR = Path()..moveTo(w * 0.72, h * 0.22)..lineTo(w * 0.78, h * 0.04)..lineTo(w * 0.64, h * 0.2)..close();
    p.color = const Color(0xFFAA0000);
    canvas.drawPath(hornL, p); canvas.drawPath(hornR, p);

    // Eyes (circuit-style)
    p.color = const Color(0xFFFFFF00);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.36, h * 0.44), width: w * 0.12, height: h * 0.07), p);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.64, h * 0.44), width: w * 0.12, height: h * 0.07), p);
    p.color = Colors.black;
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.36, h * 0.44), width: w * 0.06, height: h * 0.03), p);
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.64, h * 0.44), width: w * 0.06, height: h * 0.03), p);

    // Mouth (sharp teeth)
    p.color = Colors.black;
    canvas.drawRect(Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 0.38, height: h * 0.1), p);
    p.color = Colors.white;
    for (int i = 0; i < 5; i++) {
      final tx = w * (0.33 + i * 0.085);
      final tooth = Path()
        ..moveTo(tx, h * 0.57)..lineTo(tx + w * 0.04, h * 0.57)..lineTo(tx + w * 0.02, h * 0.64)..close();
      canvas.drawPath(tooth, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 6. Lunar Panda
class _LunarPandaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.color = const Color(0xFF222244);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Stars
    p.color = Colors.white.withValues(alpha: 0.3);
    for (final star in [(0.1, 0.15), (0.8, 0.1), (0.9, 0.4), (0.05, 0.6), (0.85, 0.7)]) {
      canvas.drawCircle(Offset(w * star.$1, h * star.$2), w * 0.012, p);
    }

    // Head
    p.color = const Color(0xFFF0F0F0);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.66, height: h * 0.56), p);

    // Black eye patches
    p.color = const Color(0xFF222222);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.35, h * 0.46), width: w * 0.2, height: h * 0.18), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.65, h * 0.46), width: w * 0.2, height: h * 0.18), p);

    // Ears
    p.color = const Color(0xFF222222);
    canvas.drawCircle(Offset(w * 0.2, h * 0.2), w * 0.1, p);
    canvas.drawCircle(Offset(w * 0.8, h * 0.2), w * 0.1, p);

    // Eyes
    p.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.35, h * 0.46), w * 0.065, p);
    canvas.drawCircle(Offset(w * 0.65, h * 0.46), w * 0.065, p);
    p.color = const Color(0xFF222222);
    canvas.drawCircle(Offset(w * 0.38, h * 0.47), w * 0.035, p);
    canvas.drawCircle(Offset(w * 0.68, h * 0.47), w * 0.035, p);
    p.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.38, h * 0.44), w * 0.012, p);
    canvas.drawCircle(Offset(w * 0.68, h * 0.44), w * 0.012, p);

    // Nose
    p.color = const Color(0xFF555577);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.59), width: w * 0.1, height: h * 0.06), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 7. Void Serpent
class _VoidSerpentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.color = const Color(0xFF001A0A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Serpent coil body
    p..color = const Color(0xFF006633)..style = PaintingStyle.stroke..strokeWidth = w * 0.12..strokeCap = StrokeCap.round;
    final coil = Path()
      ..moveTo(w * 0.5, h * 0.85)
      ..quadraticBezierTo(w * 0.1, h * 0.7, w * 0.3, h * 0.5)
      ..quadraticBezierTo(w * 0.6, h * 0.3, w * 0.5, h * 0.2)
      ..quadraticBezierTo(w * 0.35, h * 0.1, w * 0.5, h * 0.18);
    canvas.drawPath(coil, p);
    p.style = PaintingStyle.fill;

    // Head
    p.color = const Color(0xFF008844);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.32), width: w * 0.3, height: h * 0.22), p);

    // Eyes
    final eyeG = Paint()..color = const Color(0xFF00FF88)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(w * 0.42, h * 0.3), w * 0.045, eyeG);
    canvas.drawCircle(Offset(w * 0.58, h * 0.3), w * 0.045, eyeG);
    p.color = Colors.black;
    canvas.drawCircle(Offset(w * 0.42, h * 0.3), w * 0.022, p);
    canvas.drawCircle(Offset(w * 0.58, h * 0.3), w * 0.022, p);

    // Tongue
    p..color = const Color(0xFFFF2200)..style = PaintingStyle.stroke..strokeWidth = w * 0.03..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5, h * 0.48), p);
    canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.44, h * 0.53), p);
    canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.56, h * 0.53), p);
    p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 8. Storm Raven
class _StormRavenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.shader = const LinearGradient(colors: [Color(0xFF0A0E2A), Color(0xFF060D20)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Wings
    p.color = const Color(0xFF1A2050);
    final wingL = Path()
      ..moveTo(w * 0.3, h * 0.5)..lineTo(w * 0.0, h * 0.3)..lineTo(w * 0.05, h * 0.65)..close();
    final wingR = Path()
      ..moveTo(w * 0.7, h * 0.5)..lineTo(w * 1.0, h * 0.3)..lineTo(w * 0.95, h * 0.65)..close();
    canvas.drawPath(wingL, p); canvas.drawPath(wingR, p);

    // Body
    p.color = const Color(0xFF1A1A2E);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.5, height: h * 0.5), p);

    // Head
    p.color = const Color(0xFF1A1A2E);
    canvas.drawCircle(Offset(w * 0.5, h * 0.34), w * 0.22, p);

    // Beak
    p.color = const Color(0xFF4FC3F7);
    final beak = Path()
      ..moveTo(w * 0.5, h * 0.38)..lineTo(w * 0.58, h * 0.43)..lineTo(w * 0.5, h * 0.46)..close();
    canvas.drawPath(beak, p);

    // Eyes (lightning blue)
    final eyeG = Paint()..color = const Color(0xFF4FC3F7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(w * 0.4, h * 0.31), w * 0.055, eyeG);
    canvas.drawCircle(Offset(w * 0.6, h * 0.31), w * 0.055, eyeG);
    p.color = const Color(0xFF0088FF);
    canvas.drawCircle(Offset(w * 0.4, h * 0.31), w * 0.03, p);
    canvas.drawCircle(Offset(w * 0.6, h * 0.31), w * 0.03, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 9. Solar Kitsune
class _SolarKitsunePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.shader = const LinearGradient(colors: [Color(0xFF1A0E00), Color(0xFF0A0600)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Multiple fox tails (fan)
    for (int i = -2; i <= 2; i++) {
      final angle = i * 0.22;
      final tailPath = Path()
        ..moveTo(w * 0.5, h * 0.75)
        ..quadraticBezierTo(
          w * (0.5 + sin(angle) * 0.5), h * 0.5,
          w * (0.5 + sin(angle) * 0.6), h * 0.25,
        );
      final tailPaint = Paint()
        ..color = const Color(0xFFFF8C00).withValues(alpha: 0.7)
        ..strokeWidth = w * 0.07
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(tailPath, tailPaint);
    }

    // Head
    p.color = const Color(0xFFCC7700);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.4), width: w * 0.56, height: h * 0.46), p);

    // Ears
    final earL = Path()..moveTo(w * 0.24, h * 0.3)..lineTo(w * 0.18, h * 0.08)..lineTo(w * 0.38, h * 0.24)..close();
    final earR = Path()..moveTo(w * 0.76, h * 0.3)..lineTo(w * 0.82, h * 0.08)..lineTo(w * 0.62, h * 0.24)..close();
    p.color = const Color(0xFFAA5500);
    canvas.drawPath(earL, p); canvas.drawPath(earR, p);

    // Mask
    p.color = const Color(0xFFFFEECC);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.34, height: h * 0.28), p);

    // Eyes (gold)
    final eyeG = Paint()..color = const Color(0xFFFFD700)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(w * 0.38, h * 0.38), w * 0.055, eyeG);
    canvas.drawCircle(Offset(w * 0.62, h * 0.38), w * 0.055, eyeG);
    p.color = const Color(0xFF4A2800);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.38, h * 0.38), width: w * 0.025, height: h * 0.055), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.62, h * 0.38), width: w * 0.025, height: h * 0.055), p);

    // Nose
    p.color = const Color(0xFF7A3300);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.08, height: h * 0.045), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// 10. Phantom Monk
class _PhantomMonkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final p = Paint()..isAntiAlias = true;

    p.color = const Color(0xFF0D0800);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // Halo
    p..color = const Color(0xFFD4A017).withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = w * 0.06;
    canvas.drawCircle(Offset(w * 0.5, h * 0.22), w * 0.22, p);
    p.style = PaintingStyle.fill;

    // Robe
    p.color = const Color(0xFF5C3D11);
    final robe = Path()
      ..moveTo(w * 0.25, h * 0.55)
      ..lineTo(w * 0.08, h * 1.0)
      ..lineTo(w * 0.92, h * 1.0)
      ..lineTo(w * 0.75, h * 0.55);
    canvas.drawPath(robe, p);

    // Head
    p.color = const Color(0xFF8B6914);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.5, height: h * 0.42), p);

    // Eyes (closed — meditating)
    p..color = const Color(0xFF3A2000)..style = PaintingStyle.stroke..strokeWidth = w * 0.03..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.38, h * 0.42), width: w * 0.12, height: h * 0.06), 3.14, 3.14, false, p);
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.62, h * 0.42), width: w * 0.12, height: h * 0.06), 3.14, 3.14, false, p);
    p.style = PaintingStyle.fill;

    // Mark on forehead
    final markGlow = Paint()..color = const Color(0xFFD4A017)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.05, markGlow);
    p.color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.03, p);

    // Smile
    p..color = const Color(0xFF3A2000)..style = PaintingStyle.stroke..strokeWidth = w * 0.025..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.2, height: h * 0.1), 0.2, 2.7, false, p);
    p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}
