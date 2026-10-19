import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/report_models.dart';

/// Read-only: daily smart reports + admin financial ledger.
abstract interface class ReportsRepository {
  Future<ReportsDto> daily({int limit = 30});
  Future<FinancialLedgerPage> financialLedger(
      {String? before, String? section, String? currency, String? q});
}

class RemoteReportsRepository implements ReportsRepository {
  RemoteReportsRepository(this._api);
  final ApiClient _api;

  @override
  Future<ReportsDto> daily({int limit = 30}) async => ReportsDto.fromData(
      (await _api.get(ApiEndpoints.reports, query: {'limit': limit})).data);

  @override
  Future<FinancialLedgerPage> financialLedger(
          {String? before,
          String? section,
          String? currency,
          String? q}) async =>
      FinancialLedgerPage.fromData((await _api.get(ApiEndpoints.financialLedger,
              query: {
            'before': before,
            'section': section,
            'currency': currency,
            'q': q
          }))
          .data);
}
