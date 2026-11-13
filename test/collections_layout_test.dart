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
    'admin collections row stays horizontal at 440 and text scale 1.3',
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

      _expectSameRow(tester, const [
        Key('metric-approved'),
        Key('metric-cash-received'),
        Key('metric-remaining'),
        Key('metric-pending'),
      ]);
      _expectSameRow(tester, const [
        Key('collections-tab-all'),
        Key('collections-tab-review'),
        Key('collections-tab-cash'),
        Key('collections-tab-previous'),
      ]);
      _expectSameRow(tester, const [
        Key('collections-payroll'),
        Key('close-batch'),
        Key('collections-export-pdf'),
      ]);
      _expectRightToLeft(tester, const [
        Key('collections-payroll'),
        Key('close-batch'),
        Key('collections-export-pdf'),
      ]);
      _expectRightToLeft(tester, const [
        Key('collections-filter-batch'),
        Key('collections-filter-employee'),
      ]);
      expect(find.text(CollectionsText.closeScopeNote), findsNothing);
      expect(find.text(CollectionsText.summaryNote), findsNothing);
      expect(find.textContaining('غير المربوط ضمن هذا العدد'), findsNothing);
      expect(find.byKey(const Key('close-batch-review')), findsOneWidget);
      expect(
        find.textContaining(CollectionsText.cashNotReceived),
        findsOneWidget,
      );
      final search = tester.getRect(
        find.byKey(const Key('collections-search')),
      );
      final totals = tester.getRect(
        find.byKey(const Key('employee-totals-toggle')),
      );
      expect((search.center.dy - totals.center.dy).abs(), lessThan(8));

      final approved = _plain(tester, const Key('metric-approved'));
      await tester.enterText(
        find.byKey(const Key('collections-search')),
        'لا يطابق شيئا',
      );
      await tester.pump();
      expect(find.text(CollectionsText.noMatch), findsOneWidget);
      expect(_plain(tester, const Key('metric-approved')), approved);

      await tester.tap(find.byKey(const Key('employee-totals-toggle')));
      await tester.pump();
      expect(find.byKey(const Key('employee-totals')), findsOneWidget);
      expect(find.text('موظف استلام تجريبي'), findsWidgets);
      expect(find.text('موظف آخر تجريبي'), findsWidgets);

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
      expect(find.text(CollectionsText.cashToHandNote), findsOneWidget);

      _expectSameRow(tester, const [
        Key('metric-assigned'),
        Key('metric-pending'),
        Key('metric-cash'),
      ]);
      _expectSameRow(tester, const [
        Key('collections-tab-cards'),
        Key('collections-tab-receipts'),
        Key('collections-tab-cash'),
      ]);
      _expectRightToLeft(tester, const [
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

void _expectSameRow(WidgetTester tester, List<Key> keys) {
  final rects = [for (final key in keys) tester.getRect(find.byKey(key))];
  final top = rects.first.top;
  final width = rects.first.width;
  for (final rect in rects) {
    expect((rect.top - top).abs(), lessThan(2));
    expect((rect.width - width).abs(), lessThan(8));
    expect(rect.height, greaterThan(24));
  }
}

void _expectRightToLeft(WidgetTester tester, List<Key> keys) {
  final centers = [
    for (final key in keys) tester.getRect(find.byKey(key)).center.dx,
  ];
  for (var i = 1; i < centers.length; i++) {
    expect(centers[i - 1], greaterThan(centers[i]));
  }
}

String _plain(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((text) => text.data ?? '').join(' ');
}
