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

/// Vodafone amounts are Egyptian pounds.
///
/// Confirmed by the API contract: Egyptian deposits, Masraweya, and Vodafone
/// are EGP, and `vodafoneConsumedUnits` / `vodafoneRemainingUnits` are pounds
/// (`docs/api/README.ar.md`). DEF-033.
const Currency vodafoneCurrency = Currency.egp;

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
    this.dayId,
    this.sequence,
    this.dayNumber,
    this.businessDate,
    this.dayStatus,
    this.dayClosingDebtUnits,
    this.dayVersion,
    this.correctionOpen = false,
    this.itemCode,
    this.itemLabel,
    this.egpValueUnits,
    this.calculationMode,
    this.exchangeRate,
    this.resultUnits,
    this.paidUnits,
    this.remainingUnits,
    this.vodafoneConsumedUnits,
    this.actorName,
    this.actorIsOwner = false,
    this.version,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? dayId;
  final int? sequence;
  final int? dayNumber;
  final String? businessDate;

  /// `draft` or `finalized` on the entry's own day.
  final String? dayStatus;
  final MoneyValue? dayClosingDebtUnits;
  final int? dayVersion;
  final bool correctionOpen;
  final String? itemCode;
  final String? itemLabel;
  final MoneyValue? egpValueUnits; // EGP
  final CalculationMode? calculationMode;
  final DecimalString?
  exchangeRate; // decimal TEXT; display via formatDecimal only
  final MoneyValue? resultUnits; // LYD, server-computed
  final MoneyValue? paidUnits; // LYD
  final MoneyValue? remainingUnits; // LYD, server-computed
  final MoneyValue? vodafoneConsumedUnits; // EGP ([vodafoneCurrency])
  final String? actorName;
  final bool actorIsOwner;

  /// Row version. Writes still send the day's version only (P-05).
  final int? version;
  final String? createdAt;
  final String? updatedAt;

  factory PurchaseEntryDto.fromJson(Json j) {
    final rowId = strOrNull(j['id']);
    MoneyValue? money(String key) =>
        unitsOrNull(j[key], fieldPath: key, rowId: rowId);
    return PurchaseEntryDto(
      id: str(j['id']),
      dayId: strOrNull(j['dayId']),
      sequence: intOrNull(j['sequence']),
      dayNumber: intOrNull(j['dayNumber']),
      businessDate: strOrNull(j['businessDate']),
      dayStatus: strOrNull(j['dayStatus']),
      dayClosingDebtUnits: money('dayClosingDebtUnits'),
      dayVersion: intOrNull(j['dayVersion']),
      correctionOpen: boolOf(j['correctionOpen']),
      itemCode: strOrNull(j['itemCode']),
      itemLabel: strOrNull(j['itemLabel']),
      egpValueUnits: money('egpValueUnits'),
      calculationMode: CalculationMode.fromName(j['calculationMode']),
      exchangeRate: decimalOrNull(j['exchangeRate']),
      resultUnits: money('resultUnits'),
      paidUnits: money('paidUnits'),
      remainingUnits: money('remainingUnits'),
      vodafoneConsumedUnits: money('vodafoneConsumedUnits'),
      actorName: strOrNull(j['actorName']),
      actorIsOwner: boolOf(j['actorIsOwner']),
      version: intOrNull(j['version']),
      createdAt: strOrNull(j['createdAt']),
      updatedAt: strOrNull(j['updatedAt']),
    );
  }
}

/// The open purchase day. `previous*` is the carried opening on this day.
///
/// `status` is `draft` or `finalized`. A correction session is [correctionOpen],
/// not a third status. Money stays on this object; entries are siblings on
/// [PurchasesPage].
class PurchaseDayDto {
  const PurchaseDayDto({
    required this.id,
    this.dayNumber,
    this.businessDate,
    this.status,
    this.previousDebtUnits,
    this.previousVodafoneUnits,
    this.todayResultUnits,
    this.todayPaidUnits,
    this.totalDebtUnits,
    this.vodafoneRemainingUnits,
    this.version,
    this.correctionOpen = false,
  });

  final String id;
  final int? dayNumber;
  final String? businessDate;

  /// `draft` or `finalized`.
  final String? status;
  final MoneyValue? previousDebtUnits; // LYD
  final MoneyValue? previousVodafoneUnits; // EGP
  final MoneyValue? todayResultUnits; // LYD
  final MoneyValue? todayPaidUnits; // LYD
  final MoneyValue? totalDebtUnits; // LYD
  final MoneyValue? vodafoneRemainingUnits; // EGP ([vodafoneCurrency])

  /// Day version sent as `expectedDayVersion`.
  final int? version;
  final bool correctionOpen;

  /// Widget key and correction-chip id. The write path uses [id].
  String get numberLabel => dayNumber == null ? id : '$dayNumber';

  static PurchaseDayDto? fromJsonOrNull(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (يوم المشتريات)',
      );
    }
    final j = asJson(value);
    final rowId = strOrNull(j['id']);
    MoneyValue? money(String key) =>
        unitsOrNull(j[key], fieldPath: 'day.$key', rowId: rowId);
    return PurchaseDayDto(
      id: str(j['id']),
      dayNumber: intOrNull(j['dayNumber']),
      businessDate: strOrNull(j['businessDate']),
      status: strOrNull(j['status']),
      previousDebtUnits: money('previousDebtUnits'),
      previousVodafoneUnits: money('previousVodafoneUnits'),
      todayResultUnits: money('todayResultUnits'),
      todayPaidUnits: money('todayPaidUnits'),
      totalDebtUnits: money('totalDebtUnits'),
      vodafoneRemainingUnits: money('vodafoneRemainingUnits'),
      version: intOrNull(j['version']),
      correctionOpen: boolOf(j['correctionOpen']),
    );
  }
}

class PurchaseMerchantDto {
  const PurchaseMerchantDto({required this.key, required this.name});

  final String key;
  final String name;

  static PurchaseMerchantDto? fromJsonOrNull(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (التاجر)',
      );
    }
    final j = asJson(value);
    return PurchaseMerchantDto(key: str(j['key']), name: str(j['name']));
  }
}

/// Register totals for one merchant, across the whole book.
///
/// `remainingUnits` and `vodafoneRemainingUnits` are the open day's carried
/// balance, including opening and finalize. They are not a sum of this page.
/// A non-integer money field is [MoneyValue.invalid] for that field. A
/// `registerTotals` value that is present but is not a JSON object still
/// fails the whole response: there is no field left to mark.
class PurchasesRegisterTotalsDto {
  const PurchasesRegisterTotalsDto({
    this.resultUnits,
    this.paidUnits,
    this.remainingUnits,
    this.vodafoneConsumedUnits,
    this.vodafoneRemainingUnits,
  });

  final MoneyValue? resultUnits; // LYD
  final MoneyValue? paidUnits; // LYD
  final MoneyValue? remainingUnits; // LYD
  final MoneyValue? vodafoneConsumedUnits; // EGP
  final MoneyValue? vodafoneRemainingUnits; // EGP

  static PurchasesRegisterTotalsDto? fromJsonOrNull(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (إجماليات السجل)',
      );
    }
    final j = asJson(value);
    MoneyValue? money(String key) =>
        unitsOrNull(j[key], fieldPath: 'registerTotals.$key');
    return PurchasesRegisterTotalsDto(
      resultUnits: money('resultUnits'),
      paidUnits: money('paidUnits'),
      remainingUnits: money('remainingUnits'),
      vodafoneConsumedUnits: money('vodafoneConsumedUnits'),
      vodafoneRemainingUnits: money('vodafoneRemainingUnits'),
    );
  }
}

/// GET /api/purchases/{merchant}?limit=&before=
///
/// `days`, `lifetimeTotals`, and `totals` are not read. The contract page is
/// one open [day], a flat [entries] list, numeric [nextBefore], and
/// [registerTotals].
class PurchasesPage {
  const PurchasesPage({
    this.merchant,
    this.day,
    this.entries = const [],
    this.nextBefore,
    this.registerTotals,
  });

  final PurchaseMerchantDto? merchant;
  final PurchaseDayDto? day;
  final List<PurchaseEntryDto> entries;

  /// Pass this integer back as `before`. Null when there is no older page.
  final int? nextBefore;
  final PurchasesRegisterTotalsDto? registerTotals;

  factory PurchasesPage.fromData(Object? data) {
    if (data is! Map) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة (المشتريات)',
      );
    }
    final raw = asJson(data);
    return PurchasesPage(
      merchant: PurchaseMerchantDto.fromJsonOrNull(raw['merchant']),
      day: PurchaseDayDto.fromJsonOrNull(raw['day']),
      entries: asJsonList(raw['entries'])
          .map(PurchaseEntryDto.fromJson)
          .toList(growable: false),
      nextBefore: _nextBefore(raw['nextBefore']),
      registerTotals: PurchasesRegisterTotalsDto.fromJsonOrNull(
        raw['registerTotals'],
      ),
    );
  }
}

/// `nextBefore` is an integer or null. Anything else is a broken cursor, not
/// a money field, so the page fails instead of truncating it.
int? _nextBefore(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  throw const InvalidServerResponseException(
    message: 'استجابة الخادم غير صالحة (مؤشر المشتريات)',
  );
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
