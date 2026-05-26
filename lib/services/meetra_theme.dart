// Meetra Premium Design System
// Centralized design tokens for light/dark mode
// Inspired by Stitch "Obsidian Orbit" + Spark Luxury Light

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Palette ───────────────────────────────────────────────

class MeetraColors {
  final Brightness brightness;

  const MeetraColors._({required this.brightness});

  static MeetraColors of(BuildContext context) {
    return MeetraColors._(brightness: Theme.of(context).brightness);
  }

  bool get isDark => brightness == Brightness.dark;

  // ── Backgrounds ──
  Color get scaffold => isDark ? const Color(0xFF000000) : const Color(0xFFFFF8F0);
  Color get surface => isDark ? const Color(0xFF0C0E14) : const Color(0xFFFFFDF9);
  Color get surfaceDim => isDark ? const Color(0xFF040507) : const Color(0xFFF5EDE3);
  Color get surfaceBright => isDark ? const Color(0xFF161922) : const Color(0xFFFFFFFF);

  // ── Card Surfaces ──
  Color get card => isDark ? const Color(0xFF0A0C12) : Colors.white.withValues(alpha: 0.85);
  Color get cardHover => isDark ? const Color(0xFF141722) : Colors.white.withValues(alpha: 0.92);
  Color get cardBorder => isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE8DDD0).withValues(alpha: 0.6);
  Color get cardShadowColor => isDark ? const Color(0xFFFF5C00).withValues(alpha: 0.04) : const Color(0xFFB48C64).withValues(alpha: 0.12);

  // ── Primary ──
  Color get primary => isDark ? const Color(0xFFFF6B00) : const Color(0xFF8A2BE2);
  Color get primaryContainer => isDark ? const Color(0xFFFF5C00) : const Color(0xFF6A1BB4);
  Color get onPrimary => isDark ? Colors.white : Colors.white;
  Color get primaryMuted => isDark ? const Color(0xFFFF6B00).withValues(alpha: 0.15) : const Color(0xFF8A2BE2).withValues(alpha: 0.08);

  // ── Secondary ──
  Color get secondary => isDark ? const Color(0xFFFF8A00) : const Color(0xFFD4A574);
  Color get secondaryContainer => isDark ? const Color(0xFFFF6B00) : const Color(0xFFC8956E);
  Color get onSecondary => isDark ? Colors.white : Colors.white;

  // ── Tertiary ──
  Color get tertiary => isDark ? const Color(0xFFFF9E80) : const Color(0xFFFF6B8A);
  Color get tertiaryContainer => isDark ? const Color(0xFFFF3D00) : const Color(0xFFFF4D6D);

  // ── Text ──
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get textSecondary => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B5B4F);
  Color get textTertiary => isDark ? const Color(0xFF616161) : const Color(0xFF9B8E84);
  Color get textOnAccent => Colors.white;

  // ── Accent Neon ──
  Color get neonCyan => isDark ? const Color(0xFFFF6B00) : const Color(0xFF00BCD4);
  Color get neonPurple => isDark ? const Color(0xFFFF7E40) : const Color(0xFF8A2BE2);
  Color get neonPink => isDark ? const Color(0xFFFF3D00) : const Color(0xFFFF4D6D);
  Color get gold => isDark ? const Color(0xFFFFC107) : const Color(0xFFD4A574);

  // ── Status ──
  Color get success => isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E);
  Color get error => isDark ? const Color(0xFFFF8A80) : const Color(0xFFDC2626);
  Color get warning => isDark ? const Color(0xFFFFC107) : const Color(0xFFF59E0B);

  // ── Navigation ──
  Color get navBarBg => isDark
      ? const Color(0xFF000000).withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.75);
  Color get navBarBorder => isDark
      ? Colors.white.withValues(alpha: 0.04)
      : const Color(0xFFE8DDD0).withValues(alpha: 0.4);
  Color get navActive => isDark ? const Color(0xFFFF6B00) : const Color(0xFF8A2BE2);
  Color get navInactive => isDark ? Colors.white60 : const Color(0xFF9B8E84);

  // ── Input ──
  Color get inputBg => isDark ? const Color(0xFF0C0E14) : Colors.white.withValues(alpha: 0.7);
  Color get inputBorder => isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8DDD0);
  Color get inputFocusBorder => isDark ? const Color(0xFFFF6B00) : const Color(0xFF8A2BE2);
  Color get inputHint => isDark ? const Color(0xFF616161) : const Color(0xFF9B8E84);

  // ── Divider ──
  Color get divider => isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8DDD0).withValues(alpha: 0.5);

  // ── Overlay ──
  Color get overlay => isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3);
  Color get shimmerBase => isDark ? const Color(0xFF0C0E14) : const Color(0xFFF5EDE3);
  Color get shimmerHighlight => isDark ? const Color(0xFF1C1F2E) : const Color(0xFFFFFDF9);

  // ── Chip / Tag ──
  Color get chipBg => isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5EDE3);
  Color get chipText => isDark ? Colors.white70 : const Color(0xFF6B5B4F);
  Color get chipBorder => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8DDD0);
}

// ─── Gradients ───────────────────────────────────────────────────

class MeetraGradients {
  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Page background gradient
  static LinearGradient background(BuildContext context) {
    return _isDark(context)
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000000), Color(0xFF06070B), Color(0xFF000000)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8F0), Color(0xFFFFF0E0), Color(0xFFFFF8F0)],
          );
  }

  /// Primary accent gradient (buttons, highlights)
  static LinearGradient primaryAccent(BuildContext context) {
    return _isDark(context)
        ? const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8A00)])
        : const LinearGradient(colors: [Color(0xFF8A2BE2), Color(0xFFD4A574)]);
  }

  /// Holographic card gradient (feature cards like "My Hosted", "Joined")
  static LinearGradient holographicCard(BuildContext context) {
    return _isDark(context)
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B00).withValues(alpha: 0.15),
              const Color(0xFFFF8A00).withValues(alpha: 0.1),
              Colors.transparent,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8E8FF),  // Soft pink
              Color(0xFFE8FFF0),  // Soft mint
              Color(0xFFE8F0FF),  // Soft lavender
            ],
          );
  }

  /// Glass overlay gradient
  static LinearGradient glassOverlay(BuildContext context) {
    return _isDark(context)
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.8),
              Colors.white.withValues(alpha: 0.5),
            ],
          );
  }

  /// Warm silk gradient (light mode decorative background waves)
  static LinearGradient warmSilk() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFE8C9A0),
        Color(0xFFD4A574),
        Color(0xFFC8956E),
        Color(0xFFE8C9A0),
      ],
    );
  }

  /// Nebula glow (dark mode decorative background)
  static RadialGradient nebulaGlow() {
    return RadialGradient(
      center: Alignment.center,
      radius: 1.5,
      colors: [
        const Color(0xFFFF6B00).withValues(alpha: 0.08),
        const Color(0xFFFF8A00).withValues(alpha: 0.04),
        Colors.transparent,
      ],
    );
  }

  /// Bottom nav bar gradient overlay
  static LinearGradient navBarGradient(BuildContext context) {
    return _isDark(context)
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF000000).withValues(alpha: 0.0),
              const Color(0xFF000000).withValues(alpha: 0.9),
            ],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF8F0).withValues(alpha: 0.0),
              const Color(0xFFFFF8F0).withValues(alpha: 0.9),
            ],
          );
  }
}

// ─── Typography ──────────────────────────────────────────────────

class MeetraTypography {
  static TextStyle _base(BuildContext context) {
    final colors = MeetraColors.of(context);
    return GoogleFonts.outfit(color: colors.textPrimary);
  }

  static TextStyle displayLg(BuildContext context) => _base(context).copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle headlineMd(BuildContext context) => _base(context).copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle headlineSm(BuildContext context) => _base(context).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle titleLg(BuildContext context) => _base(context).copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle titleMd(BuildContext context) => _base(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle bodyLg(BuildContext context) => _base(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      );

  static TextStyle bodyMd(BuildContext context) => _base(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle bodySm(BuildContext context) => _base(context).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle labelLg(BuildContext context) => _base(context).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  static TextStyle labelMd(BuildContext context) => _base(context).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.2,
      );

  static TextStyle labelSm(BuildContext context) => _base(context).copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.2,
      );

  static TextStyle caption(BuildContext context) {
    final colors = MeetraColors.of(context);
    return _base(context).copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: colors.textTertiary,
      height: 1.4,
    );
  }
}

// ─── Spacing ─────────────────────────────────────────────────────

class MeetraSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const double pagePadding = 20;
  static const double cardPadding = 16;
  static const double sectionGap = 24;
}

// ─── Border Radius ───────────────────────────────────────────────

class MeetraRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;

  static BorderRadius get xsBr => BorderRadius.circular(xs);
  static BorderRadius get smBr => BorderRadius.circular(sm);
  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
  static BorderRadius get xlBr => BorderRadius.circular(xl);
  static BorderRadius get xxlBr => BorderRadius.circular(xxl);
  static BorderRadius get fullBr => BorderRadius.circular(full);
}

// ─── Animations ──────────────────────────────────────────────────

class MeetraAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 400);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve springCurve = Curves.easeOutBack;

  /// Staggered delay for list items
  static Duration staggerDelay(int index) =>
      Duration(milliseconds: 50 * index.clamp(0, 10));
}

// ─── Decorations ─────────────────────────────────────────────────

class MeetraDecorations {
  /// Standard glass card
  static BoxDecoration glassCard(BuildContext context, {double radius = 16}) {
    final colors = MeetraColors.of(context);
    return BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: colors.cardShadowColor,
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Elevated glass card (for featured / active items)
  static BoxDecoration elevatedGlassCard(BuildContext context, {double radius = 16}) {
    final colors = MeetraColors.of(context);
    return BoxDecoration(
      color: colors.cardHover,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: colors.cardShadowColor,
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
        if (colors.isDark)
          BoxShadow(
            color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: -5,
          ),
      ],
    );
  }

  /// Holographic feature card (My Hosted, Joined, etc.)
  static BoxDecoration holographicCard(BuildContext context, {double radius = 16}) {
    return BoxDecoration(
      gradient: MeetraGradients.holographicCard(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: MeetraColors.of(context).isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.6),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: MeetraColors.of(context).cardShadowColor,
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Input field decoration
  static InputDecoration inputDecoration(BuildContext context, {
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final colors = MeetraColors.of(context);
    return InputDecoration(
      hintText: hintText,
      hintStyle: MeetraTypography.bodyMd(context).copyWith(color: colors.inputHint),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: MeetraRadius.mdBr,
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: MeetraRadius.mdBr,
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: MeetraRadius.mdBr,
        borderSide: BorderSide(color: colors.inputFocusBorder, width: 1.5),
      ),
    );
  }

  /// Frosted search bar decoration
  static BoxDecoration searchBar(BuildContext context) {
    final colors = MeetraColors.of(context);
    return BoxDecoration(
      color: colors.inputBg,
      borderRadius: MeetraRadius.fullBr,
      border: Border.all(color: colors.inputBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: colors.cardShadowColor,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Chip / tag decoration
  static BoxDecoration chip(BuildContext context, {bool isSelected = false}) {
    final colors = MeetraColors.of(context);
    return BoxDecoration(
      color: isSelected ? colors.primaryMuted : colors.chipBg,
      borderRadius: MeetraRadius.fullBr,
      border: Border.all(
        color: isSelected ? colors.primary : colors.chipBorder,
        width: 1,
      ),
    );
  }

  /// Bottom navigation bar decoration
  static BoxDecoration navBar(BuildContext context) {
    final colors = MeetraColors.of(context);
    return BoxDecoration(
      color: colors.navBarBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(
        top: BorderSide(color: colors.navBarBorder, width: 0.5),
      ),
    );
  }
}

// ─── Theme Builder ───────────────────────────────────────────────

class MeetraThemeBuilder {
  static ThemeData light() {
    const primary = Color(0xFF8A2BE2);
    const secondary = Color(0xFFD4A574);
    const surface = Color(0xFFFFF8F0);
    const onSurface = Color(0xFF1A1A2E);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        onPrimary: Colors.white,
        error: Color(0xFFDC2626),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.outfit(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8DDD0)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8DDD0),
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData dark() {
    const primary = Color(0xFFFF6B00);
    const secondary = Color(0xFFFF5C00);
    const surface = Color(0xFF050508);
    const onSurface = Color(0xFFEEDDEE);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        onPrimary: Color(0xFF003032),
        error: Color(0xFFFFB4AB),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.outfit(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1122),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF130B16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1122),
        contentTextStyle: GoogleFonts.outfit(color: onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
