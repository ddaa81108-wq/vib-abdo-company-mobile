import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/notifications/foreground_notification_banner.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_content.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_open_seam.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_permission.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notifications_screen.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

void main() {
  test('headline keeps the employee only when the server sent one', () {
    final withEmployee = _note(id: 'a', employeeName: 'موظف استلام تجريبي');
    final withoutEmployee = _note(id: 'b');
    final blankEmployee = _note(id: 'c', employeeName: '   ');
    final emptySystem = _note(
      id: 'd',
      systemName: '',
      operationType: NotificationOperationType.unknown,
      operationTypeRaw: 'عملية-خام',
      title: '',
    );

    expect(
      notificationHeadline(withEmployee),
      'الاستلامات · استلام جديد بانتظار المراجعة · موظف استلام تجريبي',
    );
    expect(
      notificationHeadline(withoutEmployee),
      'الاستلامات · استلام جديد بانتظار المراجعة',
    );
    expect(notificationHeadline(withoutEmployee).endsWith('·'), isFalse);
    expect(notificationHeadline(withoutEmployee).contains('—'), isFalse);
    expect(
      notificationHeadline(blankEmployee),
      notificationHeadline(withoutEmployee),
    );
    expect(
      notificationHeadline(emptySystem),
      '${AppStrings.notificationSystemFallback} · عملية-خام',
    );
    expect(notificationSecondaryLines(withEmployee), [
      'استلام جديد بانتظار المراجعة',
      'افتح قسم الاستلامات',
    ]);
    expect(notificationWhen(withEmployee), '2026-10-18');
  });

  testWidgets('each notifications list state has its own pane', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await pumpFakeApp(
      tester,
      size: const Size(360, 700),
      overrides: [notificationsProvider.overrideWith(() => _HoldNotes(gate))],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(find.byKey(const Key('notifications-loading')), findsOneWidget);
    expect(find.byKey(NotificationsScreen.retryKey), findsNothing);

    gate.complete();
    await settle(tester);
    expect(find.text(AppStrings.noNotifications), findsOneWidget);
    expect(find.byKey(const Key('notifications-loading')), findsNothing);

    await pumpFakeApp(
      tester,
      size: const Size(360, 700),
      overrides: [notificationsProvider.overrideWith(_ForbiddenNotes.new)],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsOneWidget);
    expect(find.text('سر الخادم يجب ألا يظهر'), findsNothing);
    expect(find.byKey(const Key('mark-all-read')), findsNothing);

    final failures = _Flag();
    await pumpFakeApp(
      tester,
      size: const Size(360, 700),
      overrides: [
        notificationsProvider.overrideWith(() => _FailThenEmpty(failures)),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(find.byKey(NotificationsScreen.retryKey), findsOneWidget);
    expect(find.text('تعذر تنفيذ الطلب. تحقق من الاتصال.'), findsOneWidget);
    failures.failing = false;
    await tester.tap(find.byKey(NotificationsScreen.retryKey));
    await settle(tester);
    expect(find.text(AppStrings.noNotifications), findsOneWidget);
    expect(find.byKey(NotificationsScreen.retryKey), findsNothing);
    expect(failures.calls, greaterThanOrEqualTo(2));
  });

  testWidgets(
    'read all calls markAllRead only when the server count is unread',
    (tester) async {
      var calls = 0;
      await pumpFakeApp(
        tester,
        overrides: [
          notificationsProvider.overrideWith(
            () => _ReadyNotes(_samplePage(), onMarkAll: () => calls++),
          ),
          unreadNotificationsCountProvider.overrideWith(() => _FixedCount(1)),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/notifications');
      await tester.tap(find.byKey(const Key('mark-all-read')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 1);

      await pumpFakeApp(
        tester,
        overrides: [
          notificationsProvider.overrideWith(
            () => _ReadyNotes(_samplePage(), onMarkAll: () => calls++),
          ),
          unreadNotificationsCountProvider.overrideWith(() => _FixedCount(0)),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/notifications');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('mark-all-read')))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
    },
  );

  testWidgets('rows and the bell use the server notification fields', (
    tester,
  ) async {
    final seam = _RecordingSeam();
    await pumpFakeApp(
      tester,
      size: const Size(320, 568),
      overrides: [
        notificationsProvider.overrideWith(() => _ReadyNotes(_samplePage())),
        unreadNotificationsCountProvider.overrideWith(() => _FixedCount(5)),
        notificationOpenSeamProvider.overrideWithValue(seam),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(UnreadBadge.badgeKey), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '5');

    await go(tester, '/notifications');
    expect(tester.takeException(), isNull);
    expect(
      Directionality.of(
        tester.element(find.byKey(NotificationsScreen.screenKey)),
      ),
      TextDirection.rtl,
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('notice-headline-with'))).data,
      'الاستلامات · استلام جديد بانتظار المراجعة · موظف استلام تجريبي',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('notice-headline-without')))
          .data,
      'الاستلامات · استلام جديد بانتظار المراجعة',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('notice-headline-fallback')))
          .data,
      '${AppStrings.notificationSystemFallback} · عنوان احتياطي',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('notice-card-with')),
        matching: find.text('افتح قسم الاستلامات'),
      ),
      findsOneWidget,
    );
    expect(find.text('2026-10-18'), findsWidgets);
    expect(find.byKey(const Key('notice-unread-dot-with')), findsOneWidget);
    expect(find.byKey(const Key('notice-unread-dot-read')), findsNothing);

    final unreadText = tester.widget<Text>(
      find.byKey(const Key('notice-headline-with')),
    );
    final readText = tester.widget<Text>(
      find.byKey(const Key('notice-headline-read')),
    );
    expect(unreadText.style?.fontWeight, FontWeight.w800);
    expect(readText.style?.fontWeight, FontWeight.w500);
    final unreadCard = tester.widget<Card>(
      find.byKey(const Key('notice-card-with')),
    );
    final readCard = tester.widget<Card>(
      find.byKey(const Key('notice-card-read')),
    );
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('notice-card-with'))),
    ).colorScheme;
    expect(unreadCard.color, scheme.primaryContainer);
    expect(readCard.color, isNull);
    expect(
      tester.getSemantics(find.byKey(const Key('notice-with'))).label,
      contains(AppStrings.unreadLabel),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('notice-read'))).label,
      contains(AppStrings.readLabel),
    );

    await tester.ensureVisible(find.byKey(const Key('notice-with')));
    await tester.tap(find.byKey(const Key('notice-with')));
    await tester.pump();
    expect(seam.calls, 1);
    expect(seam.origin, NotificationOpenOrigin.list);
    expect(seam.note?.notificationId, 'with');
    expect(find.text(AppStrings.notificationNotFound), findsNothing);
  });

  testWidgets('the bell hides 0 and loading and draws 99+ above 99', (
    tester,
  ) async {
    final pending = Completer<int>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(0);
    });
    await pumpFakeApp(
      tester,
      overrides: [
        unreadNotificationsCountProvider.overrideWith(
          () => _PendingCount(pending),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expect(find.byKey(UnreadBadge.buttonKey), findsOneWidget);

    await pumpFakeApp(
      tester,
      overrides: [
        unreadNotificationsCountProvider.overrideWith(() => _FixedCount(0)),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);

    await pumpFakeApp(
      tester,
      overrides: [
        unreadNotificationsCountProvider.overrideWith(() => _FixedCount(150)),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(tester.widget<Text>(find.byKey(UnreadBadge.badgeKey)).data, '99+');
  });

  testWidgets(
    'a foreground event shows a banner and the tap uses origin banner',
    (tester) async {
      final bus = StreamController<AppNotification>.broadcast();
      addTearDown(bus.close);
      final seam = _RecordingSeam();
      final note = _note(id: 'live', employeeName: 'موظف التنبيه');
      await pumpFakeApp(
        tester,
        size: const Size(320, 568),
        overrides: [
          foregroundNotificationsProvider.overrideWith((ref) => bus.stream),
          notificationOpenSeamProvider.overrideWithValue(seam),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      bus.add(note);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(ForegroundNotificationBanner.bannerKey),
        findsOneWidget,
      );
      expect(find.text(notificationHeadline(note)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
      await tester.pump();
      expect(seam.calls, 1);
      expect(seam.origin, NotificationOpenOrigin.banner);
      expect(seam.note?.notificationId, 'live');

      seam.result = const NotificationOpenResult(notFound: true);
      bus.add(_note(id: 'missing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(AppStrings.notificationNotFound), findsOneWidget);
      expect(seam.origin, NotificationOpenOrigin.banner);

      seam.result = const NotificationOpenResult(noTarget: true);
      bus.add(_note(id: 'untargeted'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(ForegroundNotificationBanner.bannerKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(AppStrings.notificationNoTarget), findsOneWidget);
    },
  );

  testWidgets(
    'notification permission asks, then grants, denies, or opens settings',
    (tester) async {
      final granted = FakeNotificationPermissionService(
        initial: NotificationPermissionChoice.denied,
        afterRequest: NotificationPermissionChoice.granted,
      );
      await pumpFakeApp(
        tester,
        size: const Size(320, 568),
        notificationsPermission: granted,
      );
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/notifications');
      expect(
        find.byKey(const Key('notification-permission-explain')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.notificationPermissionBody), findsOneWidget);
      expect(granted.requested, isFalse);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('notification-permission-agree')));
      await settle(tester);
      expect(granted.requested, isTrue);
      expect(
        find.byKey(const Key('notification-permission-denied')),
        findsNothing,
      );
      expect(find.byKey(NotificationsScreen.screenKey), findsOneWidget);

      final denied = FakeNotificationPermissionService(
        initial: NotificationPermissionChoice.denied,
        afterRequest: NotificationPermissionChoice.denied,
      );
      await pumpFakeApp(
        tester,
        size: const Size(320, 568),
        notificationsPermission: denied,
      );
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/notifications');
      await tester.tap(find.byKey(const Key('notification-permission-agree')));
      await settle(tester);
      expect(denied.requested, isTrue);
      expect(
        find.byKey(const Key('notification-permission-denied')),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.notificationPermissionDenied),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('notification-permission-settings')),
      );
      await settle(tester);
      expect(denied.openedSettings, isTrue);

      final blocked = FakeNotificationPermissionService(
        initial: NotificationPermissionChoice.permanentlyDenied,
      );
      await pumpFakeApp(
        tester,
        size: const Size(430, 900),
        notificationsPermission: blocked,
      );
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/notifications');
      expect(
        find.byKey(const Key('notification-permission-explain')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('notification-permission-denied')),
        findsOneWidget,
      );
      expect(blocked.requested, isFalse);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const Key('notification-permission-settings')),
      );
      await settle(tester);
      expect(blocked.openedSettings, isTrue);
    },
  );

  testWidgets(
    'the notifications list fits a small and a large phone in both themes',
    (tester) async {
      for (final dark in [false, true]) {
        for (final size in [const Size(320, 568), const Size(430, 900)]) {
          await pumpFakeApp(
            tester,
            size: size,
            overrides: [
              if (dark) themeModeProvider.overrideWith(_DarkTheme.new),
            ],
          );
          await signIn(
            tester,
            username: 'employee.demo',
            password: 'demo-only',
          );
          await go(tester, '/notifications');
          final context = tester.element(
            find.byKey(NotificationsScreen.screenKey),
          );
          expect(Directionality.of(context), TextDirection.rtl);
          expect(
            Theme.of(context).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(find.byKey(const Key('notice-77')), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('notice-headline-77')))
                .data,
            'الاستلامات · استلام جديد بانتظار المراجعة · موظف استلام تجريبي',
          );
          expect(find.byKey(const Key('notice-unread-dot-77')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'screenshots of the notifications list at 320',
    (tester) async {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        await pumpFakeApp(
          tester,
          size: const Size(320, 568),
          overrides: [if (dark) themeModeProvider.overrideWith(_DarkTheme.new)],
        );
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        await signIn(tester, username: 'employee.demo', password: 'demo-only');
        await go(tester, '/notifications');
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        expect(find.byKey(const Key('notice-77')), findsOneWidget);
        await saveShot(tester, 'notification-list-$theme-320');
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

Future<void> go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

AppNotification _note({
  required String id,
  String systemName = 'الاستلامات',
  String? employeeName,
  NotificationOperationType operationType =
      NotificationOperationType.collectionSubmit,
  String operationTypeRaw = 'collection.submit',
  String? title = 'استلام جديد بانتظار المراجعة',
  String? body = 'افتح قسم الاستلامات',
  DateTime? readAt,
}) {
  return AppNotification(
    notificationId: id,
    systemName: systemName,
    employeeName: employeeName,
    operationType: operationType,
    operationTypeRaw: operationTypeRaw,
    relatedRef: null,
    createdAt: DateTime.utc(2026, 10, 18),
    readAt: readAt,
    recipientUserId: 'u_12',
    title: title,
    body: body,
  );
}

NotificationsPage _samplePage() {
  final items = [
    _note(id: 'with', employeeName: 'موظف استلام تجريبي'),
    _note(id: 'without'),
    _note(
      id: 'fallback',
      systemName: ' ',
      employeeName: null,
      operationType: NotificationOperationType.unknown,
      operationTypeRaw: '',
      title: 'عنوان احتياطي',
      body: null,
    ),
    _note(
      id: 'read',
      employeeName: 'موظف مقروء',
      readAt: DateTime.utc(2026, 10, 19),
    ),
  ];
  return NotificationsPage(
    items: [for (final item in items) item.toDto()],
    appNotifications: items,
    unreadCount: 3,
  );
}

class _HoldNotes extends NotificationsController {
  _HoldNotes(this.gate);

  final Completer<void> gate;

  @override
  Future<NotificationsPage> build() async {
    await gate.future;
    return const NotificationsPage(items: [], unreadCount: 0);
  }
}

class _ForbiddenNotes extends NotificationsController {
  @override
  Future<NotificationsPage> build() async {
    throw const ForbiddenException(
      code: 'FORBIDDEN',
      message: 'سر الخادم يجب ألا يظهر',
    );
  }
}

class _Flag {
  var failing = true;
  var calls = 0;
}

class _FailThenEmpty extends NotificationsController {
  _FailThenEmpty(this.flag);

  final _Flag flag;

  @override
  Future<NotificationsPage> build() async {
    flag.calls++;
    if (flag.failing) throw const NetworkException();
    return const NotificationsPage(items: [], unreadCount: 0);
  }
}

class _ReadyNotes extends NotificationsController {
  _ReadyNotes(this.page, {this.onMarkAll});

  final NotificationsPage page;
  final void Function()? onMarkAll;

  @override
  Future<NotificationsPage> build() async => page;

  @override
  Future<void> markAllRead() async {
    onMarkAll?.call();
  }
}

class _FixedCount extends UnreadNotificationsCountController {
  _FixedCount(this.value);

  final int value;

  @override
  Future<int> build() async => value;
}

class _PendingCount extends UnreadNotificationsCountController {
  _PendingCount(this.gate);

  final Completer<int> gate;

  @override
  Future<int> build() => gate.future;
}

class _RecordingSeam implements NotificationOpenSeam {
  AppNotification? note;
  NotificationOpenOrigin? origin;
  NotificationOpenResult result = const NotificationOpenResult();
  var calls = 0;

  @override
  Future<NotificationOpenResult> open(
    AppNotification note, {
    required NotificationOpenOrigin origin,
  }) async {
    calls++;
    this.note = note;
    this.origin = origin;
    return result;
  }
}

class _DarkTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}
