import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// Which look the top strip, phone drawer and bottom bar use (Ali's bar
/// options, 2026-11-01). Throwaway option branches differ only in the
/// default. 0 is the look before the options.
const int kBarsStyle = int.fromEnvironment('BARS_STYLE', defaultValue: 1);

// Brand colours already used by the home tiles.
const kBrandBlue = Color(0xFF1E3F9A);
const kBrandNavy = Color(0xFF0B2468);
const kBrandGold = Color(0xFFF2B705);
const kBrandGoldIcon = Color(0xFFFFC928);

bool _dark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Look of the top status strip.
class StripLook {
  const StripLook({
    required this.background,
    required this.roleStyle,
    required this.dateStyle,
    required this.statusStyle,
    required this.dotColor,
    this.border,
    this.margin = EdgeInsets.zero,
    this.radius,
    this.shadow,
    this.roleChip,
    this.statusChip,
    this.roleIcon,
    this.roleIconColor,
  });

  final Color background;
  final BoxBorder? border;
  final EdgeInsetsGeometry margin;
  final BorderRadius? radius;
  final List<BoxShadow>? shadow;
  final TextStyle roleStyle;
  final TextStyle dateStyle;
  final TextStyle statusStyle;
  final Color dotColor;
  final BoxDecoration? roleChip;
  final BoxDecoration? statusChip;
  final IconData? roleIcon;
  final Color? roleIconColor;

  /// What the role text is painted on (chip or strip).
  Color get roleBackground => roleChip?.color ?? background;

  static const chipPadding = EdgeInsetsDirectional.symmetric(
    horizontal: 10,
    vertical: 3,
  );
}

StripLook stripLook(BuildContext context, {required bool online}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final colors = context.appColors;
  final sidebar = context.sidebarPalette;
  final dark = _dark(context);
  final ink = scheme.onSurface;
  final muted = dark ? const Color(0xFFA7B1C2) : const Color(0xFF5B6475);
  final dot = online ? colors.success : scheme.error;
  // Narrow phones drop the role chip icon so the date keeps its words.
  final roomy = MediaQuery.sizeOf(context).width >= 380;
  TextStyle t(double size, FontWeight weight, Color color) =>
      cairo(size, weight.value.toDouble(), color: color);
  switch (kBarsStyle) {
    case 1: // Material 3 tonal
      return StripLook(
        background: dark ? const Color(0xFF151C27) : const Color(0xFFF4F6FB),
        roleStyle: t(12.5, FontWeight.w700, ink),
        dateStyle: t(12, FontWeight.w600, muted),
        statusStyle: t(11.5, FontWeight.w600, ink),
        dotColor: dot,
        roleChip: BoxDecoration(
          color: dark ? const Color(0xFF243152) : const Color(0xFFE1E8F7),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        roleIcon: roomy ? Icons.verified_user_outlined : null,
        roleIconColor: dark ? const Color(0xFFC9D6F5) : kBrandBlue,
        statusChip: BoxDecoration(
          color: online ? colors.successBg : scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      );
    case 2: // iOS: plain bar, hairline
      return StripLook(
        background: dark ? const Color(0xFF0F1115) : const Color(0xFFF9F9FB),
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0x33FFFFFF) : const Color(0x22000000),
            width: 0.5,
          ),
        ),
        roleStyle: t(13, FontWeight.w700, ink),
        dateStyle: t(12, FontWeight.w500, muted),
        statusStyle: t(11.5, FontWeight.w500, online ? muted : scheme.error),
        dotColor: dot,
      );
    case 3: // floating card
      return StripLook(
        background: dark ? const Color(0xFF18212E) : Colors.white,
        margin: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 0),
        radius: BorderRadius.circular(16),
        shadow: const [
          BoxShadow(
            color: Color(0x1A0B2468),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        roleStyle: t(13, FontWeight.w800, dark ? Colors.white : kBrandNavy),
        dateStyle: t(12, FontWeight.w600, muted),
        statusStyle: t(11.5, FontWeight.w600, ink),
        dotColor: dot,
        statusChip: BoxDecoration(
          color: online ? colors.successBg : scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      );
    case 4: // minimal hairline
      return StripLook(
        background: online
            ? (dark ? const Color(0xFF121821) : Colors.white)
            : scheme.errorContainer,
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          ),
        ),
        roleStyle: t(13, FontWeight.w800, ink),
        dateStyle: t(12, FontWeight.w500, muted),
        statusStyle: t(11.5, FontWeight.w600, muted),
        dotColor: dot,
      );
    case 5: // integrated with the app bar
      return StripLook(
        background: colors.sidebarBg,
        border: const Border(
          bottom: BorderSide(color: Color(0x33F2B705), width: 0.5),
        ),
        roleStyle: t(12, FontWeight.w700, sidebar.bright),
        dateStyle: t(12, FontWeight.w600, sidebar.shine),
        statusStyle: t(
          11.5,
          FontWeight.w600,
          online ? const Color(0xFFA6EBC9) : const Color(0xFFFFB4AB),
        ),
        dotColor: online ? const Color(0xFF4ADE9A) : const Color(0xFFFF6B60),
        roleChip: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: const Color(0x99F2B705)),
          color: const Color(0x14F2B705),
        ),
        roleIcon: roomy ? Icons.verified_user_outlined : null,
        roleIconColor: sidebar.bright,
        statusChip: BoxDecoration(
          color: online ? const Color(0x2626C281) : const Color(0x33FF5A5A),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      );
    default:
      return StripLook(
        background: online ? colors.successBg : scheme.errorContainer,
        roleStyle: theme.textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        dateStyle: theme.textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        statusStyle: theme.textTheme.bodySmall!,
        dotColor: dot,
      );
  }
}

/// Look of the phone bottom bar.
class BarLook {
  const BarLook({
    required this.background,
    required this.selected,
    required this.idle,
    this.indicator,
    this.border,
    this.margin = EdgeInsets.zero,
    this.radius,
    this.shadow,
    this.iconPill = false,
    this.topLine = false,
    this.selectedLabel,
  });

  final Color background;
  final Color selected;
  final Color idle;

  /// Pill behind the selected icon (or the whole tab when not [iconPill]).
  final Color? indicator;
  final BoxBorder? border;
  final EdgeInsetsGeometry margin;
  final BorderRadius? radius;
  final List<BoxShadow>? shadow;
  final bool iconPill;

  /// A short gold line on top of the selected tab.
  final bool topLine;
  final Color? selectedLabel;
}

BarLook barLook(BuildContext context) {
  final dark = _dark(context);
  final colors = context.appColors;
  final sidebar = context.sidebarPalette;
  switch (kBarsStyle) {
    case 1:
      return BarLook(
        background: dark ? const Color(0xFF141B26) : const Color(0xFFF4F6FB),
        indicator: dark ? const Color(0xFF2A3A66) : const Color(0xFFD9E2F6),
        selected: dark ? Colors.white : kBrandNavy,
        idle: dark ? const Color(0xFFA7B1C2) : const Color(0xFF5B6475),
        iconPill: true,
      );
    case 2:
      return BarLook(
        background: dark ? const Color(0xF20F1115) : const Color(0xF2F9F9FB),
        border: Border(
          top: BorderSide(
            color: dark ? const Color(0x33FFFFFF) : const Color(0x22000000),
            width: 0.5,
          ),
        ),
        selected: dark ? kBrandGoldIcon : kBrandBlue,
        idle: dark ? const Color(0xFF8E8E93) : const Color(0xFF8A8A8F),
      );
    case 3:
      return BarLook(
        background: colors.sidebarBg,
        margin: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
        radius: BorderRadius.circular(26),
        shadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        indicator: kBrandGold,
        selected: kBrandNavy,
        idle: colors.sidebarMuted,
      );
    case 4:
      return BarLook(
        background: dark ? const Color(0xFF121821) : Colors.white,
        border: Border(
          top: BorderSide(
            color: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          ),
        ),
        selected: dark ? kBrandGoldIcon : kBrandBlue,
        idle: dark ? const Color(0xFF8C96A8) : const Color(0xFF6B7280),
        topLine: true,
      );
    case 5:
      return BarLook(
        background: colors.sidebarBg,
        border: const Border(
          top: BorderSide(color: Color(0x33F2B705), width: 0.5),
        ),
        indicator: kBrandGold,
        selected: kBrandNavy,
        selectedLabel: sidebar.bright,
        idle: colors.sidebarMuted,
        iconPill: true,
      );
    default:
      return BarLook(
        background: colors.sidebarBg,
        indicator: sidebar.glowSoft,
        selected: sidebar.bright,
        idle: colors.sidebarMuted,
      );
  }
}
