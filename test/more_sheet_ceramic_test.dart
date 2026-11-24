import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';
import 'support/phase7_nav.dart';

Future<void> openMore(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('bottom-tab-more')));
  await tester.tap(find.byKey(const Key('bottom-tab-more')));
  await settle(tester);
  expect(find.byKey(const Key('more-sheet')), findsOneWidget);
}

Finder get sheetScroll => find.descendant(
  of: find.byKey(const Key('more-sheet')),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets(
    'ceramic more keeps all eight destinations and their original routes',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 920));
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      const destinations = {
        'libyan-deposits': '/libyan-deposits',
        'egyptian-deposits': '/egyptian-deposits',
        'masraweya': '/masraweya',
        'purchases': '/purchases',
        'treasury': '/treasury',
        'reports': '/reports',
        'settings': '/settings',
        'account': '/account',
      };
      for (final entry in destinations.entries) {
        await go(tester, '/');
        await openMore(tester);
        final destination = find.byKey(Key('more-${entry.key}'));
        await tester.scrollUntilVisible(
          destination,
          100,
          scrollable: sheetScroll,
        );
        await tester.tap(destination);
        await settle(tester);
        expect(find.byKey(const Key('more-sheet')), findsNothing);
        expect(
          GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
              .state
              .uri
              .path,
          entry.value,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'employee more has only permitted entries and close preserves the page',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 920));
      await signIn(tester, username: 'employee.demo', password: 'test-only');
      await openMore(tester);
      expect(find.byKey(const Key('more-settings')), findsNothing);
      expect(find.byKey(const Key('more-treasury')), findsNothing);
      expect(find.byKey(const Key('more-reports')), findsNothing);
      expect(find.byKey(const Key('more-account')), findsOneWidget);
      await tester.tap(find.byKey(const Key('more-close')));
      await settle(tester);
      expect(find.byKey(const Key('more-sheet')), findsNothing);
      expect(
        GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
            .state
            .uri
            .path,
        '/',
      );
    },
  );

  testWidgets(
    'more ceramic fits phone widths, landscape and enlarged text in both themes',
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
        await openMore(tester);
        await saveShot(
          tester,
          'more-ceramic-v2-${dark ? 'dark' : 'light'}',
          composite: true,
        );
        for (final size in const [
          Size(320, 568),
          Size(360, 800),
          Size(390, 920),
          Size(430, 932),
          Size(844, 390),
        ]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await settle(tester);
            await tester.scrollUntilVisible(
              find.byKey(const Key('more-account')),
              160,
              scrollable: sheetScroll,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$size / $scale / dark=$dark',
            );
            tester.state<ScrollableState>(sheetScroll).position.jumpTo(0);
            await settle(tester);
          }
        }
        tester.view.physicalSize = const Size(390, 920);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await settle(tester);
        await tester.tap(find.byKey(const Key('more-close')));
        await settle(tester);
      }
    },
  );
}
