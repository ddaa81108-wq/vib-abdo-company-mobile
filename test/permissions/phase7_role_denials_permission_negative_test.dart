@Tags(['permissions-negative'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/error_handling/error_handler.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/treasury/treasury_screen.dart';
import 'package:vib_abdo_company_mobile/state/employee_totals_provider.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import '../support/phase7_nav.dart';
import '../support/pump_app.dart';

/// Negative cases for P7-05 and P7-12. The session comes from the login form.
/// pumpFakeApp sets retry to null for every error, so it does not prove the
/// production retry rule. That rule is the container test below, which copies
/// the callback in lib/main.dart without changing production code.
void main() {
  testWidgets(
    'P7-05 employee treasury and masraweya are forbidden with no retry',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
      await signIn(tester, username: 'employee.demo', password: 'demo-only');

      expect(layer.permissions.canRead(SectionKey.treasury), isFalse);
      expect(layer.permissions.canWrite(SectionKey.reports), isFalse);

      for (final path in ['/treasury', '/masraweya', '/companies']) {
        await go(tester, path);
        expect(find.byKey(TreasuryScreen.screenKey), findsNothing);
        expect(find.byKey(const Key('screen-masraweya')), findsNothing);
        expect(find.byKey(const Key('screen-companies')), findsNothing);
        expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
        expect(find.text(AppStrings.forbidden), findsWidgets);
        expect(find.text(AppStrings.retry), findsNothing);
        expect(find.byKey(HomeShell.shellKey), findsOneWidget);
      }
    },
  );

  testWidgets(
    'P7-12 employee does not see decide buttons and the repository returns 403',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/collections');

      expect(find.byKey(const Key('approve-sb_1')), findsNothing);
      expect(find.byKey(const Key('reject-sb_1')), findsNothing);
      expect(find.byKey(const Key('approve-sb_9')), findsNothing);
      expect(find.byKey(const Key('reject-sb_9')), findsNothing);
      expect(find.byKey(const Key('unlinked-approve-ur_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-link-ur_1')), findsNothing);

      await tester.runAsync(() async {
        await expectLater(
          layer.collections.decide(
            'sb_1',
            CollectionDecision.approve,
            meta: MutationMeta(expectedVersion: 1),
          ),
          throwsA(
            isA<ForbiddenException>()
                .having((error) => error.statusCode, 'status', 403)
                .having((error) => error.code, 'code', 'FORBIDDEN'),
          ),
        );
      });
    },
  );

  testWidgets(
    'DEF-002 limited admin can decide today and employee-totals stays 403',
    (tester) async {
      // Owner decision still open. collections.decide is granted, and the
      // screen shows the button. canViewEmployeeTotals stays full-access
      // only. This records the current behaviour. It does not close DEF-002
      // and it is not a Pass for the limited manager.
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(
        tester,
        username: 'limited.admin.demo',
        password: 'demo-only',
      );
      await go(tester, '/collections');

      final approve = find.byKey(const Key('approve-sb_1'));
      expect(approve, findsOneWidget);
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await settle(tester);
      expect(find.byKey(const Key('approve-sb_1')), findsNothing);

      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      expect(
        overview!.submissions.firstWhere((row) => row.id == 'sb_1').status,
        'approved',
      );

      await go(tester, '/settings/employee-totals');
      expect(find.byKey(const Key('screen-employee-totals')), findsNothing);
      expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(HomeShell.shellKey)),
      );
      await tester.runAsync(() async {
        await expectLater(
          container.read(employeeTotalsProvider.future),
          throwsA(
            isA<ForbiddenException>().having(
              (error) => error.statusCode,
              'status',
              403,
            ),
          ),
        );
      });
      await tester.pump();
      final state = container.read(employeeTotalsStateProvider);
      expect(state, isA<EmployeeTotalsForbidden>());
      final forbidden = state as EmployeeTotalsForbidden;
      expect(forbidden.failure.isForbidden, isTrue);
      expect(forbidden.failure.code, 'FORBIDDEN');
      expect(forbidden.message, AppStrings.forbidden);
    },
    tags: ['pending-decision'],
  );

  testWidgets(
    'employee collections overview still includes the caller totals row',
    (tester) async {
      // Open question for Ali: must the server omit employeeTotals for an
      // employee? The fake still returns the caller's own row. 🔶 userId on
      // that row is how the fake scopes it. Not a Pass that the field is
      // confirmed.
      final layer = await pumpFakeApp(tester);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      final overview = await tester.runAsync(
        () => layer.collections.overview(),
      );
      expect(overview!.employeeTotals, hasLength(1));
      expect(overview.employeeTotals.single.employeeName, 'موظف استلام تجريبي');
    },
    tags: ['pending-decision'],
  );

  test('a 403 is not retried by the buildAppRoot callback', () async {
    // Same branches as buildAppRoot in lib/main.dart. Production is left as
    // it is; this test copies the callback so a 403 can be counted.
    Duration? appRetry(int retryCount, Object error) {
      if (error is SessionExpiredException) return null;
      return retryUnlessForbidden(retryCount, error);
    }

    var calls = 0;
    final probe = FutureProvider<int>((ref) async {
      calls++;
      throw const ForbiddenException(
        code: 'FORBIDDEN',
        message: 'لا تملك صلاحية لهذا الإجراء',
        statusCode: 403,
      );
    });
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);
    final container = ProviderContainer(
      retry: appRetry,
      overrides: [apiLayerProvider.overrideWithValue(layer)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(probe.future),
      throwsA(isA<ForbiddenException>()),
    );
    expect(calls, 1);

    expect(appRetry(0, const SessionExpiredException(statusCode: 401)), isNull);
    expect(
      retryUnlessForbidden(
        0,
        const ForbiddenException(
          code: 'FORBIDDEN',
          message: 'لا تملك صلاحية لهذا الإجراء',
          statusCode: 403,
        ),
      ),
      isNull,
    );
    final notFound = const NotFoundException(
      code: 'NOT_FOUND',
      message: 'العنصر غير موجود',
      statusCode: 404,
    );
    expect(appRetry(0, notFound), isNotNull);
    expect(appRetry(0, notFound), ProviderContainer.defaultRetry(0, notFound));
  });
}
