/// Shared DTO helpers.
/// MONEY RULE: the real server sends money as integers named `*Units`. DTOs keep them
/// as raw `int` and they are NEVER used in arithmetic (no +, -, *, /, sum, diff).
/// Display goes exclusively through MoneyFormatter (core/money/money_formatter.dart),
/// one value + its own currency at a time. Currencies are never converted or combined.
library;

import '../../core/money/money_formatter.dart';

export '../../core/money/money_formatter.dart' show Currency;

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

/// Raw integer from the server (e.g. a *Units field). Non-integers -> null (never coerced).
int? unitsOrNull(Object? v) =>
    v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
int? intOrNull(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Server-provided currency if present, else the section's fixed currency.
Currency currencyOr(Object? serverValue, Currency fallback) =>
    Currency.fromCode(serverValue) ?? fallback;

/// Pagination exactly as the server returns it (inside `data`):
/// `?limit&cursor` -> `nextCursor`/`hasMore`; ledgers `?limit&before`.
class Paged<T> {
  const Paged(
      {required this.items,
      this.nextCursor,
      this.hasMore = false,
      this.raw = const {}});
  final List<T> items;
  final String? nextCursor; // cursor or `before` value for the next page
  final bool hasMore;
  final Json raw; // full `data` object (for server-provided summary fields)

  static Paged<T> fromData<T>(Object? data, T Function(Json) parse,
      {String itemsKey = 'items'}) {
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
        id: strOrNull(d['id']), version: intOrNull(d['version']), raw: d);
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
