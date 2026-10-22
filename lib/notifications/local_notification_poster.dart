import 'android_notification_controller.dart';
import 'tray_notification.dart';

/// Posts a system notification. Callers pass a [TrayNotification] built from
/// a server row, or a generic line that has already dropped personal fields.
abstract interface class LocalNotificationPoster {
  Future<void> showGeneric(String text);
  Future<void> showTray(TrayNotification notification);
}

class SilentLocalNotificationPoster implements LocalNotificationPoster {
  const SilentLocalNotificationPoster();

  @override
  Future<void> showGeneric(String text) async {}

  @override
  Future<void> showTray(TrayNotification notification) async {}
}

class RecordingLocalNotificationPoster implements LocalNotificationPoster {
  final List<String> texts = [];
  final List<TrayNotification> trays = [];

  @override
  Future<void> showGeneric(String text) async {
    texts.add(text);
  }

  @override
  Future<void> showTray(TrayNotification notification) async {
    trays.add(notification);
  }
}

/// Foreground poster. The activity channel sets the lock-screen public version.
class AndroidControllerPoster implements LocalNotificationPoster {
  AndroidControllerPoster(this.controller);

  final AndroidNotificationController controller;

  @override
  Future<void> showGeneric(String text) async {
    await showTray(
      TrayNotification(
        androidId: stableAndroidNotificationId(text),
        tag: text,
        title: 'VIB',
        body: text,
        publicTitle: 'VIB',
        publicBody: lockScreenNotificationText,
        payload: '',
      ),
    );
  }

  @override
  Future<void> showTray(TrayNotification notification) async {
    await controller.showPrivateAlert(notification);
  }
}
