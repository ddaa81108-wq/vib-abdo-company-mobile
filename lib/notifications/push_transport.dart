import 'dart:async';

/// Which push adapter the process uses.
///
/// `--dart-define=PUSH_TRANSPORT=fcm` keeps the Firebase adapter even when
/// setup fails. `fake` selects the in-memory adapter. `noop` stays a no-op.
/// An empty value is resolved in `resolveAppPushTransport`: try Firebase,
/// then the no-op when the config is absent.
enum PushTransportKind { noop, fake, fcm }

/// Empty unless the process was started with `PUSH_TRANSPORT`.
const String kPushTransportName = String.fromEnvironment('PUSH_TRANSPORT');

PushTransportKind parsePushTransport(String raw) => switch (raw.trim()) {
  'fcm' => PushTransportKind.fcm,
  'fake' => PushTransportKind.fake,
  _ => PushTransportKind.noop,
};

PushTransportKind pushTransportKindFromEnvironment() =>
    parsePushTransport(kPushTransportName);

/// Adapter the rest of the app talks to. Firebase starts only after
/// `prepare` succeeds.
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

/// Used when Firebase is off or its config is missing. SSE is unchanged.
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

/// FCM adapter. Firebase is contacted only by [prepare].
///
/// Without `google-services.json`, [prepare] fails closed and [currentToken]
/// stays null, so the registrar does not call the server. The Google Services
/// plugin is applied only when that file is present, so CI builds without it.
class FcmPushTransport implements PushTransport {
  FcmPushTransport({FcmRuntime? runtime}) : _runtime = runtime ?? fcmRuntime;

  final FcmRuntime _runtime;
  final _payloads = StreamController<Map<String, dynamic>>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  var _probed = false;
  var _ready = false;
  String? _token;

  /// True after a successful [prepare]. False when Firebase is not configured.
  bool get configured => _ready;

  @override
  String get name => 'fcm';

  @override
  bool get registersDevices => true;

  /// Connects Firebase. Returns false when the native config is absent.
  /// Never throws. Does not log a token.
  Future<bool> prepare() async {
    if (_probed) return _ready;
    _probed = true;
    try {
      _ready = await _runtime.start(
        onToken: (token) {
          if (token.isEmpty || _tokens.isClosed) return;
          _token = token;
          _tokens.add(token);
        },
        onMessage: (payload) {
          if (_payloads.isClosed) return;
          final hasNotification = payload.remove('notificationPayload') == true;
          if (!fcmShouldForwardToTray(
            inForeground: _runtime.inForeground(),
            hasNotificationPayload: hasNotification,
          )) {
            return;
          }
          _payloads.add(payload);
        },
      );
      if (_ready) _token = await _runtime.token();
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<String?> currentToken() async {
    await prepare();
    if (!_ready) return null;
    final token = _token ?? await _runtime.token();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  @override
  Stream<Map<String, dynamic>> get payloads => _payloads.stream;

  @override
  Stream<String> get onTokenRefresh => _tokens.stream;

  @override
  Future<void> deleteToken() async {
    _token = null;
    if (!_ready) return;
    try {
      await _runtime.deleteToken();
    } catch (_) {}
  }
}

/// Replaced in [main] with the Firebase plugin. Tests keep this no-op.
FcmRuntime fcmRuntime = const UnavailableFcmRuntime();

class UnavailableFcmRuntime implements FcmRuntime {
  const UnavailableFcmRuntime();

  @override
  Future<bool> start({
    required void Function(String token) onToken,
    required void Function(Map<String, dynamic> payload) onMessage,
  }) async => false;

  @override
  Future<String?> token() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  bool inForeground() => true;
}

/// Platform piece behind [FcmPushTransport]. Tests pass a fake.
abstract interface class FcmRuntime {
  Future<bool> start({
    required void Function(String token) onToken,
    required void Function(Map<String, dynamic> payload) onMessage,
  });

  Future<String?> token();

  Future<void> deleteToken();

  bool inForeground();
}

/// Foreground: Android does not show the FCM `notification` block, so the
/// app posts one local alert. Background with that block: the system already
/// shows it, and a second post would duplicate it. A data-only message is
/// posted by this process in every state except the foreground sound path
/// is the local alert itself.
bool fcmShouldForwardToTray({
  required bool inForeground,
  required bool hasNotificationPayload,
}) {
  if (inForeground) return true;
  return !hasNotificationPayload;
}

bool fcmShouldPostLocalAlert({
  required bool inForeground,
  required bool hasNotificationPayload,
}) {
  if (inForeground) return false;
  return !hasNotificationPayload;
}

PushTransport createPushTransport(String raw, {FakePushTransport? fake}) =>
    switch (parsePushTransport(raw)) {
      PushTransportKind.fcm => FcmPushTransport(),
      PushTransportKind.fake => fake ?? FakePushTransport(),
      PushTransportKind.noop => const NoopPushTransport(),
    };
