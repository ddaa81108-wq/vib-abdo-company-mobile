import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/permissions/permission_service.dart';
import '../models/report_models.dart';

/// Read-only: daily smart reports + admin financial ledger and statement PDF.
abstract interface class ReportsRepository {
  Future<ReportsDto> daily({int limit = 30});
  Future<FinancialLedgerPage> financialLedger(
      {String? before, String? section, String? currency, String? q});

  /// Statement PDF. No permission code yet: full access only.
  Future<void> statementPdf({String? section, String? accountId});
}

class RemoteReportsRepository implements ReportsRepository {
  RemoteReportsRepository(this._api, this._permissions);
  final ApiClient _api;
  final PermissionService _permissions;

  void _requireFullAccess() {
    if (!_permissions.canReadPrivilegedFinance) {
      throw const ForbiddenException(code: 'FORBIDDEN', message: 'غير مصرح');
    }
  }

  @override
  Future<ReportsDto> daily({int limit = 30}) async => ReportsDto.fromData(
      (await _api.get(ApiEndpoints.reports, query: {'limit': limit})).data);

  @override
  Future<FinancialLedgerPage> financialLedger(
      {String? before,
      String? section,
      String? currency,
      String? q}) async {
    _requireFullAccess();
    return FinancialLedgerPage.fromData((await _api.get(
            ApiEndpoints.financialLedger,
            query: {
              'before': before,
              'section': section,
              'currency': currency,
              'q': q
            }))
        .data);
  }

  @override
  Future<void> statementPdf({String? section, String? accountId}) async {
    _requireFullAccess();
    await _api.get(ApiEndpoints.statementPdf, query: {
      'section': section,
      'accountId': accountId,
    });
  }
}
