import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets(
    'deposit lists keep one header row and put the rate under search',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(440, 956), textScale: 1.3);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');

      for (final path in ['/libyan-deposits', '/egyptian-deposits']) {
        await go(tester, path);
        expect(find.byKey(const Key('deposit-title')), findsNothing);
        final bar = find.descendant(
          of: find.byType(AppBar),
          matching: find.text(
            path == '/libyan-deposits' ? 'أمانات ليبية' : 'أمانات مصرية',
          ),
        );
        expect(bar, findsOneWidget);

        final total = tester.getRect(
          find.byKey(const Key('deposit-total-pill')),
        );
        final active = tester.getRect(
          find.byKey(const Key('deposit-active-pill')),
        );
        final add = tester.getRect(find.byKey(const Key('add-account')));
        expect((total.top - active.top).abs(), lessThan(4));
        expect((total.center.dy - add.center.dy).abs(), lessThan(12));
        expect(total.center.dx, greaterThan(active.center.dx));
        expect(active.center.dx, greaterThan(add.center.dx));
        expect((total.width - active.width).abs(), lessThan(24));
        expect(find.text(AppStrings.depositTotalCompact), findsOneWidget);
        expect(find.text(AppStrings.depositActiveCompact), findsOneWidget);
        expect(find.text(AppStrings.addDeposit), findsOneWidget);

        final search = tester.getRect(find.byKey(const Key('account-search')));
        final screen = tester.getSize(find.byType(Scaffold).first);
        expect(search.width, greaterThan(screen.width - 80));
        expect(search.top, greaterThan(total.bottom));
        expect(find.byKey(const Key('account-filter-all')), findsNothing);

        if (path == '/egyptian-deposits') {
          final rate = tester.getRect(
            find.byKey(const Key('exchange-rate-card')),
          );
          expect(rate.top, greaterThan(search.bottom - 1));
          expect(rate.width, greaterThan(screen.width - 80));
          final symbol = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('deposit-total')),
              matching: find.text('ج.م'),
            ),
          );
          final digits = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(const Key('deposit-total')),
                  matching: find.byType(Text),
                ),
              )
              .map((text) => text.data)
              .whereType<String>()
              .firstWhere((text) => text != 'ج.م');
          final number = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('deposit-total')),
              matching: find.text(digits),
            ),
          );
          expect(symbol.left, lessThan(number.left));
        } else {
          expect(find.byKey(const Key('exchange-rate-card')), findsNothing);
          expect(find.text('ج.م'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final route in const [
    '/customers/c_55',
    '/companies/c_co_02',
    '/libyan-deposits/c_55',
    '/egyptian-deposits/c_eg_08',
  ]) {
    testWidgets('$route keeps ✓ on the left through a sideways scroll', (
      tester,
    ) async {
      await pumpFakeApp(tester, size: const Size(440, 956));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, route);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final amount = find.byKey(const Key('movement-amount'));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: amount, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('ledger-columns-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final max = scroll.position.maxScrollExtent;
      expect(max, greaterThan(0));
      for (final offset in [scroll.position.pixels, 0.0, max / 2, max]) {
        scroll.position.jumpTo(offset);
        await tester.pump();
        _expectSaveOnTheLeft(tester);
      }
      final before = tester.getRect(find.byKey(const Key('save-movement')));
      final page = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('ledger-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      if (page.position.maxScrollExtent > 40) {
        page.position.jumpTo(40);
        await tester.pump();
        final after = tester.getRect(find.byKey(const Key('save-movement')));
        expect((after.top - before.top).abs(), greaterThan(20));
        _expectSaveOnTheLeft(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

void _expectSaveOnTheLeft(WidgetTester tester) {
  final save = find.byKey(const Key('save-movement'));
  expect(save, findsOneWidget);
  final rect = tester.getRect(save);
  expect(rect.height, greaterThan(24));
  // The ✓ sits in the draft row's تعديل column, so it travels with the
  // horizontal table instead of sitting in a gutter outside it.
  expect(
    find.descendant(
      of: find.byKey(const Key('movement-inline')),
      matching: save,
    ),
    findsOneWidget,
  );
  final columns = tester.getRect(
    find.byKey(const Key('ledger-columns-scroll')),
  );
  Rect shown(Rect raw) => raw.intersect(columns);
  final amount = shown(
    tester.getRect(find.byKey(const Key('movement-amount'))),
  );
  if (!amount.isEmpty) expect(rect.overlaps(amount), isFalse);
  for (final key in const [Key('add-debt'), Key('add-payment')]) {
    final chip = find.byKey(key);
    if (chip.evaluate().isEmpty) continue;
    final chipRect = shown(tester.getRect(chip));
    if (!chipRect.isEmpty) expect(rect.overlaps(chipRect), isFalse);
  }
  if (rect.overlaps(columns)) {
    final box = tester.renderObject<RenderBox>(save);
    final result = tester.hitTestOnBinding(rect.center);
    expect(
      result.path.whereType<BoxHitTestEntry>().any(
        (entry) => entry.target == box,
      ),
      isTrue,
      reason:
          'save $rect path ${result.path.map((entry) => entry.target.runtimeType).take(8).join(', ')}',
    );
  }
}
