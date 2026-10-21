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
/// (contract gap 14, also unconfirmed). Missing keys stay null. Currency
/// falls back to LYD (🔶 gaps 23 and 27). Money fields are integer `*Units`
/// only. A non-integer money value is `INVALID_SERVER_RESPONSE`.
/// `MONEY_UNIT_SCALE` is still gap 29: this parser does not scale, add, or
/// copy `metrics` onto a row or the totals. A non-integer money value throws
/// `InvalidServerResponseException`.
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
  final String? generatedAt;

  /// `YYYY-MM-DD` from the standalone query, echoed by that source. Null when
  /// the collections array is the source (no confirmed date filter there).
  final String? from;
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

  final String? employeeId;
  final String employeeName;
  final int? collectedUnits;
  final int? pendingUnits;
  final int? approvedCount;
  final int? rejectedCount;
  final int? pendingCount;

  /// Same unit as collections `metrics.cashOutstandingUnits`, stored per
  /// employee by the server. Not copied from the page metric.
  final int? cashOutstandingUnits;

  /// 🔶 Assumed LYD when the server omits it (gaps 23 and 27).
  final Currency currency;

  factory EmployeeTotalsItemDto.fromJson(
    Json j, {
    Currency fallback = Currency.lyd,
  }) =>
      EmployeeTotalsItemDto(
        employeeId: strOrNull(j['employeeId']),
        employeeName: str(j['employeeName'] ?? j['displayName']),
        collectedUnits: unitsOrNull(j['collectedUnits']),
        pendingUnits: unitsOrNull(j['pendingUnits']),
        approvedCount: intOrNull(j['approvedCount']),
        rejectedCount: intOrNull(j['rejectedCount']),
        pendingCount: intOrNull(j['pendingCount']),
        cashOutstandingUnits: unitsOrNull(j['cashOutstandingUnits']),
        currency: currencyOr(j['currency'], fallback),
      );

  Json toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'collectedUnits': collectedUnits,
        'pendingUnits': pendingUnits,
        'approvedCount': approvedCount,
        'rejectedCount': rejectedCount,
        'pendingCount': pendingCount,
        'cashOutstandingUnits': cashOutstandingUnits,
        'currency': currency.code,
      };
}

/// Server totals row. Money stays null when the body has no `totals` object.
class EmployeeTotalsSummaryDto {
  const EmployeeTotalsSummaryDto({this.collectedUnits, this.pendingUnits});

  final int? collectedUnits;
  final int? pendingUnits;

  factory EmployeeTotalsSummaryDto.fromJson(Json j) => EmployeeTotalsSummaryDto(
        collectedUnits: unitsOrNull(j['collectedUnits']),
        pendingUnits: unitsOrNull(j['pendingUnits']),
      );

  Json toJson() => {
        'collectedUnits': collectedUnits,
        'pendingUnits': pendingUnits,
      };
}
