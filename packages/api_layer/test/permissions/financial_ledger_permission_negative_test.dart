@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'employee and limited admin get 403 PERMISSION_DENIED on the ledger section filter',
    () async {
      for (final username in ['employee.demo', 'limited.admin.demo']) {
        final api = ApiLayer.create(
          config: const ApiConfig(
            baseUrl: 'https://fake.invalid',
            useFakeApi: true,
          ),
          fakeLatency: Duration.zero,
        );
        addTearDown(api.dispose);
        await api.session.login(username: username, password: 'x');

        await expectLater(
          api.reports.financialLedger(
            sectionKey: FinancialLedgerSectionKey.customerDebts,
          ),
          throwsA(
            isA<ForbiddenException>()
                .having((error) => error.statusCode, 'status', 403)
                .having((error) => error.code, 'code', 'PERMISSION_DENIED'),
          ),
        );
      }
    },
  );
}
