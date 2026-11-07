import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

/// Real collections dialogs. The only stand-in is the fake client inside ApiLayer.
void main() {
  testWidgets(
    'DEF-021 the next collections overview shows the submitted rows',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/collections');

      await tester.ensureVisible(find.byKey(const Key('submit-as_1')));
      await tester.tap(find.byKey(const Key('submit-as_1')));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        '40',
      );
      await tester.tap(find.byKey(const Key('save-assignment')));
      await settle(tester);

      await tester.ensureVisible(find.byKey(const Key('unlinked-collection')));
      await tester.tap(find.byKey(const Key('unlinked-collection')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('unlinked-name')),
        'زبون جديد',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('unlinked-amount')),
          matching: find.byType(TextField),
        ),
        '25',
      );
      await tester.tap(find.byKey(const Key('save-unlinked')));
      await settle(tester);

      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      // 537f073 lists submissions newest first; rejected unlinked receipts
      // are not listed.
      final posted = overview!.submissions.first;
      expect(posted.assignmentId, 'as_1');
      expect(posted.amountUnits?.units, 40);
      expect(posted.status, 'pending');
      expect(overview.submissions, hasLength(3));
      final created = overview.unlinkedReceipts.firstWhere(
        (row) => row.customerName == 'زبون جديد',
      );
      expect(created.amountUnits?.units, 25);
      expect(overview.unlinkedReceipts.map((row) => row.id), contains('ur_1'));
      expect(
        overview.unlinkedReceipts.map((row) => row.id),
        isNot(contains('ur_2')),
      );

      expect(
        find.byKey(Key('submission-${posted.id}'), skipOffstage: false),
        findsOneWidget,
      );
      // Standalone receipts are on «تحصيلاتي».
      await openReceipts(tester);
      expect(
        find.byKey(Key('unlinked-card-${created.id}'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('زبون جديد', skipOffstage: false), findsOneWidget);
      await openTab(tester, 'cards');
      // One pending receipt per card: both buttons are off now.
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('submit-as_1'), skipOffstage: false),
            )
            .onPressed,
        isNull,
      );

      await go(tester, '/');
      await go(tester, '/collections');
      expect(
        find.byKey(Key('submission-${posted.id}'), skipOffstage: false),
        findsOneWidget,
      );
      await openReceipts(tester);
      expect(
        find.byKey(Key('unlinked-card-${created.id}'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}

Future<void> openReceipts(WidgetTester tester) => openTab(tester, 'receipts');

Future<void> openTab(WidgetTester tester, String tab) async {
  final chip = find.byKey(Key('collections-tab-$tab'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(Duration.zero);
    if (!tester.binding.hasScheduledFrame) return;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  }
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}
