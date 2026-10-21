@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/state/employee_totals_provider.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

void main() {
  Future<ProviderContainer> signedIn(String username) async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    await layer.session.login(username: username, password: 'x');
    final container = ProviderContainer(
      overrides: [apiLayerProvider.overrideWithValue(layer)],
    );
    addTearDown(container.dispose);
    addTearDown(layer.dispose);
    return container;
  }

  test('employee provider state is forbidden, not an empty report', () async {
    final container = await signedIn('employee.demo');
    await expectLater(
      container.read(employeeTotalsProvider.future),
      throwsA(
        isA<ForbiddenException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.code, 'code', 'FORBIDDEN'),
      ),
    );
    final state = container.read(employeeTotalsStateProvider);
    expect(state, isA<EmployeeTotalsForbidden>());
    expect(state, isNot(isA<EmployeeTotalsReady>()));
    final forbidden = state as EmployeeTotalsForbidden;
    expect(forbidden.failure.isForbidden, isTrue);
    expect(forbidden.message, AppStrings.forbidden);
    expect(forbidden.failure.message, AppStrings.forbidden);
    expect(forbidden.message, isNot('هذا الإجراء للإدارة فقط'));
    expect(forbidden.failure.correlationId, isNull);
  });

  test('limited admin provider state is forbidden until DEF-002', () async {
    final container = await signedIn('limited.admin.demo');
    await expectLater(
      container.read(employeeTotalsProvider.future),
      throwsA(isA<ForbiddenException>()),
    );
    expect(
      container.read(employeeTotalsStateProvider),
      isA<EmployeeTotalsForbidden>(),
    );
  });
}
