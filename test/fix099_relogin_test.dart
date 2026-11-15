import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('login after logout opens home for both accounts', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);

    await _logout(tester);
    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    expect(find.byKey(HomeShell.shellKey), findsNothing);

    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.collections)),
      findsOneWidget,
    );
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.purchases)),
      findsNothing,
    );

    await _logout(tester);
    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);

    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.purchases)),
      findsOneWidget,
    );
  });
}

Future<void> _logout(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(HomeShell.logoutKey));
  await tester.tap(find.byKey(HomeShell.logoutKey));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
  await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
