import 'package:flutter_api_layer/api_layer.dart';

/// The website's «الباقي» column, from
/// `src/client/sections/purchases/purchaseRunningBalance.ts`.
///
/// The API field `remainingUnits` is the row's own `result − paid`
/// (`purchaseSupport.ts` `parseEntry`). The website does not print that.
/// It anchors at the open day's server `totalDebtUnits` and walks the loaded
/// rows from newest to oldest:
///
/// ```
/// after = balance
/// before = after − result + paid
/// balance = before
/// ```
///
/// The cell shows `after`. An older page does not restart the walk, because
/// the anchor is the current day's closing total. If the anchor is missing,
/// or any loaded row has an invalid result or payment, every cell is blank
/// (the website returns an empty map).
Map<String, int>? purchaseRunningAfter({
  required List<PurchaseEntryDto> oldestFirst,
  required int? closingUnits,
}) {
  if (closingUnits == null) return null;
  var balance = closingUnits;
  final after = <String, int>{};
  for (var i = oldestFirst.length - 1; i >= 0; i--) {
    final entry = oldestFirst[i];
    final result = entry.resultUnits;
    final paid = entry.paidUnits;
    final resultUnits = result?.units;
    final paidUnits = paid?.units;
    if (result == null ||
        paid == null ||
        result.isInvalid ||
        paid.isInvalid ||
        resultUnits == null ||
        paidUnits == null) {
      return null;
    }
    after[entry.id] = balance;
    balance = balance - resultUnits + paidUnits;
  }
  return after;
}
