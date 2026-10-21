import '../features/notifications/notification_permission.dart' as ui;
import 'notification_permission_service.dart';

/// Transport permission flag backed by the screen's permission service.
///
/// Granting in the dialog makes [granted] true, so device registration can
/// proceed. Denial and a later revocation make it false.
class UiBackedNotificationPermission implements NotificationPermissionService {
  UiBackedNotificationPermission(this._ui);

  final ui.NotificationPermissionService _ui;

  @override
  Future<bool> get granted async {
    final status = await _ui.status();
    return status == ui.NotificationPermissionChoice.granted;
  }
}
