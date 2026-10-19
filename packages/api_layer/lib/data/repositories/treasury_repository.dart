import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
import '../models/common.dart';
import '../models/treasury_models.dart';

abstract interface class TreasuryRepository {
  Future<TreasurySummaryDto> summary();
  Future<Paged<CashEntryDto>> cashLedger({String? before});
  Future<MutationAck> addCashEntry(CashEntryRequest r, MutationMeta meta);
}

class RemoteTreasuryRepository implements TreasuryRepository {
  RemoteTreasuryRepository(this._api);
  final ApiClient _api;

  @override
  Future<TreasurySummaryDto> summary() async =>
      TreasurySummaryDto.fromData((await _api.get(ApiEndpoints.treasury)).data);

  @override
  Future<Paged<CashEntryDto>> cashLedger({String? before}) async =>
      Paged.fromData(
          (await _api.get(ApiEndpoints.treasuryCashLedger,
                  query: {'before': before}))
              .data,
          CashEntryDto.fromJson);

  @override
  Future<MutationAck> addCashEntry(
          CashEntryRequest r, MutationMeta meta) async =>
      MutationAck.fromData((await _api.post(ApiEndpoints.treasuryCashEntries,
              body: {...meta.toBody(), ...r.toJson()}))
          .data);
}
