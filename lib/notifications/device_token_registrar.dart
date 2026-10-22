import 'dart:async';

import 'device_registration_client.dart';
import 'device_token_store.dart';
import 'notification_dedup.dart';
import 'notification_permission_service.dart';
import 'push_transport.dart';

/// Registers the device token after login and clears it on wipe.
///
/// A successful registration is remembered as `(token, userId)`, in memory
/// and in [DeviceTokenStore]. The same pair does not call the device endpoint
/// again. A new token, a new user, or [forget] does. The token is never logged.
///
/// [PushTransport.onTokenRefresh] calls [registerIfReady] again while a
/// session is open, so a replacement token is sent.
///
/// Every public method swallows its own failures. The session wipe already
/// ignores a cleanup that throws; this class still finishes the local delete
/// when the proposed endpoint fails.
class DeviceTokenRegistrar {
  DeviceTokenRegistrar({
    required this.transport,
    required this.permission,
    required this.store,
    required this.client,
    required this.dedup,
    this.onCancelBackground,
    this.currentUserId,
  }) {
    _listenForTokenRefresh();
  }

  final PushTransport transport;
  final NotificationPermissionService permission;
  final DeviceTokenStore store;
  final DeviceRegistrationClient client;
  final NotificationIdDedup dedup;
  final Future<void> Function()? onCancelBackground;

  /// Signed-in user at registration time. Null when the caller has no session.
  final String? Function()? currentUserId;

  StoredDeviceRegistration? _successful;
  var _signedIn = false;
  var _closed = false;
  StreamSubscription<String>? _refresh;
  Future<void> _queue = Future<void>.value();

  void _listenForTokenRefresh() {
    try {
      _refresh = transport.onTokenRefresh.listen((_) {
        if (!_signedIn || _closed) return;
        unawaited(registerIfReady(signedIn: true));
      }, onError: (_, _) {});
    } catch (_) {}
  }

  /// Drops the token-refresh subscription. Does not clear a registration.
  void dispose() {
    _closed = true;
    final sub = _refresh;
    _refresh = null;
    if (sub == null) return;
    unawaited(sub.cancel().then((_) {}, onError: (_, _) {}));
  }

  /// True only when a session is open, the transport can register, permission
  /// is granted, and the transport returned a token. Skips the POST when that
  /// token and the current user match the last successful registration.
  Future<void> registerIfReady({required bool signedIn}) {
    final next = _queue.then((_) => _registerIfReady(signedIn));
    _queue = next.then((_) {}, onError: (_, _) {});
    return next.then((_) {}, onError: (_, _) {});
  }

  Future<void> _registerIfReady(bool signedIn) async {
    try {
      if (!signedIn) {
        _signedIn = false;
        return;
      }
      _signedIn = true;
      if (!transport.registersDevices) return;
      if (!await permission.granted) return;
      final token = await transport.currentToken();
      if (token == null || token.isEmpty) return;
      final userId = _userId();
      final previous = await _remembered();
      if (previous != null &&
          previous.token == token &&
          previous.userId == userId) {
        return;
      }
      await store.write(token);
      try {
        await client.register(token: token);
      } catch (_) {
        // A failed POST is not success. The next call retries.
        return;
      }
      final saved = StoredDeviceRegistration(token: token, userId: userId);
      _successful = saved;
      try {
        await store.writeSuccessfulRegistration(saved);
      } catch (_) {}
    } catch (_) {}
  }

  String _userId() {
    final id = currentUserId?.call();
    if (id == null || id.isEmpty) return '';
    return id;
  }

  Future<StoredDeviceRegistration?> _remembered() async {
    final memory = _successful;
    if (memory != null) return memory;
    try {
      final saved = await store.readSuccessfulRegistration();
      _successful = saved;
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Logout, account switch, and session-expiry wipe.
  ///
  /// Local token, the remembered registration, and dedup are cleared even
  /// when unregister throws, so the previous account cannot keep receiving
  /// on this install. The next [registerIfReady] sends the token again.
  Future<void> forget() {
    final next = _queue.then((_) => _forget());
    _queue = next.then((_) {}, onError: (_, _) {});
    return next.then((_) {}, onError: (_, _) {});
  }

  Future<void> _forget() async {
    _signedIn = false;
    _successful = null;
    String? token;
    try {
      token = await store.read();
    } catch (_) {}
    try {
      await store.delete();
    } catch (_) {}
    try {
      await store.deleteSuccessfulRegistration();
    } catch (_) {}
    try {
      await transport.deleteToken();
    } catch (_) {}
    dedup.clear();
    try {
      await onCancelBackground?.call();
    } catch (_) {}
    if (token == null || token.isEmpty) return;
    if (!transport.registersDevices) return;
    try {
      await client.unregister(token: token);
    } catch (_) {}
  }
}

/// Bound from [main] into [SessionManager]'s existing cleanup list.
///
/// The registrar is created later by Riverpod. [forget] is what the wipe
/// calls, and it cannot throw.
class PushSessionGate {
  Future<void> Function()? onForget;

  Future<void> forget() async {
    final run = onForget;
    if (run == null) return;
    try {
      await run();
    } catch (_) {}
  }
}

/// Account switch and the signed-in edge. Logout also runs [PushSessionGate],
/// so a second [DeviceTokenRegistrar.forget] here is safe.
Future<void> syncPushRegistration({
  required SessionPhase previous,
  required SessionPhase next,
  required DeviceTokenRegistrar registrar,
}) async {
  final switched = previous.userId != null && previous.userId != next.userId;
  if (switched || next.signedOutFrom(previous)) {
    await registrar.forget();
  }
  if (next.signedIn) {
    await registrar.registerIfReady(signedIn: true);
  }
}

/// Session facts the transport needs. Kept off [SessionState] so tests can
/// drive a switch without a widget.
class SessionPhase {
  const SessionPhase({required this.userId});

  const SessionPhase.signedOut() : userId = null;

  final String? userId;

  bool get signedIn => userId != null && userId!.isNotEmpty;

  bool signedOutFrom(SessionPhase previous) => previous.signedIn && !signedIn;
}
