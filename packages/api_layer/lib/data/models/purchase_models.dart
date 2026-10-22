import '../../core/network/api_exception.dart';
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

/// Purchase `itemCode` values, per API contract.
///
/// `custom` is the only code that carries a free-text `itemLabel`. The chip
/// caption «نوع آخر» is not a server label and must not be sent.
abstract final class PurchaseItemCodes {
  static const vodafoneCash = 'vodafone_cash';
  static const kafrElSheikh = 'kafr_el_sheikh';
  static const cairo = 'cairo';
  static const mansoura = 'mansoura';
  static const fawry = 'fawry';
  static const banks = 'banks';
  static const custom = 'custom';

  /// Display caption for [custom]. Never a valid `itemLabel`.
  static const customCaption = 'نوع آخر';

  static const values = <String>[
    vodafoneCash,
    kafrElSheikh,
    cairo,
    mansoura,
    fawry,
    banks,
    custom,
  ];

  static bool contains(String? code) => code != null && values.contains(code);

  /// Rejects a code outside [values], and a custom row whose label is missing
  /// or equal to [customCaption].
  static void require(String? itemCode, String? itemLabel) {
    if (!contains(itemCode)) {
      throw const BadRequestException(
        code: 'VALIDATION_ERROR',
        message: 'نوع العملية غير معروف',
      );
    }
    if (itemCode != custom) return;
    final label = itemLabel?.trim() ?? '';
    if (label.isEmpty || label == customCaption) {
      throw const BadRequestException(
        code: 'VALIDATION_ERROR',
        message: 'أدخل اسم النوع',
      );
    }
  }
}

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
  final MoneyValue? egpValueUnits; // EGP
  final CalculationMode? calculationMode;
  final DecimalString?
      exchangeRate; // decimal TEXT; display via formatDecimal only
  final MoneyValue? resultUnits; // LYD, server-computed
  final MoneyValue? paidUnits; // LYD
  final MoneyValue? remainingUnits; // LYD, server-computed
  final MoneyValue? vodafoneConsumedUnits;
  final int? version;

  factory PurchaseEntryDto.fromJson(Json j) => PurchaseEntryDto(
        id: str(j['id']),
        kind: str(j['kind'] ?? j['entryType'], 'entry'),
        itemCode: strOrNull(j['itemCode']),
        itemLabel: strOrNull(j['itemLabel']),
        egpValueUnits: unitsOrNull(
          j['egpValueUnits'],
          fieldPath: 'egpValueUnits',
          rowId: strOrNull(j['id']),
        ),
        calculationMode: CalculationMode.fromName(j['calculationMode']),
        exchangeRate: decimalOrNull(j['exchangeRate']),
        resultUnits: unitsOrNull(
          j['resultUnits'],
          fieldPath: 'resultUnits',
          rowId: strOrNull(j['id']),
        ),
        paidUnits: unitsOrNull(
          j['paidUnits'],
          fieldPath: 'paidUnits',
          rowId: strOrNull(j['id']),
        ),
        remainingUnits: unitsOrNull(
          j['remainingUnits'],
          fieldPath: 'remainingUnits',
          rowId: strOrNull(j['id']),
        ),
        vodafoneConsumedUnits: unitsOrNull(
          j['vodafoneConsumedUnits'],
          fieldPath: 'vodafoneConsumedUnits',
          rowId: strOrNull(j['id']),
        ),
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
    this.previousVodafoneUnits,
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
  final MoneyValue? previousDebtUnits;
  final MoneyValue? previousVodafoneUnits;
  final MoneyValue? todayResultUnits;
  final MoneyValue? todayPaidUnits;
  final MoneyValue? totalDebtUnits;
  final MoneyValue? vodafoneRemainingUnits;
  final MoneyValue? dayClosingDebtUnits;

  factory PurchaseDayDto.fromJson(Json j) {
    final totalsRaw = j['totals'];
    requireJsonObject(totalsRaw, 'day.totals');
    final t = totalsRaw is Map ? asJson(totalsRaw) : j;
    final rowId = strOrNull(j['day'] ?? j['dayNumber'] ?? j['id']);
    MoneyValue? money(String key) => unitsOrNull(
          t[key],
          fieldPath: 'totals.$key',
          rowId: rowId,
        );
    return PurchaseDayDto(
      day: str(j['day'] ?? j['dayNumber'] ?? j['id']),
      version: intOrNull(j['version'] ?? j['dayVersion']),
      status: strOrNull(j['status']),
      entries: asJsonList(j['entries'])
          .map(PurchaseEntryDto.fromJson)
          .toList(growable: false),
      previousDebtUnits: money('previousDebtUnits'),
      previousVodafoneUnits: money('previousVodafoneUnits'),
      todayResultUnits: money('todayResultUnits'),
      todayPaidUnits: money('todayPaidUnits'),
      totalDebtUnits: money('totalDebtUnits'),
      vodafoneRemainingUnits: money('vodafoneRemainingUnits'),
      dayClosingDebtUnits: money('dayClosingDebtUnits'),
    );
  }
}

/// GET /api/purchases/{book}?limit=100&before
class PurchasesBookPage {
  const PurchasesBookPage({
    required this.page,
    this.lifetimeTotals,
    this.opening,
  });
  final Paged<PurchaseDayDto> page;

  /// Null when the server omits the totals object.
  final PurchasesLifetimeTotalsDto? lifetimeTotals;

  /// Null when the server omits an `opening` object. The screen then shows the
  /// first day's previous-balance fields.
  final PurchaseOpeningDto? opening;

  factory PurchasesBookPage.fromData(Object? data) {
    requireJsonObject(data is List ? null : data, 'purchases');
    final p = Paged.fromData(data, PurchaseDayDto.fromJson, itemsKey: 'days');
    return PurchasesBookPage(
      page: p,
      lifetimeTotals: PurchasesLifetimeTotalsDto.fromJsonOrNull(
        p.raw['lifetimeTotals'] ?? p.raw['totals'],
      ),
      opening: PurchaseOpeningDto.fromJsonOrNull(p.raw['opening']),
    );
  }
}

/// Book opening returned by the server, when it sends one.
/// Amounts are raw units. There is no local balance math.
class PurchaseOpeningDto {
  const PurchaseOpeningDto({
    this.previousDebtUnits,
    this.previousVodafoneUnits,
    this.version,
  });

  final MoneyValue? previousDebtUnits;
  final MoneyValue? previousVodafoneUnits;
  final int? version;

  static PurchaseOpeningDto? fromJsonOrNull(Object? v) {
    if (v == null) return null;
    if (v is! Map) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (الرصيد الافتتاحي)',
      );
    }
    final j = asJson(v);
    return PurchaseOpeningDto(
      previousDebtUnits: unitsOrNull(
        j['previousDebtUnits'],
        fieldPath: 'opening.previousDebtUnits',
      ),
      previousVodafoneUnits: unitsOrNull(
        j['previousVodafoneUnits'],
        fieldPath: 'opening.previousVodafoneUnits',
      ),
      version: intOrNull(j['version'] ?? j['dayVersion']),
    );
  }
}

/// Opening figures the screen may show: the server `opening` object when
/// present, otherwise the first day on the page. Field choice only.
class ResolvedPurchaseOpening {
  const ResolvedPurchaseOpening({
    this.previousDebtUnits,
    this.previousVodafoneUnits,
    this.version,
  });

  final MoneyValue? previousDebtUnits;
  final MoneyValue? previousVodafoneUnits;
  final int? version;

  factory ResolvedPurchaseOpening.fromPage(PurchasesBookPage page) {
    final opening = page.opening;
    final first = page.page.items.isEmpty ? null : page.page.items.first;
    return ResolvedPurchaseOpening(
      previousDebtUnits: opening?.previousDebtUnits ?? first?.previousDebtUnits,
      previousVodafoneUnits:
          opening?.previousVodafoneUnits ?? first?.previousVodafoneUnits,
      version: opening?.version ?? first?.version,
    );
  }
}

/// Register totals since the beginning. Key names pending server confirmation.
///
/// A non-integer money field is [MoneyValue.invalid] for that field. A
/// `lifetimeTotals` value that is present but is not a JSON object still
/// fails the whole response: there is no field left to mark.
class PurchasesLifetimeTotalsDto {
  const PurchasesLifetimeTotalsDto({
    this.resultUnits,
    this.paidUnits,
    this.remainingUnits,
    this.all = const {},
  });

  final MoneyValue? resultUnits;
  final MoneyValue? paidUnits;
  final MoneyValue? remainingUnits; // LYD
  final Map<String, MoneyValue> all;

  static PurchasesLifetimeTotalsDto? fromJsonOrNull(Object? v) {
    if (v == null) return null;
    if (v is! Map) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (إجماليات السجل)',
      );
    }
    final all = <String, MoneyValue>{};
    v.forEach((k, value) {
      final u = unitsOrNull(value, fieldPath: 'lifetimeTotals.$k');
      if (u != null) all['$k'] = u;
    });
    return PurchasesLifetimeTotalsDto(
      resultUnits: all['resultUnits'],
      paidUnits: all['paidUnits'],
      remainingUnits: all['remainingUnits'],
      all: Map.unmodifiable(all),
    );
  }
}

/// POST /api/purchases/{book} / PATCH …/entries/{id}
/// {requestId, expectedDayVersion, itemCode, itemLabel, egpValueUnits, calculationMode, exchangeRate, paidUnits, vodafoneConsumedUnits}
class PurchaseEntryRequest {
  const PurchaseEntryRequest({
    this.itemCode,
    this.itemLabel,
    this.egpValueUnits,
    this.calculationMode,
    this.exchangeRate,
    this.paidUnits,
    this.vodafoneConsumedUnits,
  });
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
