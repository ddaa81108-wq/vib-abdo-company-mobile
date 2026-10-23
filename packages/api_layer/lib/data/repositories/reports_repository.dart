import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/logging_interceptor.dart';
import '../models/report_models.dart';

/// Read-only: daily smart reports, admin financial ledger, statement PDF.
abstract interface class ReportsRepository {
  Future<ReportsDto> daily({int limit = 30});

  /// [sectionKey] is the contract ledger section (`customer_debts`, …).
  /// It is sent as the query `section`, which is the name
  /// `GET /api/financial-ledger` documents. No other list operation in the
  /// contract documents a section filter. [section] is that same query as
  /// raw text. When both are set, [sectionKey] is sent.
  ///
  /// P-14 api (G-12).
  Future<FinancialLedgerPage> financialLedger({
    String? before,
    String? section,
    FinancialLedgerSectionKey? sectionKey,
    String? currency,
    String? q,
  });

  /// Proposed GET /api/statements/pdf. The server has no PDF export.
  /// Callers must use this only when the client is the fake API.
  Future<StatementFile> statementPdf({String? section, String? accountId});
}

class RemoteReportsRepository implements ReportsRepository {
  RemoteReportsRepository(this._api);
  final ApiClient _api;

  @override
  Future<ReportsDto> daily({int limit = 30}) async {
    const path = ApiEndpoints.reports;
    final data = (await _api.get(path, query: {'limit': limit})).data;
    return runWithMoneyEndpoint(path, () => ReportsDto.fromData(data));
  }

  @override
  Future<FinancialLedgerPage> financialLedger({
    String? before,
    String? section,
    FinancialLedgerSectionKey? sectionKey,
    String? currency,
    String? q,
  }) async {
    const path = ApiEndpoints.financialLedger;
    final data = (await _api.get(path, query: {
      'before': before,
      'section': _financialLedgerSection(sectionKey, section),
      'currency': currency,
      'q': q,
    }))
        .data;
    return runWithMoneyEndpoint(
      path,
      () => FinancialLedgerPage.fromData(data),
    );
  }

  @override
  Future<StatementFile> statementPdf(
      {String? section, String? accountId}) async {
    final data = (await _api.get(ApiEndpoints.statementPdf, query: {
      if (section != null) 'section': section,
      if (accountId != null) 'accountId': accountId,
    }))
        .data;
    return StatementFile.fromData(data);
  }
}

/// Wire value for `GET /api/financial-ledger?section`. A known [sectionKey]
/// wins. [FinancialLedgerSectionKey.unknown] is not a query the contract
/// names, so the raw [section] string is used instead.
String? _financialLedgerSection(
  FinancialLedgerSectionKey? sectionKey,
  String? section,
) {
  if (sectionKey != null &&
      sectionKey != FinancialLedgerSectionKey.unknown &&
      sectionKey.wire.isNotEmpty) {
    return sectionKey.wire;
  }
  return section;
}
