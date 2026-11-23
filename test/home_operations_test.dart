import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/state/home_operations_providers.dart';

import 'shell_screenshots_test.dart' show saveShot, loadScreenshotFonts;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets(
    'operations home keeps all sections and opens focused unified search',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 1050));
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      expect(find.byKey(const Key('home-five-am')), findsOneWidget);
      expect(find.textContaining('162,665'), findsOneWidget);
      expect(find.textContaining('+4,000'), findsOneWidget);
      for (final section in SectionKey.values) {
        expect(find.byKey(HomeShell.sectionKey(section)), findsOneWidget);
      }
      expect(find.byKey(HomeDashboard.settingsTileKey), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-unified-search')));
      await settle(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('unified-search')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('employee sees own work without global financial reports', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 1050));
    await signIn(tester, username: 'employee.demo', password: 'test-only');
    expect(find.byKey(const Key('home-five-am')), findsNothing);
    expect(find.byKey(HomeShell.sectionKey(SectionKey.reports)), findsNothing);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.collections)),
      findsOneWidget,
    );
    expect(find.textContaining('162,665'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('home-recent-activity')));
    expect(find.text('آخر الإشعارات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing snapshot stays unavailable instead of displaying zero', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      overrides: [
        homeClosingProvider.overrideWith(
          (ref) async => const ReportClosingOverviewDto(state: 'missed'),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'test-only');
    expect(find.text('لم تُسجّل لقطة لهذا اليوم'), findsOneWidget);
    expect(find.textContaining('162,665'), findsNothing);
    expect(find.byKey(const Key('home-closing-change')), findsNothing);
  });

  testWidgets('operations home fits phones and large text in both themes', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 1050));
    await tester.runAsync(loadScreenshotFonts);
    await signIn(tester, username: 'admin.demo', password: 'test-only');
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(HomeShell.shellKey)),
    );
    for (final dark in [false, true]) {
      container.read(themeModeProvider.notifier).setDark(dark);
      await settle(tester);
      await saveShot(tester, 'home-operations-01-${dark ? 'dark' : 'light'}');
      for (final width in [320.0, 360.0, 390.0, 600.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, 1050);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await settle(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: '$width / $scale / dark=$dark',
          );
        }
      }
      tester.view.physicalSize = const Size(390, 1050);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await settle(tester);
    }
  });
}
