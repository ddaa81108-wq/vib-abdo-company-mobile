import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin confirms cancel-approval and the server row is dropped', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await tester.ensureVisible(find.byKey(const Key('cancel-approval-sb_2')));
    expect(find.byKey(const Key('cash-sb_2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-approval-sb_2')));
    await tester.pumpAndSettle();
    expect(find.text(CollectionsText.cancelApprovalTitle), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-cancel-approval')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('cancel-approval-reason')),
      'تصحيح',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-cancel-approval')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel-approval-sb_2')), findsNothing);
    expect(find.byKey(const Key('cash-sb_2')), findsNothing);
  });

  testWidgets('the phone cash step shows both pills', (tester) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await tester.runAsync(loadScreenshotFonts);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await tester.ensureVisible(find.byKey(const Key('cancel-approval-sb_2')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'collections-receipt-cancel-light');
  }, tags: const ['screenshots']);
}
