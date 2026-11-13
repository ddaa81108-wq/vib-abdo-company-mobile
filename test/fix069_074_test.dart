import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('debt header is compact and load-more sits in the list', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(find.text(AppStrings.customersTotalDebt), findsOneWidget);
    expect(find.text(AppStrings.activeShort), findsOneWidget);
    expect(find.text(AppStrings.todayTab), findsNothing);
    expect(find.byKey(const Key('app-bar-theme')), findsOneWidget);
    final more = find.byKey(const Key('load-more-accounts'));
    if (more.evaluate().isNotEmpty) {
      expect(
        find.descendant(of: find.byType(CustomScrollView), matching: more),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the day-edit button sits on the named day above the divider', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    final button = find.byKey(const Key('day-correction-11'));
    await tester.scrollUntilVisible(button, 80, scrollable: _purchasesScroll);
    final buttonBox = tester.getRect(button);
    final named = tester.getRect(
      find.byKey(const Key('purchase-carry-close-11')),
    );
    final below = tester.getRect(
      find.byKey(const Key('purchase-carry-open-11')),
    );
    expect((buttonBox.center.dy - named.center.dy).abs(), lessThan(20));
    expect(buttonBox.bottom, lessThanOrEqualTo(below.top + 1));
    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_old')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance stays readable in the light theme', (tester) async {
    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    expect(find.text(AppStrings.appearance), findsOneWidget);
    final sw = tester.widget<Switch>(
      find.byKey(const Key('settings-theme-switch')),
    );
    expect(sw.value, isFalse);
    expect(sw.trackColor!.resolve({}), const Color(0xFF1E3A8A));
    expect(sw.thumbColor!.resolve({}), const Color(0xFFFFFFFF));
    expect(tester.takeException(), isNull);
  });
}

final _purchasesScroll = find.descendant(
  of: find.byKey(const Key('screen-purchases')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  ),
);
