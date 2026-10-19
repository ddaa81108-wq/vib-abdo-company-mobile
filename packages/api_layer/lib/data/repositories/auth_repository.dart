import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/auth_models.dart';

/// Cookie-session endpoints (per API contract).
abstract interface class AuthRepository {
  /// POST /api/auth/login {username, password} -> {user, csrfToken}. Sets the session cookie.
  Future<LoginResult> login(
      {required String username, required String password});

  /// POST /api/auth/logout (requires cookie + X-CSRF-Token).
  Future<void> logout();

  /// POST /api/auth/change-password {currentPassword, newPassword} (min 10 chars, server-validated).
  Future<void> changePassword(
      {required String currentPassword, required String newPassword});
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api);
  final ApiClient _api;
  static const _public = ApiRequestOptions(authenticated: false, noRetry: true);

  @override
  Future<LoginResult> login(
      {required String username, required String password}) async {
    final res = await _api.post(ApiEndpoints.login,
        body: {'username': username, 'password': password}, options: _public);
    return LoginResult.fromData(res.data);
  }

  @override
  Future<void> logout() async {
    await _api.post(ApiEndpoints.logout);
  }

  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    await _api.post(ApiEndpoints.changePassword,
        body: {'currentPassword': currentPassword, 'newPassword': newPassword});
  }
}
