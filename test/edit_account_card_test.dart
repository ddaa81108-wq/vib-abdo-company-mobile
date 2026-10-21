import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/accounts/edit_account_card_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

void main() {
  test('edit request sends name and phone and no financial fields', () {
    final json = accountCardEditRequest(
      name: '  علي  ',
      phone: ' 091 ',
    ).toJson();
    expect(json.keys, ['name', 'phone']);
    expect(json['name'], 'علي');
    expect(json['phone'], '091');

    final cleared = accountCardEditRequest(name: 'علي', phone: '  ').toJson();
    expect(cleared['phone'], '');
    expect(cleared.containsKey('balanceUnits'), isFalse);
    expect(cleared.containsKey('openingBalance'), isFalse);
    expect(cleared.containsKey('debtAgeDays'), isFalse);
    expect(cleared.containsKey('ageStatus'), isFalse);
  });

  test('a blank name is rejected before a request exists', () {
    expect(validateAccountCardEdit(name: '  '), AppStrings.nameRequired);
    expect(validateAccountCardEdit(name: 'علي'), isNull);
  });

  test('edit follows section write, allowedActions, and system cards', () {
    final reader = PermissionService()
      ..applyFromServer(
        ['debts.read'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'read'},
      );
    final writer = PermissionService()
      ..applyFromServer(
        ['debts.read', 'debts.write'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'manage'},
      );
    final admin = PermissionService()..applyFromServer(const [], role: 'admin');
    final card = _card();

    expect(
      canEditAccountCard(
        permissions: reader,
        section: SectionKey.customers,
        card: card,
      ),
      isFalse,
    );
    expect(
      canEditAccountCard(
        permissions: writer,
        section: SectionKey.customers,
        card: card,
      ),
      isTrue,
    );
    expect(
      canEditAccountCard(
        permissions: admin,
        section: SectionKey.customers,
        card: _card(systemManaged: true, allowedActions: const ['edit']),
      ),
      isFalse,
    );
    expect(
      canEditAccountCard(
        permissions: admin,
        section: SectionKey.customers,
        card: _card(allowedActions: const ['pin']),
      ),
      isFalse,
    );
    expect(
      canEditAccountCard(
        permissions: reader,
        section: SectionKey.customers,
        card: _card(allowedActions: const ['edit']),
      ),
      isTrue,
    );
  });

  testWidgets('a reader does not see the edit action on the card', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    expect(find.byKey(const Key('edit-account-card')), findsNothing);

    await go(tester, '/customers/c_55/edit');
    expect(find.byKey(const Key('screen-edit-card-customers')), findsOneWidget);
    expect(find.text(AppStrings.editCardUnavailable), findsOneWidget);
    expect(find.byKey(const Key('save-account-card')), findsNothing);
    expect(find.byKey(const Key('edit-card-name')), findsNothing);
    expectRtl(tester);
  });

  testWidgets('a limited admin with read-only debts does not see edit', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    expect(find.byKey(const Key('edit-account-card')), findsNothing);
    expect(find.byKey(const Key('add-debt')), findsNothing);
  });

  testWidgets('system cards and a record without edit hide the action', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        accountCardProvider.overrideWith(
          (ref, key) async => _card(
            id: key.$2,
            section: key.$1,
            systemManaged: true,
            allowedActions: const ['edit'],
          ),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('edit-account-card')), findsNothing);
    expect(find.byKey(const Key('add-debt')), findsNothing);

    await go(tester, '/customers/c_55/edit');
    expect(find.byKey(const Key('save-account-card')), findsNothing);
    expect(find.text(AppStrings.editCardUnavailable), findsOneWidget);
  });

  testWidgets('an explicit allowedActions list without edit hides the button', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        accountCardProvider.overrideWith(
          (ref, key) async =>
              _card(id: key.$2, section: key.$1, allowedActions: const ['pin']),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies/c_55');
    expect(find.byKey(const Key('screen-ledger-companies')), findsOneWidget);
    expect(find.byKey(const Key('edit-account-card')), findsNothing);
  });

  testWidgets('admin can open edit from each card section', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    for (final section in AccountSection.values) {
      await go(tester, '/${section.path}/c_55');
      expect(find.byKey(const Key('edit-account-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit-account-card')));
      await settle(tester);
      expect(
        find.byKey(Key('screen-edit-card-${section.path}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('edit-card-name')), findsOneWidget);
      expect(find.byKey(const Key('edit-card-phone')), findsOneWidget);
      expect(find.byType(UnitsField), findsNothing);
      expect(find.text(AppStrings.editCardScope), findsOneWidget);
      expectRtl(tester);
      await tester.tap(find.byTooltip(AppStrings.back));
      await settle(tester);
      expect(find.byKey(Key('screen-ledger-${section.path}')), findsOneWidget);
    }
  });

  testWidgets('a blank name does not send, and a retry reuses the request id', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55/edit');

    await tester.enterText(find.byKey(const Key('edit-card-name')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-account-card')));
    await tester.pump();
    expect(find.text(AppStrings.nameRequired), findsOneWidget);
    expect(fake.mutationRequestIds, isEmpty);

    await tester.enterText(
      find.byKey(const Key('edit-card-name')),
      'عميل معدّل',
    );
    await tester.pump();
    fake.failMutationsRemaining = 3;

    final firstBody = await hold(tester, fake, const Key('save-account-card'));
    expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
    expect(firstBody, contains('"expectedVersion":4'));
    expect(firstBody, contains('"name":"عميل معدّل"'));
    expect(firstBody, contains('"phone":"0910000000"'));
    expect(firstBody, isNot(contains('balanceUnits')));
    expect(firstBody, isNot(contains('openingBalance')));
    expect(firstBody, isNot(contains('debtAgeDays')));
    expect(firstBody, isNot(contains('inputValue')));
    final first = fake.mutationRequestIds.single;

    await hold(tester, fake, const Key('save-account-card'));
    expect(fake.mutationRequestIds, [first, first]);

    await tester.enterText(
      find.byKey(const Key('edit-card-phone')),
      '0920000000',
    );
    await tester.pump();
    final changed = await hold(tester, fake, const Key('save-account-card'));
    expect(fake.mutationRequestIds, hasLength(3));
    expect(fake.mutationRequestIds[2], isNot(first));
    expect(changed, contains('"phone":"0920000000"'));
    expect(changed, contains('"expectedVersion":4'));
  });

  testWidgets('a version conflict refreshes the card and shows the message', (
    tester,
  ) async {
    var loads = 0;
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          loads++;
          final fresh = loads > 1;
          return _card(
            id: key.$2,
            section: key.$1,
            name: fresh ? 'بعد التعارض' : 'قبل التعارض',
            phone: fresh ? '0922222222' : '0911111111',
            version: fresh ? 9 : -1,
          );
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/libyan-deposits/c_55/edit');
    expect(find.text('قبل التعارض'), findsWidgets);
    final before = loads;

    final conflictBody = await hold(
      tester,
      fake,
      const Key('save-account-card'),
    );

    expect(find.text(AppStrings.versionConflict), findsOneWidget);
    expect(loads, greaterThan(before));
    expect(find.text('بعد التعارض'), findsWidgets);
    expect(conflictBody, contains('"expectedVersion":-1'));
    expect(conflictBody, isNot(contains('balanceUnits')));
    final conflictId = fake.mutationRequestIds.single;

    final savedBody = await hold(tester, fake, const Key('save-account-card'));
    expect(fake.mutationRequestIds, hasLength(2));
    expect(fake.mutationRequestIds[1], isNot(conflictId));
    expect(savedBody, contains('"expectedVersion":9'));
    expect(savedBody, contains('"name":"بعد التعارض"'));
    expect(savedBody, contains('"phone":"0922222222"'));
    expect(
      find.byKey(const Key('screen-ledger-libyan-deposits')),
      findsOneWidget,
    );
  });

  testWidgets('the edit screen stays RTL on a small phone in both themes', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 640));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/egyptian-deposits/c_55');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('edit-account-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-account-card')));
    await settle(tester);
    expect(
      find.byKey(const Key('screen-edit-card-egyptian-deposits')),
      findsOneWidget,
    );
    expectRtl(tester);
    expect(tester.takeException(), isNull);
    final phone = tester.widget<TextField>(
      find.byKey(const Key('edit-card-phone')),
    );
    expect(phone.textDirection, TextDirection.ltr);

    await _toggleTheme(tester, AppStrings.themeDark);
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
    expectRtl(tester);
    expect(find.byKey(const Key('save-account-card')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _toggleTheme(tester, AppStrings.themeLight);
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.light,
    );
    expectRtl(tester);
    expect(tester.takeException(), isNull);
  });
}

AccountCardDto _card({
  String id = 'c_55',
  AccountSection section = AccountSection.customers,
  String name = 'عميل',
  String? phone = '0910000000',
  int version = 4,
  bool systemManaged = false,
  List<String>? allowedActions,
}) {
  final json = <String, Object?>{
    'id': id,
    'name': name,
    'phone': phone,
    'balanceUnits': 320,
    'version': version,
    'systemManaged': systemManaged,
  };
  if (allowedActions != null) {
    json['allowedActions'] = allowedActions;
  }
  return AccountCardDto.fromJson(json, section);
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

Future<void> _toggleTheme(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(HomeShell.menuKey));
  await settle(tester);
  final item = find.text(label);
  await tester.scrollUntilVisible(
    item,
    80,
    scrollable: find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first,
  );
  await tester.tap(item);
  await settle(tester);
  if (find.byType(Drawer).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await settle(tester);
  }
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
  // A zero-delay fake response can leave a timer that pumpAndSettle missed.
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<String?> hold(WidgetTester tester, FakeApiClient fake, Key key) async {
  final gate = Completer<void>();
  fake.pauseMutations = gate;
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(Duration.zero);
  final body = fake.lastWireBody;
  gate.complete();
  fake.pauseMutations = null;
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
  return body;
}
