import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';
import 'support/phase7_ui.dart';
import 'transaction_correction_test.dart' as correction;

void main() {
  for (final (section, id) in [
    (AccountSection.customers, 'c_55'),
    (AccountSection.companies, 'c_co_02'),
    (AccountSection.libyanDeposits, 'c_55'),
    (AccountSection.egyptianDeposits, 'c_eg_08'),
  ]) {
    testWidgets(
      '${section.path} edits its own endpoint and preserves its currency',
      (tester) async {
        final layer = await pumpFakeApp(tester, size: const Size(430, 932));
        final fake = layer.client as FakeApiClient;
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        final card = await tester.runAsync(
          () => layer.accounts.get(section, id),
        );
        expect(card!.currency, section.currency);
        await go(tester, '/${section.path}/$id');
        await correction.tapCorrect(tester, 'tx_1');
        final row = tester.getRect(find.byKey(const Key('ledger-row-tx_1')));
        expect(row.height, lessThan(150));
        if (section == AccountSection.libyanDeposits ||
            section == AccountSection.egyptianDeposits) {
          expect(
            find.byKey(const Key('correction-payment-mode')),
            findsNothing,
          );
        }
        await correction.enterAmount(tester, '77');
        await correction.closeCorrection(tester, 'tx_1');
        expect(
          fake.mutationBodies,
          isEmpty,
          reason: 'closing the row does not send a transaction',
        );
        await correction.tapCorrect(tester, 'tx_1');
        final amount = tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('correction-amount')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text;
        expect(amount, isNot('77'), reason: 'cancel discarded the local edit');
        await correction.enterAmount(tester, '77');
        await correction.openConfirm(tester);
        await correction.confirmSend(tester, fake);
        await settle(tester);
        expect(fake.mutationPaths, hasLength(1));
        expect(
          fake.mutationPaths.single,
          '/api/${section.path}/$id/transactions/tx_1/corrections',
        );
        final body = jsonDecode(fake.mutationBodies.single) as Map;
        expect(body['inputValue'], 77);
        expect(body['expectedVersion'], card.version);
        expect(body['requestId'], isNotEmpty);
        expect(body['type'], 'debt');
        expect(body['calculationMode'], 'direct');
        expect(
          body.containsKey('rateMicros'),
          isFalse,
          reason: 'no conversion is introduced by shared presentation',
        );
        expect(find.byKey(const Key('correction-form')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
