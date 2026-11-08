import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

void main() {
  testWidgets('a stored limited section is not a choice and is not upgraded', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1200));
    final fake = layer.client as FakeApiClient;
    fake.extraLoginUsers.add(_reader());
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-legacy-customerDebts'));
    expect(find.byKey(const Key('edit-legacy-customerDebts')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('edit-access-customerDebts')),
        matching: find.text('قراءة'),
      ),
      findsNothing,
    );
    final grant = tester.widget<ChoiceChip>(
      find.byKey(const Key('edit-grant-customerDebts')),
    );
    expect(grant.selected, isFalse);
    await tester.ensureVisible(
      find.byKey(const Key('login-account-save-permissions')),
    );
    await tester.tap(find.byKey(const Key('login-account-save-permissions')));
    await tester.pumpAndSettle();
    final kept = fake.mutationBodies.join('\n');
    expect(kept, contains('"customerDebtsAccess":"read"'));
    expect(kept, isNot(contains('"debts.write"')));
  });

  testWidgets('granting a section persists manage and the section codes', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    fake.extraLoginUsers.add(_reader());
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-grant-customerDebts'));
    await tester.tap(find.byKey(const Key('edit-grant-customerDebts')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('login-account-save-permissions')),
    );
    await tester.tap(find.byKey(const Key('login-account-save-permissions')));
    await tester.pumpAndSettle();
    final body = fake.mutationBodies.join('\n');
    expect(body, contains('"customerDebtsAccess":"manage"'));
    expect(body, contains('"debts.read"'));
    expect(body, contains('"debts.write"'));
    expect(body, isNot(contains('"purchases.finalize"')));
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-grant-customerDebts'));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('edit-grant-customerDebts')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('edit-legacy-customerDebts')), findsNothing);
  });

  testWidgets('denying a section removes its codes and reports the error', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    fake.extraLoginUsers.add(_reader());
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-deny-customerDebts'));
    await tester.tap(find.byKey(const Key('edit-deny-customerDebts')));
    await tester.pumpAndSettle();
    fake.failNextResponse = (
      status: 403,
      code: 'FORBIDDEN',
      message: 'تعديل الحساب مرفوض.',
    );
    await tester.ensureVisible(
      find.byKey(const Key('login-account-save-permissions')),
    );
    await tester.tap(find.byKey(const Key('login-account-save-permissions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-account-save-error')), findsOneWidget);
    expect(find.byKey(const Key('screen-login-account-edit')), findsOneWidget);
    fake.failNextResponse = null;
    await tester.tap(find.byKey(const Key('login-account-save-permissions')));
    await tester.pumpAndSettle();
    final body = fake.mutationBodies.join('\n');
    expect(body, contains('"customerDebtsAccess":"none"'));
    expect(body, isNot(contains('"debts.read"')));
    expect(body, isNot(contains('"debts.write"')));
  });

  testWidgets('creating a section grant sends manage and the section codes', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/new');
    await tester.enterText(
      find.byKey(const Key('create-username')),
      'full.section',
    );
    await tester.enterText(
      find.byKey(const Key('create-display-name')),
      'موظف قسم',
    );
    await tester.enterText(
      find.byKey(const Key('create-password')),
      'temporary-10',
    );
    await _show(
      tester,
      const Key('create-grant-customerDebts'),
      const Key('screen-login-account-create'),
    );
    await tester.tap(find.byKey(const Key('create-grant-customerDebts')));
    await tester.pumpAndSettle();
    await _show(
      tester,
      const Key('create-grant-reports'),
      const Key('screen-login-account-create'),
    );
    await tester.tap(find.byKey(const Key('create-grant-reports')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('create-account-submit')));
    await tester.tap(find.byKey(const Key('create-account-submit')));
    await tester.pumpAndSettle();
    final body = fake.mutationBodies.join('\n');
    expect(body, contains('"customerDebtsAccess":"manage"'));
    expect(body, contains('"reportsAccess":"manage"'));
    expect(body, contains('"debts.read"'));
    expect(body, contains('"debts.write"'));
    expect(body, contains('"reports.read"'));
    expect(body, isNot(contains('reports.write')));
    expect(body, isNot(contains('"purchases.finalize"')));
    expect(find.text('موظف قسم'), findsOneWidget);
  });

  testWidgets('cancel leaves a chosen section unsaved', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    fake.extraLoginUsers.add(_reader());
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-grant-customerDebts'));
    await tester.tap(find.byKey(const Key('edit-grant-customerDebts')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-account-cancel')));
    await tester.tap(find.byKey(const Key('login-account-cancel')));
    await tester.pumpAndSettle();
    expect(fake.mutationBodies, isEmpty);
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-legacy-customerDebts'));
    expect(find.byKey(const Key('edit-legacy-customerDebts')), findsOneWidget);
  });

  testWidgets('section grants hold at 360 and text scale 2', (tester) async {
    final layer = await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      textScale: 2,
    );
    (layer.client as FakeApiClient).extraLoginUsers.add(_reader());
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-grant-customerDebts'));
    expect(find.byKey(const Key('edit-grant-customerDebts')), findsOneWidget);
    expect(find.text('دخول كامل'), findsWidgets);
    expect(find.text('ممنوع'), findsWidgets);
    expect(tester.takeException(), isNull);
    await go(tester, '/settings');
    await tester.tap(find.byKey(const Key('settings-theme-switch')));
    await tester.pumpAndSettle();
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-legacy-customerDebts'));
    expect(find.byKey(const Key('edit-legacy-customerDebts')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section grant light and dark at 360, fake', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      textScale: 2,
    );
    (layer.client as FakeApiClient).extraLoginUsers.add(_reader());
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-legacy-customerDebts'));
    await saveShot(tester, 'section-grant-light-360');
    await go(tester, '/settings');
    await tester.tap(find.byKey(const Key('settings-theme-switch')));
    await tester.pumpAndSettle();
    await go(tester, '/settings/users/u_read');
    await _show(tester, const Key('edit-legacy-customerDebts'));
    await saveShot(tester, 'section-grant-dark-360');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

Map<String, dynamic> _reader() => {
  'id': 'u_read',
  'username': 'reader.demo',
  'displayName': 'حساب قديم',
  'role': 'employee',
  'isOwner': false,
  'isActive': true,
  'version': 2,
  'email': null,
  'mustChangePassword': true,
  'permissions': ['debts.read'],
  'sectionAccess': {
    'customerDebts': 'read',
    'companyDebts': 'none',
    'libyanDeposits': 'none',
    'egyptianDeposits': 'none',
    'masraweya': 'none',
    'purchases': 'none',
    'treasury': 'none',
    'reports': 'none',
  },
};

Future<void> _show(
  WidgetTester tester,
  Key key, [
  Key screen = const Key('screen-login-account-edit'),
]) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    300,
    scrollable: find
        .descendant(of: find.byKey(screen), matching: find.byType(Scrollable))
        .first,
  );
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
