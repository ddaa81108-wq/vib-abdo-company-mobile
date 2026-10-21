@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a missing or expired session is 401 before 404', () async {
    final api = FakeApiClient(latency: Duration.zero);

    await expectLater(
      api.get('/api/notifications'),
      throwsA(_status<SessionExpiredException>(401)),
    );
    await expectLater(
      api.get('/api/notifications/unread-count'),
      throwsA(_status<SessionExpiredException>(401)),
    );
    await expectLater(
      api.patch('/api/notifications/88/read'),
      throwsA(_status<SessionExpiredException>(401)),
    );
    await expectLater(
      api.post('/api/notifications/read-all'),
      throwsA(_status<SessionExpiredException>(401)),
    );

    await _login(api, 'employee.demo');
    api.expireSession();
    await expectLater(
      api.patch('/api/notifications/${FakeFixtures.otherEmployeeId}/read'),
      throwsA(_status<SessionExpiredException>(401)),
    );
    await expectLater(
      api.patch('/api/notifications/88/read'),
      throwsA(_status<SessionExpiredException>(401)),
    );
  });

  test('another user id is 404 and lists stay private', () async {
    final employee = FakeApiClient(latency: Duration.zero);
    await _login(employee, 'employee.demo');

    final notes = await employee.get('/api/notifications');
    expect(_ids(notes), ['77']);
    expect(_ids(notes), isNot(contains('88')));
    expect(_ids(notes), isNot(contains('n_1')));
    expect(_ids(notes), isNot(contains('n_20')));

    for (final id in ['88', 'n_1', 'n_20', 'missing']) {
      await expectLater(
        employee.patch('/api/notifications/$id/read'),
        throwsA(_status<NotFoundException>(404)),
        reason: id,
      );
    }

    final other = FakeApiClient(latency: Duration.zero);
    await _login(other, 'other.employee');
    final otherNotes = await other.get('/api/notifications');
    expect(_ids(otherNotes), ['88', 'n_20']);
    expect(_ids(otherNotes), isNot(contains('77')));
    expect(_ids(otherNotes), isNot(contains('n_1')));
    await expectLater(
      other.patch('/api/notifications/77/read'),
      throwsA(_status<NotFoundException>(404)),
    );

    final admin = FakeApiClient(latency: Duration.zero);
    await _login(admin, 'admin.demo');
    final adminNotes = await admin.get('/api/notifications');
    expect(_ids(adminNotes), ['n_1']);
    expect(_ids(adminNotes), isNot(contains('77')));
    expect(_ids(adminNotes), isNot(contains('88')));
    await expectLater(
      admin.patch('/api/notifications/77/read'),
      throwsA(_status<NotFoundException>(404)),
    );
  });
}

Future<void> _login(FakeApiClient api, String username) {
  return api.post(
    '/api/auth/login',
    body: {'username': username, 'password': 'x'},
    options: const ApiRequestOptions(authenticated: false),
  );
}

List<String> _ids(ApiResponse response) => [
  for (final item in (response.data as Map)['items'] as List)
    '${(item as Map)['id']}',
];

Matcher _status<T extends ApiException>(int status) =>
    isA<T>().having((error) => error.statusCode, 'statusCode', status);
