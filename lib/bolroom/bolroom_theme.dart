import 'package:flutter/material.dart';

/// ============================================================
/// BolRoom Design System — Premium Dark Theme
/// Inspired by the reference UI: clean, muted, glassmorphic
/// ============================================================
class BolroomTheme {
  // ── Core backgrounds ──
  static const bg         = Color(0xFF000000);
  static const bgAlt      = Color(0xFF050505);
  static const surface    = Color(0xFF0A0A0A);
  static const card       = Color(0xFF111111);
  static const cardHover  = Color(0xFF1A1A1A);
  static const sheet      = Color(0xFF0A0A0A);

  // ── Accent palette (muted) ──
  static const purple     = Color(0xFF7856FF);
  static const purpleDim  = Color(0xFF5B3FCC);
  static const pink       = Color(0xFFE8457A);
  static const cyan       = Color(0xFF00D4B8);
  static const gold       = Color(0xFFFFB347);
  static const blue       = Color(0xFF4E8BFF);
  static const red        = Color(0xFFFF4466);
  static const green      = Color(0xFF2ECB71);

  // ── Text hierarchy ──
  static const textPrimary   = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF8B8BA3);
  static const textMuted     = Color(0xFF5C5C7A);
  static const textHint      = Color(0xFF3E3E5C);

  // ── Borders & glass ──
  static const border        = Color(0xFF222222);
  static const borderSubtle  = Color(0xFF1A1A1A);
  static const glass         = Color(0x05FFFFFF);
  static const glassBorder   = Color(0x0AFFFFFF);

  // ── Gradients ──
  static const purpleGradient = LinearGradient(
    colors: [Color(0xFF7856FF), Color(0xFF5B3FCC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF7856FF), Color(0xFFE8457A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cyanGradient = LinearGradient(
    colors: [Color(0xFF00D4B8), Color(0xFF4E8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Decorations ──
  static BoxDecoration cardDecoration({Color? color, double radius = 20}) => BoxDecoration(
    color: color ?? card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderSubtle),
  );

  static BoxDecoration glassDecoration({double radius = 20, Color? borderColor}) => BoxDecoration(
    color: glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? glassBorder),
  );

  static BoxDecoration glowDecoration({required Color color, double radius = 20, double blur = 8}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color.withValues(alpha: 0.1)),
    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: blur)],
  );

  // ── Avatar presets ──
  static const avatarPresets = <String, Map<String, dynamic>>{
    'default': {'label': 'Default', 'icon': '🌑', 'color': Color(0xFF3A3A5C)},
    'fox':     {'label': 'Fox',     'icon': '🦊', 'color': Color(0xFF8B4513)},
    'void':    {'label': 'Void',    'icon': '🌌', 'color': Color(0xFF2D1B69)},
    'phoenix': {'label': 'Phoenix', 'icon': '🔥', 'color': Color(0xFF8B0000)},
    'prism':   {'label': 'Prism',   'icon': '💎', 'color': Color(0xFF4169E1)},
    'ghost':   {'label': 'Ghost',   'icon': '👻', 'color': Color(0xFF4A4A6A)},
    'wolf':    {'label': 'Wolf',    'icon': '🐺', 'color': Color(0xFF2F4F4F)},
    'dragon':  {'label': 'Dragon',  'icon': '🐉', 'color': Color(0xFF006400)},
  };

  // ── Voice modulator options ──
  static const voiceModulators = ['None', 'Deep Shadow', 'Cosmic Echo', 'Phantom', 'Neon Drift', 'Crystal'];

  // ── Community categories ──
  static const communityCategories = [
    {'name': 'Trending',   'icon': '🔥'},
    {'name': 'Music',      'icon': '🎵'},
    {'name': 'Gaming',     'icon': '🎮'},
    {'name': 'Tech',       'icon': '💻'},
    {'name': 'Art',        'icon': '🎨'},
    {'name': 'Sports',     'icon': '⚽'},
    {'name': 'Anime',      'icon': '🎌'},
    {'name': 'Memes',      'icon': '😂'},
    {'name': 'Movies',     'icon': '🎬'},
    {'name': 'Books',      'icon': '📚'},
    {'name': 'Crypto',     'icon': '🪙'},
    {'name': 'General',    'icon': '💬'},
  ];

  // ── Custom Navigation Transitions ──
  static Route slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }
}
