import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets(
    'administration opens isolated employee pages and cancelled entries disappear after reopening',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(430, 1200));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      await go(tester, '/collections?view=payroll');
      expect(
        find.byKey(const Key('payroll-employee-directory')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('payroll-entry-pe_1')), findsNothing);
      await tester.tap(find.byKey(const Key('payroll-employee-u_12')));
      await settle(tester);
      expect(find.byKey(const Key('payroll-page-u_12')), findsOneWidget);
      expect(find.byKey(const Key('payroll-u_20')), findsNothing);
      expect(find.byKey(const Key('payroll-entry-pe_9')), findsNothing);
      for (final id in ['pe_1', 'pe_2']) {
        final button = find.byKey(Key('payroll-cancel-$id'));
        await tester.ensureVisible(button);
        final press = tester.widget<TextButton>(button).onPressed!;
        for (var attempt = 0; attempt < 20; attempt++) {
          press();
        }
        await pumpUntilFound(tester, find.byKey(const Key('confirm-mutation')));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('confirm-mutation')), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm-mutation')));
        await settle(tester);
        expect(find.byKey(Key('payroll-entry-$id')), findsNothing);
      }
      expect(
        fake.mutationPaths.where((path) => path.endsWith('/cancel')),
        hasLength(2),
      );
      expect(find.text('لا توجد حركات في هذه الفترة.'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('payroll-employees-back')),
      );
      await tester.tap(find.byKey(const Key('payroll-employees-back')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('payroll-employee-u_20')));
      await settle(tester);
      expect(find.byKey(const Key('payroll-entry-pe_9')), findsOneWidget);
      expect(find.byKey(const Key('payroll-entry-pe_1')), findsNothing);
      await go(tester, '/collections/payroll/u_12');
      expect(find.text('لا توجد حركات في هذه الفترة.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a refused cancellation leaves the movement and balance intact until a successful retry',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(430, 1200));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      await go(tester, '/collections/payroll/u_12');
      Future<void> openConfirmation() async {
        final button = find.byKey(const Key('payroll-cancel-pe_1'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await pumpUntilFound(tester, find.byKey(const Key('confirm-mutation')));
      }

      await openConfirmation();
      fake.failNextResponse = (
        status: 400,
        code: 'BALANCE_OUT_OF_RANGE',
        message: 'رفض اختبار منفصل',
      );
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);
      expect(find.byKey(const Key('payroll-entry-pe_1')), findsOneWidget);
      await tester.runAsync(() async {
        expect(
          (await layer.collections.payroll())
              .employees
              .first
              .remainingUnits
              ?.asInt,
          1250,
        );
      });
      await openConfirmation();
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);
      expect(find.byKey(const Key('payroll-entry-pe_1')), findsNothing);
      await tester.runAsync(() async {
        expect(
          (await layer.collections.payroll())
              .employees
              .first
              .remainingUnits
              ?.asInt,
          1550,
        );
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'salary and entry forms target only the employee whose page is open',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(430, 1200));
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      await go(tester, '/collections/payroll/u_20');
      await tester.ensureVisible(find.byKey(const Key('payroll-add-u_20')));
      await tester.tap(find.byKey(const Key('payroll-add-u_20')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('payroll-amount')), '25');
      await tester.enterText(
        find.byKey(const Key('payroll-reason')),
        'سحب اختبار الموظف الثاني',
      );
      await tester.ensureVisible(find.byKey(const Key('save-payroll-entry')));
      await tester.tap(find.byKey(const Key('save-payroll-entry')));
      await settle(tester);
      await tester.runAsync(() async {
        final data = await layer.collections.payroll();
        expect(
          data.employees
              .firstWhere((row) => row.userId == 'u_12')
              .remainingUnits
              ?.asInt,
          1250,
        );
        expect(
          data.employees
              .firstWhere((row) => row.userId == 'u_20')
              .remainingUnits
              ?.asInt,
          2555,
        );
      });
      await tester.ensureVisible(find.byKey(const Key('payroll-salary-u_20')));
      await tester.tap(find.byKey(const Key('payroll-salary-u_20')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('payroll-salary-amount')),
        '2600',
      );
      await tester.tap(find.byKey(const Key('save-salary')));
      await settle(tester);
      await tester.runAsync(() async {
        final data = await layer.collections.payroll();
        expect(
          data.employees
              .firstWhere((row) => row.userId == 'u_12')
              .remainingUnits
              ?.asInt,
          1250,
        );
        expect(
          data.employees
              .firstWhere((row) => row.userId == 'u_20')
              .remainingUnits
              ?.asInt,
          2755,
        );
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'employees see their own payroll without cancel controls and cannot open another employee',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 1100));
      await signIn(tester, username: 'employee.demo', password: 'test-only');
      await go(tester, '/collections?view=payroll');
      expect(find.byKey(const Key('payroll-employee-directory')), findsNothing);
      expect(find.byKey(const Key('payroll-u_12')), findsOneWidget);
      expect(find.byKey(const Key('payroll-cancel-pe_1')), findsNothing);
      await go(tester, '/collections/payroll/u_20');
      expect(find.byType(ForbiddenPane), findsOneWidget);
      expect(find.byKey(const Key('payroll-u_20')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
