import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/search/search_screen.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';
import 'support/account_search_fixture.dart';

void main() {
  testWidgets(
    'unified search remains readable at phone widths, both themes and keyboard height',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        for (final width in [320.0, 390.0, 430.0]) {
          for (final dark in [false, true]) {
            final layer = await pumpFakeApp(
              tester,
              size: Size(width, 900),
              textScale: scale,
            );
            if (const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) {
              await tester.runAsync(loadScreenshotFonts);
            }
            await signIn(tester, username: 'admin.demo', password: 'demo-only');
            if (dark) {
              await tester.tap(find.byKey(const Key('app-bar-theme')));
              await tester.pumpAndSettle();
            }
            scriptAccountSearch(layer.client as FakeApiClient, [
              {
                'id': 'c_55',
                'name': 'عميل تجريبي باسم طويل للاختبار',
                'section': 'customers',
                'balanceUnits': 987654321,
                'currency': 'LYD',
                'activeAssignmentId': 'assignment-test',
                'activeAssigneeName': 'موظف التحصيل',
              },
              {
                'id': 'egp',
                'name': 'أمانة مصرية',
                'section': 'egyptian-deposits',
                'balanceUnits': -654321,
                'currency': 'EGP',
              },
            ]);
            await go(tester, '/search');
            await tester.enterText(
              find.byKey(const Key('unified-search')),
              'عميل',
            );
            await tester.pump(SearchScreen.debounce);
            await tester.pumpAndSettle();
            expect(find.text('987,654,321'), findsOneWidget);
            expect(find.text('654,321'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: '$width scale=$scale dark=$dark',
            );
            if (const bool.fromEnvironment('CAPTURE_SCREENSHOTS') &&
                scale == 1) {
              await saveShot(
                tester,
                'unified-search-${dark ? 'dark' : 'light'}-${width.toInt()}',
              );
            }
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('unified-search')).hitTestable(),
              findsOneWidget,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$width scale=$scale dark=$dark',
            );
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
          }
        }
      }
    },
  );
}
