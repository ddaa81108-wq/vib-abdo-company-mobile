import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/home_models.dart';

/// Home screen (04_ui_spec §6.2). Uses the PROPOSED aggregated `GET /api/home`
/// (➕ تحتاج إضافة من الخادم). Until the server adds it the call fails (likely
/// NotFoundException); the UI then falls back to the existing per-section endpoints
/// (accounts `summary`, collections `metrics`, treasury, reports) shown as-is with neutral
/// colours (no `tone`). No values are combined across sections or currencies.
abstract interface class HomeRepository {
  Future<HomeDto> fetch();
}

class RemoteHomeRepository implements HomeRepository {
  RemoteHomeRepository(this._api);
  final ApiClient _api;

  @override
  Future<HomeDto> fetch() async =>
      HomeDto.fromData((await _api.get(ApiEndpoints.proposedHome)).data);
}
