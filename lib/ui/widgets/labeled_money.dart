import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'common.dart';

/// Server amount that stays one line and scales down instead of clipping.
class ScaledMoney extends StatelessWidget {
  const ScaledMoney(
    this.value, {
    super.key,
    this.style,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String value;
  final TextStyle? style;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: MoneyText(value, style: style ?? context.textExtras.amount),
    );
  }
}

/// Arabic label on the start side and the server amount on the end side.
///
/// The amount is LTR. It keeps its own width until it would overflow, then
/// scales down. Nothing is summed or reformatted here.
class LabeledMoney extends StatelessWidget {
  const LabeledMoney({
    required this.label,
    required this.value,
    super.key,
    this.valueStyle,
    this.labelStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedLabel = labelStyle ?? theme.textTheme.bodyMedium;
    final resolvedValue = valueStyle ?? context.textExtras.amount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxValue = constraints.maxWidth.isFinite
            ? constraints.maxWidth * 0.62
            : 240.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: resolvedLabel)),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxValue),
              child: ScaledMoney(
                value,
                style: resolvedValue,
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        );
      },
    );
  }
}
