import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
import '../models/account_models.dart';
import '../models/common.dart';

/// Cards + ledger for customers / companies / libyan-deposits / egyptian-deposits.
/// (= "الكروت" + "فتح السجل الداخلي" + "إنشاء/تعديل/إلغاء المعاملة" + "التسديد" in the contract.)
abstract interface class AccountsRepository {
  Future<AccountsPage> list(AccountSection s,
      {String? cursor, int limit = 100, String? q, String? filter});
  Future<List<AccountSuggestionDto>> suggestions(AccountSection s, String q);
  Future<MutationAck> create(
      AccountSection s, CreateAccountRequest r, MutationMeta meta);
  Future<AccountCardDto> get(AccountSection s, String id);
  Future<MutationAck> update(
      AccountSection s, String id, UpdateAccountRequest r, MutationMeta meta);
  Future<LedgerPage> ledger(AccountSection s, String id,
      {String? before, int limit = 100});

  /// Debt / partial payment / full payment (server computes amount + new balance).
  Future<MutationAck> addTransaction(AccountSection s, String accountId,
      AccountTransactionRequest r, MutationMeta meta);
  Future<MutationAck> correctTransaction(AccountSection s, String accountId,
      String txId, AccountTransactionRequest r, MutationMeta meta);
  Future<MutationAck> cancelTransaction(
      AccountSection s, String accountId, String txId, MutationMeta meta,
      {String? reason});
  Future<MutationAck> setPinned(
      AccountSection s, String id, bool pinned, MutationMeta meta);

  /// Customers only; admin. Uses `expectedFinancialVersion`.
  Future<MutationAck> confirmZeroReview(String customerId, MutationMeta meta);

  Future<ExchangeRateDto> getExchangeRate();
  Future<ExchangeRateDto> updateExchangeRate(
      String egpPerLyd, MutationMeta meta);
}

class RemoteAccountsRepository implements AccountsRepository {
  RemoteAccountsRepository(this._api);
  final ApiClient _api;

  @override
  Future<AccountsPage> list(AccountSection s,
      {String? cursor, int limit = 100, String? q, String? filter}) async {
    final res = await _api.get(ApiEndpoints.accounts(s.path),
        query: {'limit': limit, 'cursor': cursor, 'q': q, 'filter': filter});
    return AccountsPage.fromData(res.data, s);
  }

  @override
  Future<List<AccountSuggestionDto>> suggestions(
      AccountSection s, String q) async {
    final res = await _api
        .get(ApiEndpoints.accountSuggestions(s.path), query: {'q': q});
    return Paged.fromData(res.data, AccountSuggestionDto.fromJson).items;
  }

  @override
  Future<MutationAck> create(
          AccountSection s, CreateAccountRequest r, MutationMeta meta) async =>
      MutationAck.fromData((await _api.post(ApiEndpoints.accounts(s.path),
              body: {...meta.toBody(), ...r.toJson()}))
          .data);

  @override
  Future<AccountCardDto> get(AccountSection s, String id) async {
    final d = asJson((await _api.get(ApiEndpoints.account(s.path, id))).data);
    final inner = d['account'] ?? d['customer'] ?? d['company'];
    return AccountCardDto.fromJson(inner is Map ? asJson(inner) : d, s);
  }

  @override
  Future<MutationAck> update(AccountSection s, String id,
          UpdateAccountRequest r, MutationMeta meta) async =>
      MutationAck.fromData((await _api.patch(ApiEndpoints.account(s.path, id),
              body: {...meta.toBody(), ...r.toJson()}))
          .data);

  @override
  Future<LedgerPage> ledger(AccountSection s, String id,
      {String? before, int limit = 100}) async {
    final res = await _api.get(ApiEndpoints.accountLedger(s.path, id),
        query: {'limit': limit, 'before': before});
    return LedgerPage.fromData(res.data, s);
  }

  @override
  Future<MutationAck> addTransaction(AccountSection s, String accountId,
          AccountTransactionRequest r, MutationMeta meta) async =>
      MutationAck.fromData((await _api.post(
              ApiEndpoints.accountTransactions(s.path, accountId),
              body: {...meta.toBody(), ...r.toJson()}))
          .data);

  @override
  Future<MutationAck> correctTransaction(AccountSection s, String accountId,
          String txId, AccountTransactionRequest r, MutationMeta meta) async =>
      MutationAck.fromData((await _api.post(
              ApiEndpoints.accountTxCorrection(s.path, accountId, txId),
              body: {...meta.toBody(), ...r.toJson()}))
          .data);

  @override
  Future<MutationAck> cancelTransaction(
          AccountSection s, String accountId, String txId, MutationMeta meta,
          {String? reason}) async =>
      MutationAck.fromData((await _api.post(
              ApiEndpoints.accountTxCancel(s.path, accountId, txId),
              body: {...meta.toBody(), if (reason != null) 'reason': reason}))
          .data);

  @override
  Future<MutationAck> setPinned(
          AccountSection s, String id, bool pinned, MutationMeta meta) async =>
      MutationAck.fromData((await _api.patch(
              ApiEndpoints.accountPin(s.path, id),
              body: {...meta.toBody(), 'pinned': pinned}))
          .data);

  @override
  Future<MutationAck> confirmZeroReview(
          String customerId, MutationMeta meta) async =>
      MutationAck.fromData((await _api.post(
              ApiEndpoints.customerZeroReview(customerId),
              body: meta.toBody(versionField: 'expectedFinancialVersion')))
          .data);

  @override
  Future<ExchangeRateDto> getExchangeRate() async => ExchangeRateDto.fromData(
      (await _api.get(ApiEndpoints.egyptianExchangeRate)).data);

  @override
  Future<ExchangeRateDto> updateExchangeRate(
          String egpPerLyd, MutationMeta meta) async =>
      ExchangeRateDto.fromData((await _api.patch(
              ApiEndpoints.egyptianExchangeRate,
              body: {...meta.toBody(), 'egpPerLyd': egpPerLyd}))
          .data);
}
