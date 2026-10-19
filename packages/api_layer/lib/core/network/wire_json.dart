import 'dart:convert';

import '../config/api_config.dart';
import '../money/decimal_string.dart';
import 'api_exception.dart';

/// Request-body JSON writer. The ONLY place where a [DecimalString] meets the wire.
///
/// - [RateWireFormat.string]: `"9.5"`.
/// - [RateWireFormat.number]: the literal digits `9.5` are written straight into the JSON
///   text. No `double` is ever created, so no float rounding happens on our side.
///   (The server's JSON parser will read it as its own number type — e.g. a JS double —
///   which is exactly what the current server already does with the web client.)
///
/// Everything else is encoded like `jsonEncode`. Money stays `int` (*Units).
class WireJson {
  const WireJson._();

  static String encode(Object? value, RateWireFormat format) {
    final out = StringBuffer();
    _write(out, value, format);
    return out.toString();
  }

  static void _write(StringBuffer out, Object? v, RateWireFormat f) {
    if (v is DecimalString) {
      out.write(f == RateWireFormat.number ? v.value : jsonEncode(v.value));
    } else if (v is Map) {
      out.write('{');
      var first = true;
      v.forEach((k, val) {
        if (!first) out.write(',');
        first = false;
        out.write(jsonEncode('$k'));
        out.write(':');
        _write(out, val, f);
      });
      out.write('}');
    } else if (v is Iterable) {
      out.write('[');
      var first = true;
      for (final e in v) {
        if (!first) out.write(',');
        first = false;
        _write(out, e, f);
      }
      out.write(']');
    } else if (v is DateTime) {
      out.write(jsonEncode(v.toIso8601String()));
    } else {
      // String, int, bool, null (and anything jsonEncode supports). A double here would
      // be a bug in a model; money is int and rates are DecimalString.
      out.write(jsonEncode(v));
    }
  }
}

/// Parses a response body and keeps each JSON number's original token.
/// Plain integers become [int]. Every other number becomes [JsonNumber].
/// A [double] is never created.
Object? decodeWireJson(String source) {
  try {
    final parser = _WireParser(source);
    final value = parser.value();
    parser.skipWs();
    if (!parser.done) throw const FormatException('trailing');
    return value;
  } on FormatException {
    throw const InvalidServerResponseException();
  }
}

class _WireParser {
  _WireParser(this.source);
  final String source;
  int i = 0;

  bool get done => i >= source.length;

  Object? value() {
    skipWs();
    if (done) throw const FormatException('eof');
    final c = source.codeUnitAt(i);
    if (c == 0x6e) {
      _literal('null');
      return null;
    }
    if (c == 0x74) {
      _literal('true');
      return true;
    }
    if (c == 0x66) {
      _literal('false');
      return false;
    }
    if (c == 0x22) return _string();
    if (c == 0x5b) return _array();
    if (c == 0x7b) return _object();
    if (c == 0x2d || (c >= 0x30 && c <= 0x39)) return _number();
    throw const FormatException('value');
  }

  void skipWs() {
    while (!done) {
      final c = source.codeUnitAt(i);
      if (c != 0x20 && c != 0x09 && c != 0x0a && c != 0x0d) return;
      i++;
    }
  }

  void _literal(String word) {
    if (!source.startsWith(word, i)) throw const FormatException('literal');
    i += word.length;
  }

  String _string() {
    final start = i;
    i++;
    while (!done) {
      final c = source.codeUnitAt(i);
      if (c == 0x5c) {
        i += 2;
        continue;
      }
      i++;
      if (c == 0x22) return jsonDecode(source.substring(start, i)) as String;
    }
    throw const FormatException('string');
  }

  List<Object?> _array() {
    i++;
    final out = <Object?>[];
    skipWs();
    if (!done && source.codeUnitAt(i) == 0x5d) {
      i++;
      return out;
    }
    while (true) {
      out.add(value());
      skipWs();
      if (done) throw const FormatException('array');
      final c = source.codeUnitAt(i);
      i++;
      if (c == 0x5d) return out;
      if (c != 0x2c) throw const FormatException('array');
    }
  }

  Map<String, Object?> _object() {
    i++;
    final out = <String, Object?>{};
    skipWs();
    if (!done && source.codeUnitAt(i) == 0x7d) {
      i++;
      return out;
    }
    while (true) {
      skipWs();
      if (done || source.codeUnitAt(i) != 0x22) throw const FormatException('key');
      final key = _string();
      skipWs();
      if (done || source.codeUnitAt(i) != 0x3a) throw const FormatException('colon');
      i++;
      out[key] = value();
      skipWs();
      if (done) throw const FormatException('object');
      final c = source.codeUnitAt(i);
      i++;
      if (c == 0x7d) return out;
      if (c != 0x2c) throw const FormatException('object');
    }
  }

  Object _number() {
    final start = i;
    if (source.codeUnitAt(i) == 0x2d) i++;
    if (done || source.codeUnitAt(i) < 0x30 || source.codeUnitAt(i) > 0x39) {
      throw const FormatException('number');
    }
    while (!done && source.codeUnitAt(i) >= 0x30 && source.codeUnitAt(i) <= 0x39) {
      i++;
    }
    var plainInt = true;
    if (!done && source.codeUnitAt(i) == 0x2e) {
      plainInt = false;
      i++;
      if (done || source.codeUnitAt(i) < 0x30 || source.codeUnitAt(i) > 0x39) {
        throw const FormatException('fraction');
      }
      while (!done && source.codeUnitAt(i) >= 0x30 && source.codeUnitAt(i) <= 0x39) {
        i++;
      }
    }
    if (!done && (source.codeUnitAt(i) == 0x65 || source.codeUnitAt(i) == 0x45)) {
      plainInt = false;
      i++;
      if (!done && (source.codeUnitAt(i) == 0x2b || source.codeUnitAt(i) == 0x2d)) {
        i++;
      }
      if (done || source.codeUnitAt(i) < 0x30 || source.codeUnitAt(i) > 0x39) {
        throw const FormatException('exponent');
      }
      while (!done && source.codeUnitAt(i) >= 0x30 && source.codeUnitAt(i) <= 0x39) {
        i++;
      }
    }
    final token = source.substring(start, i);
    if (plainInt) {
      return int.tryParse(token) ?? JsonNumber(token);
    }
    return JsonNumber(token);
  }
}
