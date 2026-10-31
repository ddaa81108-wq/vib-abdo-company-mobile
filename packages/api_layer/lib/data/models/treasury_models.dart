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
  final MoneyValue? receivablesUnits; // LYD — ديون لنا
  final MoneyValue? liabilitiesUnits; // LYD — ديون علينا
  final MoneyValue? activeCashUnits; // LYD — الفلوس النشطة
  final MoneyValue? egyptianSourceUnits; // EGP — source amount
  final DecimalString? egyptianRate; // decimal TEXT, display only
  final MoneyValue? egyptianConvertedUnits; // LYD — converted BY THE SERVER
  final MoneyValue? netUnits; // LYD — صافي الخزينة (server)
  final int? version; // -> expectedVersion for cash entries
  final bool rateMissing; // "يلزم سعر تحويل معتمد"

  /// Proposed field, pending server confirmation. Absent or unknown stays
  /// null, and the card stays neutral.
  final SummaryTone? activeCashTone;

  static const Currency lydFields = Currency.lyd;
  static const Currency egyptianSourceCurrency = Currency.egp;

  factory TreasurySummaryDto.fromData(Object? data) {
    requireJsonObject(data, 'treasury');
    final d = asJson(data);
    final totalsRaw = d['totals'];
    requireJsonObject(totalsRaw, 'totals');
    final t = totalsRaw is Map ? asJson(totalsRaw) : d;
    MoneyValue? money(String key) =>
        unitsOrNull(t[key], fieldPath: 'totals.$key');
    return TreasurySummaryDto(
      receivablesUnits: money('receivablesUnits'),
      liabilitiesUnits: money('liabilitiesUnits'),
      activeCashUnits: money('activeCashUnits'),
      egyptianSourceUnits: money('egyptianSourceUnits'),
      egyptianRate: decimalOrNull(t['egyptianRate']),
      egyptianConvertedUnits: money('egyptianConvertedUnits'),
      netUnits: money('netUnits'),
      // Production names the cash version `cashVersion` (POST cash-entries
      // rejects a body without it). `version` is the older name.
      version: intOrNull(
          d['cashVersion'] ?? t['cashVersion'] ?? d['version'] ?? t['version']),
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
  final MoneyValue? amountUnits; // LYD
  final String? description;
  final MoneyValue? balanceAfterUnits; // from server
  final DateTime? createdAt;
  final String? createdByName;
  factory CashEntryDto.fromJson(Json j) => CashEntryDto(
        id: str(j['id']),
        direction: str(j['direction']),
        amountUnits: unitsOrNull(
          j['amountUnits'],
          fieldPath: 'amountUnits',
          rowId: strOrNull(j['id']),
        ),
        description: strOrNull(j['description']),
        balanceAfterUnits: unitsOrNull(
          j['balanceAfterUnits'],
          fieldPath: 'balanceAfterUnits',
          rowId: strOrNull(j['id']),
        ),
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
