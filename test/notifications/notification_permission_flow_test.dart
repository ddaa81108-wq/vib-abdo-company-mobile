import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_controller.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_setup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';

void main() {
  test('API 29 does not request a runtime permission', () async {
    final platform = FakeNotificationPlatform()..enabled = true;
    final controller = AndroidNotificationController(
      platform: platform,
      sdkInt: 29,
    );

    await controller.initialize();
    final readiness = await controller.requestPermission();

    expect(readiness, NotificationReadiness.implicitlyGranted);
    expect(platform.requestCount, 0);
    expect(platform.icon, NotificationChannels.smallIcon);
    expect(platform.channel, NotificationChannels.collections);
    expect(NotificationPermissionPolicy.runtimeRequestRequired(32), isFalse);
    expect(NotificationPermissionPolicy.runtimeRequestRequired(33), isTrue);
  });

  test('API 33 maps grant, deny, and a missing answer', () async {
    final granted = FakeNotificationPlatform()..permissionResult = true;
    expect(
      await AndroidNotificationController(
        platform: granted,
        sdkInt: 33,
      ).requestPermission(),
      NotificationReadiness.granted,
    );
    expect(granted.requestCount, 1);

    final denied = FakeNotificationPlatform()..permissionResult = false;
    expect(
      await AndroidNotificationController(
        platform: denied,
        sdkInt: 34,
      ).requestPermission(),
      NotificationReadiness.denied,
    );

    final missing = FakeNotificationPlatform();
    expect(
      await AndroidNotificationController(
        platform: missing,
        sdkInt: 35,
      ).requestPermission(),
      NotificationReadiness.denied,
    );
  });

  test(
    'a disabled system skips the post and an enabled one keeps the badge',
    () async {
      final blocked = FakeNotificationPlatform()..enabled = false;
      final blockedController = AndroidNotificationController(
        platform: blocked,
        sdkInt: 33,
      );
      final blockedShown = await blockedController.showCollectionsAlert(
        id: NotificationChannels.probeNotificationId,
        title: 'تنبيه',
        body: 'تحصيل',
        badgeCount: 2,
      );
      expect(blockedShown, isFalse);
      expect(blocked.shown, isEmpty);

      final allowed = FakeNotificationPlatform()..enabled = true;
      final shown =
          await AndroidNotificationController(
            platform: allowed,
            sdkInt: 29,
          ).showCollectionsAlert(
            id: NotificationChannels.probeNotificationId,
            title: 'تنبيه',
            body: 'تحصيل',
            badgeCount: -3,
          );
      expect(shown, isTrue);
      expect(allowed.shown, hasLength(1));
      final request = allowed.shown.single;
      expect(request.id, NotificationChannels.probeNotificationId);
      expect(request.channel.id, NotificationChannels.collectionsId);
      expect(request.icon, NotificationChannels.smallIcon);
      expect(request.channel.showBadge, isTrue);
      expect(request.badgeCount, isNull);
    },
  );

  test('start reports an init failure and still requests on API 33', () async {
    Object? reported;
    await AndroidNotificationSetup.start(
      platform: _ThrowingPlatform(),
      sdkInt: 33,
      onError: (error, stackTrace) {
        reported = error;
      },
    );
    expect(reported, isA<StateError>());

    final platform = FakeNotificationPlatform()..permissionResult = true;
    await AndroidNotificationSetup.start(platform: platform, sdkInt: 33);
    expect(platform.initializeCount, 1);
    expect(platform.requestCount, 1);

    final older = FakeNotificationPlatform();
    await AndroidNotificationSetup.start(platform: older, sdkInt: 29);
    expect(older.requestCount, 0);
    expect(older.initializeCount, 1);
  });

  testWidgets('permission flow shows denied then granted', (tester) async {
    final platform = FakeNotificationPlatform()
      ..permissionResult = false
      ..enabled = false;
    final controller = AndroidNotificationController(
      platform: platform,
      sdkInt: 33,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: _FlowHarness(controller: controller)),
    );
    await tester.tap(find.text('تشغيل'));
    await tester.pumpAndSettle();

    expect(find.text('denied'), findsOneWidget);
    expect(find.text('shown=false'), findsOneWidget);
    expect(platform.shown, isEmpty);

    platform
      ..permissionResult = true
      ..enabled = true;
    await tester.tap(find.text('تشغيل'));
    await tester.pumpAndSettle();

    expect(find.text('granted'), findsOneWidget);
    expect(find.text('shown=true'), findsOneWidget);
    expect(platform.shown, hasLength(1));
    expect(platform.shown.single.badgeCount, 2);
    expect(platform.shown.single.channel.showBadge, isTrue);
  });

  testWidgets('API 29 flow is implicitly granted and posts', (tester) async {
    final platform = FakeNotificationPlatform()..enabled = true;
    final controller = AndroidNotificationController(
      platform: platform,
      sdkInt: 29,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: _FlowHarness(controller: controller)),
    );
    await tester.tap(find.text('تشغيل'));
    await tester.pumpAndSettle();

    expect(find.text('implicitlyGranted'), findsOneWidget);
    expect(find.text('shown=true'), findsOneWidget);
    expect(platform.requestCount, 0);
    expect(platform.channel?.name, NotificationChannels.collectionsName);
  });
}

class FakeNotificationPlatform implements NotificationPlatform {
  String? icon;
  NotificationChannelSpec? channel;
  var initializeCount = 0;
  var requestCount = 0;
  bool? permissionResult;
  bool? enabled;
  final shown = <AndroidNotificationRequest>[];

  @override
  Future<void> initialize({required String androidIcon}) async {
    initializeCount += 1;
    icon = androidIcon;
  }

  @override
  Future<void> createAndroidChannel(NotificationChannelSpec channel) async {
    this.channel = channel;
  }

  @override
  Future<bool?> requestAndroidPermission() async {
    requestCount += 1;
    return permissionResult;
  }

  @override
  Future<bool?> androidNotificationsEnabled() async => enabled;

  @override
  Future<void> showAndroid(AndroidNotificationRequest request) async {
    shown.add(request);
  }

  @override
  Future<void> cancel(int id) async {}
}

class _ThrowingPlatform extends FakeNotificationPlatform {
  @override
  Future<void> initialize({required String androidIcon}) {
    throw StateError('plugin down');
  }
}

class _FlowHarness extends StatefulWidget {
  const _FlowHarness({required this.controller});

  final AndroidNotificationController controller;

  @override
  State<_FlowHarness> createState() => _FlowHarnessState();
}

class _FlowHarnessState extends State<_FlowHarness> {
  NotificationReadiness? readiness;
  bool? shown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(readiness?.name ?? 'unknown'),
          Text('shown=${shown ?? false}'),
          TextButton(
            onPressed: () async {
              final next = await widget.controller.requestPermission();
              final didShow = await widget.controller.showCollectionsAlert(
                id: NotificationChannels.probeNotificationId,
                title: 'تنبيه',
                body: 'تحصيل',
                badgeCount: 2,
              );
              setState(() {
                readiness = next;
                shown = didShow;
              });
            },
            child: const Text('تشغيل'),
          ),
        ],
      ),
    );
  }
}
