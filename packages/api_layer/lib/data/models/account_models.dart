import '../../core/permissions/permission_codes.dart';
import 'common.dart';

/// The four "card" sections share one API shape: /api/{section}/...
enum AccountSection {
  customers('customers', SectionKey.customers, Currency.lyd, 'customer'),
  companies('companies', SectionKey.companies, Currency.lyd, 'company'),
  libyanDeposits('libyan-deposits', SectionKey.libyanDeposits, Currency.lyd,
      'libyan-deposit'),
  egyptianDeposits('egyptian-deposits', SectionKey.egyptianDeposits,
      Currency.egp, 'egyptian-deposit');

  const AccountSection(
      this.path, this.sectionKey, this.currency, this.topicPrefix);
  final String path;
  final SectionKey sectionKey;

  /// Fixed per section (EGP only for Egyptian deposits). Never converted.
  final Currency currency;

  /// Realtime topics: '$topicPrefix.changed', '$topicPrefix.ledger.changed'.
  final String topicPrefix;
}

class AccountCardDto {
  const AccountCardDto({
    required this.id,
    required this.name,
    this.phone,
    required this.balanceUnits,
    required this.currency,
    this.activeAssigneeName,
    this.lastActivityAt,
    this.pinned = false,
    this.version,
    this.nextSequence,
    this.debtAgeDays,
    this.ageStatus,
    this.ageStatusLabel,
    this.zeroReview,
    this.allowedActions,
    this.systemManaged = false,
    this.systemLinkKey,
    this.systemKind,
  });

  final String id;
  final String name;
  final String? phone;
  final int? balanceUnits; // raw server value, display only
  final Currency currency;
  final String? activeAssigneeName;
  final DateTime? lastActivityAt;
  final bool pinned;
  final int? version; // -> expectedVersion on mutations
  final int? nextSequence;
  final int?
      debtAgeDays; // display only; the app does NOT apply 3/7-day thresholds

  /// Required from the server, per API contract: new | warning | overdue | zero | credit + label.
  final String? ageStatus;
  final String? ageStatusLabel;
  final Json? zeroReview;
  final List<String>? allowedActions;

  /// Server flag. System cards can be opened and have no write controls.
  final bool systemManaged;

  /// Confirmed server field: link key of a system-managed card (e.g. masraweya_remainder, purchases_vodafone_remainder). Raw, as sent.
  final String? systemLinkKey;

  /// Pending server confirmation. Raw systemKind only, never aliased to or inferred from systemLinkKey.
  final String? systemKind;

  factory AccountCardDto.fromJson(Json j, AccountSection s) => AccountCardDto(
        id: str(j['id']),
        name: str(j['name']),
        phone: strOrNull(j['phone']),
        balanceUnits: unitsOrNull(j['balanceUnits']),
        currency: currencyOr(j['currency'], s.currency),
        activeAssigneeName: strOrNull(j['activeAssigneeName']),
        lastActivityAt:
            dateOrNull(j['lastActivityAt'] ?? j['lastTransactionAt']),
        pinned: boolOf(j['pinned'] ?? j['isPinned']),
        version: intOrNull(j['version']),
        nextSequence: intOrNull(j['nextSequence']),
        debtAgeDays: intOrNull(j['debtAgeDays']),
        ageStatus: strOrNull(j['ageStatus']),
        ageStatusLabel: strOrNull(j['ageStatusLabel']),
        zeroReview: j['zeroReview'] is Map ? asJson(j['zeroReview']) : null,
        allowedActions:
            j['allowedActions'] is List ? strList(j['allowedActions']) : null,
        systemManaged: boolOf(j['systemManaged']),
        systemLinkKey: strOrNull(j['systemLinkKey']),
        systemKind: strOrNull(j['systemKind']),
      );
}

/// `summary` object of GET /api/{section} (per API contract):
/// `data.summary = {netBalance, totalDebt, activeCards, pendingReviewCount}`.
/// `netBalance`/`totalDebt` are integer money units WITHOUT the `Units` suffix on the wire.
/// - netBalance: section net (what the web card "صافي إجمالي الديون" actually shows).
/// - totalDebt:  sum of positive balances only.
/// All from the server; the app never sums card balances (the web does as a fallback; we don't).
class AccountsSummaryDto {
  const AccountsSummaryDto(
      {this.netBalanceUnits,
      this.totalDebtUnits,
      this.activeCards,
      this.pendingReviewCount,
      this.tabCounts = const {}});
  final int? netBalanceUnits;
  final int? totalDebtUnits;
  final int? activeCards;
  final int? pendingReviewCount;

  /// Requested from the server, per API contract: {active, today, debts, paid, pinned, pendingReview}.
  final Map<String, int> tabCounts;

  factory AccountsSummaryDto.fromJson(Json j) => AccountsSummaryDto(
        netBalanceUnits: unitsOrNull(j['netBalance'] ?? j['netBalanceUnits']),
        totalDebtUnits: unitsOrNull(j['totalDebt'] ?? j['totalDebtUnits']),
        activeCards: intOrNull(j['activeCards']),
        pendingReviewCount: intOrNull(j['pendingReviewCount']),
        tabCounts: {
          for (final e in asJson(j['tabCounts']).entries)
            if (e.value is int) e.key: e.value as int,
        },
      );
}

/// GET /api/{section}?limit&cursor&q&filter -> `{items[], nextCursor, totalItems, summary{…}}`.
class AccountsPage {
  const AccountsPage(
      {required this.page, required this.summary, this.totalItems});
  final Paged<AccountCardDto> page;
  final AccountsSummaryDto summary; // data.summary — server totals
  final int? totalItems; // data.totalItems (top level, not inside summary)

  factory AccountsPage.fromData(Object? data, AccountSection s) {
    final p = Paged.fromData(data, (j) => AccountCardDto.fromJson(j, s));
    return AccountsPage(
      page: p,
      summary: AccountsSummaryDto.fromJson(asJson(p.raw['summary'])),
      totalItems: intOrNull(p.raw['totalItems']),
    );
  }
}

class LedgerEntryDto {
  const LedgerEntryDto({
    required this.id,
    required this.sequence,
    required this.type,
    required this.status,
    this.date,
    this.recordedAt,
    this.note,
    this.amountUnits,
    this.inputValue,
    this.calculationMode,
    this.factorMicros,
    this.balanceAfterUnits,
    this.createdByName,
    this.corrected = false,
    this.version,
    this.paymentMode,
    this.allowedActions,
  });

  final String id;

  /// Absent on the wire stays null. The UI shows a dash; it does not invent 0.
  final int? sequence;
  final String type; // debt | payment (deposits: in/out wording in UI)
  final String
      status; // posted | draft | finalized | reversed | corrected | deleted
  final DateTime? date;
  final DateTime? recordedAt;
  final String? note;
  final int? amountUnits; // server-computed effective amount
  final int? inputValue; // what the user entered (display only)
  final CalculationMode? calculationMode;
  final int?
      factorMicros; // rate × 1e6, display via MoneyFormatter.formatScaled(…, 6)

  /// Required from the server, per API contract. The app does not compute this.
  final int? balanceAfterUnits;
  final String? createdByName;
  final bool corrected;
  final int? version;

  /// Server value `full` / `partial` when present. Never inferred from amounts.
  final String? paymentMode;

  /// Present only when the server sends a list. A missing field stays null so
  /// the UI can fall back to the section permission. The action names inside
  /// the list, including `correct`, are not a confirmed permission vocabulary.
  final List<String>? allowedActions;

  factory LedgerEntryDto.fromJson(Json j) => LedgerEntryDto(
        id: str(j['id']),
        sequence: intOrNull(j['sequence']),
        type: str(j['type']),
        status: str(j['status']),
        date: dateOrNull(j['date']),
        recordedAt: dateOrNull(j['createdAt']),
        note: strOrNull(j['displayNote'] ?? j['note']),
        amountUnits: unitsOrNull(j['amountUnits']),
        inputValue: unitsOrNull(j['inputValue']),
        calculationMode: CalculationMode.fromName(j['calculationMode']),
        factorMicros: unitsOrNull(j['factorMicros']),
        balanceAfterUnits: unitsOrNull(j['balanceAfterUnits']),
        createdByName: strOrNull(j['createdByName'] ?? j['actorName']),
        corrected: boolOf(j['corrected']) || j['correctedAt'] != null,
        version: intOrNull(j['version']),
        paymentMode: strOrNull(j['paymentMode']),
        allowedActions:
            j['allowedActions'] is List ? strList(j['allowedActions']) : null,
      );
}

/// GET /api/{section}/{id}/ledger?limit&before
class LedgerPage {
  const LedgerPage(
      {required this.page,
      required this.currency,
      this.pageOpeningBalanceUnits,
      this.account});
  final Paged<LedgerEntryDto> page;
  final Currency currency;

  /// Display only. NEVER used to accumulate a running balance (web client does; we don't).
  final int? pageOpeningBalanceUnits;
  final AccountCardDto? account;

  factory LedgerPage.fromData(Object? data, AccountSection s) {
    final p = Paged.fromData(data, LedgerEntryDto.fromJson);
    return LedgerPage(
      page: p,
      currency: currencyOr(p.raw['currency'], s.currency),
      pageOpeningBalanceUnits: unitsOrNull(p.raw['pageOpeningBalanceUnits']),
      account: (p.raw['account'] ?? p.raw['customer']) is Map
          ? AccountCardDto.fromJson(
              asJson(p.raw['account'] ?? p.raw['customer']), s)
          : null,
    );
  }
}

class CreateAccountRequest {
  const CreateAccountRequest(
      {required this.name, this.phone, this.openingBalance});
  final String name;
  final String? phone;
  final int? openingBalance; // raw user input (units); server applies it
  Json toJson() => {
        'name': name,
        if (phone != null) 'phone': phone,
        if (openingBalance != null) 'openingBalance': openingBalance
      };
}

class UpdateAccountRequest {
  const UpdateAccountRequest({this.name, this.phone});
  final String? name;
  final String? phone;
  Json toJson() =>
      {if (name != null) 'name': name, if (phone != null) 'phone': phone};
}

enum PaymentMode { partial, full }

/// POST /api/{section}/{id}/transactions
/// {requestId, expectedVersion, type: debt|payment, paymentMode?, inputValue, calculationMode, factor?, date?, note}
/// The server computes the final amount. The app shows no preview, per API contract.
/// [date] is omitted when the caller has no date the user chose; the server stamps it.
class AccountTransactionRequest {
  const AccountTransactionRequest._({
    required this.type,
    this.paymentMode,
    required this.inputValue,
    required this.calculationMode,
    this.factor,
    this.date,
    this.note,
  });

  factory AccountTransactionRequest.debt(
          {required int inputValue,
          CalculationMode mode = CalculationMode.direct,
          DecimalString? factor,
          required DateTime date,
          String? note}) =>
      AccountTransactionRequest._(
          type: 'debt',
          inputValue: inputValue,
          calculationMode: mode,
          factor: factor,
          date: date,
          note: note);

  factory AccountTransactionRequest.partialPayment(
          {required int inputValue,
          CalculationMode mode = CalculationMode.direct,
          DecimalString? factor,
          required DateTime date,
          String? note}) =>
      AccountTransactionRequest._(
          type: 'payment',
          paymentMode: PaymentMode.partial,
          inputValue: inputValue,
          calculationMode: mode,
          factor: factor,
          date: date,
          note: note);

  /// Full payment: same constant body as the web client (inputValue: 1, direct); the server zeroes the balance.
  ///
  /// [date] is sent only when the user chose one. The ledger button has no
  /// date control, so it omits the field and the server stamps the financial date.
  factory AccountTransactionRequest.fullPayment(
          {DateTime? date, String? note}) =>
      AccountTransactionRequest._(
          type: 'payment',
          paymentMode: PaymentMode.full,
          inputValue: 1,
          calculationMode: CalculationMode.direct,
          date: date,
          note: note);

  final String type;
  final PaymentMode? paymentMode;
  final int inputValue;
  final CalculationMode calculationMode;

  /// Rate as typed by the user, kept as decimal TEXT (no float). On the wire it is a JSON
  /// number literal or string per ApiConfig.rateWireFormat (default number), per API contract.
  final DecimalString? factor;
  final DateTime? date;
  final String? note;

  Json toJson() => {
        'type': type,
        if (paymentMode != null) 'paymentMode': paymentMode!.name,
        'inputValue': inputValue,
        'calculationMode': calculationMode.name,
        if (factor != null && calculationMode != CalculationMode.direct)
          'factor': factor, // DecimalString; WireJson encodes it
        if (date != null) 'date': date!.toIso8601String(),
        if (note != null) 'note': note,
      };
}

/// GET /api/{section}/suggestions?q — duplicate-name hints before creation.
class AccountSuggestionDto {
  const AccountSuggestionDto(
      {required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
  factory AccountSuggestionDto.fromJson(Json j) => AccountSuggestionDto(
      id: str(j['id']), name: str(j['name']), phone: strOrNull(j['phone']));
}

/// GET|PATCH /api/egyptian-deposits/exchange-rate  (`egpPerLyd`)
class ExchangeRateDto {
  const ExchangeRateDto({this.egpPerLyd, this.version, this.updatedAt});
  final DecimalString?
      egpPerLyd; // decimal TEXT; displayed only, never used to convert anything
  final int? version;
  final DateTime? updatedAt;
  factory ExchangeRateDto.fromData(Object? data) {
    final d = asJson(data);
    return ExchangeRateDto(
        egpPerLyd: decimalOrNull(d['egpPerLyd']),
        version: intOrNull(d['version']),
        updatedAt: dateOrNull(d['updatedAt']));
  }
}
