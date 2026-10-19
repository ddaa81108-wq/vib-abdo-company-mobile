/// THE ONLY place in the app that turns a server money value into text.
///
/// HARD RULE: the app performs NO calculations. The real server returns money as
/// integers named `*Units` (e.g. balanceUnits) and provides NO formatted field.
/// This class is a pure presentation formatter:
///   - input: one raw integer from the server + its currency;
///   - output: a display string (sign, thousands separators, optional decimal point, symbol);
///   - it works on the DIGIT STRING only (no division, no rounding, no sums/differences);
///   - it never combines two values and never converts between currencies.
/// If the server later adds a formatted field, prefer it and keep this as fallback.
enum Currency {
  lyd('LYD', 'د.ل'),
  egp('EGP', 'ج.م');

  const Currency(this.code, this.symbol);
  final String code;
  final String symbol;

  static Currency? fromCode(Object? code) {
    final c = '$code'.toUpperCase();
    for (final v in values) {
      if (v.code == c) return v;
    }
    return null;
  }
}

class MoneyFormatter {
  /// [unitScale] = fractional digits encoded in *Units (observed: 0 -> whole units). 🔶
  const MoneyFormatter(
      {this.unitScale = 0,
      this.groupSeparator = ',',
      this.decimalSeparator = '.'});

  final int unitScale;
  final String groupSeparator;
  final String decimalSeparator;

  /// e.g. format(-125000, Currency.lyd) -> "-125,000 د.ل"
  String format(int units, Currency currency) =>
      '${formatNumber(units, scale: unitScale)} ${currency.symbol}';

  /// Server-provided `null` -> dash (never substitute 0).
  String formatOrDash(int? units, Currency currency) =>
      units == null ? '—' : format(units, currency);

  /// Scaled integer (e.g. factorMicros with scale 6) to text — still string-only.
  String formatScaled(int scaledValue, int scale) =>
      formatNumber(scaledValue, scale: scale, trimTrailingZeros: true);

  /// Digit-string formatting. No arithmetic is performed on the value.
  String formatNumber(int value,
      {int scale = 0, bool trimTrailingZeros = false}) {
    final raw = value.toString();
    final negative = raw.startsWith('-');
    var digits = negative ? raw.substring(1) : raw;

    var fraction = '';
    if (scale > 0) {
      digits = digits.padLeft(scale + 1, '0');
      final cut = digits.length - scale;
      fraction = digits.substring(cut);
      digits = digits.substring(0, cut);
      if (trimTrailingZeros) {
        fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
      }
    }

    final grouped = _group(digits);
    final sign = negative ? '-' : '';
    return fraction.isEmpty
        ? '$sign$grouped'
        : '$sign$grouped$decimalSeparator$fraction';
  }

  String _group(String digits) {
    final out = StringBuffer();
    final lead = digits.length % 3;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (i - lead) % 3 == 0) out.write(groupSeparator);
      out.write(digits[i]);
    }
    return out.toString();
  }
}
