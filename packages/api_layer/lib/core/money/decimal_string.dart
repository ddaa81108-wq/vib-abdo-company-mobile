/// A non-money decimal value (exchange rate, multiply/divide factor) kept as TEXT.
///
/// HARD RULE: no `double`/`num`/float for any monetary value or rate in the app.
/// The contract requires the server to send/accept rates as decimal STRINGS
/// (e.g. `"9.5"`, `"0.105263"`). This type validates the text and never converts it
/// to a number; display uses MoneyFormatter.formatDecimal (string grouping only).
class DecimalString {
  const DecimalString._(this.value);

  /// Canonical text, e.g. "9.5". Only digits, optional leading '-', optional one '.'.
  final String value;

  static final RegExp _pattern = RegExp(r'^-?\d+(\.\d+)?$');

  /// User input (accepts Arabic-Indic digits and ',' / '٫' as decimal mark). Null if invalid.
  static DecimalString? tryParse(String? input) {
    if (input == null) return null;
    final normalized = _normalizeDigits(input.trim())
        .replaceAll('٫', '.')
        .replaceAll(',', '.');
    if (!_pattern.hasMatch(normalized)) return null;
    return DecimalString._(_stripLeadingZeros(normalized));
  }

  /// Server value. Contract: a JSON STRING. Transitional (🔶 contract §15): the current
  /// server still sends JSON numbers for `exchangeRate`/`egpPerLyd`; the JSON decoder has
  /// already produced a Dart number, so it is turned into text right here, once, with no
  /// arithmetic, and never stored as a number. Remove when the server sends strings.
  static DecimalString? fromJson(Object? v) {
    if (v is String) return tryParse(v);
    if (v is int) return DecimalString._('$v');
    if (v is num) {
      return tryParse(v.toString()); // transitional text conversion only
    }
    return null;
  }

  /// Text form. Wire encoding (string vs number) is decided ONLY by WireJson / ApiConfig.rateWireFormat.
  String toJson() => value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is DecimalString && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// "007.50" -> "7.50", "-00" -> "-0": text edit only, so the value is a valid JSON number literal.
  static String _stripLeadingZeros(String s) {
    final negative = s.startsWith('-');
    var body = negative ? s.substring(1) : s;
    final dot = body.indexOf('.');
    var intPart = dot < 0 ? body : body.substring(0, dot);
    final rest = dot < 0 ? '' : body.substring(dot);
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    body = '$intPart$rest';
    return negative ? '-$body' : body;
  }

  static String _normalizeDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final ch in s.split('')) {
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      out.write(a >= 0 ? '$a' : (p >= 0 ? '$p' : ch));
    }
    return out.toString();
  }
}
