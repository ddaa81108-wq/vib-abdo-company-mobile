import 'package:flutter_api_layer/api_layer.dart';

/// Display-only preview for a direct partial payment that is above the
/// balance the server just returned.
///
/// Whole currency units, scale 0. This is not stored, not sent, and not the
/// balance shown after a successful save.
class OverpaymentPreview {
  const OverpaymentPreview({
    required this.overageUnits,
    required this.expectedBalanceUnits,
  });

  /// `amount − balance`. Positive when the payment is above the balance.
  final int overageUnits;

  /// `balance − amount`. Negative when the payment is above the balance.
  final int expectedBalanceUnits;

  /// Null when [amountUnits] does not exceed [balanceUnits].
  static OverpaymentPreview? aboveBalance({
    required int amountUnits,
    required int balanceUnits,
  }) {
    if (amountUnits <= balanceUnits) return null;
    return OverpaymentPreview(
      overageUnits: amountUnits - balanceUnits,
      expectedBalanceUnits: balanceUnits - amountUnits,
    );
  }
}

/// A successful movement. [balanceUnits] is the integer on the mutation
/// `data` object when the server sent one. It is null when that field is
/// absent. The UI does not fill it in.
class PostedMovement {
  const PostedMovement({this.balanceUnits});

  final int? balanceUnits;
}

/// Integer `balanceUnits` from a mutation acknowledgement, if the server
/// included one. Anything else stays null.
int? postedBalanceUnits(MutationAck ack) {
  final value = ack.raw['balanceUnits'];
  if (value is int) return value;
  return null;
}
