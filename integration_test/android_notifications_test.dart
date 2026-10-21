import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_controller.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_setup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';

/// Host-driven permission check.
///
/// `tool/android_notification_emulator_test.sh` installs the APK and then
/// grants or revokes `POST_NOTIFICATIONS` with `adb shell pm` (and appops)
/// before `flutter test`. This file does not request the permission and does
/// not use a permission service. `NOTIF_CASE` is `implicit`, `denied`, or
/// `granted`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('notification permission matches NOTIF_CASE', (tester) async {
    const caseName = String.fromEnvironment('NOTIF_CASE');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('notification-probe', key: Key('notification-probe')),
        ),
      ),
    );
    expect(find.byKey(const Key('notification-probe')), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final sdk = await AndroidNotificationBridge.sdkInt();
    expect(sdk, greaterThanOrEqualTo(29));
    debugPrint('notification probe sdk=$sdk case=$caseName');

    final plugin = FlutterLocalNotificationsPlugin();
    final controller = AndroidNotificationController(
      platform: FlutterLocalNotificationsAdapter(plugin),
    );
    await controller.initialize();

    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    expect(android, isNotNull);
    final enabled = await android!.areNotificationsEnabled();
    final channel = await _collectionsChannel(android);
    expect(channel.name, NotificationChannels.collectionsName);
    expect(channel.description, NotificationChannels.collectionsDescription);
    expect(channel.showBadge, isTrue);
    expect(channel.importance, Importance.high);

    const id = NotificationChannels.probeNotificationId;
    try {
      if (sdk < 33) {
        expect(caseName, 'implicit');
        expect(enabled, isTrue);
        expect(
          await controller.showCollectionsAlert(
            id: id,
            title: 'تنبيه تجريبي',
            body: 'تحصيل',
            badgeCount: 1,
          ),
          isTrue,
        );
        expect(await _posted(plugin, id), isTrue);
      } else if (caseName == 'denied') {
        expect(enabled, isFalse);
        expect(
          await controller.showCollectionsAlert(
            id: id,
            title: 'تنبيه تجريبي',
            body: 'تحصيل',
            badgeCount: 1,
          ),
          isFalse,
        );
        expect(await _posted(plugin, id), isFalse);
      } else if (caseName == 'granted') {
        expect(enabled, isTrue);
        expect(
          await controller.showCollectionsAlert(
            id: id,
            title: 'تنبيه تجريبي',
            body: 'تحصيل',
            badgeCount: 1,
          ),
          isTrue,
        );
        expect(await _posted(plugin, id), isTrue);
      } else {
        fail(
          'NOTIF_CASE must be implicit, denied, or granted. Was "$caseName".',
        );
      }
    } finally {
      await controller.cancel(id);
    }
  });
}

Future<AndroidNotificationChannel> _collectionsChannel(
  AndroidFlutterLocalNotificationsPlugin android,
) async {
  final channels = await android.getNotificationChannels();
  for (final channel in channels ?? const <AndroidNotificationChannel>[]) {
    if (channel.id == NotificationChannels.collectionsId) return channel;
  }
  fail(
    'Channel ${NotificationChannels.collectionsId} was not created. '
    'Saw: ${channels?.map((channel) => channel.id).join(", ")}',
  );
}

Future<bool> _posted(FlutterLocalNotificationsPlugin plugin, int id) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final active = await plugin.getActiveNotifications();
    final found = active.any(
      (item) =>
          item.id == id && item.channelId == NotificationChannels.collectionsId,
    );
    if (found) return true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return false;
}
