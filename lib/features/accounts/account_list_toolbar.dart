import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';

/// Two equal controls in the space formerly occupied by section search.
/// Keep the existing card-border/button styling independent of list data.
class AccountListToolbar extends StatelessWidget {
  const AccountListToolbar({
    super.key,
    required this.active,
    required this.assign,
  });

  final Widget active;
  final Widget assign;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = 28 + 12 * scale.clamp(1.0, 2.0);
    return TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, height),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(color: look.cardBorder),
          ),
          foregroundColor: look.accent,
          backgroundColor: look.card,
          textStyle: cairo(13, 700),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(height: height, child: active),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(height: height, child: assign),
          ),
        ],
      ),
    );
  }
}
