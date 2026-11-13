import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('076-081 previews at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    await go(tester, '/purchases');
    final purchases = find
        .descendant(
          of: find.byKey(const Key('screen-purchases')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-pe_1')),
      200,
      scrollable: purchases,
    );
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix076-purchases-active-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix076-purchases-active-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();

    await go(tester, '/notifications');
    await saveShot(tester, 'fix077-notifications-light-360');

    await go(tester, '/treasury');
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix078-treasury-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix078-treasury-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();

    for (final path in const [
      'customers',
      'companies',
      'libyan-deposits',
      'egyptian-deposits',
    ]) {
      await go(tester, '/$path');
      await saveShot(tester, 'fix079-080-$path-light-360');
      await tester.tap(find.byKey(const Key('app-bar-theme')));
      await tester.pumpAndSettle();
      await saveShot(tester, 'fix079-$path-dark-360');
      await tester.tap(find.byKey(const Key('app-bar-theme')));
      await tester.pumpAndSettle();
    }
  }, tags: ['screenshots']);

  testWidgets('080 pale fills and frames', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 980);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: _CardChoices()),
      ),
    );
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix080-choices-light-360');
  }, tags: ['screenshots']);
}

class _CardChoices extends StatelessWidget {
  const _CardChoices();

  @override
  Widget build(BuildContext context) {
    const fills = <(String, Color)>[
      ('أبيض', Color(0xFFFFFFFF)),
      ('وردي باهت', Color(0xFFFFF1F2)),
      ('نعناعي باهت', Color(0xFFEFFAF3)),
      ('كريمي', Color(0xFFFFF8EE)),
      ('سماوي باهت', Color(0xFFF3F6FB)),
    ];
    const frames = <(String, BoxBorder)>[
      (
        'حد رفيع',
        Border.fromBorderSide(BorderSide(color: Color(0xFFB42318), width: 1)),
      ),
      (
        'إطار ذهبي',
        Border.fromBorderSide(BorderSide(color: Color(0xFFC4A46A), width: 1.6)),
      ),
      (
        'شريط جانبي',
        Border(right: BorderSide(color: Color(0xFF0E7A45), width: 6)),
      ),
      (
        'إطار مزدوج',
        Border.fromBorderSide(BorderSide(color: Color(0xFF6B4423), width: 2.4)),
      ),
    ];
    final card = AccountCardDto(
      id: 'preview',
      name: 'عميل تجريبي',
      balanceUnits: MoneyValue.known(320),
      currency: Currency.lyd,
      lastActivityAt: DateTime.utc(2026, 10, 18, 10, 3),
      debtAgeDays: 4,
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('خلفيات باهتة'),
        for (final fill in fills)
          _sample(
            context,
            fill.$1,
            fill.$2,
            Border.all(color: const Color(0xFFD6D3D1)),
            card,
          ),
        const SizedBox(height: 8),
        const Text('إطارات'),
        for (final frame in frames)
          _sample(context, frame.$1, Colors.white, frame.$2, card),
      ],
    );
  }

  Widget _sample(
    BuildContext context,
    String label,
    Color fill,
    BoxBorder border,
    AccountCardDto card,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: cairo(12, 800)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
              border: border,
            ),
            child: WebsiteAccountCardBody(
              card: card,
              status: 'مرّ عليه 3 أيام',
              amount: '320 د.ل',
              movement: '${AppStrings.lastActivity}: 2026/10/18, 12:03 م',
              ink: const Color(0xFFB42318),
              wide: true,
            ),
          ),
        ],
      ),
    );
  }
}
