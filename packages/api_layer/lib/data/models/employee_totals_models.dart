import 'common.dart';

/// 🔶 PROPOSED admin employee-totals dashboard.
///
/// Two unconfirmed bodies parse into this one type. The repository picks the
/// body; the provider and the UI only read these fields.
///
/// Standalone `GET /api/admin/employee-totals` (no `/api/admin` prefix is
/// confirmed in this repo):
/// `{ generatedAt, from, to, version, currency, items, totals }`
/// with `totals: { collectedUnits, pendingUnits }`.
///
/// Collections `GET /api/collections` reads the `employeeTotals` array
/// (contract gap 14, also unconfirmed). Currency falls back to LYD (🔶 gaps
/// 23 and 27). Money fields are integer `*Units` only. A non-integer money
/// value is [MoneyValue.invalid] on that field. `MONEY_UNIT_SCALE` is still gap 29:
/// this parser does not scale, add, or copy `metrics` onto a row or the
/// totals. A non-integer money value does not fail the rest of the body.
///
/// 🔶 Not provided by the collections source, so these stay null. They are
/// not fabricated as `0` or `''`. Null money is "not sent"; the UI shows
/// '—' (`MoneyFormatter.formatOrDash`), not zero:
/// `generatedAt`, `from`, `to`, `items.employeeId`, `items.pendingUnits`,
/// `items.rejectedCount`, `items.cashOutstandingUnits`,
/// `totals.collectedUnits`, `totals.pendingUnits`.
/// A value that source does send is kept, including a real `collectedUnits`
/// of `0`.
class EmployeeTotalsDto {
  const EmployeeTotalsDto({
    this.generatedAt,
    this.from,
    this.to,
    this.version,
    this.currency = Currency.lyd,
    this.items = const [],
    this.totals = const EmployeeTotalsSummaryDto(),
  });

  /// Server timestamp text, kept as sent. Not parsed into a [DateTime].
  /// 🔶 Not provided by the collections source: left null.
  final String? generatedAt;

  /// `YYYY-MM-DD` echoed by the standalone source. 🔶 Not provided by the
  /// collections source: left null. Do not invent a date. The UI shows '—'.
  final String? from;

  /// `YYYY-MM-DD` echoed by the standalone source. 🔶 Not provided by the
  /// collections source: left null. Do not invent a date. The UI shows '—'.
  final String? to;
  final int? version;

  /// 🔶 Assumed LYD when the server omits it or sends an unknown code.
  final Currency currency;
  final List<EmployeeTotalsItemDto> items;

  /// Server totals row. Null fields mean the body did not include them.
  /// The app must show them as sent and must not sum [items].
  final EmployeeTotalsSummaryDto totals;

  factory EmployeeTotalsDto.fromJson(Json j) =>
      EmployeeTotalsDto.fromStandalone(j);

  /// Standalone report object (`items` + `totals`).
  factory EmployeeTotalsDto.fromStandalone(Object? data) {
    final d = asJson(data);
    final currency = currencyOr(d['currency'], Currency.lyd);
    return EmployeeTotalsDto(
      generatedAt: strOrNull(d['generatedAt']),
      from: strOrNull(d['from']),
      to: strOrNull(d['to']),
      version: intOrNull(d['version']),
      currency: currency,
      items: asJsonList(d['items'])
          .map((row) => EmployeeTotalsItemDto.fromJson(row, fallback: currency))
          .toList(growable: false),
      totals: d['totals'] is Map
          ? EmployeeTotalsSummaryDto.fromJson(asJson(d['totals']))
          : const EmployeeTotalsSummaryDto(),
    );
  }

  /// `employeeTotals` on a collections overview. Does not read `metrics`.
  ///
  /// 🔶 `generatedAt`, `from`, `to`, `employeeId`, `pendingUnits`,
  /// `rejectedCount`, `cashOutstandingUnits`, and both totals money fields
  /// are not provided by this source. They stay null. A sent `collectedUnits`
  /// of `0` stays `0`.
  factory EmployeeTotalsDto.fromCollectionsOverview(Object? data) {
    final d = asJson(data);
    final currency = currencyOr(d['currency'], Currency.lyd);
    return EmployeeTotalsDto(
      generatedAt: strOrNull(d['generatedAt']),
      from: strOrNull(d['from']),
      to: strOrNull(d['to']),
      version: intOrNull(d['version']),
      currency: currency,
      items: asJsonList(d['employeeTotals'])
          .map((row) => EmployeeTotalsItemDto.fromJson(row, fallback: currency))
          .toList(growable: false),
      totals: d['totals'] is Map
          ? EmployeeTotalsSummaryDto.fromJson(asJson(d['totals']))
          : const EmployeeTotalsSummaryDto(),
    );
  }

  Json toJson() => {
        'generatedAt': generatedAt,
        'from': from,
        'to': to,
        'version': version,
        'currency': currency.code,
        'items': [for (final item in items) item.toJson()],
        'totals': totals.toJson(),
      };
}

/// One employee on the dashboard. `displayName` is accepted when `employeeName`
/// is absent (the collections and payroll fixtures use either name).
class EmployeeTotalsItemDto {
  const EmployeeTotalsItemDto({
    required this.employeeName,
    this.employeeId,
    this.collectedUnits,
    this.pendingUnits,
    this.approvedCount,
    this.rejectedCount,
    this.pendingCount,
    this.cashOutstandingUnits,
    this.currency = Currency.lyd,
  });

  /// Standalone employee id. 🔶 Not provided by the collections source: left
  /// null. Do not invent an id. The UI shows '—'.
  final String? employeeId;
  final String employeeName;
  final MoneyValue? collectedUnits;

  /// Integer units from the server. 🔶 Not provided by the collections source:
  /// left null, not `0`. Null money is "not sent"; the UI shows '—'
  /// (`MoneyFormatter.formatOrDash`). A real zero, such as `collectedUnits`
  /// on the collections row, stays `0`.
  final MoneyValue? pendingUnits;
  final int? approvedCount;

  /// 🔶 Not provided by the collections source: left null, not `0`.
  final int? rejectedCount;
  final int? pendingCount;

  /// Same unit as collections `metrics.cashOutstandingUnits`, stored per
  /// employee by the server. Not copied from the page metric. 🔶 Not provided
  /// by the collections `employeeTotals` row: left null, not `0`. The UI
  /// shows '—'.
  final MoneyValue? cashOutstandingUnits;

  /// 🔶 Assumed LYD when the server omits it (gaps 23 and 27).
  final Currency currency;

  factory EmployeeTotalsItemDto.fromJson(
    Json j, {
    Currency fallback = Currency.lyd,
  }) =>
      EmployeeTotalsItemDto(
        employeeId: strOrNull(j['employeeId']),
        employeeName: str(j['employeeName'] ?? j['displayName']),
        collectedUnits: unitsOrNull(
          j['collectedUnits'],
          fieldPath: 'collectedUnits',
          rowId: strOrNull(j['employeeId'] ?? j['userId']),
        ),
        pendingUnits: unitsOrNull(
          j['pendingUnits'],
          fieldPath: 'pendingUnits',
          rowId: strOrNull(j['employeeId'] ?? j['userId']),
        ),
        approvedCount: intOrNull(j['approvedCount']),
        rejectedCount: intOrNull(j['rejectedCount']),
        pendingCount: intOrNull(j['pendingCount']),
        cashOutstandingUnits: unitsOrNull(
          j['cashOutstandingUnits'],
          fieldPath: 'cashOutstandingUnits',
          rowId: strOrNull(j['employeeId'] ?? j['userId']),
        ),
        currency: currencyOr(j['currency'], fallback),
      );

  Json toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'collectedUnits': wireMoney(collectedUnits),
        'pendingUnits': wireMoney(pendingUnits),
        'approvedCount': approvedCount,
        'rejectedCount': rejectedCount,
        'pendingCount': pendingCount,
        'cashOutstandingUnits': wireMoney(cashOutstandingUnits),
        'currency': currency.code,
      };
}

/// Server totals row. Money stays null when the body has no `totals` object.
/// 🔶 The collections source does not send `totals`, so both fields stay null
/// (not `0`). The UI shows '—'.
class EmployeeTotalsSummaryDto {
  const EmployeeTotalsSummaryDto({this.collectedUnits, this.pendingUnits});

  final MoneyValue? collectedUnits;
  final MoneyValue? pendingUnits;

  factory EmployeeTotalsSummaryDto.fromJson(Json j) => EmployeeTotalsSummaryDto(
        collectedUnits: unitsOrNull(
          j['collectedUnits'],
          fieldPath: 'totals.collectedUnits',
        ),
        pendingUnits:
            unitsOrNull(j['pendingUnits'], fieldPath: 'totals.pendingUnits'),
      );

  Json toJson() => {
        'collectedUnits': wireMoney(collectedUnits),
        'pendingUnits': wireMoney(pendingUnits),
      };
}
