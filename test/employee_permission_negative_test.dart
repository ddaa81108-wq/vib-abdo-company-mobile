@Tags(['permissions-negative'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/authentication/auth_gate.dart';
import 'package:vib_abdo_company_mobile/error_handling/app_failure.dart';
import 'package:vib_abdo_company_mobile/error_handling/error_handler.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

void main() {
  test('FORBIDDEN stays on the existing failure type and is not retried', () {
    const error = ForbiddenException(
      code: 'FORBIDDEN',
      message: 'لا تملك صلاحية لهذا الإجراء',
      statusCode: 403,
    );
    final failure = const ErrorHandler().toFailure(error);
    expect(failure, isA<AppFailure>());
    expect(failure.code, 'FORBIDDEN');
    expect(failure.isForbidden, isTrue);
    expect(failure.message, 'لا تملك صلاحية لهذا الإجراء');
    expect(retryUnlessForbidden(0, error), isNull);
    expect(retryUnlessForbidden(0, Exception('other')), isNotNull);

    const denied = ForbiddenException(
      code: 'PERMISSION_DENIED',
      message: 'نص الخادم لا يُعرض',
      statusCode: 403,
    );
    final deniedFailure = const ErrorHandler().toFailure(denied);
    expect(deniedFailure.code, 'PERMISSION_DENIED');
    expect(deniedFailure.isForbidden, isTrue);
    expect(failureText(deniedFailure), AppStrings.forbidden);
    expect(presentFailure(deniedFailure), isA<ForbiddenPane>());
    expect(retryUnlessForbidden(0, denied), isNull);
  });

  test('forbidden and admin paths redirect to /forbidden without a loop', () {
    final employee = PermissionService()
      ..applyFromServer(
        FakeFixtures.employeePermissions,
        role: 'employee',
        sectionAccess: FakeFixtures.employeeSectionAccess,
      );
    for (final path in _adminPaths) {
      expect(permissionRedirect(path, employee), forbiddenLocation);
    }
    expect(permissionRedirect(forbiddenLocation, employee), isNull);
    expect(permissionRedirect('/', employee), isNull);
    expect(permissionRedirect('/collections', employee), isNull);
    expect(permissionRedirect('/customers', employee), isNull);
  });

  testWidgets('an employee deep link opens the forbidden screen', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');

    for (final action in ManagementAction.values) {
      expect(find.byKey(HomeShell.actionKey(action)), findsNothing);
    }
    expect(find.text(AppStrings.settings), findsNothing);
    expect(find.text(AppStrings.approve), findsNothing);
    expect(find.text(AppStrings.reject), findsNothing);

    await go(tester, '/collections');
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    expect(find.byKey(const Key('reject-sb_1')), findsNothing);
    expect(find.byKey(const Key('cash-sb_2')), findsNothing);
    expect(find.byKey(const Key('close-batch')), findsNothing);
    expect(find.byKey(const Key('unlinked-approve-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsNothing);
    expect(find.text(AppStrings.employeeTotals), findsNothing);
    expect(find.text('موظف آخر تجريبي'), findsNothing);

    for (final path in _adminPaths) {
      await go(tester, path);
      expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
      expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
      expect(find.text(AppStrings.retry), findsNothing);
      expect(_location(tester), forbiddenLocation);
    }

    await go(tester, forbiddenLocation);
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(_location(tester), forbiddenLocation);

    await tester.tap(find.byKey(ForbiddenScreen.homeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(_location(tester), '/');
  });

  testWidgets('a provider 403 shows ForbiddenPane and does not retry', (
    tester,
  ) async {
    var reads = 0;
    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        collectionsProvider.overrideWith((ref) async {
          reads++;
          throw const ForbiddenException(
            code: 'FORBIDDEN',
            message: 'لا تملك صلاحية لهذا الإجراء',
            statusCode: 403,
          );
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    final readsAfterSignIn = reads;
    await go(tester, '/collections');
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsWidgets);
    expect(find.text(AppStrings.retry), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, readsAfterSignIn + 1);
  });
}

const _adminPaths = [
  '/settings',
  '/settings/employees',
  '/settings/audit',
  '/settings/operations',
  '/treasury',
  '/reports',
  '/purchases',
  '/masraweya',
  '/companies',
  '/companies/c_co_02',
];

String _location(WidgetTester tester) {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  return GoRouter.of(context).state.uri.path;
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
