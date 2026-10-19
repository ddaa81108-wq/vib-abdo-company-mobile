import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/profile_models.dart';

abstract interface class ProfileRepository {
  /// GET /api/me — user + role + permissions[] + mustChangePassword.
  Future<MeResponse> fetchMe();
}

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<MeResponse> fetchMe() async =>
      MeResponse.fromData((await _api.get(ApiEndpoints.me)).data);
}
