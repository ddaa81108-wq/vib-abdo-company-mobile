import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

// Look of the top strip and phone bottom bar (layout: Ali's pick,
// 2026-11-01; colours: concepts 1 and 3, 2026-11-03): a floating card strip
// and a floating rounded bottom bar with a tinted pill on the selected tab.

/// Look of the top status strip.
class StripLook {
  const StripLook({
    required this.background,
    required this.border,
    required this.shadow,
    required this.roleStyle,
    required this.dateStyle,
    required this.statusStyle,
    required this.dotColor,
    required this.statusChip,
  });

  final Color background;
  final Color border;
  final List<BoxShadow> shadow;
  final TextStyle roleStyle;
  final TextStyle dateStyle;
  final TextStyle statusStyle;
  final Color dotColor;
  final BoxDecoration statusChip;

  static const margin = EdgeInsetsDirectional.fromSTEB(10, 8, 10, 0);
  static const radius = BorderRadius.all(Radius.circular(16));
  static const chipPadding = EdgeInsetsDirectional.symmetric(
    horizontal: 10,
    vertical: 3,
  );
}

StripLook stripLook(BuildContext context, {required bool online}) {
  final scheme = Theme.of(context).colorScheme;
  final colors = context.appColors;
  final look = context.look;
  return StripLook(
    background: look.strip,
    border: look.cardBorder,
    shadow: look.cardShadow,
    roleStyle: cairo(13, 700, color: look.ink),
    dateStyle: cairo(12, 500, color: look.muted),
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
  static const radius = BorderRadius.all(Radius.circular(24));
  static const shadow = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 30, offset: Offset(0, 8)),
  ];
}
