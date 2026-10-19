import 'dart:convert';

/// A JSON number that is not a plain integer (it has a fraction or an exponent, or is
/// too large for `int`), kept as the EXACT text from the response body.
/// Never converted to `double`. Consumers decide: `DecimalString.fromJson` validates the
/// text, `unitsOrNull` rejects it as INVALID_SERVER_RESPONSE.
class JsonNumberText {
  const JsonNumberText(this.text);
  final String text;

  /// Logging/re-encoding only: emitted as a JSON string (never a double).
  String toJson() => text;

  @override
  String toString() => text;

  @override
  bool operator ==(Object other) => other is JsonNumberText && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Strict RFC 8259 JSON decoder that preserves numeric text, per API contract.
/// Output types: Map<String, dynamic>, List<dynamic>, String, bool, null,
/// int (integer literals that fit), JsonNumberText (everything else). No double, ever.
/// Throws [FormatException] on malformed input.
class PreciseJson {
  PreciseJson._(this._s);
  final String _s;
  int _i = 0;

  static Object? decode(String source) {
    final p = PreciseJson._(source);
    p._ws();
    final v = p._value();
    p._ws();
    if (p._i != source.length) p._fail('Unexpected trailing characters');
    return v;
  }

  static final RegExp _number =
      RegExp(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?');
  static final RegExp _intOnly = RegExp(r'^-?(?:0|[1-9][0-9]*)$');

  Never _fail(String m) => throw FormatException(m, _s, _i);

  void _ws() {
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        _i++;
      } else {
        break;
      }
    }
  }

  Object? _value() {
    if (_i >= _s.length) _fail('Unexpected end of input');
    final c = _s[_i];
    switch (c) {
      case '{':
        return _object();
      case '[':
        return _array();
      case '"':
        return _string();
      case 't':
        return _literal('true', true);
      case 'f':
        return _literal('false', false);
      case 'n':
        return _literal('null', null);
      default:
        return _num();
    }
  }

  Object? _literal(String word, Object? v) {
    if (!_s.startsWith(word, _i)) _fail('Invalid literal');
    _i += word.length;
    return v;
  }

  Map<String, dynamic> _object() {
    _i++; // {
    final out = <String, dynamic>{};
    _ws();
    if (_i < _s.length && _s[_i] == '}') {
      _i++;
      return out;
    }
    while (true) {
      _ws();
      if (_i >= _s.length || _s[_i] != '"') _fail('Expected string key');
      final k = _string();
      _ws();
      if (_i >= _s.length || _s[_i] != ':') _fail('Expected ":"');
      _i++;
      _ws();
      out[k] = _value();
      _ws();
      if (_i >= _s.length) _fail('Unterminated object');
      if (_s[_i] == ',') {
        _i++;
        continue;
      }
      if (_s[_i] == '}') {
        _i++;
        return out;
      }
      _fail('Expected "," or "}"');
    }
  }

  List<dynamic> _array() {
    _i++; // [
    final out = <dynamic>[];
    _ws();
    if (_i < _s.length && _s[_i] == ']') {
      _i++;
      return out;
    }
    while (true) {
      _ws();
      out.add(_value());
      _ws();
      if (_i >= _s.length) _fail('Unterminated array');
      if (_s[_i] == ',') {
        _i++;
        continue;
      }
      if (_s[_i] == ']') {
        _i++;
        return out;
      }
      _fail('Expected "," or "]"');
    }
  }

  String _string() {
    final start = _i;
    _i++; // opening quote
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == 0x5C) {
        _i += 2; // skip escaped char; escapes validated by jsonDecode below
      } else if (c == 0x22) {
        _i++;
        // Delegate escape handling for this single token to the SDK decoder (strings only).
        return jsonDecode(_s.substring(start, _i)) as String;
      } else {
        _i++;
      }
    }
    _fail('Unterminated string');
  }

  Object _num() {
    final m = _number.matchAsPrefix(_s, _i);
    if (m == null) _fail('Invalid value');
    final text = m[0]!;
    _i = m.end;
    if (_intOnly.hasMatch(text)) {
      final v = int.tryParse(text);
      if (v != null) return v;
    }
    return JsonNumberText(text);
  }
}
