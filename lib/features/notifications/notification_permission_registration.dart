import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Grant calls [DeviceTokenRegistrar.registerIfReady]. Denial and revocation
/// call [DeviceTokenRegistrar.forget]. Login and logout stay on his registrar.
Future<void> registerForNotificationPermission({
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
  if (status == NotificationPermissionChoice.granted) {
    await registrar.registerIfReady(signedIn: signedIn);
    return;
  }
  await registrar.forget();
}

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
      registerForNotificationPermission(
        signedIn: session is SessionAuthenticated,
        permission: ref.read(notificationPermissionServiceProvider),
        registrar: ref.read(deviceTokenRegistrarProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
