import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../notifications/device_token_registrar.dart';
import '../../notifications/notification_permission_service.dart' as transport;
import '../../notifications/push_providers.dart';
import '../../state/session_providers.dart';
import 'notification_permission.dart';

/// His registrar reads [notificationPermissionProvider]. This adapter leaves
/// that provider's default stub in place and reports the screen's choice.
class UiNotificationPermissionAdapter
    implements transport.NotificationPermissionService {
  UiNotificationPermissionAdapter(this._ui);

  final NotificationPermissionService _ui;

  @override
  Future<bool> get granted async {
    final status = await _ui.status();
    return status == NotificationPermissionChoice.granted;
  }
}

/// Root-scope override. The registrar is created in that same container, so a
/// nested scope never reaches it.
Override notificationPermissionRegistrarOverride() {
  return notificationPermissionProvider.overrideWith(
    (ref) => UiNotificationPermissionAdapter(
      ref.watch(notificationPermissionServiceProvider),
    ),
  );
}

/// Last choice this scope already applied. A second grant does not register
/// again. Login and logout stay on his registrar.
class NotificationPermissionSync
    extends Notifier<NotificationPermissionChoice?> {
  Future<void> _queue = Future<void>.value();

  @override
  NotificationPermissionChoice? build() => null;

  Future<void> sync({
    required bool signedIn,
    required NotificationPermissionService permission,
    required DeviceTokenRegistrar registrar,
  }) {
    final next = _queue.then(
      (_) => _apply(
        signedIn: signedIn,
        permission: permission,
        registrar: registrar,
      ),
    );
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _apply({
    required bool signedIn,
    required NotificationPermissionService permission,
    required DeviceTokenRegistrar registrar,
  }) async {
    final NotificationPermissionChoice status;
    try {
      status = await permission.status();
    } catch (_) {
      return;
    }
    if (status == state) return;
    state = status;
    if (status == NotificationPermissionChoice.granted) {
      await registrar.registerIfReady(signedIn: signedIn);
      return;
    }
    await registrar.forget();
  }
}

final notificationPermissionSyncProvider =
    NotifierProvider<NotificationPermissionSync, NotificationPermissionChoice?>(
      NotificationPermissionSync.new,
    );

/// Watches app resume so a revocation in system settings unregisters.
class NotificationPermissionRegistration extends ConsumerStatefulWidget {
  const NotificationPermissionRegistration({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationPermissionRegistration> createState() =>
      _NotificationPermissionRegistrationState();
}

class _NotificationPermissionRegistrationState
    extends ConsumerState<NotificationPermissionRegistration>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final session = ref.read(sessionStateProvider);
    unawaited(
      ref
          .read(notificationPermissionSyncProvider.notifier)
          .sync(
            signedIn: session is SessionAuthenticated,
            permission: ref.read(notificationPermissionServiceProvider),
            registrar: ref.read(deviceTokenRegistrarProvider),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
