import 'device_registration_client.dart';
import 'device_token_store.dart';
import 'notification_dedup.dart';
import 'notification_permission_service.dart';
import 'push_transport.dart';

/// Registers the device token after login and clears it on wipe.
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
  });

  final PushTransport transport;
  final NotificationPermissionService permission;
  final DeviceTokenStore store;
  final DeviceRegistrationClient client;
  final NotificationIdDedup dedup;
  final Future<void> Function()? onCancelBackground;

  /// True only when a session is open, the transport can register, permission
  /// is granted, and the transport returned a token.
  Future<void> registerIfReady({required bool signedIn}) async {
    try {
      if (!signedIn) return;
      if (!transport.registersDevices) return;
      if (!await permission.granted) return;
      final token = await transport.currentToken();
      if (token == null || token.isEmpty) return;
      await store.write(token);
      try {
        await client.register(token: token);
      } catch (_) {
        // 🔶 The route is unconfirmed. A failure must not undo login.
      }
    } catch (_) {}
  }

  /// Logout, account switch, and session-expiry wipe.
  ///
  /// Local token and dedup are cleared even when unregister throws, so the
  /// previous account cannot keep receiving on this install.
  Future<void> forget() async {
    String? token;
    try {
      token = await store.read();
    } catch (_) {}
    try {
      await store.delete();
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
