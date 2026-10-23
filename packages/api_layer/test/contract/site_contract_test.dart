/// Contract tests for the website staging samples.
///
/// Samples are `docs/api/evidence/api-samples.json` on main. `csrfToken` is the
/// placeholder `<session-csrf-token>`. There is no password, cookie, or bearer
/// token. Transport is [FakeApiClient] (one scripted GET). Parsing is the real
/// repository and DTO path. A case that does not match the contract today is
/// skipped with a G id from `docs/api/gap-analysis.ar.md` section 0 only.
/// GET /api/collections is not parsed here (G-01, owned by P-03). GET
/// /api/purchases is not parsed here (G-02, owned by P-04). DEF-028 and the
/// Egyptian part of DEF-035 have no G id.
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
    'treasury expectedVersion is cashVersion and sources are read',
    () async {
      final api = await _session();
      final raw = _data(samples, 'GET /api/treasury');
      api.scriptedGetJson[ApiEndpoints.treasury] = jsonEncode(raw);
      final summary = await RemoteTreasuryRepository(api).summary();
      expect(summary.version, raw['cashVersion']);
    },
    skip: 'G-04. The sample version field is cashVersion. '
        'TreasurySummaryDto reads version, so expectedVersion stays null. '
        'sources.* is not read.',
  );

  test(
    'GET /api/purchases sample parse',
    () {
      // TODO(PR #68): re-enable the parser assertion after
      // cursor/p04-purchases-contract-shape lands. This body does not name
      // PurchasesBookPage or PurchasesPage.
      final raw = _data(samples, 'GET /api/purchases/al_bayan');
      expect(raw.containsKey('merchant'), isTrue);
      expect(raw.containsKey('day'), isTrue);
      expect(raw.containsKey('entries'), isTrue);
      expect(raw.containsKey('nextBefore'), isTrue);
      expect(
          (raw['registerTotals'] as Map).containsKey('remainingUnits'), isTrue);
      expect(raw.containsKey('days'), isFalse);
      expect(raw.containsKey('lifetimeTotals'), isFalse);
      fail('todo: G-02');
    },
    skip: 'G-02. PurchasesBookPage reads days[] and lifetimeTotals/totals. '
        'The sample is merchant, day, entries, nextBefore, and registerTotals '
        '(DEF-034). The passing parse belongs to P-04 '
        '(cursor/p04-purchases-contract-shape). This suite does not add one.',
  );

  test(
    'GET /api/collections sample parse',
    () {
      final raw = _data(samples, 'GET /api/collections');
      final submissions = (raw['submissions'] as List).cast<Map>();
      final unlinked = (raw['unlinkedReceipts'] as List).cast<Map>();
      expect(submissions, isNotEmpty);
      expect(unlinked, isNotEmpty);
      for (final row in [...submissions, ...unlinked]) {
        expect(row.containsKey('version'), isFalse, reason: '${row['id']}');
      }
      fail('todo: G-01');
    },
    skip: 'G-01. The passing parse of this sample belongs to P-03 '
        '(PR #66, cursor/p03-collections-no-version). This suite does not '
        'add a second one. Submissions and unlinked receipts have no version.',
  );

  test(
    'an unlinked receipt can be linked to an Egyptian deposit',
    () {
      final raw = _data(samples, 'GET /api/collections');
      final unlinked = (raw['unlinkedReceipts'] as List).cast<Map>();
      for (final row in unlinked) {
        expect(row.containsKey('currency'), isFalse, reason: '${row['id']}');
        expect(row.containsKey('rate'), isFalse, reason: '${row['id']}');
        expect(row['sectionKey'], isNot('egyptian_deposits'),
            reason: '${row['id']}');
      }
      fail('todo: DEF-035');
    },
    skip: 'DEF-035. No G id. Linking an unlinked receipt to '
        'egyptian_deposits stays open (P-20). The collections sample itself '
        'is not parsed here.',
  );

  test(
    'a collection decision sends without expectedVersion',
    () async {
      // TODO(PR #66): re-enable this body after
      // cursor/p03-collections-no-version lands. Do not unskip it here.
      final api = await _session();
      final repo = RemoteCollectionsRepository(api);
      await repo.decide(
        'd37f68dd-814d-4a9b-908b-278e1a259b2f',
        CollectionDecision.approve,
        meta: MutationMeta(requestId: 'contract-decision'),
      );
      expect(api.lastWireBody, isNot(contains('expectedVersion')));
    },
    skip: 'G-01. Submissions and unlinked receipts in the sample have no '
        'version. RemoteCollectionsRepository._versioned throws ArgumentError '
        'before the request, so approve, reject, and cash-received never send.',
  );

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

  test(
    'payroll employeeName is the displayed name',
    () async {
      final api = await _session();
      final raw = _data(samples, 'GET /api/collections/payroll');
      api.scriptedGetJson[ApiEndpoints.payroll] = jsonEncode(raw);
      final payroll = await RemoteCollectionsRepository(api).payroll();
      final wire = (raw['employees'] as List).first as Map;
      expect(payroll.employees.first.name, wire['employeeName']);
    },
    skip: 'No id in gap-analysis section 0. PayrollEmployeeDto reads '
        'displayName or name. The sample sends employeeName, so the parsed '
        'name is empty.',
  );

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

  test(
    'a notification row uses sectionKey',
    () async {
      final api = await _session();
      final raw = _data(samples, 'GET /api/notifications');
      api.scriptedGetJson[ApiEndpoints.notifications] = jsonEncode(raw);
      final page = await RemoteNotificationsRepository(api).list();
      final wire = (raw['items'] as List).first as Map;
      expect(page.items.first.section, wire['sectionKey']);
    },
    skip: 'No id in gap-analysis section 0. NotificationDto reads section. '
        'The sample sends sectionKey. G-12 is the financial-ledger fields, '
        'not this row.',
  );

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

  test(
    'reports expose current.daily and current.summary',
    () async {
      final api = await _session();
      final raw = _data(samples, 'GET /api/reports');
      api.scriptedGetJson[ApiEndpoints.reports] = jsonEncode(raw);
      final reports = await RemoteReportsRepository(api).daily();
      expect(reports.rows.single.netChangeUnits, isNull);
      expect(
        reports.methodologyNote,
        raw['current']['summary'],
      );
    },
    skip: 'No id in gap-analysis section 0. ReportsDto reads items[] and '
        'methodology.note. It does not read current, current.daily, or '
        'current.summary. G-12 is only sectionKey, sourceStatus, and '
        'occurredAt.',
  );

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

  test(
    'a financial ledger row uses sectionKey, sourceStatus, and occurredAt',
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
    },
    skip: 'G-12. FinancialLedgerEntryDto reads section, status, and createdAt. '
        'The sample sends sectionKey, sourceStatus, and occurredAt.',
  );

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

  test(
    'a limited employee with codes and no sectionAccess can read those sections',
    () {
      final limited = MeResponse.fromData(_data(samples, 'limitedMe'));
      final access = PermissionService();
      access.applyFromServer(
        limited.user.permissions,
        role: limited.user.role,
        sectionAccess: limited.user.sectionAccess,
      );
      expect(access.canRead(SectionKey.companies), isTrue);
      expect(access.canRead(SectionKey.purchases), isTrue);
      expect(access.canRead(SectionKey.treasury), isTrue);
      expect(access.canRead(SectionKey.collections), isTrue);
    },
    skip: 'G-15. /api/me on the sample has permissions and no sectionAccess. '
        'PermissionService treats a missing section entry as none, so the '
        'eight section codes do not open the UI.',
  );

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

  test(
    'CLIENT_VERSION_MISMATCH is an upgrade, not a data conflict',
    () {
      final err = const ErrorMapper()
          .fromResponse(409, _body(samples, 'versionHeaderError'), null);
      expect(err, isA<UpgradeRequiredException>());
      expect(err.code, 'CLIENT_VERSION_MISMATCH');
    },
    skip: 'G-07. Every non-VERSION_CONFLICT 409 becomes ConflictException, '
        'including CLIENT_VERSION_MISMATCH.',
  );

  test(
    'REQUEST_ID_REUSED and DUPLICATE_SAME_WORKDAY are not generic conflicts',
    () {
      const mapper = ErrorMapper();
      final reused = mapper.fromResponse(409, _body(samples, 'reusedId'), null);
      final duplicate =
          mapper.fromResponse(409, _body(samples, 'duplicateWarning'), null);
      expect(reused, isNot(isA<ConflictException>()));
      expect(duplicate.code, 'DUPLICATE_SAME_WORKDAY');
      expect(duplicate, isNot(isA<ConflictException>()));
    },
    skip: 'G-07. REQUEST_ID_REUSED and DUPLICATE_SAME_WORKDAY are both '
        'ConflictException. The duplicate warning is not a distinct type.',
  );

  test(
    'INVALID_AMOUNT details.field is the field name',
    () {
      final err = const ErrorMapper()
          .fromResponse(400, _body(samples, 'invalidAmount'), null);
      expect(err, isA<ValidationException>());
      expect(
          (err as ValidationException).fieldErrors.single.field, 'inputValue');
    },
    skip: 'G-07. details is {"field": "inputValue"}. The mapper treats the '
        'key "field" as the field name.',
  );

  test(
    'MFA_REQUIRED is not shown as invalid credentials',
    () {
      fail('todo: G-07');
    },
    skip: 'G-07. api-samples.json has no MFA_REQUIRED body, and this suite '
        'does not invent one. An unauthenticated 401 becomes '
        'InvalidCredentialsException. P-09 owns the MFA mapping.',
  );

  test(
    'pin sends isPinned and expectedVersion',
    () async {
      final api = await _session();
      await RemoteAccountsRepository(api).setPinned(
        AccountSection.customers,
        '0342102a-b304-4e81-a4b7-a08081516bfa',
        true,
        MutationMeta(expectedVersion: 2, requestId: 'contract-pin-01'),
      );
      final body = jsonDecode(api.lastWireBody!) as Map;
      expect(body['isPinned'], isTrue);
      expect(body.containsKey('pinned'), isFalse);
      expect(body['expectedVersion'], 2);
    },
    skip: 'G-05. setPinned sends pinned, not isPinned.',
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
      );
      final patch = jsonDecode(api.lastWireBody!) as Map;
      expect(patch.containsKey('expectedVersion'), isTrue);
      expect(patch.containsKey('expectedDayVersion'), isTrue);
    },
    skip: 'G-06. Entry PATCH and DELETE send expectedDayVersion only. '
        'Day correction sends expectedDayVersion; the contract name is expectedVersion.',
  );

  test(
    'a payment body can ask the server to check for a same-day duplicate',
    () {
      final body = AccountTransactionRequest.partialPayment(
        inputValue: 250,
        date: DateTime.utc(2026, 10, 22),
      ).toJson();
      expect(body.containsKey('checkDuplicate'), isTrue);
    },
    skip: 'G-10. checkDuplicate and allowDuplicate are never sent.',
  );

  test(
    'collection submission exactly-once is represented by the samples',
    () {
      expect(samples.containsKey('collectionSubmissionReplay'), isTrue);
    },
    skip: 'G-03. DEF-037. The replay sample is a debt payment (meta.replayed '
        'on the envelope). No sample shows exactly-once for '
        'POST /api/collections/assignments/{id}/submissions. '
        'Stays skip until the server fix.',
  );

  test(
    'parallel writes do not refresh CSRF against each other',
    () {
      // TODO(PR #67): update this skip reason after the CSRF write queue lands.
      expect(samples.containsKey('parallelCsrf'), isTrue);
    },
    skip: 'G-08. The samples have a single CSRF_REJECTED response. They do '
        'not show two writes refreshing the token at the same time, and the '
        'client has no write queue.',
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
    skip: 'G-14. Paged.hasMore reads hasMore and nextCursor only. A '
        'nextBefore value is stored on nextCursor and does not set hasMore. '
        'This uses the treasury cash ledger, which #68 does not replace. '
        'Both purchase samples have nextBefore null, so they are not used.',
  );

  test('openapi omits the five paths the app still calls', () {
    final paths = _openapiPaths();
    for (final path in _missingContractPaths) {
      expect(paths, isNot(contains(path)), reason: path);
    }
  });

  test(
    'the app does not call paths that are absent from openapi.json',
    () {
      final roots = [
        Directory('lib'),
        Directory('../../lib'),
      ];
      final text = roots
          .where((dir) => dir.existsSync())
          .expand((dir) => dir.listSync(recursive: true))
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      for (final path in _missingContractPaths) {
        expect(text.contains("'$path'"), isFalse, reason: path);
      }
    },
    skip: 'G-09. The app still names /api/notifications/unread-count, '
        '/api/mobile-push/devices, /api/admin/employee-totals, /api/home, '
        'and /api/statements/pdf. None is in openapi.json.',
  );
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
