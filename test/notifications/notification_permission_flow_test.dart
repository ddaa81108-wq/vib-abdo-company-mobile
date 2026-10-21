import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_controller.dart';
import 'package:vib_abdo_company_mobile/notifications/android_notification_setup.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_channels.dart';

void main() {
  test(
    'initialize creates the collections channel and the status icon',
    () async {
      final platform = FakeNotificationPlatform();
      await AndroidNotificationController(platform: platform).initialize();

      expect(platform.initializeCount, 1);
      expect(platform.icon, NotificationChannels.smallIcon);
      expect(platform.channel, NotificationChannels.collections);
      expect(platform.channel?.showBadge, isTrue);
      expect(platform.channel?.name, NotificationChannels.collectionsName);
    },
  );

  test('a disabled system skips the post and an enabled one drops a negative badge', () async {
    final blocked = FakeNotificationPlatform()..enabled = false;
    final blockedShown = await AndroidNotificationController(platform: blocked)
        .showCollectionsAlert(
          id: NotificationChannels.probeNotificationId,
          title: 'تنبيه',
          body: 'تحصيل',
          badgeCount: 2,
        );
    expect(blockedShown, isFalse);
    expect(blocked.shown, isEmpty);

    final allowed = FakeNotificationPlatform()..enabled = true;
    final shown = await AndroidNotificationController(platform: allowed)
        .showCollectionsAlert(
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
  });

  test('start reports an init failure and does not throw', () async {
    Object? reported;
    await AndroidNotificationSetup.start(
      platform: _ThrowingPlatform(),
      onError: (error, stackTrace) {
        reported = error;
      },
    );
    expect(reported, isA<StateError>());

    final platform = FakeNotificationPlatform();
    await AndroidNotificationSetup.start(platform: platform);
    expect(platform.initializeCount, 1);
    expect(platform.channel?.id, NotificationChannels.collectionsId);
  });

  testWidgets('showing an alert follows the enabled flag', (tester) async {
    final platform = FakeNotificationPlatform()..enabled = false;
    final controller = AndroidNotificationController(platform: platform);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: _ShowHarness(controller: controller)),
    );
    await tester.tap(find.text('إظهار'));
    await tester.pumpAndSettle();

    expect(find.text('shown=false'), findsOneWidget);
    expect(platform.shown, isEmpty);

    platform.enabled = true;
    await tester.tap(find.text('إظهار'));
    await tester.pumpAndSettle();

    expect(find.text('shown=true'), findsOneWidget);
    expect(platform.shown, hasLength(1));
    expect(platform.shown.single.badgeCount, 2);
    expect(platform.shown.single.channel.showBadge, isTrue);
  });
}

class FakeNotificationPlatform implements NotificationPlatform {
  String? icon;
  NotificationChannelSpec? channel;
  var initializeCount = 0;
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

class _ShowHarness extends StatefulWidget {
  const _ShowHarness({required this.controller});

  final AndroidNotificationController controller;

  @override
  State<_ShowHarness> createState() => _ShowHarnessState();
}

class _ShowHarnessState extends State<_ShowHarness> {
  bool? shown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('shown=${shown ?? false}'),
          TextButton(
            onPressed: () async {
              final didShow = await widget.controller.showCollectionsAlert(
                id: NotificationChannels.probeNotificationId,
                title: 'تنبيه',
                body: 'تحصيل',
                badgeCount: 2,
              );
              setState(() {
                shown = didShow;
              });
            },
            child: const Text('إظهار'),
          ),
        ],
      ),
    );
  }
}
