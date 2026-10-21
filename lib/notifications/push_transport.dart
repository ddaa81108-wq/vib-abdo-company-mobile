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

  /// Drops the platform token. Must not throw past the session wipe.
  Future<void> deleteToken();
}

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
  Future<void> deleteToken() async {}
}

/// Test and dev adapter. No Firebase. Payloads are injected by the test.
class FakePushTransport implements PushTransport {
  FakePushTransport({this.token});

  final _payloads = StreamController<Map<String, dynamic>>.broadcast();
  String? token;
  var _deleted = false;

  @override
  String get name => 'fake';

  @override
  bool get registersDevices => true;

  bool get deleted => _deleted;

  void setToken(String? value) {
    token = value;
    _deleted = false;
  }

  void inject(Map<String, dynamic> payload) {
    if (!_payloads.isClosed) _payloads.add(payload);
  }

  @override
  Future<String?> currentToken() async => _deleted ? null : token;

  @override
  Stream<Map<String, dynamic>> get payloads => _payloads.stream;

  @override
  Future<void> deleteToken() async {
    _deleted = true;
    token = null;
  }

  Future<void> dispose() => _payloads.close();
}

/// Compile-time seam for FCM. `firebase_messaging` is not a dependency.
///
/// The Android build of that plugin expects `google-services.json` and the
/// Google Services Gradle plugin. This repo must not contain that file or any
/// API key. Until a build can isolate the plugin without that file, this
/// adapter yields no token and no messages.
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
  Future<void> deleteToken() async {}
}

PushTransport createPushTransport(String raw, {FakePushTransport? fake}) =>
    switch (parsePushTransport(raw)) {
      PushTransportKind.fcm => const FcmPushTransport(),
      PushTransportKind.fake => fake ?? FakePushTransport(),
      PushTransportKind.noop => const NoopPushTransport(),
    };
