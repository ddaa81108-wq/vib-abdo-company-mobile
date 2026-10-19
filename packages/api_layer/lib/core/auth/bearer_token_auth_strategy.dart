import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import '../session/token_storage.dart';
import 'auth_strategy.dart';

/// 🔶 STUB — PENDING the server owner's answer about a mobile token scheme
/// (contract §3.B). The real system today only supports cookie + CSRF.
/// Proposed contract: POST /api/auth/mobile/login -> {accessToken, refreshToken, expiresIn},
/// POST /api/auth/mobile/refresh (rotation), POST /api/auth/mobile/logout.
/// Until confirmed: no refresh is attempted; 401 -> forced logout.
class BearerTokenAuthStrategy implements AuthStrategy {
  BearerTokenAuthStrategy({required TokenStorage tokenStorage})
      : _tokens = tokenStorage;
  final TokenStorage _tokens;

  @override
  String get name => 'bearer(pending)';

  @override
  Future<void> attach(RequestOptions options,
      {required bool authenticated}) async {
    if (!authenticated) return;
    final token = await _tokens.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
  }

  @override
  Future<void> capture(Response<dynamic> response) async {}

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async {
    final access = loginData['accessToken'];
    final refresh = loginData['refreshToken'];
    if (access is String && refresh is String) {
      await _tokens.saveTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresInSeconds: (loginData['expiresIn'] as num?)?.toInt(),
      );
    }
  }

  @override
  Future<void> onSessionResumed() async {}

  @override
  Future<bool> hasPersistedSession() async =>
      (await _tokens.readRefreshToken()) != null;

  @override
  Future<AuthErrorAction> handleAuthError(
      ApiException error, RequestOptions request,
      {required bool authenticated}) async {
    // TODO(pending server answer): single-flight refresh via /api/auth/mobile/refresh with rotation.
    if (error is SessionExpiredException && authenticated) {
      return AuthErrorAction.forceLogout;
    }
    return AuthErrorAction.passThrough;
  }

  @override
  Future<void> clear() => _tokens.clear();
}
