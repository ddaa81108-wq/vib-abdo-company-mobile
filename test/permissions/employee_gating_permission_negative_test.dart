@Tags(['permissions-negative'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'an employee does not see totals or decide, and the fake server rejects both',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await _go(tester, '/collections');

      expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
      expect(find.text(AppStrings.employeeTotals), findsNothing);
      expect(find.byKey(const Key('collections-metrics')), findsNothing);
      expect(find.byKey(const Key('approve-sb_1')), findsNothing);
      expect(find.byKey(const Key('reject-sb_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-approve-ur_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-reject-ur_1')), findsNothing);
      expect(find.byKey(const Key('close-batch')), findsNothing);

      final version = MutationMeta(expectedVersion: 1);
      // The fake's latency is a timer. Listen before pumping so the 403 is not
      // an unhandled async error, and advance the clock so Duration.zero fires.
      await _forbidden(
        tester,
        layer.collections.decide(
          'sb_1',
          CollectionDecision.approve,
          meta: version,
        ),
      );
      await _forbidden(
        tester,
        layer.collections.decide(
          'sb_1',
          CollectionDecision.reject,
          meta: version,
        ),
      );

      final loggedOut = layer.session.logout();
      await tester.pump(const Duration(milliseconds: 1));
      await loggedOut;
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(layer.session.state, isA<SessionUnauthenticated>());
      final me = expectLater(
        layer.profile.fetchMe(),
        throwsA(isA<SessionExpiredException>()),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await me;
    },
  );
}

Future<void> _forbidden(WidgetTester tester, Future<void> pending) async {
  final expectation = expectLater(pending, throwsA(isA<ForbiddenException>()));
  await tester.pump(const Duration(milliseconds: 1));
  await expectation;
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
