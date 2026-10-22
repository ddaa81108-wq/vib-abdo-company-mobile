import 'common.dart';

/// Proposed `GET /api/home` (per API contract). The server does not provide this yet.
/// The server returns ONLY what the current user may see (filtered by permissions).
/// Every number, colour (`tone`), counter and date comes from the server as-is:
/// the app performs no sums across sections, no currency conversion, no date math.
///
/// { businessDate, generatedAt,
///   summaries: [{key, section, title, valueUnits, currency, tone, note, status, updatedAt}],
///   counters:  `{"<section>": <int>}`,
///   oldDebts?: [{id, section, name, balanceUnits, currency, debtAgeDays, ageStatus, ageStatusLabel}] }

/// Server-provided colour intent. Unknown/absent -> null = neutral colours.
enum SummaryTone {
  positive,
  negative,
  neutral;

  static SummaryTone? fromServer(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

class HomeSummaryDto {
  const HomeSummaryDto({
    required this.key,
    required this.section,
    required this.title,
    this.valueUnits,
    this.currency,
    this.tone,
    this.note,
    this.status,
    this.updatedAt,
  });

  final String key; // e.g. customers.netBalance
  final String section; // customers | companies | … | reports
  final String title; // server text
  final MoneyValue?
      valueUnits; // null -> "—". Invalid is not a number and not a dash.
  final Currency?
      currency; // explicit per card; never inferred from another card
  final SummaryTone? tone;
  final String? note; // optional explanation line from the server
  final String?
      status; // e.g. reports day status (normal|review|critical|missing_rate)
  final DateTime? updatedAt;

  factory HomeSummaryDto.fromJson(Json j) => HomeSummaryDto(
        key: str(j['key']),
        section: str(j['section']),
        title: str(j['title']),
        valueUnits: unitsOrNull(
          j['valueUnits'],
          fieldPath: 'valueUnits',
          rowId: strOrNull(j['key']),
        ),
        currency: Currency.fromCode(j['currency']),
        tone: SummaryTone.fromServer(j['tone']),
        note: strOrNull(j['note']),
        status: strOrNull(j['status']),
        updatedAt: dateOrNull(j['updatedAt']),
      );
}

class OldDebtDto {
  const OldDebtDto(
      {required this.id,
      required this.section,
      required this.name,
      this.balanceUnits,
      this.currency,
      this.debtAgeDays,
      this.ageStatus,
      this.ageStatusLabel});
  final String id;
  final String section;
  final String name;
  final MoneyValue? balanceUnits;
  final Currency? currency;
  final int? debtAgeDays; // display text only
  final String? ageStatus; // server status -> colour; no thresholds in the app
  final String? ageStatusLabel;

  factory OldDebtDto.fromJson(Json j) => OldDebtDto(
        id: str(j['id']),
        section: str(j['section']),
        name: str(j['name']),
        balanceUnits: unitsOrNull(
          j['balanceUnits'],
          fieldPath: 'balanceUnits',
          rowId: strOrNull(j['id']),
        ),
        currency: Currency.fromCode(j['currency']),
        debtAgeDays: intOrNull(j['debtAgeDays']),
        ageStatus: strOrNull(j['ageStatus']),
        ageStatusLabel: strOrNull(j['ageStatusLabel']),
      );
}

class HomeDto {
  const HomeDto(
      {this.businessDate,
      this.generatedAt,
      required this.summaries,
      required this.counters,
      this.oldDebts});

  /// Business day as the server states it ("YYYY-MM-DD"), displayed as text — no local date math.
  final String? businessDate;
  final DateTime? generatedAt; // "آخر تحديث"
  final List<HomeSummaryDto> summaries; // render ONLY these, in server order
  final Map<String, int> counters; // optional per-section badge counts (server)
  /// null = field absent -> do not render the old-debts strip at all.
  final List<OldDebtDto>? oldDebts;

  factory HomeDto.fromData(Object? data) {
    final d = asJson(data);
    return HomeDto(
      businessDate: strOrNull(d['businessDate']),
      generatedAt: dateOrNull(d['generatedAt']),
      summaries: asJsonList(d['summaries'])
          .map(HomeSummaryDto.fromJson)
          .toList(growable: false),
      counters: {
        for (final e in asJson(d['counters']).entries)
          if (e.value is int) e.key: e.value as int,
      },
      oldDebts: d['oldDebts'] is List
          ? asJsonList(d['oldDebts'])
              .map(OldDebtDto.fromJson)
              .toList(growable: false)
          : null,
    );
  }
}
