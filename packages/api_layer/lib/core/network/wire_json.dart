import 'dart:convert';

import '../config/api_config.dart';
import '../money/decimal_string.dart';

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
