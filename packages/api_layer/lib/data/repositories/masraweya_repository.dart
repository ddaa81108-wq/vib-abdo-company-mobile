import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
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
  Future<MasraweyaDayDto> getDay({String? date}) async =>
      MasraweyaDayDto.fromData((await _api
              .get(ApiEndpoints.masraweyaDay, query: {'date': date}))
          .data);

  @override
  Future<MasraweyaDayDto> saveDay(
          SaveMasraweyaDayRequest r, MutationMeta meta) async =>
      MasraweyaDayDto.fromData((await _api.put(ApiEndpoints.masraweyaDay,
              body: {...meta.toBody(), ...r.toJson()}))
          .data);
}
