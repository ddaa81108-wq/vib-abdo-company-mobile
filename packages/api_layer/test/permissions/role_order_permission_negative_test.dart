@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

import '../phase7/phase7_harness.dart';

/// P7-04. Real session and client. The fake server (or the scripted transport
/// for the `/api/me` reload) is the only stand-in. The matrix names
/// `GET /api/auth/me`; this client reads `GET /api/me`.
void main() {
  const leaks = ['موظف آخر تجريبي', '0910000000', '10635', '555-0100'];

  for (final username in [
    'employee.demo',
    'other.employee',
    'limited.admin',
    'flag.admin',
    'guest',
  ]) {
    test(
      'P7-04 $username: 401 then 404 then 403, with no leaked fields',
      () async {
        final layer = await _open();
        try {
          final loggedOut = await _capture(
            layer.client.get('${ApiEndpoints.users}/u_20'),
          );
          expect(loggedOut, isA<SessionExpiredException>());
          expect(loggedOut.statusCode, 401);
          _noLeak(loggedOut, leaks);

          await layer.session.login(username: username, password: 'demo-only');
          final missing = await _capture(
            layer.client.get('${ApiEndpoints.users}/missing-user'),
          );
          expect(missing, isA<NotFoundException>());
          expect(missing.statusCode, 404);
          _noLeak(missing, leaks);

          final catalog = await _capture(layer.client.get(ApiEndpoints.users));
          expect(catalog, isA<ForbiddenException>());
          expect(catalog.statusCode, 403);
          _noLeak(catalog, leaks);

          final companies = await _capture(
            layer.client.get(ApiEndpoints.accounts('companies')),
          );
          expect(companies, isA<ForbiddenException>());
          _noLeak(companies, leaks);
        } finally {
          await layer.dispose();
        }
      },
    );
  }

  test(
    'P7-04 admin: 401 then 404, and the directory is allowed after login',
    () async {
      final layer = await _open();
      try {
        final loggedOut = await _capture(
          layer.client.get('${ApiEndpoints.users}/u_20'),
        );
        expect(loggedOut, isA<SessionExpiredException>());
        expect(loggedOut.statusCode, 401);
        _noLeak(loggedOut, const ['موظف آخر تجريبي']);

        await layer.session.login(username: 'admin.demo', password: 'demo-only');
        final missing = await _capture(
          layer.client.get('${ApiEndpoints.users}/missing-user'),
        );
        expect(missing, isA<NotFoundException>());
        expect(missing.statusCode, 404);
        _noLeak(missing, const ['موظف آخر تجريبي', '0910000000']);

        final catalog = await layer.client.get(ApiEndpoints.users);
        expect(catalog.statusCode, 200);
        expect(catalog.dataMap['items'], isA<List<Object?>>());
      } finally {
        await layer.dispose();
      }
    },
  );

  test(
    'P7-04 permissions come from GET /api/me and change when that body changes',
    () async {
      final harness = await Phase7Harness.open();
      try {
        harness.transport.user = {
          'id': 'u_12',
          'username': 'employee@example.invalid',
          'displayName': 'موظف استلام تجريبي',
          'role': 'employee',
          'permissions': ['collections.read', 'debts.read'],
          'sectionAccess': {
            'customerDebts': 'read',
            'companyDebts': 'none',
            'treasury': 'none',
          },
          'mustChangePassword': false,
        };
        await harness.login(username: 'employee.demo', password: 'demo-only');
        expect(harness.layer.permissions.fullAccess, isFalse);
        expect(
          harness.layer.permissions.canRead(SectionKey.customers),
          isTrue,
        );
        expect(
          harness.layer.permissions.canRead(SectionKey.companies),
          isFalse,
        );
        expect(
          harness.layer.permissions.canRaw('collections.read'),
          isTrue,
        );

        harness.transport.user = {
          'id': 'u_12',
          'username': 'employee@example.invalid',
          'displayName': 'موظف استلام تجريبي',
          'role': 'employee',
          'permissions': ['collections.read'],
          'sectionAccess': {
            'customerDebts': 'none',
            'companyDebts': 'none',
          },
          'mustChangePassword': false,
        };
        await harness.layer.session.reloadProfileAndPermissions();
        expect(
          harness.layer.permissions.canRead(SectionKey.customers),
          isFalse,
        );
        expect(
          harness.layer.permissions.canRaw('debts.read'),
          isFalse,
        );
        expect(
          harness.layer.permissions.canRaw('collections.read'),
          isTrue,
        );
        expect(
          harness.transport.matching('GET', ApiEndpoints.me),
          isNotEmpty,
        );
        expect(
          harness.transport.calls.map((call) => call.path),
          isNot(contains('/api/auth/me')),
        );
      } finally {
        await harness.dispose();
      }
    },
  );
}

Future<ApiLayer> _open() {
  return Future.value(
    ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    ),
  );
}

Future<ApiException> _capture(Future<Object?> future) async {
  try {
    await future;
  } on ApiException catch (error) {
    return error;
  }
  fail('expected an ApiException');
}

void _noLeak(ApiException error, List<String> leaks) {
  for (final leak in leaks) {
    expect(error.message, isNot(contains(leak)));
    expect(error.toString(), isNot(contains(leak)));
    expect('${error.details}', isNot(contains(leak)));
  }
}
