import '../network/api_exception.dart';

/// Original text of a JSON number that is not a plain integer.
/// Never converted through [double].
class JsonNumber {
  const JsonNumber(this.literal);
  final String literal;

  @override
  String toString() => literal;
}

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

  /// User input (Arabic-Indic digits and '٫' as the decimal mark).
  /// ',' is a thousands separator and is rejected, not treated as a decimal mark.
  static DecimalString? tryParse(String? input) {
    if (input == null) return null;
    final normalized = _normalizeDigits(input.trim()).replaceAll('٫', '.');
    if (normalized.contains(',') ||
        normalized.contains('e') ||
        normalized.contains('E')) {
      return null;
    }
    if (!_pattern.hasMatch(normalized)) return null;
    return DecimalString._(_stripLeadingZeros(normalized));
  }

  /// Server value. A JSON string or a [JsonNumber] whose literal was copied from
  /// the raw body. A [double] is rejected: `num.toString()` would turn `1e-7`
  /// into a different token. Thousands separators and exponent notation are
  /// [InvalidServerResponseException].
  static DecimalString? fromJson(Object? v) {
    if (v == null) return null;
    if (v is JsonNumber) return _fromServerToken(v.literal);
    if (v is int) return DecimalString._('$v');
    if (v is String) return _fromServerToken(v);
    throw const InvalidServerResponseException();
  }

  static DecimalString _fromServerToken(String raw) {
    final s = raw.trim();
    if (s.contains(',') ||
        s.contains('٬') ||
        s.contains('e') ||
        s.contains('E')) {
      throw const InvalidServerResponseException();
    }
    if (!_pattern.hasMatch(s)) {
      throw const InvalidServerResponseException();
    }
    return DecimalString._(_stripLeadingZeros(s));
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
