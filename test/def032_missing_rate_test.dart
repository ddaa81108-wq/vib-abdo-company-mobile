import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vib_abdo_company_mobile/features/treasury/treasury_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// DEF-032. Real treasury screen and [treasuryProvider].
/// Transport is [FakeApiClient] only.
///
/// The rendered EGP line is [MoneyFormatter] of the server integer, nothing else.
/// QA's skipped phase-8 test stays on their branch.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'DEF-032 explicit null rate keeps the server EGP text in light and dark',
    (tester) async {
      await _runMissingRate(
        tester,
        configure: (fake) {
          fake.treasuryTotalsPatch = const <String, Object?>{
            'egyptianRate': null,
          };
        },
        expectWire: (wire) {
          expect(wire, contains('"egyptianRate":null'));
          expect(wire, contains('"egyptianSourceUnits":95000'));
          expect(wire, contains('"egyptianConvertedUnits":10000'));
        },
      );
    },
  );

  testWidgets(
    'DEF-032 absent rate field keeps the server EGP text in light and dark',
    (tester) async {
      await _runMissingRate(
        tester,
        configure: (fake) {
          fake.omitTreasuryTotalKeys.add('egyptianRate');
        },
        expectWire: (wire) {
          expect(wire, isNot(contains('egyptianRate')));
          expect(wire, contains('"egyptianSourceUnits":95000'));
          expect(wire, contains('"egyptianConvertedUnits":10000'));
        },
      );
    },
  );

  testWidgets(
    'DEF-032 a present rate shows both server amounts in light and dark',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
      final fake = layer.client as FakeApiClient;
      // 95,000 / 9.5 would be 10,000. The stored converted figure is different.
      fake.treasuryTotalsPatch = const <String, Object?>{
        'egyptianConvertedUnits': 11111,
      };
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/treasury');

      for (final dark in const [false, true]) {
        if (dark) await _switchToDark(tester);
        _expectLocaleAndDirection(tester, dark: dark);

        final summary = _loadedSummary(tester);
        final money = layer.money;
        expect(summary.egyptianRate?.value, '9.5');
        expect(summary.rateMissing, isFalse);
        expect(summary.egyptianSourceUnits, 95000);
        expect(summary.egyptianConvertedUnits, 11111);

        final wire = fake.lastTreasuryJson;
        expect(wire, isNotNull);
        expect(wire, contains('"egyptianRate":"9.5"'));
        expect(wire, contains('"egyptianConvertedUnits":11111'));
        expect(wire, isNot(contains('"egyptianConvertedUnits":10000')));

        final source = money.format(summary.egyptianSourceUnits!, Currency.egp);
        final converted = money.format(
          summary.egyptianConvertedUnits!,
          Currency.lyd,
        );
        final rate = money.formatDecimal(summary.egyptianRate!);
        expect(source, '95,000 ج.م');
        expect(converted, '11,111 د.ل');
        expect(rate, '9.5');

        final sourceText = _amountText(
          tester,
          AppStrings.egyptianSource,
          source,
        );
        final convertedText = _amountText(
          tester,
          AppStrings.converted,
          converted,
        );
        expect(sourceText.data, source);
        expect(sourceText.data, '95,000 ج.م');
        expect(convertedText.data, converted);
        expect(convertedText.data, '11,111 د.ل');
        expect(
          _labeled(TreasuryScreen.screenKey, AppStrings.rate, rate),
          findsOneWidget,
        );
        expect(_inside(TreasuryScreen.screenKey, '10,000 د.ل'), findsNothing);
        expect(_inside(TreasuryScreen.screenKey, '95,000 د.ل'), findsNothing);
        expect(_inside(TreasuryScreen.screenKey, '11,111 ج.م'), findsNothing);
        expect(find.byKey(const Key('rate-missing')), findsNothing);
        expect(find.text(AppStrings.rateMissing), findsNothing);
        _expectCashColorUnchanged(tester);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _runMissingRate(
  WidgetTester tester, {
  required void Function(FakeApiClient fake) configure,
  required void Function(String wire) expectWire,
}) async {
  final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
  final fake = layer.client as FakeApiClient;
  configure(fake);
  await signIn(tester, username: 'admin.demo', password: 'demo-only');
  await go(tester, '/treasury');

  for (final dark in const [false, true]) {
    if (dark) await _switchToDark(tester);
    _expectLocaleAndDirection(tester, dark: dark);

    final summary = _loadedSummary(tester);
    expect(summary.egyptianRate, isNull);
    expect(summary.rateMissing, isTrue);
    expect(summary.egyptianSourceUnits, 95000);
    expect(summary.egyptianConvertedUnits, 10000);

    final wire = fake.lastTreasuryJson;
    expect(wire, isNotNull);
    expectWire(wire!);

    final source = layer.money.format(
      summary.egyptianSourceUnits!,
      Currency.egp,
    );
    final converted = layer.money.format(
      summary.egyptianConvertedUnits!,
      Currency.lyd,
    );
    expect(source, '95,000 ج.م');
    expect(converted, '10,000 د.ل');

    final sourceText = _amountText(tester, AppStrings.egyptianSource, source);
    expect(sourceText.data, source);
    expect(sourceText.data, '95,000 ج.م');
    expect(
      _labeled(TreasuryScreen.screenKey, AppStrings.rate, AppStrings.dash),
      findsOneWidget,
    );

    final card = _egyptianCard();
    expect(_insideCard(card, converted), findsNothing);
    expect(_insideCard(card, AppStrings.converted), findsNothing);
    expect(_insideCard(card, '0'), findsNothing);
    expect(_insideCard(card, '0 د.ل'), findsNothing);
    expect(_insideCard(card, '0 ج.م'), findsNothing);
    expect(_insideCard(card, '10,000'), findsNothing);
    expect(
      find.descendant(of: card, matching: find.textContaining('د.ل')),
      findsNothing,
    );

    final note = tester.widget<Text>(
      find.descendant(of: card, matching: find.text(AppStrings.rateMissing)),
    );
    expect(note.data, 'يلزم سعر تحويل معتمد');
    expect(find.byKey(const Key('rate-missing')), findsOneWidget);
    final noteContext = tester.element(
      find.descendant(of: card, matching: find.text(AppStrings.rateMissing)),
    );
    expect(
      note.style?.color,
      Theme.of(noteContext).colorScheme.onErrorContainer,
    );

    expect(
      find.descendant(of: card, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(TextButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(ElevatedButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(IconButton)),
      findsNothing,
    );
    _expectCashColorUnchanged(tester);
    expect(tester.takeException(), isNull);
  }
}

Future<void> _switchToDark(WidgetTester tester) async {
  await tester.ensureVisible(find.byTooltip(AppStrings.themeDark));
  await tester.tap(find.byTooltip(AppStrings.themeDark));
  await settle(tester);
}

void _expectLocaleAndDirection(WidgetTester tester, {required bool dark}) {
  final context = tester.element(find.byKey(TreasuryScreen.screenKey));
  expect(Directionality.of(context), TextDirection.rtl);
  expect(Localizations.localeOf(context), const Locale('ar', 'LY'));
  expect(
    Theme.of(context).brightness,
    dark ? Brightness.dark : Brightness.light,
  );
}

void _expectCashColorUnchanged(WidgetTester tester) {
  final cash = tester.widget<Card>(find.byKey(const Key('active-cash-card')));
  expect(cash.color, AppStatusColors.light.cashPositive);
  expect(cash.color, AppStatusColors.dark.cashPositive);
  expect(cash.color, const Color(0xFF087A50));
}

TreasurySummaryDto _loadedSummary(WidgetTester tester) {
  final context = tester.element(find.byKey(TreasuryScreen.screenKey));
  return ProviderScope.containerOf(context).read(treasuryProvider).requireValue;
}

Finder _egyptianCard() {
  return find
      .ancestor(
        of: find.text(AppStrings.egyptianTransfers),
        matching: find.byType(Card),
      )
      .first;
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}

Finder _insideCard(Finder card, String text) {
  return find.descendant(of: card, matching: find.text(text));
}

Finder _labeled(Key screen, String label, String value) {
  final row = find
      .ancestor(
        of: find.descendant(of: find.byKey(screen), matching: find.text(label)),
        matching: find.byType(Row),
      )
      .first;
  return find.descendant(of: row, matching: find.text(value));
}

Text _amountText(WidgetTester tester, String label, String value) {
  return tester.widget<Text>(_labeled(TreasuryScreen.screenKey, label, value));
}
