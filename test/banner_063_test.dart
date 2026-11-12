import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/notifications/foreground_notification_banner.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_content.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_open_seam.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('the banner leaves on its own and the row stays unread', (
    tester,
  ) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');

    final first = _note('a', 'استلام أول');
    bus.add(first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    expect(fake.notificationMutationApplies, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer banner replaces the old one and restarts the hold', (
    tester,
  ) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    await pumpFakeApp(
      tester,
      size: const Size(1280, 900),
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final first = _note('a', 'استلام أول', systemName: 'الأول');
    final second = _note('b', 'استلام ثان', systemName: 'الثاني');
    bus.add(first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(notificationHeadline(first)), findsOneWidget);

    bus.add(second);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(notificationHeadline(second)), findsOneWidget);
    expect(find.text(notificationHeadline(first)), findsNothing);
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a swipe dismisses the banner and leaves it unread', (
    tester,
  ) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    bus.add(_note('swipe', 'اسحب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(
      find.byKey(ForegroundNotificationBanner.bannerKey),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '1');
    expect(fake.notificationMutationApplies, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap still opens the banner', (tester) async {
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    final seam = _RecordingSeam();
    await pumpFakeApp(
      tester,
      overrides: [
        foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
        notificationOpenSeamProvider.overrideWithValue(seam),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    bus.add(_note('tap', 'افتح'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
    await tester.pump();
    expect(seam.calls, 1);
    expect(seam.origin, NotificationOpenOrigin.banner);
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);
    await tester.pump(ForegroundNotificationBanner.hold);
    expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

AppNotification _note(
  String id,
  String title, {
  String systemName = 'الاستلامات',
}) => AppNotification(
  notificationId: id,
  systemName: systemName,
  employeeName: null,
  operationType: NotificationOperationType.collectionSubmit,
  operationTypeRaw: 'collection.submit',
  relatedRef: null,
  createdAt: DateTime.utc(2026, 10, 18, 12),
  readAt: null,
  recipientUserId: 'u_12',
  title: title,
);

class _RecordingSeam implements NotificationOpenSeam {
  var calls = 0;
  NotificationOpenOrigin? origin;
  AppNotification? note;

  @override
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  }) async {
    calls++;
    this.origin = origin;
    this.note = note;
    return const NotificationOpenResult();
  }
}
