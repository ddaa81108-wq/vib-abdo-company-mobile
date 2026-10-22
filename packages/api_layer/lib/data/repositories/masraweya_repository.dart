import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
import '../../core/network/logging_interceptor.dart';
import '../models/masraweya_models.dart';

abstract interface class MasraweyaRepository {
  Future<MasraweyaDayDto> getDay({String? date});

  /// Returns the server's recomputed day (workTotalUnits / remainingUnits requested from server).
  Future<MasraweyaDayDto> saveDay(SaveMasraweyaDayRequest r, MutationMeta meta);
}

class RemoteMasraweyaRepository implements MasraweyaRepository {
  RemoteMasraweyaRepository(this._api);
  final ApiClient _api;

  @override
  Future<MasraweyaDayDto> getDay({String? date}) async {
    const path = ApiEndpoints.masraweyaDay;
    final data = (await _api.get(path, query: {'date': date})).data;
    return runWithMoneyEndpoint(path, () => MasraweyaDayDto.fromData(data));
  }

  @override
  Future<MasraweyaDayDto> saveDay(
      SaveMasraweyaDayRequest r, MutationMeta meta) async {
    const path = ApiEndpoints.masraweyaDay;
    final data = (await _api.put(path, body: {...meta.toBody(), ...r.toJson()}))
        .data;
    return runWithMoneyEndpoint(path, () => MasraweyaDayDto.fromData(data));
  }
}
