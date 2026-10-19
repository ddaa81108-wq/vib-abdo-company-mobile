import 'common.dart';

/// Masraweya (EGP daily book). GET/PUT /api/masraweya/day.
class MasraweyaEntryDto {
  const MasraweyaEntryDto({this.valueUnits, this.commissionUnits});
  final int? valueUnits;
  final int? commissionUnits;
  factory MasraweyaEntryDto.fromJson(Json j) => MasraweyaEntryDto(
      valueUnits: unitsOrNull(j['valueUnits']),
      commissionUnits: unitsOrNull(j['commissionUnits']));
  Json toJson() =>
      {'valueUnits': valueUnits, 'commissionUnits': commissionUnits};
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
  final int? previousValueUnits;
  final int? purchasesUnits;
  final List<MasraweyaEntryDto> entries;

  /// REQUIRED FROM SERVER (contract §12): the web client computes both locally.
  final int? workTotalUnits;
  final int? remainingUnits;
  final int? historicalAdjustmentUnits;
  final String? status;

  Currency get currency => Currency.egp;

  factory MasraweyaDayDto.fromData(Object? data) {
    final d = asJson(data);
    final day = d['day'] is Map ? asJson(d['day']) : d;
    return MasraweyaDayDto(
      businessDate: str(day['businessDate']),
      version: intOrNull(day['version']),
      previousValueUnits: unitsOrNull(day['previousValueUnits']),
      purchasesUnits: unitsOrNull(day['purchasesUnits']),
      entries: asJsonList(day['entries'])
          .map(MasraweyaEntryDto.fromJson)
          .toList(growable: false),
      workTotalUnits: unitsOrNull(day['workTotalUnits']),
      remainingUnits: unitsOrNull(day['remainingUnits'] ??
          day['finalUnits']), // 01b: server returns finalUnits
      historicalAdjustmentUnits: unitsOrNull(day['historicalAdjustmentUnits']),
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
