import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/change_password_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('DEF-008 mustchange.demo is kept on the change-password screen', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'mustchange.demo', password: 'demo-only');

    expect(find.byKey(ChangePasswordScreen.screenKey), findsOneWidget);
    expect(find.text(AppStrings.passwordChangeRequired), findsOneWidget);

    GoRouter.of(tester.element(find.byKey(ChangePasswordScreen.screenKey)))
        .go('/customers');
    await settle(tester);
    expect(find.byKey(ChangePasswordScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);

    await tester.enterText(
      find.byKey(ChangePasswordScreen.currentKey),
      'demo-only',
    );
    await tester.enterText(
      find.byKey(ChangePasswordScreen.nextKey),
      'new-password-1',
    );
    await tester.enterText(
      find.byKey(ChangePasswordScreen.confirmKey),
      'new-password-1',
    );
    await tester.tap(find.byKey(ChangePasswordScreen.submitKey));
    await settle(tester);

    expect(layer.session.currentUser?.mustChangePassword, isFalse);
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(ChangePasswordScreen.screenKey), findsNothing);
  });

  testWidgets(
    'DEF-009 and P2-07 the demo card has one age and the system card has no writes',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');

      expect(find.textContaining('مرّ عليه 3 أيام'), findsNothing);
      expect(find.textContaining('منذ 4 أيام'), findsWidgets);

      await go(tester, '/customers');
      expect(find.text('مرّ عليه 3 أيام'), findsNothing);
      expect(find.text('منذ 4 أيام'), findsWidgets);
      expect(find.text('متبقي المصراوية تجريبي'), findsOneWidget);

      await go(tester, '/customers/c_masraweya_remainder');
      expect(
        find.byKey(const ValueKey('system-masraweya_remainder')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.systemCard), findsWidgets);
      expect(find.byKey(const Key('add-debt')), findsNothing);
      expect(find.byKey(const Key('add-payment')), findsNothing);
      expect(find.byKey(const Key('full-payment')), findsNothing);
      expect(find.byKey(const Key('cancel-tx_1')), findsNothing);

      await go(tester, '/');
      await go(tester, '/customers/c_55');
      expect(find.byKey(const Key('add-debt')), findsOneWidget);
      expect(find.byKey(const Key('full-payment')), findsOneWidget);
      expect(find.text('مرّ عليه 3 أيام'), findsNothing);
      expect(find.text('منذ 4 أيام'), findsWidgets);
    },
  );
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
