@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'employee without a treasury code cannot read or write treasury',
    () async {
      final api = FakeApiClient(latency: Duration.zero);
      final login = await api.post(
        '/api/auth/login',
        body: {'username': 'employee.demo', 'password': 'demo-only'},
      );
      final user = (login.data as Map)['user'] as Map;
      final codes = (user['permissions'] as List).map((code) => '$code');
      expect(user['role'], 'employee');
      expect(codes, isNot(contains('treasury.read')));
      expect(codes, isNot(contains('treasury.write')));

      await expectLater(
        api.get('/api/treasury'),
        throwsA(
          isA<ForbiddenException>().having(
            (error) => error.statusCode,
            'status',
            403,
          ),
        ),
      );
      await expectLater(
        api.post(
          '/api/treasury/cash-entries',
          body: {
            'requestId': 'permissions-negative-cash',
            'expectedVersion': 1,
            'direction': 'in',
            'amountUnits': 1,
            'description': 'blocked',
          },
        ),
        throwsA(isA<ForbiddenException>()),
      );

      expect((await api.get('/api/collections')).statusCode, 200);
    },
  );
}
