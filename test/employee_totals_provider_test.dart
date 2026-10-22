import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/state/employee_totals_provider.dart';

void main() {
  Future<({ApiLayer layer, ProviderContainer container})> signedIn(
    String username,
  ) async {
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
    return (layer: layer, container: container);
  }

  test('admin provider exposes the server totals', () async {
    final harness = await signedIn('admin.demo');
    harness.container.read(employeeTotalsQueryProvider.notifier).state =
        const EmployeeTotalsQuery(from: '2026-10-01', to: '2026-10-31');

    final report = await harness.container.read(employeeTotalsProvider.future);
    expect(report.from, '2026-10-01');
    expect(report.to, '2026-10-31');
    expect(report.items.single.employeeId, 'u_12');
    expect(report.items.single.employeeName, 'موظف استلام تجريبي');
    expect(report.totals.collectedUnits?.units, 0);
    expect(report.totals.pendingUnits?.units, 100);
    expect(report.items.single.cashOutstandingUnits?.units, 250);

    final state = harness.container.read(employeeTotalsStateProvider);
    expect(state, isA<EmployeeTotalsReady>());
    final ready = state as EmployeeTotalsReady;
    expect(ready.report.totals.pendingUnits, report.totals.pendingUnits);
    expect(ready.report.items.single.collectedUnits?.units, 0);
  });

  test('loading then a server error are distinct from forbidden', () async {
    final harness = await signedIn('admin.demo');
    final fake = harness.layer.client as FakeApiClient;
    final gate = Completer<void>();
    fake.pauseEmployeeTotals = gate;
    fake.failEmployeeTotalsRemaining = 1;

    final loading = harness.container.read(employeeTotalsStateProvider);
    expect(loading, isA<EmployeeTotalsLoading>());

    gate.complete();
    await expectLater(
      harness.container.read(employeeTotalsProvider.future),
      throwsA(isA<ServerException>()),
    );
    expect(
      harness.container.read(employeeTotalsStateProvider),
      isA<EmployeeTotalsFailure>(),
    );
    expect(
      harness.container.read(employeeTotalsStateProvider),
      isNot(isA<EmployeeTotalsForbidden>()),
    );
  });
}
