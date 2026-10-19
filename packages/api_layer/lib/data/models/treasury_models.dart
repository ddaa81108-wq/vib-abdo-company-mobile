import 'common.dart';
import 'home_models.dart';

/// GET /api/treasury — the five cards, all server-computed.
/// Each value is shown with ITS OWN currency; the app never converts or nets them.
class TreasurySummaryDto {
  const TreasurySummaryDto({
    this.receivablesUnits,
    this.liabilitiesUnits,
    this.activeCashUnits,
    this.egyptianSourceUnits,
    this.egyptianRate,
    this.egyptianConvertedUnits,
    this.netUnits,
    this.version,
    this.rateMissing = false,
    this.activeCashTone,
  });
  final int? receivablesUnits; // LYD — ديون لنا
  final int? liabilitiesUnits; // LYD — ديون علينا
  final int? activeCashUnits; // LYD — الفلوس النشطة
  final int? egyptianSourceUnits; // EGP — source amount
  final DecimalString? egyptianRate; // decimal TEXT, display only
  final int? egyptianConvertedUnits; // LYD — converted BY THE SERVER
  final int? netUnits; // LYD — صافي الخزينة (server)
  final int? version; // -> expectedVersion for cash entries
  final bool rateMissing; // "يلزم سعر تحويل معتمد"

  /// Server colour for the active-cash card. Null stays neutral.
  final SummaryTone? activeCashTone;

  static const Currency lydFields = Currency.lyd;
  static const Currency egyptianSourceCurrency = Currency.egp;

  factory TreasurySummaryDto.fromData(Object? data) {
    final d = asJson(data);
    final t = d['totals'] is Map ? asJson(d['totals']) : d;
    return TreasurySummaryDto(
      receivablesUnits: unitsOrNull(t['receivablesUnits']),
      liabilitiesUnits: unitsOrNull(t['liabilitiesUnits']),
      activeCashUnits: unitsOrNull(t['activeCashUnits']),
      egyptianSourceUnits: unitsOrNull(t['egyptianSourceUnits']),
      egyptianRate: decimalOrNull(t['egyptianRate']),
      egyptianConvertedUnits: unitsOrNull(t['egyptianConvertedUnits']),
      netUnits: unitsOrNull(t['netUnits']),
      version: intOrNull(d['version'] ?? t['version']),
      rateMissing: t['egyptianRate'] == null,
      activeCashTone: SummaryTone.fromServer(
          t['activeCashTone'] ?? t['tone'] ?? d['activeCashTone']),
    );
  }
}

class CashEntryDto {
  const CashEntryDto(
      {required this.id,
      required this.direction,
      this.amountUnits,
      this.description,
      this.balanceAfterUnits,
      this.createdAt,
      this.createdByName});
  final String id;
  final String direction; // in | out
  final int? amountUnits; // LYD
  final String? description;
  final int? balanceAfterUnits; // from server
  final DateTime? createdAt;
  final String? createdByName;
  factory CashEntryDto.fromJson(Json j) => CashEntryDto(
        id: str(j['id']),
        direction: str(j['direction']),
        amountUnits: unitsOrNull(j['amountUnits']),
        description: strOrNull(j['description']),
        balanceAfterUnits: unitsOrNull(j['balanceAfterUnits']),
        createdAt: dateOrNull(j['createdAt']),
        createdByName: strOrNull(j['createdByName'] ?? j['actorName']),
      );
}

enum CashDirection { cashIn, cashOut }

extension CashDirectionWire on CashDirection {
  String get wire => this == CashDirection.cashIn ? 'in' : 'out';
}

/// POST /api/treasury/cash-entries {requestId, expectedVersion, direction, amountUnits, description}
class CashEntryRequest {
  const CashEntryRequest(
      {required this.direction,
      required this.amountUnits,
      required this.description});
  final CashDirection direction;
  final int amountUnits; // raw user input
  final String description;
  Json toJson() => {
        'direction': direction.wire,
        'amountUnits': amountUnits,
        'description': description
      };
}
