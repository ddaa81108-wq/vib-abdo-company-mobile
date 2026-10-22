import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// P7-25 dataset. Rows come from [FakeApiClient], not a hand-built list.
/// The walk keeps one page at a time.
void main() {
  test('P7-25 large ledger is 20 pages and a short card stays short', () async {
    final api = _large();
    await _login(api, 'admin.demo');

    final pages = await _walkLedger(api, FakeLargeCatalog.longLedgerAccountId);
    expect(pages, FakeLargeCatalog.ledgerPageCount);
    expect(pages, 20);

    final other = await api.get(
      '/api/customers/lc_00001/ledger',
      query: const {'limit': 100},
    );
    final shortItems = (other.data as Map)['items'] as List;
    expect(shortItems.length, lessThan(5));
    expect(shortItems.length, isNot(FakeLargeCatalog.ledgerLineCount));
  });

  test('P7-25 customer and company pages cover the catalog without storing it',
      () async {
    final api = _large();
    await _login(api, 'admin.demo');

    final customers = await _walkCursor(
      api,
      '/api/customers',
      expected: FakeLargeCatalog.customerCount,
    );
    final companies = await _walkCursor(
      api,
      '/api/companies',
      expected: FakeLargeCatalog.companyCount,
    );
    expect(customers, 100);
    expect(companies, 50);

    final first = (await api.get(
      '/api/customers',
      query: const {'limit': 100},
    ))
        .data as Map;
    final again = (await api.get(
      '/api/customers',
      query: const {'limit': 100},
    ))
        .data as Map;
    expect((first['items'] as List).first['id'], 'lc_00000');
    expect((again['items'] as List).first['id'], 'lc_00000');
    expect((first['items'] as List).length, FakeLargeCatalog.pageSize);
    expect((first['summary'] as Map)['netBalance'], 12800000);
    expect((first['summary'] as Map)['activeCards'], 4000);
    expect((first['items'] as List).first['name'], isNot(contains('تجريبي')));
  });

  test('P7-25 collections and notifications page to a known last page',
      () async {
    final admin = _large();
    await _login(admin, 'admin.demo');
    final collectionPages = await _walkCursor(
      admin,
      '/api/collections',
      expected: FakeLargeCatalog.collectionCount,
      itemsKey: 'assignments',
    );
    expect(collectionPages, 75);

    final employee = _large();
    await _login(employee, 'employee.demo');
    final own = await _walkCursor(
      employee,
      '/api/collections',
      expected: FakeLargeCatalog.collectionCount ~/ 2,
      itemsKey: 'assignments',
    );
    expect(own, 38);

    final notices = await _walkBefore(admin);
    expect(notices, 75);
    final unread = (await admin.get(
      '/api/notifications/unread-count',
    ))
        .data as Map;
    expect(unread['unreadCount'], FakeLargeCatalog.notificationUnreadLiteral);

    final firstId =
        (((await admin.get('/api/notifications')).data as Map)['items'] as List)
            .first['id'];
    final marked = (await admin.patch(
      '/api/notifications/$firstId/read',
    ))
        .data as Map;
    expect(marked['unreadCount'], 1499);
    final all = (await admin.post('/api/notifications/read-all')).data as Map;
    expect(all['unreadCount'], 0);
  });

  test('standard dataset and an unknown name stay unchanged', () async {
    final standard = FakeApiClient(latency: Duration.zero);
    await _login(standard, 'admin.demo');
    final page = (await standard.get('/api/customers')).data as Map;
    expect((page['items'] as List).length, lessThan(24));
    expect(
      (page['items'] as List).any((item) => item['id'] == 'lc_00000'),
      isFalse,
    );
    expect(
      () => FakeApiClient(latency: Duration.zero, dataset: 'huge'),
      throwsArgumentError,
    );
  });

  test('a bad cursor is an empty page, not the whole catalog', () async {
    final page = FakeLargeCatalog.accountPage(
      section: 'customers',
      cursor: 'not-a-cursor',
      limit: 40,
    );
    expect(page['items'], isEmpty);
    expect(page['nextCursor'], isNull);
  });
}

FakeApiClient _large() =>
    FakeApiClient(latency: Duration.zero, dataset: FakeDataset.large);

Future<void> _login(FakeApiClient api, String username) async {
  final response = await api.post(
    '/api/auth/login',
    body: {'username': username, 'password': 'demo-only'},
  );
  expect(response.statusCode, 200);
}

Future<int> _walkLedger(FakeApiClient api, String id) async {
  String? before;
  var pages = 0;
  var seen = 0;
  final ids = <String>{};
  while (true) {
    final data = (await api.get(
      '/api/customers/$id/ledger',
      query: {'limit': 100, 'before': before},
    ))
        .data as Map;
    final items = data['items'] as List;
    expect(items.length, lessThanOrEqualTo(FakeLargeCatalog.pageSize));
    expect(items, isNotEmpty);
    for (final item in items) {
      final lineId = (item as Map)['id'] as String;
      expect(
        ids.add(lineId),
        isTrue,
        reason: 'duplicate ledger id $lineId on page ${pages + 1}',
      );
    }
    seen += items.length;
    pages++;
    expect(pages, lessThanOrEqualTo(FakeLargeCatalog.ledgerPageCount));
    before = data['nextBefore'] as String?;
    if (before == null) break;
  }
  expect(seen, FakeLargeCatalog.ledgerLineCount);
  expect(ids, {
    for (var index = 0; index < FakeLargeCatalog.ledgerLineCount; index++)
      'ltx_${index.toString().padLeft(5, '0')}',
  });
  return pages;
}

Future<int> _walkCursor(
  FakeApiClient api,
  String path, {
  required int expected,
  String itemsKey = 'items',
}) async {
  String? cursor;
  var pages = 0;
  var seen = 0;
  while (true) {
    final data = (await api.get(
      path,
      query: {'limit': 100, 'cursor': cursor},
    ))
        .data as Map;
    final items = data[itemsKey] as List;
    expect(items.length, lessThanOrEqualTo(FakeLargeCatalog.pageSize));
    if (items.isEmpty && pages > 0) break;
    expect(items, isNotEmpty);
    seen += items.length;
    pages++;
    expect(pages, lessThan(200));
    final next = data['nextCursor'] as String?;
    if (next == null || next.isEmpty) break;
    expect(next, isNot(cursor));
    cursor = next;
  }
  expect(seen, expected);
  return pages;
}

Future<int> _walkBefore(FakeApiClient api) async {
  String? before;
  var pages = 0;
  var seen = 0;
  while (true) {
    final data = (await api.get(
      '/api/notifications',
      query: {'before': before},
    ))
        .data as Map;
    final items = data['items'] as List;
    expect(items.length, lessThanOrEqualTo(FakeLargeCatalog.pageSize));
    expect(items, isNotEmpty);
    seen += items.length;
    pages++;
    expect(pages, lessThan(200));
    before = data['nextBefore'] as String?;
    if (before == null) break;
  }
  expect(seen, FakeLargeCatalog.notificationCount);
  return pages;
}
