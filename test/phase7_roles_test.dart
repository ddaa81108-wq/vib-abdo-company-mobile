import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

/// P7-05. Each role starts on the login form. The rail is whatever
/// [PermissionService.visibleSections] built from the session the Fake
/// returned. No provider under test is replaced.
void main() {
  testWidgets('P7-05 admin sees every section and settings', (tester) async {
    await _signIn(tester, 'admin.demo');
    _expectIdentity('مدير تجريبي', AppStrings.roleAdmin);
    _expectSections(SectionKey.values, settings: true);
    expect(find.text(AppStrings.noSections), findsNothing);
    expect(
      find.byKey(HomeShell.writeKey(SectionKey.reports), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('P7-05 limited admin sees customers and collections only', (
    tester,
  ) async {
    await _signIn(tester, 'limited.admin.demo');
    _expectIdentity('إداري محدود تجريبي', AppStrings.roleAdmin);
    _expectSections(const [
      SectionKey.customers,
      SectionKey.collections,
    ], settings: false);
  });

  testWidgets('P7-05 collector sees collections only', (tester) async {
    await _signIn(tester, 'employee.demo');
    _expectIdentity('موظف استلام تجريبي', AppStrings.roleEmployee);
    _expectSections(const [SectionKey.collections], settings: false);
  });

  testWidgets('P7-05 guest sees no sections despite the codes on the user', (
    tester,
  ) async {
    await _signIn(tester, 'guest.demo');
    _expectIdentity('دور غير معروف', AppStrings.roleUnknown);
    _expectSections(const [], settings: false);
    expect(find.text(AppStrings.noSections), findsOneWidget);
  });

  testWidgets('P7-05 flag admin with fullAccess false sees no sections', (
    tester,
  ) async {
    await _signIn(tester, 'flag.admin.demo');
    _expectIdentity('إداري بعلم صريح', AppStrings.roleAdmin);
    _expectSections(const [], settings: false);
    expect(find.text(AppStrings.noSections), findsOneWidget);
  });
}

Future<void> _signIn(WidgetTester tester, String username) async {
  await pumpFakeApp(tester, size: const Size(800, 1600));
  expect(find.byKey(const Key('login-screen')), findsOneWidget);
  await signIn(tester, username: username, password: 'demo-only');
  expect(find.byKey(const Key('login-screen')), findsNothing);
  expect(find.byKey(HomeShell.shellKey), findsOneWidget);
}

void _expectIdentity(String displayName, String role) {
  expect(find.text(displayName), findsWidgets);
  expect(testerWidget(HomeShell.roleKey), role);
  expect(
    find.byKey(const Key('rail-home'), skipOffstage: false),
    findsOneWidget,
  );
  expect(
    find.byKey(const Key('rail-account'), skipOffstage: false),
    findsOneWidget,
  );
}

String testerWidget(Key key) {
  return (find.byKey(key).evaluate().single.widget as Text).data!;
}

void _expectSections(List<SectionKey> visible, {required bool settings}) {
  for (final section in SectionKey.values) {
    expect(
      find.byKey(Key('rail-${section.key}'), skipOffstage: false),
      visible.contains(section) ? findsOneWidget : findsNothing,
      reason: section.key,
    );
  }
  expect(
    find.byKey(const Key('rail-settings'), skipOffstage: false),
    settings ? findsOneWidget : findsNothing,
  );
}
