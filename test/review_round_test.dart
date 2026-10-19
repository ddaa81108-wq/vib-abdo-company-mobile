import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/presentation.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

void main() {
  test('financial tokens stay the web CSS values at every width', () {
    const light = AppStatusColors.light;
    const dark = AppStatusColors.dark;
    expect(light.overdueDebt.colors, const [
      Color(0xFFFF164E),
      Color(0xFFD30036),
      Color(0xFF870021),
    ]);
    expect(light.newDebt.colors, const [
      Color(0xFF3548FF),
      Color(0xFF211CAF),
      Color(0xFF15126F),
    ]);
    expect(light.warningDebt.colors, const [
      Color(0xFFFF9A00),
      Color(0xFFE36D00),
      Color(0xFF9F3F00),
    ]);
    expect(light.creditBalance.colors, const [
      Color(0xFF00C77B),
      Color(0xFF00965E),
      Color(0xFF00603E),
    ]);
    expect(light.zeroBalance.colors, const [
      Color(0xFF151515),
      Color(0xFF050505),
      Color(0xFF000000),
    ]);
    expect(light.cashPositive, const Color(0xFF087A50));
    expect(light.cashNegative, const Color(0xFFB43131));
    expect(light.zeroCardBorder, const Color(0xFF737373));
    expect(dark.overdueDebt.colors, const [
      Color(0xFF813849),
      Color(0xFF552537),
    ]);
    expect(dark.cashPositive, const Color(0xFF087A50));
    expect(dark.cashNegative, const Color(0xFFB43131));
    expect(dark.chipNormalFg, light.chipNormalFg);
    expect(dark.chipCriticalBg, light.chipCriticalBg);
    for (final width in [360.0, 700.0, 1000.0]) {
      expect(useFlatAgeCard(width, Brightness.light), isFalse);
      expect(useFlatAgeCard(width, Brightness.dark), isFalse);
    }
    expect(light.overdueDebt.begin, dark.overdueDebt.begin);
    expect(Icons.arrow_back.matchTextDirection, isTrue);
    expect(Icons.arrow_forward.matchTextDirection, isTrue);
    expect(light.overdueDebt.end, const Alignment(0.5736, 0.8192));
  });

  testWidgets('offline disables writes and the status line follows connectivity', (
    tester,
  ) async {
    final link = ToggleConnectivity(true);
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        connectivityPortProvider.overrideWithValue(link),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('add-account'))).onPressed,
      isNotNull,
    );

    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text(AppStrings.offline), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('add-account'))).onPressed,
      isNull,
    );

    link.setOnline(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('add-account'))).onPressed,
      isNotNull,
    );
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
