import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fake follows the implemented four-section contract. It is not a call
/// to the Node server, and it is not a claim that staging exposes the routes.
void main() {
  test('a section review uses financialVersion and can be replayed once',
      () async {
    final fake = FakeApiClient(latency: Duration.zero);
    await _login(fake, 'admin.demo');
    fake.appendedAccountCards.add((
      section: 'companies',
      card: _pending('co_new', version: 7, financial: 2),
    ));

    final first = await fake.post(
      '/api/companies/co_new/zero-review',
      body: {'requestId': 'review-1', 'expectedFinancialVersion': 2},
    );
    final data = first.data as Map;
    expect(data['replayed'], isNot(true));
    expect(data['zeroReview'], {
      'pending': false,
      'financialVersion': 2,
      'reviewedAt': '2026-11-09T00:40:00.000Z',
      'reviewedByName': 'مدير تجريبي',
    });
    expect(data.containsKey('balanceUnits'), isFalse);
    expect(fake.zeroReviewCommits, 1);

    final card = (await fake.get('/api/companies/co_new')).data as Map;
    expect(card['balanceUnits'], 0);
    expect(card['version'], 7);
    expect((card['zeroReview'] as Map)['pending'], isFalse);

    final replay = await fake.post(
      '/api/companies/co_new/zero-review',
      body: {'requestId': 'review-2', 'expectedFinancialVersion': 2},
    );
    expect((replay.data as Map)['replayed'], isTrue);
    expect(fake.zeroReviewCommits, 1);
  });

  test('stale, historical, linked, and cross-section reviews do not write',
      () async {
    final fake = FakeApiClient(latency: Duration.zero);
    await _login(fake, 'company.writer');
    fake.appendedAccountCards.addAll([
      (section: 'companies', card: _pending('co_stale', financial: 4)),
      (
        section: 'companies',
        card: {
          ..._pending('co_old_zero', financial: 1),
          'zeroReview': {
            'pending': false,
            'financialVersion': 1,
            'reviewedAt': null,
            'reviewedByName': null,
          },
        },
      ),
      (
        section: 'companies',
        card: {..._pending('co_moved', financial: 3), 'balanceUnits': 15},
      ),
      (section: 'libyan-deposits', card: _pending('ly_new', financial: 6)),
      (
        section: 'egyptian-deposits',
        card: {
          ..._pending('eg_link', financial: 1),
          'systemManaged': true,
          'systemLinkKey': 'purchases_vodafone_remainder',
        },
      ),
    ]);

    await _expect(
      fake.post('/api/companies/co_stale/zero-review', body: {
        'requestId': 'stale',
        'expectedFinancialVersion': 9,
      }),
      409,
      'ZERO_REVIEW_CHANGED',
    );
    await _expect(
      fake.post('/api/companies/co_old_zero/zero-review', body: {
        'requestId': 'historical',
        'expectedFinancialVersion': 1,
      }),
      409,
      'ZERO_REVIEW_NOT_PENDING',
    );
    await _expect(
      fake.post('/api/companies/co_moved/zero-review', body: {
        'requestId': 'nonzero',
        'expectedFinancialVersion': 3,
      }),
      409,
      'ZERO_REVIEW_CHANGED',
    );
    await _expect(
      fake.post('/api/companies/co_stale/zero-review', body: {
        'requestId': 'bad',
        'expectedFinancialVersion': -1,
      }),
      400,
      'INVALID_REVIEW_VERSION',
    );
    await _expect(
      fake.post('/api/libyan-deposits/ly_new/zero-review', body: {
        'requestId': 'cross',
        'expectedFinancialVersion': 6,
      }),
      403,
      'PERMISSION_DENIED',
    );
    final admin = FakeApiClient(latency: Duration.zero);
    await _login(admin, 'admin.demo');
    admin.appendedAccountCards.addAll([
      (
        section: 'egyptian-deposits',
        card: {
          ..._pending('eg_link', financial: 1),
          'systemManaged': true,
          'systemLinkKey': 'purchases_vodafone_remainder',
        },
      ),
      (section: 'companies', card: _pending('co_other', financial: 4)),
    ]);
    await _expect(
      admin.post('/api/egyptian-deposits/eg_link/zero-review', body: {
        'requestId': 'linked',
        'expectedFinancialVersion': 1,
      }),
      404,
      'NOT_FOUND',
    );
    await _expect(
      admin.post('/api/customers/co_other/zero-review', body: {
        'requestId': 'wrong-section',
        'expectedFinancialVersion': 4,
      }),
      404,
      'NOT_FOUND',
    );
    expect(fake.zeroReviewCommits, 0);
    expect(admin.zeroReviewCommits, 0);
    final kept = (await fake.get('/api/companies/co_stale')).data as Map;
    expect((kept['zeroReview'] as Map)['pending'], isTrue);
    expect(kept['balanceUnits'], 0);
  });

  test('the implemented zeroReview object parses and an absent field does not',
      () {
    final pending = AccountCardDto.fromJson({
      'id': 'co',
      'name': 'شركة',
      'balanceUnits': 0,
      'currency': 'LYD',
      'version': 4,
      'zeroReview': {
        'pending': true,
        'financialVersion': 2,
        'reviewedAt': null,
        'reviewedByName': null,
      },
    }, AccountSection.companies);
    expect(readZeroReview(pending.zeroReview), ZeroReviewRead.pending);
    expect(pending.zeroReview?['financialVersion'], 2);

    final historical = AccountCardDto.fromJson({
      'id': 'old',
      'name': 'قديم',
      'balanceUnits': 0,
      'zeroReview': {
        'pending': false,
        'financialVersion': 0,
        'reviewedAt': null,
        'reviewedByName': null,
      },
    }, AccountSection.libyanDeposits);
    expect(readZeroReview(historical.zeroReview), ZeroReviewRead.closed);

    final absent = AccountCardDto.fromJson({
      'id': 'legacy',
      'name': 'بدون الحقل',
      'balanceUnits': 0,
    }, AccountSection.egyptianDeposits);
    expect(absent.zeroReview, isNull);
    expect(readZeroReview(absent.zeroReview), ZeroReviewRead.unknown);

    final ack = MutationAck.fromData({
      'zeroReview': {
        'pending': false,
        'financialVersion': 2,
        'reviewedAt': '2026-11-09T00:40:00.000Z',
        'reviewedByName': 'مراجع',
      },
      'replayed': true,
    });
    expect(ack.replayed, isTrue);
    expect(ack.raw['zeroReview'], isA<Map>());
    expect(ack.balanceUnits, isNull);
  });
}

Map<String, dynamic> _pending(
  String id, {
  int version = 3,
  required int financial,
}) =>
    {
      'id': id,
      'name': id,
      'balanceUnits': 0,
      'currency': 'LYD',
      'version': version,
      'zeroReview': {
        'pending': true,
        'financialVersion': financial,
        'reviewedAt': null,
        'reviewedByName': null,
      },
    };

Future<void> _expect(Future<ApiResponse> call, int status, String code) async {
  await expectLater(
    call,
    throwsA(
      isA<ApiException>()
          .having((error) => error.statusCode, 'status', status)
          .having((error) => error.code, 'code', code),
    ),
  );
}

Future<void> _login(FakeApiClient api, String username) {
  return api.post(
    '/api/auth/login',
    body: {'username': username, 'password': 'demo-only'},
  );
}
