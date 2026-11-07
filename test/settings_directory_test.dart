import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/authentication/auth_gate.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/financial_ledger_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

void main() {
  test('isOwner is only boolean true from the server', () {
    expect(
      UserProfile.fromJson(const {
        'id': '1',
        'username': 'a',
        'displayName': 'a',
        'role': 'admin',
        'permissions': <String>[],
        'mustChangePassword': false,
        'fullAccess': true,
      }).isOwner,
      isFalse,
    );
    expect(
      UserProfile.fromJson(const {
        'id': '1',
        'username': 'a',
        'displayName': 'a',
        'role': 'admin',
        'permissions': <String>[],
        'mustChangePassword': false,
        'isOwner': 'true',
      }).isOwner,
      isFalse,
    );
    expect(
      UserProfile.fromJson(const {
        'id': '1',
        'username': 'a',
        'displayName': 'a',
        'role': 'employee',
        'permissions': <String>[],
        'mustChangePassword': false,
        'isOwner': true,
      }).isOwner,
      isTrue,
    );
  });

  test('the create route is closed unless the server says isOwner', () {
    final fullAdmin = PermissionService()
      ..applyFromServer(const [], role: 'admin');
    expect(fullAdmin.fullAccess, isTrue);
    expect(
      permissionRedirect('/settings/users/new', fullAdmin, primaryOwner: false),
      forbiddenLocation,
    );
    expect(
      permissionRedirect('/settings/users/new', fullAdmin, primaryOwner: true),
      isNull,
    );
    final employee = PermissionService()
      ..applyFromServer(const ['collections.read'], role: 'employee');
    expect(
      permissionRedirect('/settings/users/new', employee, primaryOwner: false),
      forbiddenLocation,
    );
    final unknown = PermissionService()
      ..applyFromServer(const ['debts.read'], role: 'guest');
    expect(
      permissionRedirect('/settings/users/new', unknown),
      forbiddenLocation,
    );
    expect(
      permissionRedirect('/settings/users', fullAdmin, primaryOwner: false),
      isNull,
    );
  });

  test('only the primary manager can create a login account', () async {
    final owner = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(owner.dispose);
    await owner.session.login(username: 'admin.demo', password: 'demo-only');
    expect(owner.session.currentUser!.isOwner, isTrue);
    final created = await owner.directory.createLoginAccount(const {
      'username': 'new.collector',
      'displayName': 'محصل جديد',
      'role': 'employee',
      'password': 'temporary-10',
      'permissions': ['collections.read'],
      'customerDebtsAccess': 'none',
    });
    expect(created.isOwner, isFalse);
    expect(created.role, 'employee');
    expect(created.mustChangePassword, isTrue);

    await expectLater(
      owner.directory.createLoginAccount(const {
        'username': 'no-mail',
        'displayName': 'مدير بلا بريد',
        'role': 'admin',
        'password': 'temporary-10',
      }),
      throwsA(isA<ApiException>()),
    );

    final createdAdmin = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(createdAdmin.dispose);
    await createdAdmin.session.login(
      username: 'created.admin',
      password: 'demo-only',
    );
    expect(createdAdmin.session.currentUser!.role, 'admin');
    expect(createdAdmin.session.currentUser!.isOwner, isFalse);
    expect(createdAdmin.permissions.fullAccess, isTrue);
    await expectLater(
      createdAdmin.directory.createLoginAccount(const {
        'username': 'should-fail',
        'displayName': 'لا',
        'role': 'employee',
        'password': 'temporary-10',
      }),
      throwsA(isA<ForbiddenException>()),
    );
    final pending = await createdAdmin.directory.accountRequests();
    expect(pending.single.pending, isTrue);
    final decided = await createdAdmin.directory.decideAccountRequest(
      pending.single.id,
      {'decision': 'reject', 'expectedVersion': pending.single.version},
    );
    expect(decided.status, 'rejected');

    final employeeApi = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(employeeApi.dispose);
    await employeeApi.session.login(
      username: 'employee.demo',
      password: 'demo-only',
    );
    expect(employeeApi.session.currentUser!.isOwner, isFalse);
    await expectLater(
      employeeApi.directory.createLoginAccount(const {
        'username': 'nope',
        'displayName': 'لا',
        'role': 'employee',
        'password': 'temporary-10',
      }),
      throwsA(isA<ForbiddenException>()),
    );
  });

  testWidgets('a created admin cannot open account creation', (tester) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await signIn(tester, username: 'created.admin', password: 'demo-only');
    await go(tester, '/settings/users');
    expect(find.byKey(const Key('login-account-create')), findsNothing);
    expect(
      find.byKey(const Key('login-account-create-closed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-request-ar_1')), findsOneWidget);
    await go(tester, '/settings/users/new');
    expect(find.byKey(const Key('screen-login-account-create')), findsNothing);
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
  });

  testWidgets(
    'the owner creates an employee and the ledger lists server rows',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(440, 1200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/settings/users/new');
      expect(
        find.byKey(const Key('screen-login-account-create')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('create-username')),
        'collector.2',
      );
      await tester.enterText(
        find.byKey(const Key('create-display-name')),
        'محصل ثان',
      );
      await tester.enterText(
        find.byKey(const Key('create-password')),
        'temporary-10',
      );
      await tester.ensureVisible(
        find.byKey(const Key('create-account-submit')),
      );
      await tester.tap(find.byKey(const Key('create-account-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('screen-settings-employees')),
        findsOneWidget,
      );
      expect(find.text('محصل ثان'), findsOneWidget);

      await go(tester, '/settings/ledger');
      expect(find.byKey(FinancialLedgerScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('ledger-entry-4')), findsOneWidget);
      expect(find.text('عميل تجريبي'), findsOneWidget);
      expect(find.byKey(const Key('ledger-page-note')), findsOneWidget);
      expect(find.byType(ForbiddenPane), findsNothing);
    },
  );

  test('an audit cursor is the integer before token, not a session list', () {
    final page = AuditPage.fromData(const {
      'items': [
        {
          'id': 3,
          'action': 'collection.submit',
          'outcome': 'success',
        },
      ],
      'nextBefore': 14,
    });
    expect(page.nextBefore, '14');
    expect(page.items.single.isSessionAction, isFalse);
    expect(auditCursor('14'), '14');
    expect(auditCursor({'id': 14}), isNull);
  });

  test('approving a public request does not open a session', () async {
    final admin = ApiLayer.create(
      config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    );
    addTearDown(admin.dispose);
    await admin.session.login(username: 'created.admin', password: 'demo-only');
    final pending = await admin.directory.accountRequests();
    final approved = await admin.directory.decideAccountRequest(
      pending.single.id,
      {'decision': 'approve', 'expectedVersion': pending.single.version},
    );
    expect(approved.status, 'approved');
    final accounts = await admin.directory.loginAccounts();
    expect(
      accounts.items.any((item) => item.email == pending.single.email),
      isFalse,
    );

    final stranger = ApiLayer.create(
      config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    );
    addTearDown(stranger.dispose);
    await stranger.session.restore();
    expect(stranger.session.state, isA<SessionUnauthenticated>());
    expect(stranger.session.currentUser, isNull);
    expect(stranger.permissions.role, AccountRole.unknown);
  });

  testWidgets('older audit rows load only through the server before cursor', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    (layer.client as FakeApiClient).scriptedGetJson['/api/audit-log'] =
        jsonEncode({
      'items': [
        {
          'id': 20,
          'action': 'collection.approve',
          'outcome': 'success',
          'actorName': 'مدير تجريبي',
          'createdAt': '2026-10-22T22:00:00.000Z',
        },
      ],
      'nextBefore': 15,
    });
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/audit');
    expect(find.byKey(const Key('audit-event-20')), findsOneWidget);
    expect(find.byKey(const Key('audit-older')), findsOneWidget);
    await tester.tap(find.byKey(const Key('audit-older')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audit-event-15')), findsOneWidget);
    expect(find.byKey(const Key('audit-older')), findsNothing);
    expect(find.byKey(const Key('security-mfa-evidence')), findsOneWidget);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
