import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// P7-12. Approve and reject go through the collections screen buttons and
/// the real collections repository. The limited-admin case is not here: it
/// is pending DEF-002 and is not a Pass.
void main() {
  testWidgets('P7-12 admin approves one submission and rejects another', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    // 537f073 words: an approved row without cash reads "awaiting cash".
    final awaitingBefore = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('awaiting-cash-'),
        )
        .evaluate()
        .length;
    final approve = find.byKey(const Key('approve-sb_1'));
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await settle(tester);

    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    expect(find.byKey(const ValueKey('awaiting-cash-sb_1')), findsOneWidget);
    expect(
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('awaiting-cash-'),
          )
          .evaluate()
          .length,
      awaitingBefore + 1,
    );

    final reject = find.byKey(const Key('reject-sb_9'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await settle(tester);

    expect(find.byKey(const Key('reject-sb_9')), findsNothing);

    final overview = await tester.runAsync(() => layer.collections.overview());
    expect(
      overview!.submissions.firstWhere((row) => row.id == 'sb_1').status,
      'approved',
    );
    expect(
      overview.submissions.firstWhere((row) => row.id == 'sb_9').status,
      'rejected',
    );
    // The screen hides a second decision. Another decision is a 409 once the
    // row is no longer pending.
  });

  testWidgets('P7-12 a changed status is a conflict and the list refreshes', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await tester.runAsync(
      () => layer.collections.decide(
        'sb_9',
        CollectionDecision.approve,
        meta: MutationMeta(),
      ),
    );

    final reject = find.byKey(const Key('reject-sb_9'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await settle(tester);

    expect(
      find.text(FakeApiClient.submissionAlreadyDecidedMessage),
      findsWidgets,
    );
    expect(find.byKey(const Key('reject-sb_9')), findsNothing);

    final overview = await tester.runAsync(() => layer.collections.overview());
    expect(
      overview!.submissions.firstWhere((row) => row.id == 'sb_9').status,
      'approved',
    );
  });
}
