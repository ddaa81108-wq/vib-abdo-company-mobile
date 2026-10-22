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

      expect(
        find.byKey(const Key('submission-sb_posted_1'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unlinked-card-ur_posted_1'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('زبون جديد', skipOffstage: false), findsOneWidget);

      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      expect(overview!.submissions.map((row) => row.id).toList(), [
        'sb_1',
        'sb_2',
        'sb_posted_1',
      ]);
      expect(overview.unlinkedReceipts.map((row) => row.id).toList(), [
        'ur_1',
        'ur_2',
        'ur_posted_1',
      ]);
      expect(overview.submissions.last.amountUnits, 40);
      expect(overview.unlinkedReceipts.last.amountUnits, 25);
      expect(overview.unlinkedReceipts.last.customerName, 'زبون جديد');

      await go(tester, '/');
      await go(tester, '/collections');
      expect(
        find.byKey(const Key('submission-sb_posted_1'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unlinked-card-ur_posted_1'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );
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
