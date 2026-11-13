import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchase_preview.dart';

import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  test('nearest divide matches the website exchange result', () {
    expect(
      convertedWholeUnits(
        value: 10000,
        rateMicros: positiveRateMicros('9.5')!,
        multiply: false,
      ),
      1053,
    );
    expect(
      convertedWholeUnits(
        value: 9,
        rateMicros: positiveRateMicros('2')!,
        multiply: false,
      ),
      5,
    );
    expect(
      convertedWholeUnits(
        value: 10,
        rateMicros: positiveRateMicros('2.5')!,
        multiply: true,
      ),
      25,
    );
  });

  test('a blank new row previews the open-day total', () {
    expect(
      purchasePreviewBalance(
        before: 2553,
        valueText: '',
        rateText: '',
        paidText: '',
        multiply: false,
      ),
      2553,
    );
  });

  test('typing adds result minus paid onto the balance before the row', () {
    expect(
      purchasePreviewBalance(
        before: 2553,
        valueText: '1000',
        rateText: '10',
        paidText: '',
        multiply: false,
      ),
      2653,
    );
    expect(
      purchaseDraftResult(valueText: '1000', rateText: '10', multiply: false),
      100,
    );
  });

  test('an unusable payment or a missing anchor is a dash', () {
    expect(
      purchasePreviewBalance(
        before: 2553,
        valueText: '1000',
        rateText: 'nope',
        paidText: '1.5',
        multiply: false,
      ),
      isNull,
    );
    expect(
      purchasePreviewBalance(
        before: null,
        valueText: '1000',
        rateText: '10',
        paidText: '0',
        multiply: false,
      ),
      isNull,
    );
  });

  test('an unusable rate previews before minus paid, as the website does', () {
    expect(
      purchasePreviewBalance(
        before: 2553,
        valueText: '1000',
        rateText: 'nope',
        paidText: '20',
        multiply: false,
      ),
      2533,
    );
  });

  testWidgets('the new row previews الباقي while typing', (tester) async {
    await pumpFakeApp(tester, size: const Size(1280, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(
      tester
          .widget<Text>(find.byKey(const Key('purchase-preview-balance')))
          .data,
      '2,553',
    );
    await tester.enterText(
      find.byKey(const Key('purchase-field-value')),
      '1000',
    );
    await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('purchase-preview-result')))
          .data,
      '100',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('purchase-preview-balance')))
          .data,
      '2,653',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a partial page names the first carry as prior shown balance', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(1280, 980));
    (layer.client as FakeApiClient).purchaseFirstNextBefore = 11;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-prior-row')),
      40,
      scrollable: find.descendant(
        of: find.byKey(const Key('screen-purchases')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    expect(find.text('الرصيد السابق للمعاملات المعروضة'), findsOneWidget);
    expect(find.text('الباقي المرحّل من اليوم السابق'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('purchase-prior-balance')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '2,000',
    );
    expect(tester.takeException(), isNull);
  });
}
