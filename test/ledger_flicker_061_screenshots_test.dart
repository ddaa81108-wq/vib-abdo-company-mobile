import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  testWidgets('061 after frames stay on the same rows', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(390, 844),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    await tester.pump(const Duration(milliseconds: 200));
    final scrollable = find.descendant(
      of: find.byKey(const Key('ledger-entries-list')),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable);
    state.position.jumpTo(40);
    await tester.pump();
    await saveShot(tester, 'fix061-after-1');
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('screen-ledger-customers'))),
    ).invalidate(
      ledgerProvider((
        AccountSection.customers,
        FakeLargeCatalog.longLedgerAccountId,
      )),
    );
    await tester.pump();
    await saveShot(tester, 'fix061-after-2');
    await tester.pump(const Duration(milliseconds: 80));
    await saveShot(tester, 'fix061-after-3');
    expect(state.position.pixels, 40);
  }, tags: const ['screenshots']);
}
