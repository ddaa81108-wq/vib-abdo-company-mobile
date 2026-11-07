import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';
import 'package:vib_abdo_company_mobile/features/collections/phone_dialer.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  test('tel URI keeps the digits and a leading plus', () {
    expect(telUri('091 000-0000').toString(), 'tel:0910000000');
    expect(telUri(' +218 91 000 0000 ').toString(), 'tel:+218910000000');
  });

  Future<List<String>> pumpWithDialer(
    WidgetTester tester, {
    required bool opens,
    required List<String?> clipboard,
  }) async {
    final dialed = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpFakeApp(
      tester,
      size: const Size(430, 2400),
      overrides: [
        phoneDialerProvider.overrideWithValue((phone) async {
          dialed.add(phone);
          return opens;
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    final call = find.byKey(const Key('call-as_1'));
    await tester.ensureVisible(call);
    expect(
      find.descendant(of: call, matching: find.text(CollectionsText.call)),
      findsOneWidget,
    );
    await tester.tap(call);
    await settle(tester);
    return dialed;
  }

  testWidgets('call opens the dialer and copies nothing', (tester) async {
    final clipboard = <String?>[];
    final dialed = await pumpWithDialer(
      tester,
      opens: true,
      clipboard: clipboard,
    );
    expect(dialed, hasLength(1));
    expect(dialed.single, isNotEmpty);
    expect(clipboard, isEmpty);
    expect(find.text(CollectionsText.phoneCopied), findsNothing);
  });

  testWidgets('without a dialer the number is copied', (tester) async {
    final clipboard = <String?>[];
    final dialed = await pumpWithDialer(
      tester,
      opens: false,
      clipboard: clipboard,
    );
    expect(dialed, hasLength(1));
    expect(clipboard, [dialed.single]);
    expect(find.text(CollectionsText.phoneCopied), findsOneWidget);
  });
}
