import '../network/api_exception.dart';
import '../network/precise_json.dart';

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

  /// USER INPUT. Accepts Arabic-Indic/Persian digits and the Arabic decimal mark '٫'.
  /// Rejects ',' (ambiguous with a thousands separator: "1,000" must never become 1.000)
  /// and exponents ("1e5", "1E-2"). Null if invalid.
  static DecimalString? tryParse(String? input) {
    if (input == null) return null;
    final normalized = _normalizeDigits(input.trim()).replaceAll('٫', '.');
    if (!_pattern.hasMatch(normalized)) return null;
    return DecimalString._(_stripLeadingZeros(normalized));
  }

  /// SERVER VALUE (contract §2). null/missing -> null. Accepted: a JSON string, an int, or
  /// a [JsonNumberText] (the EXACT numeric text from the body, preserved by PreciseJson —
  /// never `toString()` of a double). The text must be plain ASCII `-?digits(.digits)?`:
  /// comma separators, exponents (1e5, 1E-2), Arabic digits, or a Dart `double` (text
  /// already lost) => [InvalidServerResponseException].
  static DecimalString? fromJson(Object? v) {
    if (v == null) return null;
    final String text;
    if (v is String) {
      text = v.trim();
    } else if (v is int) {
      text = '$v';
    } else if (v is JsonNumberText) {
      text = v.text;
    } else {
      throw const InvalidServerResponseException(
          message: 'استجابة الخادم غير صالحة (قيمة عشرية بنوع غير مدعوم)');
    }
    if (!_pattern.hasMatch(text)) {
      throw const InvalidServerResponseException(
          message: 'استجابة الخادم غير صالحة (قيمة عشرية بصيغة غير مقبولة)');
    }
    return DecimalString._(_stripLeadingZeros(text));
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
