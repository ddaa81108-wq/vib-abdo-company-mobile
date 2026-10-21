/// Android notification permission. The UI dev owns the real implementation
/// and the `POST_NOTIFICATIONS` manifest entry.
///
/// The transport registers a device only when [granted] is true.
abstract interface class NotificationPermissionService {
  Future<bool> get granted;
}

/// Stub until the UI dev supplies a service that reads the system setting.
///
/// The default is not granted, so a release build does not register a device.
class StubNotificationPermissionService
    implements NotificationPermissionService {
  const StubNotificationPermissionService({this.grantedValue = false});

  final bool grantedValue;

  @override
  Future<bool> get granted async => grantedValue;
}
