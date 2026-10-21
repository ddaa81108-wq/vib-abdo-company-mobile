import 'package:dio/dio.dart';

import '../../data/fake/fake_api_client.dart';
import '../auth/auth_strategy.dart';
import '../config/api_config.dart';
import 'fake_stack_parts.dart';

/// Debug, profile, and test builds. Release compiles the other builder.
FakeStackParts buildFakeStack({
  required ApiConfig config,
  Duration? fakeLatency,
}) {
  return FakeStackParts(
    client: FakeApiClient(
      rateWireFormat: config.rateWireFormat,
      latency: fakeLatency ?? const Duration(milliseconds: 250),
    ),
    strategy: _FakeStrategy(),
  );
}

/// No-op strategy for FakeApiClient (the fake keeps its own logged-in flag).
class _FakeStrategy implements AuthStrategy {
  bool _session = false;

  @override
  String get name => 'fake';

  @override
  Future<void> attach(
    RequestOptions options, {
    required bool authenticated,
  }) async {}

  @override
  Future<void> capture(Response<dynamic> response) async {}

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async =>
      _session = true;

  @override
  Future<void> onSessionResumed() async {}

  @override
  Future<bool> hasPersistedSession() async => _session;

  @override
  Future<AuthErrorAction> handleAuthError(
    error,
    RequestOptions request, {
    required bool authenticated,
  }) async => AuthErrorAction.passThrough;

  @override
  Future<void> clear() async => _session = false;
}
