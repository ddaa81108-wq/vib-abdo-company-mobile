import 'package:flutter_api_layer/api_layer.dart';

/// A successful movement.
///
/// [balanceUnits] is [MutationAck.balanceUnits]. Null means the server omitted
/// it. An invalid value is not a number. The screen does not replace either
/// with a computed balance or with the balance from before the payment.
class PostedMovement {
  const PostedMovement({this.balanceUnits});

  final MoneyValue? balanceUnits;
}
