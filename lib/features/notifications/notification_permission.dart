import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 13+ notification permission, hidden behind this type so tests
/// never touch the platform channel.
///
/// `permission_handler` 12.0.3 resolves `permission_handler_android` 13.0.1,
/// which declares minSdk 19 and compileSdk 35. This app is minSdk 24,
/// compileSdk 36, and targetSdk 36, so the plugin stays inside those bounds.
/// `permission_handler` 13.0.0 and later pull android 14.x, which compiles
/// against SDK 37. That is newer than this project's compileSdk, so it is not
/// used.
enum NotificationPermissionChoice { granted, denied, permanentlyDenied }

abstract class NotificationPermissionService {
  Future<NotificationPermissionChoice> status();

  Future<NotificationPermissionChoice> request();

  Future<bool> openSettings();
}

class DeviceNotificationPermission implements NotificationPermissionService {
  const DeviceNotificationPermission();

  @override
  Future<NotificationPermissionChoice> status() async {
    return _map(await Permission.notification.status);
  }

  @override
  Future<NotificationPermissionChoice> request() async {
    return _map(await Permission.notification.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  NotificationPermissionChoice _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return NotificationPermissionChoice.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return NotificationPermissionChoice.permanentlyDenied;
    }
    return NotificationPermissionChoice.denied;
  }
}

/// Scripted answers for widget tests.
class FakeNotificationPermissionService
    implements NotificationPermissionService {
  FakeNotificationPermissionService({
    this.initial = NotificationPermissionChoice.denied,
    this.afterRequest = NotificationPermissionChoice.granted,
  });

  NotificationPermissionChoice initial;
  NotificationPermissionChoice afterRequest;
  var requested = false;
  var openedSettings = false;

  @override
  Future<NotificationPermissionChoice> status() async {
    return requested ? afterRequest : initial;
  }

  @override
  Future<NotificationPermissionChoice> request() async {
    requested = true;
    return afterRequest;
  }

  @override
  Future<bool> openSettings() async {
    openedSettings = true;
    return true;
  }
}

/// Always granted. Widget tests that are not about permission use this so the
/// explanation dialog does not cover the screen.
class GrantedNotificationPermission implements NotificationPermissionService {
  const GrantedNotificationPermission();

  @override
  Future<NotificationPermissionChoice> status() async =>
      NotificationPermissionChoice.granted;

  @override
  Future<NotificationPermissionChoice> request() async =>
      NotificationPermissionChoice.granted;

  @override
  Future<bool> openSettings() async => false;
}

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>(
      (ref) => const DeviceNotificationPermission(),
    );

/// One explanation per provider scope, which is one signed-in app session.
class NotificationPermissionPrompted extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;
}

final notificationPermissionPromptedProvider =
    NotifierProvider<NotificationPermissionPrompted, bool>(
      NotificationPermissionPrompted.new,
    );
