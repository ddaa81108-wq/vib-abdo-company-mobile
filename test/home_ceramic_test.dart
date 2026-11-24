import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'shell_screenshots_test.dart' show saveShot, loadScreenshotFonts;
import 'support/pump_app.dart';
import 'support/phase7_nav.dart';

void main() {
  testWidgets(
    'ceramic home preserves original section order and working search',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 920));
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      final tiles = tester.widgetList<HomeTile>(find.byType(HomeTile)).toList();
      expect(tiles.map((tile) => tile.tileKey), [
        for (final section in SectionKey.values) HomeShell.sectionKey(section),
        HomeDashboard.settingsTileKey,
      ]);
      expect(find.byKey(const Key('home-five-am')), findsNothing);
      await tester.tap(find.byKey(const Key('unified-search-open')));
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

  testWidgets(
    'ceramic home fits phones, rotation and large text in both themes',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 920));
      await tester.runAsync(loadScreenshotFonts);
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(HomeShell.shellKey)),
      );
      for (final dark in [false, true]) {
        container.read(themeModeProvider.notifier).setDark(dark);
        await settle(tester);
        await saveShot(
          tester,
          'home-ceramic-approved-${dark ? 'dark' : 'light'}',
        );
        for (final size in const [
          Size(320, 568),
          Size(360, 800),
          Size(390, 920),
          Size(430, 932),
          Size(800, 600),
          Size(844, 390),
        ]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await settle(tester);
            expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: '$size / $scale / dark=$dark',
            );
          }
        }
        tester.view.physicalSize = const Size(390, 920);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await settle(tester);
      }
    },
  );

  testWidgets(
    'employee ceramic home keeps own sections and no admin settings',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 920));
      await signIn(tester, username: 'employee.demo', password: 'test-only');
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.collections)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.reports)),
        findsNothing,
      );
      expect(find.byKey(HomeDashboard.settingsTileKey), findsNothing);
      await tester.tap(
        find.byKey(HomeShell.sectionKey(SectionKey.collections)),
      );
      await settle(tester);
      expect(find.byKey(const Key('screen-collections')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
