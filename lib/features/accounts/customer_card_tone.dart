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
    this.gloss,
  });

  final Color background;
  final Color border;

  /// Name and secondary text.
  final Color ink;

  /// The status word and the amount: red for debt, green for credit,
  /// brown for zero.
  final Color amount;

  /// Glossy finish for the card, or null for a plain card.
  final Gloss? gloss;
}

CustomerTone _fromGloss(Gloss gloss) => CustomerTone(
  background: gloss.bottom,
  border: gloss.border,
  ink: gloss.ink,
  amount: gloss.amount,
  gloss: gloss,
);

CustomerTone customerTone(BuildContext context, CustomerBalanceKind kind) {
  final look = context.look;
  return switch (kind) {
    CustomerBalanceKind.debt => _fromGloss(look.glossDebt),
    CustomerBalanceKind.credit => _fromGloss(look.glossCredit),
    CustomerBalanceKind.zero => _fromGloss(look.glossZero),
    CustomerBalanceKind.unknown => CustomerTone(
      background: look.card,
      border: look.cardBorder,
      ink: look.ink,
      amount: look.ink,
    ),
  };
}
