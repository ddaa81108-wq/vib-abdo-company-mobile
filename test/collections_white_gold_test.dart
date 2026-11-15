import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';

import 'support/pump_app.dart';
import 'shell_screenshots_test.dart' show go, loadScreenshotFonts, saveShot;

void main() {
  const enabled = bool.fromEnvironment(
    'COLLECTIONS_WHITE_GOLD',
    defaultValue: true,
  );
  for (final user in ['admin.demo', 'employee.demo']) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final dark in [false, true]) {
        testWidgets('white gold $user $width dark=$dark', (tester) async {
          await pumpFakeApp(
            tester,
            size: Size(width, 1200),
            textScale: width == 320
                ? 1.3
                : width == 430
                ? 1.6
                : 1,
          );
          await tester.runAsync(loadScreenshotFonts);
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await tester.pumpAndSettle();
          }
          await signIn(tester, username: user, password: 'demo-only');
          await go(tester, '/collections');
          expect(
            find.byKey(const Key('collections-white-gold-header')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('collections-gold-list-frame')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('assignment-as_1')), findsOneWidget);
          expect(find.byKey(const Key('assigned-amount-as_1')), findsOneWidget);
          if (user == 'admin.demo') {
            expect(
              find.byKey(const Key('collections-filter-batch')),
              findsOneWidget,
            );
            expect(find.byKey(const Key('close-batch')), findsOneWidget);
            expect(find.byKey(const Key('submit-as_1')), findsNothing);
          } else {
            expect(
              find.byKey(const Key('collections-filter-batch')),
              findsNothing,
            );
            expect(find.byKey(const Key('close-batch')), findsNothing);
            expect(find.byKey(const Key('approve-sb_1')), findsNothing);
          }
          expect(tester.takeException(), isNull);
          if (width == 390) {
            await saveShot(
              tester,
              'collections-white-gold-${user.split('.').first}-${dark ? 'dark' : 'light'}',
            );
          }
          String metrics() => tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(const Key('collections-metrics')),
                  matching: find.byType(Text),
                ),
              )
              .map((t) => t.data ?? '')
              .join('|');
          final before = metrics();
          await tester.enterText(
            find.byKey(const Key('collections-search')),
            'اسم غير موجود للاختبار',
          );
          await tester.pumpAndSettle();
          expect(find.text(CollectionsText.noMatch), findsOneWidget);
          expect(metrics(), before);
          await tester.enterText(
            find.byKey(const Key('collections-search')),
            '',
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('assignment-as_1')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, skip: !enabled);
      }
    }
  }
}
