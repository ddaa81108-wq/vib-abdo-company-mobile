import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';

/// `POST /api/mobile-push/devices`. Body: `token`, `platform: android`,
/// and `unregister: true` to drop this session's row. The registrar
/// swallows a missing route, so logout still finishes when the server
/// has not enabled the endpoint.
abstract interface class DeviceRegistrationClient {
  Future<void> register({required String token});
  Future<void> unregister({required String token});
}

class HttpDeviceRegistrationClient implements DeviceRegistrationClient {
  HttpDeviceRegistrationClient(this._client);

  final ApiClient _client;

  @override
  Future<void> register({required String token}) {
    return _client.post(
      ApiEndpoints.proposedMobilePushDevices,
      body: {'token': token, 'platform': 'android'},
    );
  }

  @override
  Future<void> unregister({required String token}) {
    return _client.post(
      ApiEndpoints.proposedMobilePushDevices,
      body: {'token': token, 'platform': 'android', 'unregister': true},
    );
  }
}

/// Records calls. Tests use this so a missing server route cannot fail logout.
class RecordingDeviceRegistrationClient implements DeviceRegistrationClient {
  final List<String> registered = [];
  final List<String> unregistered = [];
  Object? registerError;
  Object? unregisterError;

  @override
  Future<void> register({required String token}) async {
    final error = registerError;
    if (error != null) throw error;
    registered.add(token);
  }

  @override
  Future<void> unregister({required String token}) async {
    final error = unregisterError;
    if (error != null) throw error;
    unregistered.add(token);
  }
}
