import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// Assign (التوجيه) against the fake, which mirrors 537f073:
/// `POST /api/collections/assignments` with
/// `{customerIds, assigneeUserId, section}`, answered 201
/// `{assignmentIds, eventSequences}`; one bad card refuses the whole request.
void main() {
  Future<FakeApiClient> openAssign(WidgetTester tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.ensureVisible(find.byKey(const Key('assign-mode')));
    await tester.tap(find.byKey(const Key('assign-mode')));
    await settle(tester);
    return layer.client as FakeApiClient;
  }

  Future<void> tick(WidgetTester tester, String id) async {
    final box = find.byKey(ValueKey('assign-select-$id'));
    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester) async {
    final save = find.byKey(const Key('save-assignment'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
  }

  testWidgets('only cards the server accepts get a checkbox', (tester) async {
    await openAssign(tester);
    // c_55, c_56, c_58: already assigned. c_57: zero. Masraweya: system.
    for (final id in [
      'c_55',
      'c_56',
      'c_57',
      'c_58',
      'c_masraweya_remainder',
    ]) {
      expect(
        find.byKey(ValueKey('assign-select-$id'), skipOffstage: false),
        findsNothing,
        reason: id,
      );
    }
    for (final id in ['c_59', 'c_60', 'c_61', 'c_62', 'c_63']) {
      expect(
        find.byKey(ValueKey('assign-select-$id'), skipOffstage: false),
        findsOneWidget,
        reason: id,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 201 confirms, clears the ticks and refreshes collections', (
    tester,
  ) async {
    final fake = await openAssign(tester);
    await tick(tester, 'c_59');
    await tick(tester, 'c_60');
    expect(find.text(AppStrings.assignSelected(2)), findsOneWidget);
    // The first assignee is chosen by default, like the website.
    final firstId = fake.collectionsEngine.employees.keys.first;
    final firstName = fake.collectionsEngine.employees[firstId]!;

    await press(tester);

    final i = fake.mutationPaths.lastIndexWhere(
      (p) => p.endsWith('/api/collections/assignments'),
    );
    expect(i, isNonNegative);
    final body = jsonDecode(fake.mutationBodies[i]) as Map<String, dynamic>;
    expect(body['customerIds'], ['c_59', 'c_60']);
    expect(body['assigneeUserId'], firstId);
    expect(body['section'], 'customers');

    final done = AppStrings.assignDone(2, firstName);
    expect(find.text(done), findsWidgets);
    expect(find.byKey(const Key('assignee-field')), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byKey(const Key('mutation-error')), findsNothing);
    // The list now shows the assignee on both cards (from the server).
    expect(
      fake.collectionsEngine.activeAssigneeName('customers', 'c_59'),
      firstName,
    );

    await go(tester, '/collections');
    expect(find.text('عميل تجريبي ٥', skipOffstage: false), findsWidgets);
    expect(find.text('عميل تجريبي ٦', skipOffstage: false), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 409 from the server is shown, never swallowed', (
    tester,
  ) async {
    final fake = await openAssign(tester);
    await tick(tester, 'c_61');
    // Someone else assigns the same card first (website or another phone).
    fake.collectionsEngine.assign({
      'customerIds': ['c_61'],
      'assigneeUserId': fake.collectionsEngine.employees.keys.last,
      'section': 'customers',
    });
    await press(tester);

    const message = 'أحد الكروت محدد لموظف بالفعل.';
    expect(
      tester.widget<Text>(find.byKey(const Key('mutation-error'))).data,
      contains(message),
    );
    expect(find.byKey(const Key('assign-snackbar')), findsOneWidget);
    // Still in assign mode with the tick kept, so the user can change it.
    expect(find.byKey(const Key('assignee-field')), findsOneWidget);
    expect(find.text(AppStrings.assignSelected(1)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pressing assign with no card says so', (tester) async {
    await openAssign(tester);
    await press(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('mutation-error'))).data,
      AppStrings.chooseAssignCards,
    );
    expect(find.byKey(const Key('assign-snackbar')), findsOneWidget);
  });
}
