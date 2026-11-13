import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('069-074 previews at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    await go(tester, '/customers');
    await saveShot(tester, 'fix069-070-customers-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix069-070-customers-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();

    await go(tester, '/companies');
    await saveShot(tester, 'fix069-070-companies-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix069-070-companies-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();

    await _cardCompare(tester, dark: false);
    await saveShot(tester, 'fix070-cards-compare-light-360');
    await _cardCompare(tester, dark: true);
    await saveShot(tester, 'fix070-cards-compare-dark-360');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await saveShot(tester, 'fix072-collections-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix072-collections-dark-360');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-pe_1')),
      40,
      scrollable: _purchasesScroll,
    );
    await saveShot(tester, 'fix073-active-pencils-light-360');
    await tester.scrollUntilVisible(
      find.byKey(const Key('day-correction-11')),
      40,
      scrollable: _purchasesScroll,
    );
    await saveShot(tester, 'fix073-edit-day-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('day-correction-11')),
      40,
      scrollable: _purchasesScroll,
    );
    await saveShot(tester, 'fix073-edit-day-dark-360');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-theme')),
      40,
    );
    await saveShot(tester, 'fix074-appearance-light-360');
    await tester.tap(find.byKey(const Key('settings-theme-switch')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-theme')),
      40,
    );
    await saveShot(tester, 'fix074-appearance-dark-360');
  }, tags: ['screenshots']);
}

final _purchasesScroll = find.descendant(
  of: find.byKey(const Key('screen-purchases')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  ),
);

Future<void> _cardCompare(WidgetTester tester, {required bool dark}) async {
  final card = AccountCardDto(
    id: 'preview',
    name: 'عميل تجريبي',
    balanceUnits: const MoneyValue.known(2198),
    currency: Currency.lyd,
    activeAssigneeName: 'موظف تجريبي',
    lastActivityAt: DateTime.utc(2026, 11, 2, 9, 15),
    debtAgeDays: 4,
  );
  Widget body({required bool wide}) {
    return WebsiteAccountCardBody(
      card: card,
      status: 'دين متأخر',
      amount: '2.198 د.ل',
      movement: 'آخر حركة: 2026/11/02, 11:15 ص',
      ink: Colors.white,
      showAssignee: true,
      wide: wide,
    );
  }

  Widget framed(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: websiteCardGradient(AccountSection.customers, 2198),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAC04A)),
      ),
      child: child,
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('صفّان'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: framed(body(wide: false))),
                  const SizedBox(width: 8),
                  Expanded(child: framed(body(wide: false))),
                ],
              ),
              const SizedBox(height: 12),
              const Text('صف واحد'),
              const SizedBox(height: 6),
              framed(body(wide: true)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
