import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens live ONLY in secure storage (Keychain / Android Keystore-backed).
abstract interface class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<DateTime?> readAccessExpiry();
  Future<void> saveTokens(
      {required String accessToken,
      required String refreshToken,
      int? expiresInSeconds});
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  final FlutterSecureStorage _s;
  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kExpiry = 'auth.access_expiry';

  // In-memory cache to avoid hitting the keystore on every request.
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccessToken() async =>
      _access ??= await _s.read(key: _kAccess);

  @override
  Future<String?> readRefreshToken() async =>
      _refresh ??= await _s.read(key: _kRefresh);

  @override
  Future<DateTime?> readAccessExpiry() async {
    final v = await _s.read(key: _kExpiry);
    return v == null ? null : DateTime.tryParse(v);
  }

  @override
  Future<void> saveTokens(
      {required String accessToken,
      required String refreshToken,
      int? expiresInSeconds}) async {
    _access = accessToken;
    _refresh = refreshToken;
    await _s.write(key: _kAccess, value: accessToken);
    await _s.write(key: _kRefresh, value: refreshToken);
    if (expiresInSeconds != null) {
      // Expiry timestamp derived from server-provided lifetime (clock bookkeeping, not business math).
      final exp =
          DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds));
      await _s.write(key: _kExpiry, value: exp.toIso8601String());
    } else {
      await _s.delete(key: _kExpiry);
    }
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kExpiry);
  }
}

/// For tests / fake mode only.
class InMemoryTokenStorage implements TokenStorage {
  String? _a, _r;
  DateTime? _e;
  @override
  Future<String?> readAccessToken() async => _a;
  @override
  Future<String?> readRefreshToken() async => _r;
  @override
  Future<DateTime?> readAccessExpiry() async => _e;
  @override
  Future<void> saveTokens(
      {required String accessToken,
      required String refreshToken,
      int? expiresInSeconds}) async {
    _a = accessToken;
    _r = refreshToken;
    _e = expiresInSeconds == null
        ? null
        : DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds));
  }

  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
    _e = null;
  }
}
