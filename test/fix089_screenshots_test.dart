import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('089 zero أسمر next to a live card, light and dark', (
    tester,
  ) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(
      tester,
      size: const Size(360, 900),
      overrides: [
        accountsProvider.overrideWith((ref, section) async {
          AccountCardDto card(String id, String name, int units) {
            return AccountCardDto(
              id: id,
              name: name,
              balanceUnits: MoneyValue.known(units),
              currency: section.currency,
              lastActivityAt: DateTime.utc(2026, 10, 18, 12, 3),
              version: 1,
            );
          }

          final live = switch (section) {
            AccountSection.customers => card('live', 'عميل تجريبي', 320),
            AccountSection.companies => card('live', 'شركة تجريبية', 200),
            AccountSection.libyanDeposits => card('live', 'أمانة ليبية', 320),
            AccountSection.egyptianDeposits => card(
              'live',
              'أمانة مصرية',
              15000,
            ),
          };
          return AccountsPage(
            page: Paged(items: [live, card('zero', 'بطاقة صفر', 0)]),
            summary: const AccountsSummaryDto(activeCards: 1),
          );
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    for (final path in const [
      'customers',
      'companies',
      'libyan-deposits',
      'egyptian-deposits',
    ]) {
      await go(tester, '/$path');
      await saveShot(tester, 'fix089-$path-light-360');
      await tester.tap(find.byKey(const Key('app-bar-theme')));
      await tester.pumpAndSettle();
      await saveShot(tester, 'fix089-$path-dark-360');
      await tester.tap(find.byKey(const Key('app-bar-theme')));
      await tester.pumpAndSettle();
    }
  }, tags: ['screenshots']);

  testWidgets('089 أسمر swatches', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 520);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const old = Color(0xFF6B4423);
    const a = Color(0xFF5C4634);
    const b = websiteCardZeroLight;
    const c = Color(0xFF3C2E24);
    Widget chip(String label, Color color, {String? note}) {
      return Expanded(
        child: Column(
          children: [
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: websiteCardLightFill,
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('حساب صفر', style: cairo(13, 800, color: color)),
            ),
            const SizedBox(height: 4),
            Text(label, style: cairo(12, 800, color: const Color(0xFF1A1308))),
            if (note != null)
              Text(note, style: cairo(10, 700, color: const Color(0xFF6B5428))),
          ],
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF4EFE6),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أسمر — صفر',
                  textAlign: TextAlign.center,
                  style: cairo(16, 800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    chip('الحالي', old),
                    const SizedBox(width: 6),
                    chip('A', a),
                    const SizedBox(width: 6),
                    chip('B', b, note: 'المطبّق'),
                    const SizedBox(width: 6),
                    chip('C', c),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF343434), Color(0xFF080808)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    'B في الليل  حساب صفر',
                    textAlign: TextAlign.center,
                    style: cairo(14, 800, color: websiteCardZeroDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix089-swatches');
  }, tags: ['screenshots']);
}
