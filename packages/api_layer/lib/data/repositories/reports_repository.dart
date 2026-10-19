import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/report_models.dart';

/// Read-only: daily smart reports, admin financial ledger, statement PDF.
abstract interface class ReportsRepository {
  Future<ReportsDto> daily({int limit = 30});
  Future<FinancialLedgerPage> financialLedger(
      {String? before, String? section, String? currency, String? q});

  /// Proposed GET /api/statements/pdf. The server has no PDF export.
  /// Callers must use this only when the client is the fake API.
  Future<StatementFile> statementPdf({String? section, String? accountId});
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

  @override
  Future<StatementFile> statementPdf({String? section, String? accountId}) async {
    final data = (await _api.get(ApiEndpoints.statementPdf, query: {
      if (section != null) 'section': section,
      if (accountId != null) 'accountId': accountId,
    }))
        .data;
    return StatementFile.fromData(data);
  }
}
