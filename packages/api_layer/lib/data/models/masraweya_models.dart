import 'common.dart';

/// Masraweya (EGP daily book). GET/PUT /api/masraweya/day.
class MasraweyaEntryDto {
  const MasraweyaEntryDto({this.valueUnits, this.commissionUnits});
  final MoneyValue? valueUnits;
  final MoneyValue? commissionUnits;
  factory MasraweyaEntryDto.fromJson(Json j) => MasraweyaEntryDto(
        valueUnits: unitsOrNull(j['valueUnits'], fieldPath: 'valueUnits'),
        commissionUnits:
            unitsOrNull(j['commissionUnits'], fieldPath: 'commissionUnits'),
      );
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
    );
  }
}

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
