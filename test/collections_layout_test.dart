import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

/// Headless layout checks for the collections redesign. Fake sessions only.
void main() {
  testWidgets(
    'admin collections rows stack at equal height at 440 and text scale 1.3',
    (tester) async {
      await _open(tester, 'admin.demo', textScale: 1.3);

      expect(find.text(CollectionsText.title), findsNothing);
      expect(find.byKey(const Key('collections-filter-card')), findsOneWidget);
      expect(find.text(CollectionsText.filterBatch), findsOneWidget);
      expect(find.text(CollectionsText.filterEmployee), findsOneWidget);
      expect(find.text(CollectionsText.payrollButton), findsOneWidget);
      expect(find.text(CollectionsText.closeShort), findsOneWidget);
      expect(find.text(CollectionsText.exportShort), findsOneWidget);
      expect(find.text(CollectionsText.closeBatch), findsNothing);
      expect(find.text(CollectionsText.tabAll), findsWidgets);
      expect(find.text(CollectionsText.tabReview), findsWidgets);
      expect(find.text(CollectionsText.tabCash), findsWidgets);
      expect(find.text(CollectionsText.tabPrevious), findsWidgets);
      expect(find.text('بانتظار الاعتماد'), findsWidgets);
      expect(find.byKey(const Key('employee-totals')), findsNothing);

      _expectStacked(tester, const [
        Key('metric-approved'),
        Key('metric-cash-received'),
        Key('metric-remaining'),
        Key('metric-pending'),
      ]);
      _expectStacked(tester, const [
        Key('collections-tab-all'),
        Key('collections-tab-review'),
        Key('collections-tab-cash'),
        Key('collections-tab-previous'),
      ]);
      _expectStacked(tester, const [
        Key('collections-payroll'),
        Key('close-batch'),
        Key('collections-export-pdf'),
      ]);
      expect(find.text(CollectionsText.closeScopeNote), findsNothing);
      expect(find.text(CollectionsText.summaryNote), findsNothing);
      final batch = tester.getRect(
        find.byKey(const Key('collections-filter-batch')),
      );
      final employee = tester.getRect(
        find.byKey(const Key('collections-filter-employee')),
      );
      expect(employee.top, greaterThan(batch.bottom - 1));

      final approved = _plain(tester, const Key('metric-approved'));
      await tester.enterText(
        find.byKey(const Key('collections-search')),
        'لا يطابق شيئا',
      );
      await tester.pump();
      expect(find.text(CollectionsText.noMatch), findsOneWidget);
      expect(_plain(tester, const Key('metric-approved')), approved);

      final collectionsScroll = find
          .descendant(
            of: find.byKey(const Key('screen-collections')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('employee-totals-toggle')),
        200,
        scrollable: collectionsScroll,
      );
      await tester.drag(collectionsScroll, const Offset(0, -40));
      await tester.pump();
      await tester.tap(find.byKey(const Key('employee-totals-toggle')));
      await tester.pump();
      expect(find.byKey(const Key('employee-totals')), findsOneWidget);
      expect(find.text('موظف استلام تجريبي'), findsWidgets);
      expect(find.text('موظف آخر تجريبي'), findsWidgets);

      tester.state<ScrollableState>(collectionsScroll).position.jumpTo(0);
      await tester.pump();
      await tester.tap(find.byKey(const Key('collections-payroll')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collections-payroll-back')), findsOneWidget);
      expect(find.text(AppStrings.payroll), findsWidgets);
      expect(find.byKey(const Key('close-batch')), findsNothing);
      await tester.tap(find.byKey(const Key('collections-payroll-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'employee collections view keeps own scope and hides admin controls',
    (tester) async {
      await _open(tester, 'employee.demo', textScale: 1.3);

      expect(find.byKey(const Key('collections-filter-card')), findsNothing);
      expect(find.byKey(const Key('collections-filter-batch')), findsNothing);
      expect(
        find.byKey(const Key('collections-filter-employee')),
        findsNothing,
      );
      expect(find.byKey(const Key('close-batch')), findsNothing);
      expect(find.byKey(const Key('employee-totals')), findsNothing);
      expect(find.byKey(const Key('employee-totals-toggle')), findsNothing);
      expect(find.text(CollectionsText.employeeTotals), findsNothing);
      expect(find.text('موظف آخر تجريبي'), findsNothing);
      expect(find.byKey(const Key('approve-sb_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-collection')), findsOneWidget);
      expect(find.text(CollectionsText.tabMyCards), findsWidgets);
      expect(find.text(CollectionsText.tabMyReceipts), findsWidgets);
      expect(find.text(CollectionsText.tabMyCash), findsWidgets);
      expect(find.text(CollectionsText.cashToHandNote), findsNothing);

      _expectStacked(tester, const [
        Key('metric-assigned'),
        Key('metric-pending'),
        Key('metric-cash'),
      ]);
      _expectStacked(tester, const [
        Key('collections-tab-cards'),
        Key('collections-tab-receipts'),
        Key('collections-tab-cash'),
      ]);
      _expectStacked(tester, const [
        Key('unlinked-collection'),
        Key('collections-payroll'),
        Key('collections-export-pdf'),
      ]);

      await tester.tap(find.byKey(const Key('collections-payroll')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collections-payroll-back')), findsOneWidget);
      expect(find.text(AppStrings.myPayroll), findsWidgets);
      expect(find.text(AppStrings.payroll), findsNothing);
      expect(find.byKey(const Key('employee-totals-toggle')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(
  WidgetTester tester,
  String username, {
  required double textScale,
}) async {
  await pumpFakeApp(tester, size: const Size(440, 956), textScale: textScale);
  await signIn(tester, username: username, password: 'demo-only');
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go('/collections');
  await tester.pumpAndSettle();
}

void _expectStacked(WidgetTester tester, List<Key> keys) {
  final rects = [for (final key in keys) tester.getRect(find.byKey(key))];
  for (var i = 1; i < rects.length; i++) {
    expect(rects[i].top, greaterThan(rects[i - 1].bottom - 1));
    expect((rects[i].height - rects.first.height).abs(), lessThan(4));
  }
}

String _plain(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((text) => text.data ?? '').join(' ');
}
