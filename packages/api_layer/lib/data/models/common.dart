/// Shared DTO helpers.
/// MONEY RULE: the real server sends money as integers named `*Units`. DTOs keep a
/// valid value as [MoneyValue.known] and NEVER use it in arithmetic (no +, -, *, /,
/// sum, diff). Display goes exclusively through MoneyFormatter, one value + its own
/// currency at a time. Currencies are never converted or combined.
///
/// A money *field* that is not a JSON integer (string, fraction, exponent, `double`,
/// oversized integer, bool, array, or object) becomes [MoneyValue.invalid] for that
/// field only. The rest of the object and the other rows still parse. Null stays
/// null (the UI dash). Nothing is rounded or truncated, and a `double` is never stored.
///
/// A *container* that is present but is not a JSON object still fails the whole
/// response via [requireJsonObject]. There is no field left to mark, and turning
/// that payload into a page of dashes would hide a broken body. A missing container
/// stays null or empty. A list element that is not an object is still dropped by
/// [asJsonList]; that is not a money field.
library;

import '../../core/money/money_formatter.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/logging_interceptor.dart';

export '../../core/money/money_formatter.dart' show Currency, DecimalString;
export '../../core/money/money_value.dart';
export '../../core/network/logging_interceptor.dart'
    show SafeLog, currentMoneyEndpoint, runWithMoneyEndpoint;

typedef Json = Map<String, dynamic>;

Json asJson(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asJsonList(Object? v) => v is List
    ? v.whereType<Map>().map(asJson).toList(growable: false)
    : const [];
String str(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
String? strOrNull(Object? v) => v == null ? null : '$v';
DateTime? dateOrNull(Object? v) => v == null ? null : DateTime.tryParse('$v');
List<String> strList(Object? v) =>
    v is List ? v.map((e) => '$e').toList(growable: false) : const [];
bool boolOf(Object? v) => v == true;

/// Money field. Null/missing -> null (UI shows '—'). A JSON integer -> [MoneyValue.known].
/// Anything else -> [MoneyValue.invalid] for this field only. No rounding, no `double`.
///
/// [fieldPath] and the current endpoint ([runWithMoneyEndpoint]) are logged with
/// [rowId]. The value itself is not read into the log.
MoneyValue? unitsOrNull(Object? v, {String fieldPath = '-', String? rowId}) {
  if (v == null) return null;
  if (v is int) return MoneyValue.known(v);
  if (v is MoneyValue) return v;
  SafeLog.invalidMoney(
    endpoint: currentMoneyEndpoint,
    fieldPath: fieldPath,
    rowId: rowId,
  );
  return const MoneyValue.invalid();
}

/// Present container must be a JSON object. Missing is allowed.
///
/// Used for a whole object (`summary`, `totals`, `day`, `registerTotals`,
/// or the response `data`). A string, list, or number here fails the response.
/// A bad money field inside a real object does not: that is [unitsOrNull].
void requireJsonObject(Object? value, String label) {
  if (value == null || value is Map) return;
  throw InvalidServerResponseException(
    message: 'استجابة الخادم غير صالحة ($label)',
  );
}

/// Rate / factor as decimal TEXT (no double anywhere).
DecimalString? decimalOrNull(Object? v) => DecimalString.fromJson(v);

/// Counts / versions (not money). Integers only; no float truncation.
int? intOrNull(Object? v) =>
    v is int ? v : (v is String ? int.tryParse(v) : null);

/// Server-provided currency if present, else the section's fixed currency.
Currency currencyOr(Object? serverValue, Currency fallback) =>
    Currency.fromCode(serverValue) ?? fallback;

/// Pagination exactly as the server returns it (inside `data`):
/// `?limit&cursor` -> `nextCursor`/`hasMore`; ledgers `?limit&before`.
class Paged<T> {
  const Paged({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.raw = const {},
  });
  final List<T> items;
  final String? nextCursor; // cursor or `before` value for the next page
  final bool hasMore;
  final Json raw; // full `data` object (for server-provided summary fields)

  static Paged<T> fromData<T>(
    Object? data,
    T Function(Json) parse, {
    String itemsKey = 'items',
  }) {
    if (data is List) {
      return Paged(items: asJsonList(data).map(parse).toList(growable: false));
    }
    final d = asJson(data);
    return Paged(
      items: asJsonList(d[itemsKey]).map(parse).toList(growable: false),
      nextCursor: strOrNull(d['nextCursor'] ?? d['nextBefore']),
      hasMore: d['hasMore'] == true || d['nextCursor'] != null,
      raw: d,
    );
  }
}

/// Minimal acknowledgement of a mutation. After any mutation the UI refetches /
/// invalidates the affected providers; it never patches numbers locally.
class MutationAck {
  const MutationAck({this.id, this.version, this.raw = const {}});
  final String? id;
  final int? version;
  final Json raw;
  factory MutationAck.fromData(Object? data) {
    final d = asJson(data);
    return MutationAck(
      id: strOrNull(d['id']),
      version: intOrNull(d['version']),
      raw: d,
    );
  }
}

/// Server-side enum `calculationMode` (direct | multiply | divide). The SERVER applies it.
enum CalculationMode {
  direct,
  multiply,
  divide;

  static CalculationMode? fromName(Object? v) {
    for (final m in values) {
      if (m.name == '$v') return m;
    }
    return null;
  }
}
