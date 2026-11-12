import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

/// Before/after shots for 065 and 066. The name prefix is the only switch.
const _shot = String.fromEnvironment('FIX065_SHOT', defaultValue: 'after');

void main() {
  testWidgets('065 066 cards and routing at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    final cards = [
      _card(
        'long',
        'مجموعه عصام الشوادفي',
        balance: 2198,
        days: 1,
        assignee: 'الصفير',
      ),
      _card('debt', 'عميل تجريبي', balance: 320, days: 4),
      _card('trust', 'أمانة طويلة الاسم للتجربة', balance: -80, days: 0),
      _card('zero', 'حساب مغلق', balance: 0, days: 0),
    ];
    await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      overrides: [
        accountsProvider.overrideWith((ref, section) async {
          return AccountsPage(
            page: Paged(items: cards),
            summary: const AccountsSummaryDto(activeCards: 4),
          );
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.pump(const Duration(milliseconds: 50));
    await saveShot(tester, 'fix065067-cards-$_shot');

    await tester.ensureVisible(find.byKey(const Key('assign-mode')));
    await tester.tap(find.byKey(const Key('assign-mode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('account-card-debt')));
    await tester.pump();
    await saveShot(tester, 'fix065067-route-customers-$_shot');

    await go(tester, '/companies');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.ensureVisible(find.byKey(const Key('assign-mode')));
    await tester.tap(find.byKey(const Key('assign-mode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('account-card-debt')));
    await tester.pump();
    await saveShot(tester, 'fix065067-route-companies-$_shot');
  }, tags: const ['screenshots']);
}

AccountCardDto _card(
  String id,
  String name, {
  required int balance,
  required int days,
  String? assignee,
}) {
  return AccountCardDto(
    id: id,
    name: name,
    balanceUnits: MoneyValue.known(balance),
    currency: Currency.lyd,
    activeAssigneeName: assignee,
    lastActivityAt: DateTime(2026, 10, 18, 14, 3),
    debtAgeDays: days,
    version: 1,
  );
}
