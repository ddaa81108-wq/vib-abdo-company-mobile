import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/theme.dart';

/// Which word and colour a customer card uses, from the sign of the server
/// balance only. No arithmetic (Ali, 2026-11-02).
enum CustomerBalanceKind { debt, credit, zero, unknown }

CustomerBalanceKind customerBalanceKind(MoneyValue? balance) {
  final units = balance?.asInt;
  if (units == null) return CustomerBalanceKind.unknown;
  if (units > 0) return CustomerBalanceKind.debt;
  if (units < 0) return CustomerBalanceKind.credit;
  return CustomerBalanceKind.zero;
}

/// Colours for one customer card.
class CustomerTone {
  const CustomerTone({
    required this.background,
    required this.border,
    required this.ink,
    required this.amount,
  });

  final Color background;
  final Color border;

  /// Name and secondary text.
  final Color ink;

  /// The status word and the amount: red for debt, green for credit,
  /// brown for zero.
  final Color amount;
}

CustomerTone customerTone(BuildContext context, CustomerBalanceKind kind) {
  final scheme = Theme.of(context).colorScheme;
  final colors = context.statusColors;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (kind == CustomerBalanceKind.zero) {
    return dark
        ? const CustomerTone(
            background: Color(0xFF3A2B22),
            border: Color(0xFF8D6E63),
            ink: Color(0xFFEBD7C4),
            amount: Color(0xFFD7B899),
          )
        : const CustomerTone(
            background: Color(0xFFF1E4D4),
            border: Color(0xFFB08968),
            ink: Color(0xFF4E342E),
            amount: Color(0xFF6D4C41),
          );
  }
  return CustomerTone(
    background: scheme.surface,
    border: scheme.outlineVariant,
    ink: scheme.onSurface,
    amount: switch (kind) {
      CustomerBalanceKind.debt => colors.debtText,
      CustomerBalanceKind.credit => colors.creditText,
      _ => scheme.onSurface,
    },
  );
}
