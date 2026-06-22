// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import '../services/doodle_theme.dart';
import 'location_picker_sheet.dart';

/// A reactive location pill that shows the active city/district and lets
/// the user tap it to change their location via [LocationPickerSheet].
class LocationBanner extends StatelessWidget {
  /// Optional label shown before the city name (default: 'Near').
  final String? prefix;

  /// If true, renders in compact pill style (for use inside headers).
  final bool compact;

  const LocationBanner({
    super.key,
    this.prefix,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final doodle = isDoodleMode(context);
    return ValueListenableBuilder<String>(
      valueListenable: locationService.activeDistrictNotifier,
      builder: (context, district, _) {
        final hasLocation = district.isNotEmpty && district != 'Unknown';
        final label = hasLocation ? district : 'Set location';

        if (compact) {
          return _CompactPill(
            label: label,
            hasLocation: hasLocation,
            doodle: doodle,
            onTap: () => showLocationSearchSheet(context),
          );
        }

        return _FullBanner(
          prefix: prefix ?? 'Showing',
          label: label,
          hasLocation: hasLocation,
          doodle: doodle,
          onTap: () => showLocationSearchSheet(context),
        );
      },
    );
  }
}

// ── Compact pill (for headers & nav bars) ────────────────────────────────────
class _CompactPill extends StatelessWidget {
  final String label;
  final bool hasLocation;
  final bool doodle;
  final VoidCallback onTap;

  const _CompactPill({
    required this.label,
    required this.hasLocation,
    required this.doodle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: doodle
            ? BoxDecoration(
                color: DoodleColors.paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DoodleColors.sketchLine, width: 1.5),
              )
            : BoxDecoration(
                color: hasLocation
                    ? const Color(0xFFFF6B00).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasLocation
                      ? const Color(0xFFFF6B00).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 12,
              color: doodle
                  ? DoodleColors.orange
                  : (hasLocation
                      ? const Color(0xFFFF6B00)
                      : Colors.white54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: doodle
                  ? DoodleFonts.caption(
                      color: DoodleColors.textPrimary,
                      fontSize: 12,
                    ).copyWith(fontWeight: FontWeight.w700)
                  : GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasLocation
                          ? const Color(0xFFFF6B00)
                          : Colors.white54,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: doodle
                  ? DoodleColors.textMuted
                  : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full banner (for section headers) ────────────────────────────────────────
class _FullBanner extends StatelessWidget {
  final String prefix;
  final String label;
  final bool hasLocation;
  final bool doodle;
  final VoidCallback onTap;

  const _FullBanner({
    required this.prefix,
    required this.label,
    required this.hasLocation,
    required this.doodle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: doodle
            ? BoxDecoration(
                color: DoodleColors.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DoodleColors.sketchLine, width: 1.5),
              )
            : BoxDecoration(
                gradient: LinearGradient(
                  colors: hasLocation
                      ? [
                          const Color(0xFFFF6B00).withValues(alpha: 0.08),
                          const Color(0xFFFF3D00).withValues(alpha: 0.04),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasLocation
                      ? const Color(0xFFFF6B00).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: doodle
                    ? DoodleColors.orange.withValues(alpha: 0.12)
                    : const Color(0xFFFF6B00).withValues(alpha: 0.15),
              ),
              child: Icon(
                hasLocation ? Icons.location_on : Icons.location_off,
                size: 14,
                color: doodle
                    ? DoodleColors.orange
                    : (hasLocation
                        ? const Color(0xFFFF6B00)
                        : Colors.white38),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prefix,
                    style: doodle
                        ? DoodleFonts.caption(
                            color: DoodleColors.textMuted,
                            fontSize: 10,
                          ).copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            )
                        : GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: doodle
                        ? DoodleFonts.body(
                            color: DoodleColors.textPrimary,
                            fontSize: 13,
                          ).copyWith(fontWeight: FontWeight.w700)
                        : GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: hasLocation ? Colors.white : Colors.white54,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: doodle
                    ? DoodleColors.orange.withValues(alpha: 0.1)
                    : const Color(0xFFFF6B00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: doodle
                      ? DoodleColors.orange.withValues(alpha: 0.3)
                      : const Color(0xFFFF6B00).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Change',
                style: doodle
                    ? DoodleFonts.caption(
                        color: DoodleColors.orange,
                        fontSize: 11,
                      ).copyWith(fontWeight: FontWeight.w700)
                    : GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF6B00),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
