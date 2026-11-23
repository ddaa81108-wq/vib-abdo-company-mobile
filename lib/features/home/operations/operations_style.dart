import 'package:flutter/material.dart';

import '../../../ui/theme.dart';

abstract final class OperationsStyle {
  static const navy = Color(0xFF14263B);
  static const gold = Color(0xFFD0B16E);
  static const ivory = Color(0xFFF8F6F1);
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0B1220)
      : ivory;
  static BoxDecoration panel(BuildContext context, {bool featured = false}) =>
      BoxDecoration(
        color: featured ? navy : context.look.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: featured
              ? gold.withValues(alpha: .7)
              : context.look.cardBorder,
        ),
      );
}
