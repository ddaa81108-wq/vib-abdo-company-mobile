import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/notifications/foreground_notification_banner.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

void main() {
  testWidgets('063 banner before the timeout', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    final bus = StreamController<AppNotification>.broadcast();
    addTearDown(bus.close);
    Future<void> show(Size size, String name) async {
      await pumpFakeApp(
        tester,
        size: size,
        overrides: [
          foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      bus.add(_note());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await saveShot(tester, '$name-shown');
      await tester.pump(const Duration(seconds: 5));
      await saveShot(tester, '$name-after-5s');
      expect(find.byKey(ForegroundNotificationBanner.bannerKey), findsNothing);
    }

    await show(const Size(1280, 900), 'fix063-after-wide');
    await show(const Size(360, 800), 'fix063-after-360');
  }, tags: const ['screenshots']);
}

AppNotification _note() => AppNotification(
  notificationId: 'live-063',
  systemName: 'الاستلامات',
  employeeName: 'موظف تجريبي',
  operationType: NotificationOperationType.collectionSubmit,
  operationTypeRaw: 'collection.submit',
  relatedRef: null,
  createdAt: DateTime.utc(2026, 10, 18, 12),
  readAt: null,
  recipientUserId: 'u_1',
  title: 'استلام جديد',
  actorName: 'موظف تجريبي',
);
