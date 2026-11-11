import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Approves or rejects every seeded receipt and marks the approved cash
/// received, so a normal close is what the server accepts.
Future<void> _settle(ApiLayer layer) async {
  await layer.collections.decide(
    'sb_1',
    CollectionDecision.approve,
    meta: MutationMeta(requestId: 'close-approve-sb1'),
  );
  await layer.collections.markCashReceived(
    'sb_1',
    MutationMeta(requestId: 'close-cash-sb1'),
  );
  await layer.collections.markCashReceived(
    'sb_2',
    MutationMeta(requestId: 'close-cash-sb2'),
  );
  await layer.collections.decide(
    'sb_9',
    CollectionDecision.reject,
    meta: MutationMeta(requestId: 'close-reject-sb9'),
  );
  await layer.collections.decideUnlinked(
    'ur_1',
    decision: CollectionDecision.reject,
    meta: MutationMeta(requestId: 'close-reject-ur1'),
  );
  await layer.collections.decideUnlinked(
    'ur_9',
    decision: CollectionDecision.reject,
    meta: MutationMeta(requestId: 'close-reject-ur9'),
  );
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a settled batch closes and the next overview drops it', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await tester.runAsync(() => _settle(layer));
    await go(tester, '/collections');

    await tester.tap(find.byKey(const Key('close-batch')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(CollectionsText.closeDialogTitle), findsOneWidget);
    expect(find.text(CollectionsText.closeConfirm), findsOneWidget);
    expect(find.byKey(const Key('close-batch-pending')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-close-batch')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('confirm-close-batch')));
    await _flush(tester);

    final body = jsonDecode(
      fake.mutationBodies.lastWhere((raw) => raw.contains('"confirmed"')),
    ) as Map<String, dynamic>;
    expect(body['batchId'], 'b_1');
    expect(body['confirmed'], true);
    expect(body.containsKey('allowOutstandingCash'), isFalse);

    final after = await tester.runAsync(() => layer.collections.overview());
    expect(after!.openBatches.where((batch) => batch.id == 'b_1'), isEmpty);
    expect(after.assignments.where((card) => card.batchId == 'b_1'), isEmpty);
    expect(find.text(CollectionsText.closeDialogTitle), findsNothing);
    expect(find.byKey(const Key('close-batch-error')), findsNothing);
    expect(find.text(CollectionsText.noOpenBatches), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a server refusal stays in the dialog in Arabic', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await tester.runAsync(() => _settle(layer));
    await go(tester, '/collections');
    await tester.tap(find.byKey(const Key('close-batch')));
    await tester.pump(const Duration(milliseconds: 300));

    const message =
        'لا يمكن مسح اليوم قبل اعتماد جميع العمليات واستلام كل النقدية.';
    fake.failNextResponse = (
      status: 409,
      code: 'COLLECTION_DAY_NOT_SETTLED',
      message: message,
    );
    await tester.tap(find.byKey(const Key('confirm-close-batch')));
    await _flush(tester);

    expect(find.text(CollectionsText.closeDialogTitle), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.byKey(const Key('close-batch-error')), findsOneWidget);
    final after = await tester.runAsync(() => layer.collections.overview());
    expect(after!.openBatches.where((batch) => batch.id == 'b_1'), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close dialog and the cleared batch on a phone', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    await tester.runAsync(loadScreenshotFonts);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await tester.runAsync(() => _settle(layer));
    await go(tester, '/collections');
    await tester.tap(find.byKey(const Key('close-batch')));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    await saveShot(tester, 'collections-close-dialog');

    await tester.tap(find.byKey(const Key('confirm-close-batch')));
    await _flush(tester);
    await saveShot(tester, 'collections-close-result');
  }, tags: const ['screenshots']);
}
