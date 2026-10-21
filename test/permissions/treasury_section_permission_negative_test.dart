@Tags(['permissions-negative'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/treasury/treasury_screen.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'employee without a treasury code cannot see or act on treasury',
    (tester) async {
      final layer = await pumpFakeApp(tester);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');

      expect(layer.permissions.canRead(SectionKey.treasury), isFalse);
      expect(layer.permissions.canWrite(SectionKey.treasury), isFalse);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsNothing,
      );
      expect(find.byKey(HomeShell.writeKey(SectionKey.treasury)), findsNothing);
      expect(find.byKey(const Key('cash-in')), findsNothing);

      final context = tester.element(find.byKey(HomeShell.shellKey));
      GoRouter.of(context).go('/treasury');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );

      expect(find.byKey(TreasuryScreen.screenKey), findsNothing);
      expect(find.byKey(const Key('cash-in')), findsNothing);
      expect(find.byKey(HomeShell.shellKey), findsOneWidget);
    },
  );
}
