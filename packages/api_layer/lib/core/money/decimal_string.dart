import '../network/api_exception.dart';
import '../network/precise_json.dart';

/// A non-money decimal value (exchange rate, multiply/divide factor) kept as TEXT.
///
/// HARD RULE: no `double`/`num`/float for any monetary value or rate in the app.
/// Per API contract, the server sends and accepts rates as decimal STRINGS
/// (e.g. `"9.5"`, `"0.105263"`). This type validates the text and never converts it
/// to a number; display uses MoneyFormatter.formatDecimal (string grouping only).
class DecimalString {
  const DecimalString._(this.value);

  /// Validated text, kept verbatim after digit and decimal-separator normalization.
  /// Only digits, optional leading '-', optional one '.'. Leading zeros stay.
  final String value;

  static final RegExp _pattern = RegExp(r'^-?\d+(\.\d+)?$');

  /// USER INPUT. Arabic-Indic and Persian digits are normalized to ASCII.
  /// At most one of ',' '٫' '.' may appear, and that single mark is the decimal
  /// separator. Repeated marks, mixed marks, grouping, and exponents are rejected.
  /// The matched text is stored verbatim (no leading-zero rewrite). Null if invalid.
  static DecimalString? tryParse(String? input) {
    if (input == null) return null;
    final normalized = _normalizeRate(input.trim());
    if (normalized == null || !_pattern.hasMatch(normalized)) return null;
    return DecimalString._(normalized);
  }

  /// Server value, per API contract. null/missing -> null. Accepted: a JSON string, an int, or
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
    return DecimalString._(text);
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

  /// ASCII digits for user input. Arabic-Indic and Persian digits map to 0-9.
  static String normalizeDigits(String s) => _normalizeDigits(s);

  /// One decimal mark among comma, Arabic decimal, and dot. Null when mixed,
  /// repeated, or an exponent is present.
  static String? _normalizeRate(String raw) {
    if (raw.isEmpty) return null;
    if (raw.contains('e') || raw.contains('E')) return null;
    final text = _normalizeDigits(raw);
    const marks = [',', '٫', '.'];
    final used = <String>[];
    for (final mark in marks) {
      final count = mark.allMatches(text).length;
      if (count > 1) return null;
      if (count == 1) used.add(mark);
    }
    if (used.length > 1) return null;
    if (used.isEmpty) return text;
    return text.replaceAll(used.single, '.');
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
