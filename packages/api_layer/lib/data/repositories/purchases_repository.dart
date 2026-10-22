import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
import '../models/common.dart';
import '../models/purchase_models.dart';

/// Purchases books (al_bayan / simsim). Version field on this domain: `expectedDayVersion`.
abstract interface class PurchasesRepository {
  Future<PurchasesBookPage> list(PurchaseBook book,
      {String? before, int limit = 100});
  Future<MutationAck> create(
      PurchaseBook book, PurchaseEntryRequest r, MutationMeta meta);
  Future<MutationAck> update(PurchaseBook book, String entryId,
      PurchaseEntryRequest r, MutationMeta meta);

  /// Server deletes and recomputes following days.
  Future<MutationAck> delete(
      PurchaseBook book, String entryId, MutationMeta meta);
  Future<MutationAck> setOpening(PurchaseBook book,
      {required int previousDebtUnits,
      required int previousVodafoneUnits,
      required MutationMeta meta});

  /// Requires purchases.finalize.
  Future<MutationAck> finalizeDay(PurchaseBook book, MutationMeta meta);
  Future<MutationAck> setDayCorrection(PurchaseBook book, String day,
      {required bool open, required MutationMeta meta});
}

class RemotePurchasesRepository implements PurchasesRepository {
  RemotePurchasesRepository(this._api);
  final ApiClient _api;
  static const _v = 'expectedDayVersion';

  @override
  Future<PurchasesBookPage> list(PurchaseBook book,
      {String? before, int limit = 100}) async {
    final path = ApiEndpoints.purchases(book.path);
    final data =
        (await _api.get(path, query: {'limit': limit, 'before': before})).data;
    return runWithMoneyEndpoint(path, () => PurchasesBookPage.fromData(data));
  }

  @override
  Future<MutationAck> create(
      PurchaseBook book, PurchaseEntryRequest r, MutationMeta meta) async {
    PurchaseItemCodes.require(r.itemCode, r.itemLabel);
    return MutationAck.fromData((await _api.post(ApiEndpoints.purchases(book.path),
            body: {...meta.toBody(versionField: _v), ...r.toJson()}))
        .data);
  }

  @override
  Future<MutationAck> update(PurchaseBook book, String entryId,
      PurchaseEntryRequest r, MutationMeta meta) async {
    PurchaseItemCodes.require(r.itemCode, r.itemLabel);
    return MutationAck.fromData((await _api.patch(
            ApiEndpoints.purchaseEntry(book.path, entryId),
            body: {...meta.toBody(versionField: _v), ...r.toJson()}))
        .data);
  }

  @override
  Future<MutationAck> delete(
          PurchaseBook book, String entryId, MutationMeta meta) async =>
      MutationAck.fromData((await _api.delete(
              ApiEndpoints.purchaseEntry(book.path, entryId),
              body: meta.toBody(versionField: _v)))
          .data);

  @override
  Future<MutationAck> setOpening(PurchaseBook book,
          {required int previousDebtUnits,
          required int previousVodafoneUnits,
          required MutationMeta meta}) async =>
      MutationAck.fromData(
          (await _api.patch(ApiEndpoints.purchasesOpening(book.path), body: {
        ...meta.toBody(versionField: _v),
        'previousDebtUnits': previousDebtUnits,
        'previousVodafoneUnits': previousVodafoneUnits,
      }))
              .data);

  @override
  Future<MutationAck> finalizeDay(PurchaseBook book, MutationMeta meta) async =>
      MutationAck.fromData((await _api.post(
              ApiEndpoints.purchasesFinalize(book.path),
              body: meta.toBody(versionField: _v)))
          .data);

  @override
  Future<MutationAck> setDayCorrection(PurchaseBook book, String day,
          {required bool open, required MutationMeta meta}) async =>
      MutationAck.fromData((await _api.patch(
              ApiEndpoints.purchasesDayCorrection(book.path, day),
              body: {...meta.toBody(versionField: _v), 'open': open}))
          .data);
}
