import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Last successful device registration. The token must not be logged.
class StoredDeviceRegistration {
  const StoredDeviceRegistration({required this.token, required this.userId});

  final String token;
  final String userId;

  @override
  String toString() => 'StoredDeviceRegistration()';
}

/// Device push token. Secure storage only. Callers must not log the value.
abstract interface class DeviceTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();

  /// Last successful `(token, userId)`, or null. Must not be logged.
  Future<StoredDeviceRegistration?> readSuccessfulRegistration();

  Future<void> writeSuccessfulRegistration(
    StoredDeviceRegistration registration,
  );

  Future<void> deleteSuccessfulRegistration();
}

class SecureDeviceTokenStore implements DeviceTokenStore {
  SecureDeviceTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'push.device_token.v1';
  static const _registrationKey = 'push.device_registration.v1';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);

  @override
  Future<StoredDeviceRegistration?> readSuccessfulRegistration() async {
    final raw = await _storage.read(key: _registrationKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final token = decoded['token'];
      final userId = decoded['userId'];
      if (token is! String || token.isEmpty || userId is! String) return null;
      return StoredDeviceRegistration(token: token, userId: userId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSuccessfulRegistration(
    StoredDeviceRegistration registration,
  ) {
    return _storage.write(
      key: _registrationKey,
      value: jsonEncode({
        'userId': registration.userId,
        'token': registration.token,
      }),
    );
  }

  @override
  Future<void> deleteSuccessfulRegistration() =>
      _storage.delete(key: _registrationKey);
}

/// Tests. Not used for a signed-in release session.
class MemoryDeviceTokenStore implements DeviceTokenStore {
  String? _token;
  StoredDeviceRegistration? _registration;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> delete() async {
    _token = null;
  }

  @override
  Future<StoredDeviceRegistration?> readSuccessfulRegistration() async =>
      _registration;

  @override
  Future<void> writeSuccessfulRegistration(
    StoredDeviceRegistration registration,
  ) async {
    _registration = registration;
  }

  @override
  Future<void> deleteSuccessfulRegistration() async {
    _registration = null;
  }
}
