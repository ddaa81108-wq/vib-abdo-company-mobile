import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/performance/history_window.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

/// Approved by Ali on 2026-10-22, enabled by default.
/// A test can still set [HistoryWindow.trimEnabled] false.
void main() {
  tearDown(() {
    HistoryWindow.trimEnabled = HistoryWindow.trimEnabledFromEnvironment;
  });

  test('HISTORY_WINDOW_TRIM is on by default and can be turned off', () {
    expect(HistoryWindow.trimEnabledFromEnvironment, isTrue);
    expect(HistoryWindow.trimEnabled, isTrue);
    HistoryWindow.trimEnabled = false;
    expect(HistoryWindow.trimEnabled, isFalse);
  });

  test('account extras keep every loaded row when trim is off', () async {
    HistoryWindow.trimEnabled = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const section = AccountSection.customers;
    final sub = container.listen(accountExtraCardsProvider(section), (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(
      accountExtraCardsProvider(section).notifier,
    );
    final cards = [for (var i = 0; i < 100; i++) _card('c_$i')];
    notifier.append(cards, nextCursor: 'o:100');
    expect(container.read(accountExtraCardsProvider(section)), hasLength(100));
    expect(notifier.cursorAfter(null), 'o:100');
  });

  test('account extras keep the last 80 rows when trim is on', () {
    HistoryWindow.trimEnabled = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const section = AccountSection.customers;
    final sub = container.listen(accountExtraCardsProvider(section), (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(
      accountExtraCardsProvider(section).notifier,
    );
    notifier.append(
      [for (var i = 0; i < 100; i++) _card('c_$i')],
      nextCursor: 'o:100',
      retainLimit: HistoryWindow.trimEnabled ? HistoryWindow.retainLimit : null,
    );
    final kept = container.read(accountExtraCardsProvider(section));
    expect(kept, hasLength(HistoryWindow.retainLimit));
    expect(kept.first.id, 'c_20');
    expect(kept.last.id, 'c_99');
  });
}

AccountCardDto _card(String id) {
  return AccountCardDto(
    id: id,
    name: id,
    balanceUnits: 1,
    currency: Currency.lyd,
  );
}
