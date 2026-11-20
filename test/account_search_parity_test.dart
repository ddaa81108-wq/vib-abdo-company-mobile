import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/search/account_search_controller.dart';

import 'support/account_search_recordings.dart';

void main() {
  final path = Platform.environment['SEARCH_PARITY_FIXTURE'];
  // Production recordings stay in a restricted local directory, never Git.
  final cases = path == null
      ? syntheticSearchRecordings()
      : (jsonDecode(File(path).readAsStringSync())['cases'] as List)
            .cast<Map<String, dynamic>>();

  for (var index = 0; index < cases.length; index++) {
    final recording = cases[index];
    testWidgets(
      'server recording #$index: names, amounts and currencies agree in all scopes',
      (tester) async {
        final repository = _RecordedAccounts(recording);
        final all = _controller(repository);
        addTearDown(all.dispose);
        await _readAll(tester, all, recording['query'] as String);
        expect(_values(all.items), _expected(recording));
        expect(repository.cappedSearchCalls, 0);

        for (final section in AccountSection.values) {
          final scoped = _controller(repository)..setScope(section);
          addTearDown(scoped.dispose);
          await _readAll(tester, scoped, recording['query'] as String);
          expect(_values(scoped.items), _expected(recording, section));
          expect(
            _values(all.items.where((item) => item.section == section)),
            _values(scoped.items),
          );
        }
      },
    );
  }

  testWidgets(
    'global paging does not starve deposits or re-request exhausted sections',
    (tester) async {
      final repository = _RecordedAccounts(syntheticSearchRecordings().first);
      final all = _controller(repository);
      addTearDown(all.dispose);
      all.search(repository.recording['query'] as String);
      await tester.pump(AccountSearchController.debounce);
      await tester.pump();
      expect(all.items.length, 120);
      expect(
        all.items
            .where((item) => item.section == AccountSection.egyptianDeposits)
            .length,
        30,
      );
      expect(all.hasMore, isTrue);
      await all.loadMore();
      expect(all.items.length, 168);
      expect(all.hasMore, isFalse);
      expect(repository.calls.length, 8);
      await all.loadMore();
      expect(repository.calls.length, 8);
    },
  );

  testWidgets(
    'global search never requests a section outside the granted scope',
    (tester) async {
      final repository = _RecordedAccounts(syntheticSearchRecordings().first);
      final controller = AccountSearchController(
        repository: () => repository,
        canRead: (section) => section == AccountSection.libyanDeposits,
        currentUserId: () => 'recording-user',
      );
      addTearDown(controller.dispose);
      await _readAll(
        tester,
        controller,
        repository.recording['query'] as String,
      );
      expect(repository.calls.toSet(), {AccountSection.libyanDeposits});
      expect(controller.items.length, 42);
    },
  );
}

AccountSearchController _controller(AccountsRepository repository) =>
    AccountSearchController(
      repository: () => repository,
      canRead: (_) => true,
      currentUserId: () => 'recording-user',
    );

Future<void> _readAll(
  WidgetTester tester,
  AccountSearchController controller,
  String query,
) async {
  controller.search(query);
  await tester.pump(AccountSearchController.debounce);
  await tester.pump();
  expect(controller.busy, isFalse);
  expect(controller.error, isEmpty);
  var pages = 0;
  while (controller.hasMore) {
    await controller.loadMore();
    expect(controller.error, isEmpty);
    expect(++pages, lessThan(100));
  }
}

Map<String, Object?> _values(Iterable<GlobalAccountHit> items) => {
  for (final item in items)
    '${item.section.path}/${item.id}': (
      item.name,
      item.phone,
      item.balanceUnits?.asInt,
      item.currency.code,
    ),
};

Map<String, Object?> _expected(
  Map<String, dynamic> recording, [
  AccountSection? only,
]) => {
  for (final section in AccountSection.values)
    if (only == null || only == section)
      for (final page in recording['responses'][section.path] as List)
        for (final item in page['data']['items'] as List)
          '${section.path}/${item['id']}': (
            item['name'],
            item['phone'],
            item['balanceUnits'],
            item['currency'],
          ),
};

class _RecordedAccounts implements AccountsRepository {
  _RecordedAccounts(this.recording);
  final Map<String, dynamic> recording;
  final calls = <AccountSection>[];
  int cappedSearchCalls = 0;

  @override
  Future<AccountsPage> list(
    AccountSection section, {
    String? cursor,
    int limit = 100,
    String? q,
    String? filter,
  }) async {
    if (q != recording['query'] || limit != 30 || filter != null) {
      throw StateError('Unexpected search request');
    }
    calls.add(section);
    final pages = recording['responses'][section.path] as List;
    final page = pages.firstWhere((dynamic page) => page['cursor'] == cursor);
    return AccountsPage.fromData(page['data'], section);
  }

  @override
  Future<List<GlobalAccountHit>> search(String q) async {
    cappedSearchCalls++;
    throw StateError('Search must use the shared paginated section endpoint');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
