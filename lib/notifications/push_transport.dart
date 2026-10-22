import 'dart:async';

/// Which push adapter the process uses.
///
/// `--dart-define=PUSH_TRANSPORT=fcm` selects the stub. `fake` selects the
/// in-memory adapter. Anything else, including empty, is [PushTransportKind.noop].
enum PushTransportKind { noop, fake, fcm }

/// Default is noop. The server has no device push (see the phase 6 contract).
const String kPushTransportName = String.fromEnvironment('PUSH_TRANSPORT');

PushTransportKind parsePushTransport(String raw) => switch (raw.trim()) {
  'fcm' => PushTransportKind.fcm,
  'fake' => PushTransportKind.fake,
  _ => PushTransportKind.noop,
};

PushTransportKind pushTransportKindFromEnvironment() =>
    parsePushTransport(kPushTransportName);

/// Adapter the rest of the app talks to. Firebase is not linked.
abstract interface class PushTransport {
  String get name;

  /// False only for [NoopPushTransport]. The device registrar refuses the
  /// proposed register call when this is false.
  bool get registersDevices;

  /// Null when this install has no device token. Never logged.
  Future<String?> currentToken();

  /// Raw maps from the platform. The ingress whitelists them before parse.
  Stream<Map<String, dynamic>> get payloads;

  /// New tokens from the platform (`onTokenRefresh`). Empty when this
  /// adapter has no refresh stream. Values must not be logged.
  Stream<String> get onTokenRefresh;

  /// Drops the platform token. Must not throw past the session wipe.
  Future<void> deleteToken();
}

/// Shared by adapters that never emit a token refresh. A broadcast stream so
/// more than one registrar can listen, including the const noop and the stub.
final Stream<String> _silentTokenRefresh = Stream<String>.empty()
    .asBroadcastStream();

/// Default. The server has no FCM or APNs registration.
class NoopPushTransport implements PushTransport {
  const NoopPushTransport();

  @override
  String get name => 'noop';

  @override
  bool get registersDevices => false;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<Map<String, dynamic>> get payloads => const Stream.empty();

  @override
  Stream<String> get onTokenRefresh => _silentTokenRefresh;

  @override
  Future<void> deleteToken() async {}
}

/// Test and dev adapter. No Firebase. Payloads are injected by the test.
class FakePushTransport implements PushTransport {
  FakePushTransport({this.token});

  final _payloads = StreamController<Map<String, dynamic>>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  String? token;
  var _deleted = false;

  @override
  String get name => 'fake';

  @override
  bool get registersDevices => true;

  bool get deleted => _deleted;

  void setToken(String? value) {
    final previous = _deleted ? null : token;
    token = value;
    _deleted = false;
    if (value == null || value.isEmpty || value == previous) return;
    if (_tokens.isClosed) return;
    _tokens.add(value);
  }

  void inject(Map<String, dynamic> payload) {
    if (!_payloads.isClosed) _payloads.add(payload);
  }

  @override
  Future<String?> currentToken() async => _deleted ? null : token;

  @override
  Stream<Map<String, dynamic>> get payloads => _payloads.stream;

  @override
  Stream<String> get onTokenRefresh => _tokens.stream;

  @override
  Future<void> deleteToken() async {
    _deleted = true;
    token = null;
  }

  Future<void> dispose() async {
    if (!_payloads.isClosed) await _payloads.close();
    if (!_tokens.isClosed) await _tokens.close();
  }
}

/// Compile-time seam for FCM. `firebase_messaging` is not a dependency.
///
/// The Android build of that plugin expects `google-services.json` and the
/// Google Services Gradle plugin. This repo must not contain that file or any
/// API key. Until a build can isolate the plugin without that file, this
/// adapter yields no token, no token-refresh events, and no messages.
class FcmPushTransport implements PushTransport {
  const FcmPushTransport();

  @override
  String get name => 'fcm';

  @override
  bool get registersDevices => true;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<Map<String, dynamic>> get payloads => const Stream.empty();

  @override
  Stream<String> get onTokenRefresh => _silentTokenRefresh;

  @override
  Future<void> deleteToken() async {}
}

PushTransport createPushTransport(String raw, {FakePushTransport? fake}) =>
    switch (parsePushTransport(raw)) {
      PushTransportKind.fcm => const FcmPushTransport(),
      PushTransportKind.fake => fake ?? FakePushTransport(),
      PushTransportKind.noop => const NoopPushTransport(),
    };
