import 'common.dart';

/// Purchases: two books. Values: egpValueUnits (EGP) -> resultUnits/paidUnits/remainingUnits (LYD).
enum PurchaseBook {
  alBayan('al_bayan', 'البيان'),
  simsim('simsim', 'سمسم');

  const PurchaseBook(this.path, this.label);
  final String path;
  final String label;
}

/// 🔶 Currency of Vodafone fields is not explicit in the frontend; assumed EGP until confirmed.
const Currency vodafoneCurrencyAssumption = Currency.egp;

class PurchaseEntryDto {
  const PurchaseEntryDto({
    required this.id,
    required this.kind,
    this.itemCode,
    this.itemLabel,
    this.egpValueUnits,
    this.calculationMode,
    this.exchangeRate,
    this.resultUnits,
    this.paidUnits,
    this.remainingUnits,
    this.vodafoneConsumedUnits,
    this.version,
  });
  final String id;
  final String kind; // entry | standalone_adjustment
  final String? itemCode;
  final String? itemLabel;
  final int? egpValueUnits; // EGP
  final CalculationMode? calculationMode;
  final DecimalString?
      exchangeRate; // decimal TEXT; display via formatDecimal only
  final int? resultUnits; // LYD, server-computed
  final int? paidUnits; // LYD
  final int? remainingUnits; // LYD, server-computed
  final int? vodafoneConsumedUnits;
  final int? version;

  factory PurchaseEntryDto.fromJson(Json j) => PurchaseEntryDto(
        id: str(j['id']),
        kind: str(j['kind'] ?? j['entryType'], 'entry'),
        itemCode: strOrNull(j['itemCode']),
        itemLabel: strOrNull(j['itemLabel']),
        egpValueUnits: unitsOrNull(j['egpValueUnits']),
        calculationMode: CalculationMode.fromName(j['calculationMode']),
        exchangeRate: decimalOrNull(j['exchangeRate']),
        resultUnits: unitsOrNull(j['resultUnits']),
        paidUnits: unitsOrNull(j['paidUnits']),
        remainingUnits: unitsOrNull(j['remainingUnits']),
        vodafoneConsumedUnits: unitsOrNull(j['vodafoneConsumedUnits']),
        version: intOrNull(j['version']),
      );
}

class PurchaseDayDto {
  const PurchaseDayDto({
    required this.day,
    this.version,
    this.status,
    this.entries = const [],
    this.previousDebtUnits,
    this.todayResultUnits,
    this.todayPaidUnits,
    this.totalDebtUnits,
    this.vodafoneRemainingUnits,
    this.dayClosingDebtUnits,
  });
  final String day; // "يوم #N"
  final int? version; // -> expectedDayVersion
  final String? status; // draft | finalized | correction (🔶)
  final List<PurchaseEntryDto> entries;
  final int? previousDebtUnits;
  final int? todayResultUnits;
  final int? todayPaidUnits;
  final int? totalDebtUnits;
  final int? vodafoneRemainingUnits;
  final int? dayClosingDebtUnits;

  factory PurchaseDayDto.fromJson(Json j) {
    final t = j['totals'] is Map ? asJson(j['totals']) : j;
    return PurchaseDayDto(
      day: str(j['day'] ?? j['dayNumber'] ?? j['id']),
      version: intOrNull(j['version'] ?? j['dayVersion']),
      status: strOrNull(j['status']),
      entries: asJsonList(j['entries'])
          .map(PurchaseEntryDto.fromJson)
          .toList(growable: false),
      previousDebtUnits: unitsOrNull(t['previousDebtUnits']),
      todayResultUnits: unitsOrNull(t['todayResultUnits']),
      todayPaidUnits: unitsOrNull(t['todayPaidUnits']),
      totalDebtUnits: unitsOrNull(t['totalDebtUnits']),
      vodafoneRemainingUnits: unitsOrNull(t['vodafoneRemainingUnits']),
      dayClosingDebtUnits: unitsOrNull(t['dayClosingDebtUnits']),
    );
  }
}

/// GET /api/purchases/{book}?limit=100&before
class PurchasesBookPage {
  const PurchasesBookPage({required this.page, this.lifetimeTotals = const {}});
  final Paged<PurchaseDayDto> page;

  /// "إجماليات السجل من البداية" exactly as returned (raw *Units ints).
  final Json lifetimeTotals;

  factory PurchasesBookPage.fromData(Object? data) {
    final p = Paged.fromData(data, PurchaseDayDto.fromJson, itemsKey: 'days');
    return PurchasesBookPage(
        page: p,
        lifetimeTotals: asJson(p.raw['lifetimeTotals'] ?? p.raw['totals']));
  }
}

/// POST /api/purchases/{book} / PATCH …/entries/{id}
/// {requestId, expectedDayVersion, itemCode, itemLabel, egpValueUnits, calculationMode, exchangeRate, paidUnits, vodafoneConsumedUnits}
class PurchaseEntryRequest {
  const PurchaseEntryRequest(
      {this.itemCode,
      this.itemLabel,
      this.egpValueUnits,
      this.calculationMode,
      this.exchangeRate,
      this.paidUnits,
      this.vodafoneConsumedUnits});
  final String? itemCode;
  final String? itemLabel;
  final int? egpValueUnits;
  final CalculationMode? calculationMode;
  final DecimalString?
      exchangeRate; // decimal text; wire format per ApiConfig.rateWireFormat
  final int? paidUnits;
  final int? vodafoneConsumedUnits;
  Json toJson() => {
        if (itemCode != null) 'itemCode': itemCode,
        if (itemLabel != null) 'itemLabel': itemLabel,
        if (egpValueUnits != null) 'egpValueUnits': egpValueUnits,
        if (calculationMode != null) 'calculationMode': calculationMode!.name,
        if (exchangeRate != null)
          'exchangeRate': exchangeRate, // DecimalString; WireJson encodes it
        if (paidUnits != null) 'paidUnits': paidUnits,
        if (vodafoneConsumedUnits != null)
          'vodafoneConsumedUnits': vodafoneConsumedUnits,
      };
}
