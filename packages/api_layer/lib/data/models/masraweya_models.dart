import 'common.dart';

/// Masraweya (EGP daily book). GET/PUT /api/masraweya/day.
///
/// The documented entry is `id`, `sequence`, `valueUnits`, `commissionUnits`
/// (`docs/api/response-types.ts.txt`). There is no per-row total field.
/// PUT sends only `valueUnits` and `commissionUnits`.
class MasraweyaEntryDto {
  const MasraweyaEntryDto({
    this.id,
    this.sequence,
    this.valueUnits,
    this.commissionUnits,
  });

  final String? id;

  /// Server row sequence when the day payload includes one.
  final int? sequence;
  final MoneyValue? valueUnits;
  final MoneyValue? commissionUnits;
  factory MasraweyaEntryDto.fromJson(Json j) => MasraweyaEntryDto(
        id: strOrNull(j['id']),
        sequence: intOrNull(j['sequence']),
        valueUnits: unitsOrNull(j['valueUnits'], fieldPath: 'valueUnits'),
        commissionUnits:
            unitsOrNull(j['commissionUnits'], fieldPath: 'commissionUnits'),
      );

  /// Write body. `id` and `sequence` are not part of the PUT item schema.
  Json toJson() => {
        'valueUnits': wireMoney(valueUnits),
        'commissionUnits': wireMoney(commissionUnits),
      };
}

class MasraweyaDayDto {
  const MasraweyaDayDto({
    required this.businessDate,
    this.version,
    this.previousValueUnits,
    this.purchasesUnits,
    this.entries = const [],
    this.workTotalUnits,
    this.remainingUnits,
    this.historicalAdjustmentUnits,
    this.status,
    this.today,
    this.earliestEditableDate,
    this.editable,
    this.openingEditable,
    this.carrySourceDate,
  });
  final String businessDate;
  final int? version;
  final MoneyValue? previousValueUnits;
  final MoneyValue? purchasesUnits;
  final List<MasraweyaEntryDto> entries;

  /// Required from the server, per API contract. The app does not compute these.
  final MoneyValue? workTotalUnits;
  final MoneyValue? remainingUnits;
  final MoneyValue? historicalAdjustmentUnits;
  final String? status;

  /// Server's current business date. Null when the payload omits it.
  /// The device does not decide this (the contract default is 04:00 Africa/Tripoli).
  final String? today;

  /// Server field. Null when omitted. The app does not derive a 7-day window.
  final String? earliestEditableDate;

  /// Server field. Null when omitted — that is not an app-side edit window.
  /// `false` means this day is read-only even for a writer.
  final bool? editable;

  /// Server field. `false` means the opening value is not typed by the client.
  /// Null when omitted.
  final bool? openingEditable;

  final String? carrySourceDate;

  Currency get currency => Currency.egp;

  factory MasraweyaDayDto.fromData(Object? data) {
    requireJsonObject(data, 'masraweya');
    final d = asJson(data);
    final dayRaw = d['day'];
    requireJsonObject(dayRaw, 'day');
    final day = dayRaw is Map ? asJson(dayRaw) : d;
    MoneyValue? money(String key) =>
        unitsOrNull(day[key], fieldPath: 'day.$key');
    return MasraweyaDayDto(
      businessDate: str(day['businessDate']),
      version: intOrNull(day['version']),
      previousValueUnits: money('previousValueUnits'),
      purchasesUnits: money('purchasesUnits'),
      entries: asJsonList(day['entries'])
          .map(MasraweyaEntryDto.fromJson)
          .toList(growable: false),
      workTotalUnits: money('workTotalUnits'),
      remainingUnits: day.containsKey('remainingUnits')
          ? money('remainingUnits')
          : unitsOrNull(day['finalUnits'], fieldPath: 'day.finalUnits'),
      historicalAdjustmentUnits: money('historicalAdjustmentUnits'),
      status: strOrNull(day['status']),
      today: strOrNull(day['today']),
      earliestEditableDate: strOrNull(day['earliestEditableDate']),
      editable: _boolOrNull(day['editable']),
      openingEditable: _boolOrNull(day['openingEditable']),
      carrySourceDate: strOrNull(day['carrySourceDate']),
    );
  }
}

bool? _boolOrNull(Object? value) => value is bool ? value : null;

/// PUT /api/masraweya/day {businessDate, expectedVersion, previousValueUnits, purchasesUnits, entries[]}
/// (+ requestId). All values are raw user inputs; the server computes totals.
class SaveMasraweyaDayRequest {
  const SaveMasraweyaDayRequest(
      {required this.businessDate,
      this.previousValueUnits,
      this.purchasesUnits,
      this.entries = const []});
  final String businessDate;
  final int? previousValueUnits;
  final int? purchasesUnits;
  final List<MasraweyaEntryDto> entries;
  Json toJson() => {
        'businessDate': businessDate,
        if (previousValueUnits != null)
          'previousValueUnits': previousValueUnits,
        if (purchasesUnits != null) 'purchasesUnits': purchasesUnits,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
