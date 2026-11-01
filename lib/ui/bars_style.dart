import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

// Look of the top strip and phone bottom bar (Ali's pick, 2026-11-01):
// a floating white card strip and a floating dark rounded bottom bar with
// a gold pill on the selected tab.

// Brand colours already used by the home tiles.
const kBrandBlue = Color(0xFF1E3F9A);
const kBrandNavy = Color(0xFF0B2468);
const kBrandGold = Color(0xFFF2B705);
const kBrandGoldIcon = Color(0xFFFFC928);

/// Look of the top status strip.
class StripLook {
  const StripLook({
    required this.background,
    required this.roleStyle,
    required this.dateStyle,
    required this.statusStyle,
    required this.dotColor,
    required this.statusChip,
  });

  final Color background;
  final TextStyle roleStyle;
  final TextStyle dateStyle;
  final TextStyle statusStyle;
  final Color dotColor;
  final BoxDecoration statusChip;

  static const margin = EdgeInsetsDirectional.fromSTEB(10, 8, 10, 0);
  static const radius = BorderRadius.all(Radius.circular(16));
  static const shadow = [
    BoxShadow(color: Color(0x1A0B2468), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const chipPadding = EdgeInsetsDirectional.symmetric(
    horizontal: 10,
    vertical: 3,
  );
}

StripLook stripLook(BuildContext context, {required bool online}) {
  final scheme = Theme.of(context).colorScheme;
  final colors = context.appColors;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final muted = dark ? const Color(0xFFA7B1C2) : const Color(0xFF5B6475);
  return StripLook(
    background: dark ? const Color(0xFF18212E) : Colors.white,
    roleStyle: cairo(13, 800, color: dark ? Colors.white : kBrandNavy),
    dateStyle: cairo(12, 600, color: muted),
    statusStyle: cairo(11.5, 600, color: scheme.onSurface),
    dotColor: online ? colors.success : scheme.error,
    statusChip: BoxDecoration(
      color: online ? colors.successBg : scheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
  );
}

/// Look of the floating phone bottom bar.
abstract final class BarLook {
  static const margin = EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10);
  static const radius = BorderRadius.all(Radius.circular(26));
  static const shadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const indicator = kBrandGold;
  static const selected = kBrandNavy;
}
