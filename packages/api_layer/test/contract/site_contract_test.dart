/// Contract tests for the website staging samples.
///
/// Samples are `docs/api/evidence/api-samples.json` on main. `csrfToken` is the
/// placeholder `<session-csrf-token>`. There is no password, cookie, or bearer
/// token. Transport is [FakeApiClient] (one scripted GET). Parsing is the real
/// repository and DTO path. Historical non-executing placeholders were replaced
/// by references to current regression suites and explicit evidence limits in
/// docs/qa/current-financial-coverage.md. Collections parsing has its own active
/// p03_collections_contract_test.dart suite; purchase parsing is exercised here.
@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';
import 'package:flutter_api_layer/data/repositories/collections_repository.dart';
import 'package:flutter_api_layer/data/repositories/masraweya_repository.dart';
import 'package:flutter_api_layer/data/repositories/notifications_repository.dart';
import 'package:flutter_api_layer/data/repositories/purchases_repository.dart';
import 'package:flutter_api_layer/data/repositories/reports_repository.dart';
import 'package:flutter_api_layer/data/repositories/treasury_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _money = MoneyFormatter();

void main() {
  final samples = _loadSamples();

  test('the fixture csrf token is the documented placeholder', () {
    final login = _entry(samples, 'login');
    final data = (login['body'] as Map)['data'] as Map;
    expect(data['csrfToken'], '<session-csrf-token>');
    final text =
        File('../../docs/api/evidence/api-samples.json').readAsStringSync();
    expect(text.contains('Bearer '), isFalse);
    expect(text.contains('mustChangePassword'), isTrue);
    expect(RegExp(r'"password"\s*:').hasMatch(text), isFalse);
  });

  test('section lists keep integer money, currency, and null phones', () async {
    final api = await _session();
    final repo = RemoteAccountsRepository(api);
    const cases = <(String, AccountSection)>[
      ('GET /api/customers', AccountSection.customers),
      ('GET /api/companies', AccountSection.companies),
      ('GET /api/libyan-deposits', AccountSection.libyanDeposits),
      ('GET /api/egyptian-deposits', AccountSection.egyptianDeposits),
    ];
    for (final (key, section) in cases) {
      final raw = _data(samples, key);
      api.scriptedGetJson['/api/${section.path}'] = jsonEncode(raw);
      final page = await repo.list(section);
      final summary = raw['summary'] as Map;
      expect(page.summary.totalDebtUnits?.asInt, summary['totalDebt'],
          reason: key);
      expect(page.summary.netBalanceUnits?.asInt, summary['netBalance'],
          reason: key);
      expect(page.totalItems, raw['totalItems'], reason: key);
      final items = (raw['items'] as List).cast<Map>();
      expect(page.page.items.length, items.length, reason: key);
      for (var i = 0; i < items.length; i++) {
        final card = page.page.items[i];
        final row = items[i];
        expect(card.balanceUnits?.isValid, isTrue, reason: key);
        expect(card.balanceUnits?.asInt, row['balanceUnits'], reason: key);
        expect(card.currency.code, row['currency'], reason: key);
        expect(card.phone, isNull, reason: '${row['name']}');
        expect(
          _money.format(card.balanceUnits!.asInt!, card.currency),
          '${_grouped(row['balanceUnits'] as int)} ${card.currency.symbol}',
          reason: key,
        );
      }
    }
  });

  test('the customer ledger keeps the opening integer and a null rate',
      () async {
    final api = await _session();
    final raw = _data(samples, 'initialLedger');
    api.scriptedGetJson[
            '/api/customers/0850d816-6dc0-4d85-b46f-fb0a6ef1cb11/ledger'] =
        jsonEncode(raw);
    final page = await RemoteAccountsRepository(api).ledger(
      AccountSection.customers,
      '0850d816-6dc0-4d85-b46f-fb0a6ef1cb11',
    );
    expect(page.pageOpeningBalanceUnits?.asInt, 0);
    expect(page.currency, Currency.lyd);
    expect(page.account?.balanceUnits?.asInt, 1000);
    expect(page.account?.currency, Currency.lyd);
    final row = page.page.items.single;
    expect(row.amountUnits?.asInt, 1000);
    expect(row.inputValue?.asInt, 1000);
    expect(row.factorMicros, isNull);
    expect(
      _money.format(row.amountUnits!.asInt!, Currency.lyd),
      '1,000 د.ل',
    );
  });

  test('a partial payment sample is an integer LYD amount with a null factor',
      () {
    for (final key in ['partial', 'replay', 'full']) {
      final raw = _data(samples, key);
      final tx = LedgerEntryDto.fromJson(
        (raw['transaction'] as Map).cast<String, dynamic>(),
      );
      expect(tx.amountUnits?.asInt, raw['transaction']['amountUnits'],
          reason: key);
      expect(tx.inputValue?.asInt, raw['transaction']['inputValue'],
          reason: key);
      expect(tx.factorMicros, isNull, reason: key);
      expect(raw['transaction']['currency'], 'LYD', reason: key);
      expect(raw['balanceUnits'], isA<int>(), reason: key);
    }
    final replay = _entry(samples, 'replay');
    expect((replay['body'] as Map)['meta']['replayed'], isTrue);
  });

  test('the Egyptian rate is the decimal text of the integer sample', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/egyptian-deposits/exchange-rate');
    api.scriptedGetJson[ApiEndpoints.egyptianExchangeRate] = jsonEncode(raw);
    final rate = await RemoteAccountsRepository(api).getExchangeRate();
    expect(rate.egpPerLyd?.value, '10');
    expect(raw['sourceCurrency'], 'EGP');
    expect(raw['targetCurrency'], 'LYD');
  });

  test('treasury money fields stay integers in their own currencies', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/treasury');
    api.scriptedGetJson[ApiEndpoints.treasury] = jsonEncode(raw);
    final summary = await RemoteTreasuryRepository(api).summary();
    expect(summary.receivablesUnits?.asInt, 3550);
    expect(summary.liabilitiesUnits?.asInt, 380);
    expect(summary.activeCashUnits?.asInt, 500);
    expect(summary.egyptianSourceUnits?.asInt, 14900);
    expect(summary.egyptianConvertedUnits?.asInt, 1490);
    expect(summary.netUnits?.asInt, 5160);
    expect(summary.egyptianRate?.value, '10');
    expect(summary.rateMissing, isFalse);
    expect(raw['currency'], 'LYD');
    expect(_money.format(summary.netUnits!.asInt!, Currency.lyd), '5,160 د.ل');
    expect(
      _money.format(summary.egyptianSourceUnits!.asInt!, Currency.egp),
      '14,900 ج.م',
    );
  });

  test(
    'treasury expectedVersion is cashVersion',
    () async {
      final api = await _session();
      final raw = _data(samples, 'GET /api/treasury');
      api.scriptedGetJson[ApiEndpoints.treasury] = jsonEncode(raw);
      final summary = await RemoteTreasuryRepository(api).summary();
      expect(raw['cashVersion'], isA<int>());
      expect(summary.version, raw['cashVersion']);
      // sources.* is still not read (gap-analysis section 2). The G-04 part,
      // cashVersion, is fixed.
    },
  );

  test('GET /api/purchases sample parse', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/purchases/al_bayan');
    expect(raw.containsKey('merchant'), isTrue);
    expect(raw.containsKey('day'), isTrue);
    expect(raw.containsKey('entries'), isTrue);
    expect(raw.containsKey('nextBefore'), isTrue);
    expect(
      (raw['registerTotals'] as Map).containsKey('remainingUnits'),
      isTrue,
    );
    expect(raw.containsKey('days'), isFalse);
    expect(raw.containsKey('lifetimeTotals'), isFalse);
    expect(raw.containsKey('totals'), isFalse);
    api.scriptedGetJson['/api/purchases/al_bayan'] = jsonEncode(raw);
    final page =
        await RemotePurchasesRepository(api).list(PurchaseBook.alBayan);
    final day = raw['day'] as Map;
    final row = (raw['entries'] as List).single as Map;
    final totals = raw['registerTotals'] as Map;
    expect(page.merchant?.key, raw['merchant']['key']);
    expect(page.merchant?.name, raw['merchant']['name']);
    expect(page.day?.id, day['id']);
    expect(page.day?.status, day['status']);
    expect(page.day?.version, day['version']);
    expect(page.day?.todayResultUnits?.asInt, day['todayResultUnits']);
    expect(page.entries, hasLength(1));
    expect(page.entries.single.id, row['id']);
    expect(page.entries.single.dayId, day['id']);
    expect(page.entries.single.dayVersion, row['dayVersion']);
    expect(page.entries.single.version, row['version']);
    expect(page.entries.single.itemCode, row['itemCode']);
    expect(page.entries.single.resultUnits?.asInt, row['resultUnits']);
    expect(page.nextBefore, raw['nextBefore']);
    expect(
        page.registerTotals?.remainingUnits?.asInt, totals['remainingUnits']);
    expect(page.registerTotals?.vodafoneRemainingUnits?.asInt,
        totals['vodafoneRemainingUnits']);
    expect(
      _money.format(page.day!.todayResultUnits!.asInt!, Currency.lyd),
      '100 د.ل',
    );
  });

  test('payroll figures are whole currency units', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/collections/payroll');
    api.scriptedGetJson[ApiEndpoints.payroll] = jsonEncode(raw);
    final payroll = await RemoteCollectionsRepository(api).payroll();
    expect(payroll.period, '2026-10');
    expect(payroll.employees.first.remainingUnits?.asInt, 3500);
    expect(payroll.employees.first.baseSalaryUnits?.asInt, 3500);
    expect(payroll.employees.first.openingCarryUnits?.asInt, 0);
  });

  test('masraweya day money stays whole pounds, including zero', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/masraweya/day');
    api.scriptedGetJson[ApiEndpoints.masraweyaDay] = jsonEncode(raw);
    final day = await RemoteMasraweyaRepository(api).getDay();
    expect(day.businessDate, '2026-10-22');
    expect(day.currency, Currency.egp);
    expect(day.previousValueUnits?.asInt, 0);
    expect(day.purchasesUnits?.asInt, 0);
    expect(day.workTotalUnits?.asInt, 0);
    expect(day.remainingUnits?.asInt, 0);
    expect(day.version, 0);
    expect(raw['carryValueUnits'], isNull);
  });

  test('notifications keep the server unread count', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/notifications');
    api.scriptedGetJson[ApiEndpoints.notifications] = jsonEncode(raw);
    final page = await RemoteNotificationsRepository(api).list();
    expect(page.unreadCount, 3);
    expect(page.items.length, 3);
    expect(page.items.first.id, '4');
  });

  test('report rows keep the sample integers', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/reports');
    api.scriptedGetJson[ApiEndpoints.reports] = jsonEncode(raw);
    final reports = await RemoteReportsRepository(api).daily();
    final row = reports.rows.single;
    expect(row.receivablesUnits?.asInt, 3550);
    expect(row.activeCashUnits?.asInt, 500);
    expect(row.egyptianUnits?.asInt, 14900);
    expect(row.egyptianConvertedUnits?.asInt, 1490);
    expect(row.netUnits?.asInt, 5160);
    expect(row.liabilitiesUnits?.asInt, 380);
    expect(reports.formula, isNotNull);
  });

  test('reports expose current.daily and current.summary', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/reports');
    api.scriptedGetJson[ApiEndpoints.reports] = jsonEncode(raw);
    final reports = await RemoteReportsRepository(api).daily();
    final wire = (raw['current'] as Map).cast<String, dynamic>();
    final daily = (wire['daily'] as Map).cast<String, dynamic>();
    final current = reports.current!;
    expect(current.summary, wire['summary']);
    expect(
      current.daily!.receivablesAddedUnits?.asInt,
      daily['receivablesAddedUnits'],
    );
    expect(current.daily!.paymentsUnits?.asInt, daily['paymentsUnits']);
    expect(
      current.daily!.liabilitiesEffectUnits?.asInt,
      daily['liabilitiesEffectUnits'],
    );
    expect(current.daily!.cashInUnits?.asInt, daily['cashInUnits']);
    expect(current.daily!.cashOutUnits?.asInt, daily['cashOutUnits']);
    final item = ((raw['items'] as List).single as Map).cast<String, dynamic>();
    expect(reports.rows.single.summary, item['summary']);
  });

  test('the financial ledger keeps integer page totals and row amounts',
      () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/financial-ledger');
    api.scriptedGetJson[ApiEndpoints.financialLedger] = jsonEncode(raw);
    final page = await RemoteReportsRepository(api).financialLedger();
    expect(page.pageTotals['LYD']?.asInt, 4430);
    expect(page.pageTotals['EGP']?.asInt, 10000);
    expect(page.page.items.first.amountUnits?.asInt, isA<int>());
    expect(page.page.items.first.currency.code, 'LYD');
    expect(
      _money.format(page.pageTotals['LYD']!.asInt!, Currency.lyd),
      '4,430 د.ل',
    );
  });

  test('a financial ledger row uses sectionKey, sourceStatus, and occurredAt',
      () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/financial-ledger');
    api.scriptedGetJson[ApiEndpoints.financialLedger] = jsonEncode(raw);
    final page = await RemoteReportsRepository(api).financialLedger();
    final wire = (raw['items'] as List).first as Map;
    final row = page.page.items.first;
    expect(row.section, wire['sectionKey']);
    expect(row.status, wire['sourceStatus']);
    expect(row.createdAt, isNotNull);
  });

  test('login and /api/me map the user; sectionAccess is absent on the sample',
      () {
    final login = LoginResult.fromData(_data(samples, 'login'));
    expect(login.user?.role, 'admin');
    expect(login.raw['csrfToken'], '<session-csrf-token>');
    final me = MeResponse.fromData(_data(samples, 'GET /api/me'));
    expect(me.user.displayName, 'مدير الاختبار');
    // P-08: an omitted sectionAccess key is null, not an empty map.
    expect(me.user.sectionAccess, isNull);
    final limited = MeResponse.fromData(_data(samples, 'limitedMe'));
    expect(limited.user.role, 'employee');
    expect(limited.user.permissions, contains('companies.read'));
    expect(limited.user.sectionAccess, isNull);
  });

  test('assignees stay a list of display names', () async {
    final api = await _session();
    final raw = _data(samples, 'GET /api/collections/assignees');
    api.scriptedGetJson[ApiEndpoints.collectionAssignees] = jsonEncode(raw);
    final items = await RemoteCollectionsRepository(api).assignees();
    expect(items.single['displayName'], 'محصل الاختبار');
  });

  test('sample error codes are in the error catalog', () {
    final catalog = jsonDecode(
      File('../../docs/api/error-catalog.json').readAsStringSync(),
    ) as Map;
    final codes = {
      for (final row in catalog['errors'] as List)
        if (row is Map && row['codeOrEntity'] is String)
          row['codeOrEntity'] as String,
    };
    for (final key in [
      'csrfError',
      'versionHeaderError',
      'invalidAmount',
      'reusedId',
      'versionConflict',
      'duplicateWarning',
      'limitedForbidden',
      'unauthenticated',
    ]) {
      final code =
          ((_entry(samples, key)['body'] as Map)['error'] as Map)['code'];
      expect(codes, contains(code), reason: key);
    }
  });

  test('CSRF, version conflict, permission, and auth samples map by code', () {
    const mapper = ErrorMapper();
    final csrf = mapper.fromResponse(403, _body(samples, 'csrfError'), null);
    expect(csrf, isA<CsrfInvalidException>());
    expect(csrf.code, 'CSRF_REJECTED');

    final conflict =
        mapper.fromResponse(409, _body(samples, 'versionConflict'), null);
    expect(conflict, isA<ConflictException>());
    expect(conflict.code, 'VERSION_CONFLICT');

    final denied =
        mapper.fromResponse(403, _body(samples, 'limitedForbidden'), null);
    expect(denied, isA<ForbiddenException>());
    expect(denied.code, 'PERMISSION_DENIED');

    final auth =
        mapper.fromResponse(401, _body(samples, 'unauthenticated'), null);
    expect(auth, isA<SessionExpiredException>());
    expect(auth.code, 'AUTH_REQUIRED');
  });

  test('CLIENT_VERSION_MISMATCH is an upgrade, not a data conflict', () {
    final err = const ErrorMapper()
        .fromResponse(409, _body(samples, 'versionHeaderError'), null);
    expect(err, isA<ClientVersionMismatchException>());
    expect(err, isNot(isA<ConflictException>()));
    expect(err.code, 'CLIENT_VERSION_MISMATCH');
  });

  test('REQUEST_ID_REUSED and DUPLICATE_SAME_WORKDAY are not generic conflicts',
      () {
    const mapper = ErrorMapper();
    final reused = mapper.fromResponse(409, _body(samples, 'reusedId'), null);
    final duplicate =
        mapper.fromResponse(409, _body(samples, 'duplicateWarning'), null);
    expect(reused, isA<RequestIdReusedException>());
    expect(reused, isNot(isA<ConflictException>()));
    expect(duplicate.code, 'DUPLICATE_SAME_WORKDAY');
    expect(duplicate, isA<DuplicateSameWorkdayException>());
    expect(duplicate, isNot(isA<ConflictException>()));
  });

  test('INVALID_AMOUNT details.field is the field name', () {
    final err = const ErrorMapper()
        .fromResponse(400, _body(samples, 'invalidAmount'), null);
    expect(err, isA<ValidationException>());
    expect((err as ValidationException).fieldErrors.single.field, 'inputValue');
  });

  test(
    'pin sends isPinned and expectedVersion',
    () async {
      final api = await _session();
      // A card the fake knows, at its current version (4).
      final ack = await RemoteAccountsRepository(api).setPinned(
        AccountSection.customers,
        'c_55',
        true,
        MutationMeta(expectedVersion: 4, requestId: 'contract-pin-01'),
      );
      final body = jsonDecode(api.lastWireBody!) as Map;
      expect(body['isPinned'], isTrue);
      expect(body.containsKey('pinned'), isFalse);
      expect(body['expectedVersion'], 4);
      expect(ack.version, 5);
    },
  );

  test(
    'purchase entry writes send both versions, and correction sends expectedVersion',
    () async {
      final api = await _session();
      final repo = RemotePurchasesRepository(api);
      const request = PurchaseEntryRequest(
        itemCode: 'custom',
        itemLabel: 'عقد',
        egpValueUnits: 1000,
        calculationMode: CalculationMode.divide,
        paidUnits: 20,
      );
      await repo.update(
        PurchaseBook.alBayan,
        'd0f6a687-1267-471b-831e-a4568602d82c',
        request,
        MutationMeta(expectedVersion: 4, requestId: 'contract-entry-1'),
        entryVersion: 2,
      );
      final patch = jsonDecode(api.lastWireBody!) as Map;
      expect(patch['expectedVersion'], 2);
      expect(patch['expectedDayVersion'], 4);
      await repo.delete(
        PurchaseBook.alBayan,
        'd0f6a687-1267-471b-831e-a4568602d82c',
        MutationMeta(expectedVersion: 4, requestId: 'contract-entry-2'),
        entryVersion: 2,
      );
      final delete = jsonDecode(api.lastWireBody!) as Map;
      expect(delete['expectedVersion'], 2);
      expect(delete['expectedDayVersion'], 4);
      await repo.setDayCorrection(
        PurchaseBook.alBayan,
        '12',
        open: true,
        meta: MutationMeta(expectedVersion: 3, requestId: 'contract-corr-1'),
      );
      final correction = jsonDecode(api.lastWireBody!) as Map;
      expect(correction['expectedVersion'], 3);
      expect(correction.containsKey('expectedDayVersion'), isFalse);
    },
  );

  test(
    'Paged.hasMore follows nextBefore on a treasury cash page',
    () async {
      final api = await _session();
      api.scriptedGetJson[ApiEndpoints.treasuryCashLedger] = jsonEncode({
        'items': [
          {'id': 'cash-1', 'direction': 'in', 'amountUnits': 10},
        ],
        'nextBefore': 'cursor-1',
      });
      final page = await RemoteTreasuryRepository(api).cashLedger();
      expect(page.nextCursor, 'cursor-1');
      expect(page.hasMore, isTrue);
    },
  );

  test('openapi omits the five paths the app still calls', () {
    final paths = _openapiPaths();
    for (final path in _missingContractPaths) {
      expect(paths, isNot(contains(path)), reason: path);
    }
  });
}

const _missingContractPaths = [
  '/api/notifications/unread-count',
  '/api/mobile-push/devices',
  '/api/admin/employee-totals',
  '/api/home',
  '/api/statements/pdf',
];

Map<String, dynamic> _loadSamples() {
  final decoded = PreciseJson.decode(
    File('../../docs/api/evidence/api-samples.json').readAsStringSync(),
  );
  return (decoded as Map).cast<String, dynamic>();
}

Map<String, dynamic> _entry(Map<String, dynamic> samples, String key) =>
    (samples[key] as Map).cast<String, dynamic>();

Map<String, dynamic> _data(Map<String, dynamic> samples, String key) {
  final body = (_entry(samples, key)['body'] as Map).cast<String, dynamic>();
  return (body['data'] as Map).cast<String, dynamic>();
}

Map<String, dynamic> _body(Map<String, dynamic> samples, String key) =>
    (_entry(samples, key)['body'] as Map).cast<String, dynamic>();

Future<FakeApiClient> _session() async {
  final api = FakeApiClient(latency: Duration.zero);
  await api.post(
    '/api/auth/login',
    body: {'username': 'admin.demo', 'password': 'demo-only'},
  );
  return api;
}

Set<String> _openapiPaths() {
  final spec = jsonDecode(
    File('../../docs/api/openapi.json').readAsStringSync(),
  ) as Map;
  return (spec['paths'] as Map).keys.map((key) => '$key').toSet();
}

String _grouped(int units) {
  final digits = '$units';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
