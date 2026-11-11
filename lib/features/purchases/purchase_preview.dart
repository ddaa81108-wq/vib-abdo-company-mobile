/// JavaScript's `Number.MAX_SAFE_INTEGER`. The website refuses a preview
/// outside this range (`purchaseRunningBalance.ts` `safe`).
const _maxSafe = 9007199254740991;
final _maxSafeBig = BigInt.from(_maxSafe);

/// Display-only copy of the website's browser formula. Nothing here is sent
/// to the server. The saved row still comes back from the API.
///
/// `positiveRateMicros` and `convertedWholeUnits(..., 'nearest')` are
/// `src/shared/moneyCalculation.ts` lines 4–24. The server's `roundedResult`
/// (`purchaseSupport.ts` lines 59–64) is the same nearest-integer division.
/// `purchaseDraftTotals` (`purchaseEditorModel.ts` lines 78–82) turns a blank
/// rate into result 0. `purchasePreviewBalance` (`purchaseRunningBalance.ts`
/// lines 22–25) is `before + (result − paid)`, or null when that sum is not
/// a safe integer.

int? positiveRateMicros(String raw) {
  final text = raw.trim();
  if (!RegExp(r'^\d{1,10}(?:\.\d{1,6})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final fraction = (parts.length > 1 ? parts[1] : '').padRight(6, '0');
  final micros =
      BigInt.parse(parts[0]) * BigInt.from(1000000) + BigInt.parse(fraction);
  if (micros <= BigInt.zero || micros > _maxSafeBig) return null;
  return micros.toInt();
}

/// Nearest whole units. Exact halves move away from zero for a positive
/// value, because the website adds `denominator / 2n` before truncating.
int? convertedWholeUnits({
  required int value,
  required int rateMicros,
  required bool multiply,
}) {
  if (value < 0 ||
      value > _maxSafe ||
      rateMicros <= 0 ||
      rateMicros > _maxSafe) {
    return null;
  }
  final numerator =
      BigInt.from(value) *
      (multiply ? BigInt.from(rateMicros) : BigInt.from(1000000));
  final denominator = multiply ? BigInt.from(1000000) : BigInt.from(rateMicros);
  final result = (numerator + denominator ~/ BigInt.two) ~/ denominator;
  if (result < BigInt.zero || result > _maxSafeBig) return null;
  return result.toInt();
}

/// Website `purchaseDraftTotals().result`. A blank or unusable rate is 0.
int purchaseDraftResult({
  required String valueText,
  required String rateText,
  required bool multiply,
}) {
  final value = _draftWhole(valueText);
  final rate = positiveRateMicros(rateText);
  if (value == null || rate == null) return 0;
  return convertedWholeUnits(
        value: value,
        rateMicros: rate,
        multiply: multiply,
      ) ??
      0;
}

/// Website `purchasePreviewBalance(before, remaining)`.
///
/// [before] for a new row is the open day's `totalDebtUnits`
/// (`PurchaseRegister.tsx` line 92). For an open editor it is that row's
/// running `before`. An unusable payment, a missing anchor, or a sum outside
/// the safe range is null, which the cell prints as «—».
int? purchasePreviewBalance({
  required int? before,
  required String valueText,
  required String rateText,
  required String paidText,
  required bool multiply,
}) {
  if (before == null || before.abs() > _maxSafe) return null;
  final paid = _draftWhole(paidText);
  if (paid == null) return null;
  final result = purchaseDraftResult(
    valueText: valueText,
    rateText: rateText,
    multiply: multiply,
  );
  final remaining = BigInt.from(result) - BigInt.from(paid);
  if (remaining.abs() > _maxSafeBig) return null;
  final sum = BigInt.from(before) + remaining;
  if (sum.abs() > _maxSafeBig) return null;
  return sum.toInt();
}

/// Empty text is 0 (`Number(draft.paid || 0)`). Anything that is not a
/// non-negative safe integer is null, matching `Number` not being a safe integer.
int? _draftWhole(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 0;
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  final value = BigInt.tryParse(text);
  if (value == null || value > _maxSafeBig) return null;
  return value.toInt();
}
