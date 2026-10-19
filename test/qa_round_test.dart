import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/signup_info_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notifications_screen.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

void main() {
  test('amounts accept grouped digits and reject decimals', () {
    expect(parseUnits('1,250'), 1250);
    expect(parseUnits('١٬٢٥٠'), 1250);
    expect(parseUnits('12,345,678'), 12345678);
    expect(parseUnits('1000'), 1000);
    expect(parseUnits('١٢٣'), 123);
    expect(parseUnits('1,00'), isNull);
    expect(parseUnits('12,34'), isNull);
    expect(parseUnits('1,0000'), isNull);
    expect(parseUnits('1.5'), isNull);
    expect(parseUnits('1٫5'), isNull);
    expect(parseUnits('1,250.00'), isNull);
    expect(parseUnits('1٬25'), isNull);
    expect(parseUnits('1,250٬000'), isNull);
    expect(parseUnits(''), isNull);
  });

  for (final user in ['admin.demo', 'employee.demo', 'limited.admin']) {
    testWidgets('home sections lay out for $user', (tester) async {
      const widths = <double>[
        320,
        360,
        393,
        430,
        561,
        600,
        700,
        900,
        901,
        1280,
      ];
      await pumpFakeApp(tester, size: const Size(800, 1600));
      await signIn(tester, username: user, password: 'demo-only');
      for (final width in widths) {
        tester.view.physicalSize = Size(width, 1600);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
      }
    });
  }

  testWidgets('confirm dialogs show the normalized amount and rate', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    await go(tester, '/egyptian-deposits');
    await tester.enterText(find.byKey(const Key('rate-field')), '1,5');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-rate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('normalized-value')), findsOneWidget);
    expect(find.text('1.5'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await settle(tester);

    await go(tester, '/treasury');
    await tester.tap(find.byKey(const Key('cash-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      '١٬٢٥٠',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-cash')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1250'), findsOneWidget);
    expect(find.byKey(const Key('normalized-value')), findsOneWidget);
  });

  testWidgets('collections and home stay laid out at text scale 2', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await go(tester, '/collections');
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    await go(tester, '/');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed home request shows per-section fields', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.text('صافي ديون العملاء'), findsOneWidget);

    (layer.client as FakeApiClient).failHomeRemaining = 1;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await refresh;
    await settle(tester);

    expect(find.text('صافي ديون العملاء'), findsNothing);
    expect(
      find.textContaining('ديون العملاء · ${AppStrings.netDebt}'),
      findsOneWidget,
    );
    expect(find.textContaining(AppStrings.totalDebt), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed refresh keeps the last report', (tester) async {
    var fail = false;
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        reportsProvider.overrideWith((ref) async {
          if (fail) throw const NetworkException();
          return ref.read(apiLayerProvider).reports.daily();
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');
    expect(find.text('2026-10-18'), findsWidgets);

    fail = true;
    await tester.tap(find.byKey(const Key('reports-refresh')));
    await settle(tester);
    expect(find.text('2026-10-18'), findsWidgets);
    expect(find.text(AppStrings.retry), findsWidgets);
    expect(find.textContaining('تحقق من الاتصال'), findsOneWidget);
  });

  testWidgets('load older shows the error and a retry', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    (layer.client as FakeApiClient).failOlderRemaining = 1;
    await tester.tap(find.byKey(const Key('load-older')));
    await settle(tester);
    expect(find.byKey(const Key('load-older-error')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsWidgets);
  });

  testWidgets('a notification opens its section and a failed read stays put', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notice-77')));
    await settle(tester);
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);

    fake.failNotificationWritesRemaining = 1;
    await go(tester, '/notifications');
    await tester.tap(find.byKey(const Key('notice-77')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تعذر تحديث الإشعار.'), findsOneWidget);
    expect(find.byKey(NotificationsScreen.screenKey), findsOneWidget);
    expect(find.byKey(CollectionsScreen.screenKey), findsNothing);
  });

  testWidgets('a missing unread count draws no badge', (tester) async {
    final layer = await pumpFakeApp(tester);
    (layer.client as FakeApiClient).omitUnreadCount = true;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(UnreadBadge.badgeKey), findsNothing);
    expect(find.byKey(UnreadBadge.buttonKey), findsOneWidget);
  });

  testWidgets('signup uses the back arrow', (tester) async {
    await pumpFakeApp(tester);
    await tester.tap(find.byKey(const Key('signup-link')));
    await settle(tester);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(SignupInfoScreen.screenKey),
        matching: find.byIcon(Icons.arrow_back),
      ),
    );
    expect(icon.icon, Icons.arrow_back);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
