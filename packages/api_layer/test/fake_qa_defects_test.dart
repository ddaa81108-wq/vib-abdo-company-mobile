import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sections = [
    'customers',
    'companies',
    'libyan-deposits',
    'egyptian-deposits',
  ];

  test(
    'DEF-006 the fake server enforces the permission matrix with 403',
    () async {
      final employee = FakeApiClient(latency: Duration.zero);
      await _login(employee, 'employee.demo');

      final customers = await employee.get('/api/customers');
      expect(customers.statusCode, 200);
      expect((customers.data as Map)['totalItems'], 10);

      await expectLater(
        employee.post(
          '/api/customers/c_55/transactions',
          body: {
            'requestId': 'emp-pay',
            'expectedVersion': 4,
            'type': 'payment',
            'paymentMode': 'full',
          },
        ),
        throwsA(_forbidden()),
      );
      await expectLater(employee.get('/api/treasury'), throwsA(_forbidden()));
      await expectLater(employee.get('/api/companies'), throwsA(_forbidden()));
      await expectLater(
        employee.post(
          '/api/collections/submissions/sb_1/decision',
          body: {
            'requestId': 'emp-decide',
            'expectedVersion': 1,
            'decision': 'approve',
          },
        ),
        throwsA(
          isA<ForbiddenException>().having(
            (error) => error.message,
            'message',
            'هذا الإجراء للإدارة فقط',
          ),
        ),
      );
      final submission = await employee.post(
        '/api/collections/unlinked-receipts',
        body: {
          'requestId': 'emp-unlinked',
          'customerName': 'عميل',
          'amountUnits': 50,
        },
      );
      expect(submission.statusCode, 200);

      final guest = FakeApiClient(latency: Duration.zero);
      await _login(guest, 'guest.demo');
      await expectLater(guest.get('/api/customers'), throwsA(_forbidden()));
      await expectLater(guest.get('/api/treasury'), throwsA(_forbidden()));

      final limited = FakeApiClient(latency: Duration.zero);
      await _login(limited, 'limited.admin.demo');
      expect((await limited.get('/api/customers')).statusCode, 200);
      await expectLater(limited.get('/api/treasury'), throwsA(_forbidden()));
      await expectLater(
        limited.post(
          '/api/customers/c_55/transactions',
          body: {
            'requestId': 'limited-pay',
            'expectedVersion': 4,
            'type': 'payment',
          },
        ),
        throwsA(_forbidden()),
      );
      // The profile includes collections.decide, so the server allows the call.
      final decision = await limited.post(
        '/api/collections/submissions/sb_1/decision',
        body: {
          'requestId': 'limited-decide',
          'expectedVersion': 1,
          'decision': 'approve',
        },
      );
      expect(decision.statusCode, 200);

      final admin = FakeApiClient(latency: Duration.zero);
      await _login(admin, 'admin.demo');
      expect((await admin.get('/api/treasury')).statusCode, 200);
      final payment = await admin.post(
        '/api/customers/c_55/transactions',
        body: {
          'requestId': 'admin-pay',
          'expectedVersion': 4,
          'type': 'payment',
          'paymentMode': 'full',
        },
      );
      expect((payment.data as Map)['version'], 5);
      await expectLater(
        admin.post(
          '/api/customers/c_masraweya_remainder/transactions',
          body: {
            'requestId': 'admin-system',
            'expectedVersion': 4,
            'type': 'payment',
          },
        ),
        throwsA(_forbidden()),
      );
    },
  );

  test(
    'DEF-011 a repeated requestId returns the original success once',
    () async {
      final api = FakeApiClient(latency: Duration.zero);
      await _login(api, 'admin.demo');
      final body = {
        'requestId': 'same-id',
        'expectedVersion': 4,
        'type': 'payment',
        'paymentMode': 'full',
      };

      final first = await api.post(
        '/api/customers/c_55/transactions',
        body: body,
      );
      final second = await api.post(
        '/api/customers/c_55/transactions',
        body: {...body, 'type': 'debt'},
      );
      expect(second.data, first.data);
      expect(api.mutationRequestIds, ['same-id']);

      api.failMutationsRemaining = 1;
      final replay = await api.post(
        '/api/customers/c_55/transactions',
        body: body,
      );
      expect(replay.data, first.data);
      expect(api.failMutationsRemaining, 1);
      expect(api.mutationRequestIds, ['same-id']);

      await expectLater(
        api.post(
          '/api/customers/c_55/transactions',
          body: {
            'requestId': 'fails-once',
            'expectedVersion': 4,
            'type': 'payment',
          },
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(api.mutationRequestIds, ['same-id', 'fails-once']);
      final retried = await api.post(
        '/api/customers/c_55/transactions',
        body: {
          'requestId': 'fails-once',
          'expectedVersion': 4,
          'type': 'payment',
        },
      );
      expect((retried.data as Map)['id'], 'tx_new');
      expect(api.mutationRequestIds, ['same-id', 'fails-once', 'fails-once']);
    },
  );

  test(
    'DEF-008 mustchange.demo returns mustChangePassword until it is changed',
    () async {
      final api = FakeApiClient(latency: Duration.zero);
      final login = await _login(api, 'mustchange.demo');
      expect((login.data as Map)['user']['mustChangePassword'], isTrue);
      final me = await api.get('/api/me');
      expect((me.data as Map)['user']['mustChangePassword'], isTrue);

      await api.post(
        '/api/auth/change-password',
        body: {'currentPassword': 'demo-only', 'newPassword': 'new-password-1'},
      );
      expect(
        ((await api.get('/api/me')).data as Map)['user']['mustChangePassword'],
        isFalse,
      );

      await api.post('/api/auth/logout');
      final again = await _login(api, 'mustchange.demo');
      expect((again.data as Map)['user']['mustChangePassword'], isFalse);

      for (final username in [
        'admin.demo',
        'employee.demo',
        'limited.admin.demo',
        'flag.admin.demo',
        'guest.demo',
      ]) {
        final other = FakeApiClient(latency: Duration.zero);
        final signedIn = await _login(other, username);
        expect(
          (signedIn.data as Map)['user']['mustChangePassword'],
          isFalse,
          reason: username,
        );
      }
    },
  );

  test(
    'DEF-009 and seed data: one age per card, ten cards, one system card',
    () {
      for (final section in sections) {
        final page = FakeFixtures.accountsFor(section);
        final items = (page['items'] as List).cast<Map>();
        expect(items, hasLength(10), reason: section);
        expect(page['totalItems'], 10, reason: section);
        expect(items.where((card) => card['id'] == 'c_55'), hasLength(1));
        for (final card in items) {
          expect(
            card['ageStatusLabel'],
            'منذ ${card['debtAgeDays']} أيام',
            reason: '$section/${card['id']}',
          );
          expect(card.containsKey('systemKind'), isFalse, reason: card['id']);
        }
      }

      final demo = FakeFixtures.cardById('customers', 'c_55');
      expect(demo['debtAgeDays'], 4);
      expect(demo['balanceUnits'], 320);
      expect(demo['ageStatusLabel'], 'منذ 4 أيام');
      expect(demo['systemManaged'], isNull);

      final bulletin = (FakeFixtures.home()['oldDebts'] as List).single as Map;
      expect(bulletin['id'], 'c_55');
      expect(bulletin['debtAgeDays'], demo['debtAgeDays']);
      expect(bulletin['ageStatus'], demo['ageStatus']);
      expect(bulletin['ageStatusLabel'], demo['ageStatusLabel']);

      final system = FakeFixtures.cardById(
        'customers',
        'c_masraweya_remainder',
      );
      expect(system['systemManaged'], isTrue);
      expect(system['systemLinkKey'], 'masraweya_remainder');
      expect(system['balanceUnits'], 8950);
      expect(
        FakeFixtures.cardById('egyptian-deposits', 'c_55')['balanceUnits'],
        15000,
      );
    },
  );

  test(
    'home copies section fixtures and withholds sections the profile cannot read',
    () async {
      final catalog = FakeFixtures.home();
      final customersPage = FakeFixtures.accountsFor('customers');
      final egyptianPage = FakeFixtures.accountsFor('egyptian-deposits');
      final customerSummary = customersPage['summary'] as Map;
      final egyptianSummary = egyptianPage['summary'] as Map;

      Map<String, dynamic> card(String section) => Map<String, dynamic>.from(
            (catalog['summaries'] as List).cast<Map>().firstWhere(
                  (item) => item['section'] == section,
                ),
          );

      expect(card('customers')['valueUnits'], customerSummary['netBalance']);
      expect(card('customers')['valueUnits'], 10635);
      expect(catalog['counters']['customers'], customerSummary['activeCards']);
      expect(catalog['counters']['customers'], customersPage['totalItems']);
      expect(
        card('egyptian-deposits')['valueUnits'],
        egyptianSummary['netBalance'],
      );
      expect(card('egyptian-deposits')['valueUnits'], 23750);
      expect(
        card('treasury')['valueUnits'],
        (FakeFixtures.treasury()['totals'] as Map)['activeCashUnits'],
      );
      expect(
        card('collections')['valueUnits'],
        (FakeFixtures.collections()['metrics'] as Map)['collectedUnits'],
      );
      expect(card('reports')['valueUnits'], isNull);

      final guest = FakeApiClient(latency: Duration.zero);
      await _login(guest, 'guest.demo');
      final guestHome = (await guest.get('/api/home')).data as Map;
      expect(guestHome['summaries'], isEmpty);
      expect(guestHome.containsKey('oldDebts'), isFalse);
      expect(
        (guestHome['counters'] as Map).containsKey('customers'),
        isFalse,
      );
      expect(
        (guestHome['counters'] as Map).containsKey('collections'),
        isFalse,
      );

      final employee = FakeApiClient(latency: Duration.zero);
      await _login(employee, 'employee.demo');
      final employeeHome = (await employee.get('/api/home')).data as Map;
      expect(
        (employeeHome['summaries'] as List).map(
          (item) => (item as Map)['section'],
        ),
        ['customers', 'collections'],
      );
      final employeeCustomers = (employeeHome['summaries'] as List)
          .cast<Map>()
          .firstWhere((item) => item['section'] == 'customers');
      expect(employeeCustomers['valueUnits'], 10635);
      expect(employeeHome['counters']['customers'], 10);
      expect((employeeHome['oldDebts'] as List).single['id'], 'c_55');
      expect(
        (employeeHome['summaries'] as List).any(
          (item) => (item as Map)['section'] == 'egyptian-deposits',
        ),
        isFalse,
      );

      final flag = FakeApiClient(latency: Duration.zero);
      await _login(flag, 'flag.admin.demo');
      final flagHome = (await flag.get('/api/home')).data as Map;
      expect(flagHome['summaries'], isEmpty);
      expect(flagHome.containsKey('oldDebts'), isFalse);
    },
  );
}

Future<ApiResponse> _login(FakeApiClient api, String username) {
  return api.post(
    '/api/auth/login',
    body: {'username': username, 'password': 'demo-only'},
  );
}

Matcher _forbidden() => isA<ForbiddenException>()
    .having((error) => error.statusCode, 'status', 403)
    .having((error) => error.code, 'code', 'FORBIDDEN');
