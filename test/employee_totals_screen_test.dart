import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/authentication/auth_gate.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/settings/employee_totals_screen.dart';
import 'package:vib_abdo_company_mobile/state/employee_totals_provider.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
const _phone = Size(320, 568);

void main() {
  testWidgets('admin ready rows keep null server totals as a dash', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: _phone,
      overrides: [
        employeeTotalsProvider.overrideWith((ref) async => _nullTotals()),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _open(tester);

    expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsOneWidget);
    expect(find.byKey(EmployeeTotalsScreen.tableKey), findsNothing);
    expect(find.text('موظف أول'), findsOneWidget);
    expect(find.text('موظف ثان'), findsOneWidget);
    expect(_money(tester, 'money-collected-u_1').text, '10 د.ل');
    expect(_money(tester, 'money-pending-u_1').text, '5 د.ل');
    expect(_money(tester, 'money-cash-u_1').text, '4 د.ل');
    expect(_money(tester, 'money-collected-u_2').text, '20 ج.م');
    expect(_money(tester, 'money-pending-u_2').text, '—');
    expect(_money(tester, 'money-cash-u_2').text, '—');
    expect(_money(tester, 'money-collected-totals').text, '—');
    expect(_money(tester, 'money-pending-totals').text, '—');
    expect(find.text('30 د.ل'), findsNothing);
    expect(find.text('15 د.ل'), findsNothing);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(
      _money(tester, 'money-collected-u_1').style?.color,
      Theme.of(tester.element(find.byKey(const Key('money-collected-u_1'))))
          .extension<AppStatusColors>()!
          .creditText,
    );
    expect(
      _money(tester, 'money-cash-u_1').style?.color,
      Theme.of(tester.element(find.byKey(const Key('money-cash-u_1'))))
          .extension<AppStatusColors>()!
          .debtText,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(EmployeeTotalsScreen.screenKey)),
      ),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the live admin payload is the server row, not a new total', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(const Key('settings-link-employees')), findsNothing);
    await _open(tester);

    expect(find.byKey(EmployeeTotalsScreen.tableKey), findsOneWidget);
    expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsNothing);
    expect(find.text('موظف استلام تجريبي'), findsOneWidget);
    expect(_money(tester, 'money-collected-u_12').text, '0 د.ل');
    expect(_money(tester, 'money-pending-u_12').text, '100 د.ل');
    expect(_money(tester, 'money-cash-u_12').text, '250 د.ل');
    expect(_money(tester, 'money-collected-totals').text, '0 د.ل');
    expect(_money(tester, 'money-pending-totals').text, '100 د.ل');
    expect(find.text(AppStrings.serverTotals), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('employee and limited admin see the forbidden pane, not rows', (
    tester,
  ) async {
    await _pumpRole(tester, 'employee.demo');
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsOneWidget);
    expect(find.text('موظف استلام تجريبي'), findsNothing);
    expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsNothing);

    await _pumpRole(tester, 'limited.admin.demo');
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text('موظف استلام تجريبي'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an employee deep link does not open the totals screen', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: _phone);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
        .go('/settings/employee-totals');
    await settle(tester);
    expect(
      GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
          .state
          .uri
          .path,
      forbiddenLocation,
    );
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.byKey(EmployeeTotalsScreen.screenKey), findsNothing);
  });

  testWidgets('failure offers retry and loading stays on the skeleton', (
    tester,
  ) async {
    var attempt = 0;
    await pumpFakeApp(
      tester,
      size: _phone,
      overrides: [
        employeeTotalsProvider.overrideWith((ref) async {
          attempt++;
          if (attempt == 1) {
            throw const ServerException(code: 'SERVER', message: 'تعطل الخادم');
          }
          return _nullTotals();
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _open(tester);
    expect(find.text('تعطل الخادم'), findsOneWidget);
    expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(EmployeeTotalsScreen.retryKey));
    await settle(tester);
    expect(find.text('تعطل الخادم'), findsNothing);
    expect(_money(tester, 'money-collected-totals').text, '—');
    expect(attempt, 2);

    final gate = Completer<EmployeeTotalsDto>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(_nullTotals());
    });
    await pumpFakeApp(
      tester,
      size: _phone,
      overrides: [employeeTotalsProvider.overrideWith((ref) => gate.future)],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _open(tester);
    expect(find.byKey(EmployeeTotalsScreen.loadingKey), findsOneWidget);
    expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 320 phone fits the cards in both themes', (tester) async {
    for (final dark in [false, true]) {
      await pumpFakeApp(
        tester,
        size: _phone,
        overrides: [
          if (dark) themeModeProvider.overrideWith(_DarkTheme.new),
          employeeTotalsProvider.overrideWith((ref) async => _nullTotals()),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await _open(tester);
      final context = tester.element(
        find.byKey(EmployeeTotalsScreen.screenKey),
      );
      expect(
        Theme.of(context).brightness,
        dark ? Brightness.dark : Brightness.light,
      );
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'screenshots of employee totals at 320',
    (tester) async {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        await pumpFakeApp(
          tester,
          size: _phone,
          overrides: [
            if (dark) themeModeProvider.overrideWith(_DarkTheme.new),
            employeeTotalsProvider.overrideWith((ref) async => _nullTotals()),
          ],
        );
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await _open(tester);
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        expect(find.byKey(EmployeeTotalsScreen.cardsKey), findsOneWidget);
        await saveShot(tester, 'employee-totals-$theme-320');
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

EmployeeTotalsDto _nullTotals() {
  return const EmployeeTotalsDto(
    currency: Currency.lyd,
    items: [
      EmployeeTotalsItemDto(
        employeeId: 'u_1',
        employeeName: 'موظف أول',
        collectedUnits: 10,
        pendingUnits: 5,
        approvedCount: 1,
        rejectedCount: 2,
        pendingCount: 3,
        cashOutstandingUnits: 4,
      ),
      EmployeeTotalsItemDto(
        employeeId: 'u_2',
        employeeName: 'موظف ثان',
        collectedUnits: 20,
        approvedCount: null,
        rejectedCount: 0,
        pendingCount: null,
        cashOutstandingUnits: null,
        currency: Currency.egp,
      ),
    ],
  );
}

Future<void> _open(WidgetTester tester) async {
  final shell = find.byKey(HomeShell.shellKey);
  if (shell.evaluate().isEmpty) {
    fail('home shell is not on screen');
  }
  GoRouter.of(tester.element(shell)).go('/settings');
  await settle(tester);
  final tile = find.byKey(const Key('settings-link-employees'));
  expect(tile, findsOneWidget);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await settle(tester);
  expect(find.byKey(EmployeeTotalsScreen.screenKey), findsOneWidget);
}

Future<void> _pumpRole(WidgetTester tester, String username) async {
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(layer.dispose);
  await tester.runAsync(
    () => layer.session.login(username: username, password: 'demo-only'),
  );
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [apiLayerProvider.overrideWithValue(layer)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'LY'),
        supportedLocales: const [Locale('ar', 'LY')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildAppTheme(),
        themeAnimationDuration: Duration.zero,
        home: const EmployeeTotalsScreen(),
      ),
    ),
  );
  await settle(tester);
}

MoneyText _money(WidgetTester tester, String key) {
  return tester.widget<MoneyText>(find.byKey(Key(key)));
}

class _DarkTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
