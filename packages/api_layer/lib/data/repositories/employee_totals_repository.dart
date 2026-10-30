import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/logging_interceptor.dart';
import '../../core/permissions/permission_service.dart';
import '../models/employee_totals_models.dart';

/// Read-only admin dashboard of employee totals.
///
/// Source selection (the provider does not branch):
/// 1. [EmployeeTotalsSource] comes from [ApiConfig.employeeTotalsSource]
///    (`--dart-define=EMPLOYEE_TOTALS_SOURCE=standalone|collections`).
///    Default is [EmployeeTotalsSource.standalone]:
///    `GET /api/admin/employee-totals` (🔶; this repo has no confirmed
///    `/api/admin` prefix). Optional `from` and `to` are `YYYY-MM-DD`.
/// 2. [EmployeeTotalsSource.collections] reads the `employeeTotals` array on
///    `GET /api/collections` (🔶 contract gap 14). `from` and `to` are not
///    sent: that array has no confirmed date filter. A `totals` object is
///    used only when that body includes one. `metrics` is not copied.
/// 3. When the server confirms a body, change the define (or the default on
///    [ApiConfig]). [fetch] keeps the same signature and the same DTO.
///    Production (vip2100.com) answers the standalone path with 404
///    `ROUTE_NOT_FOUND`. For a full admin that 404 falls back to the
///    collections array, so the default build still works there. A release
///    for production should pass `EMPLOYEE_TOTALS_SOURCE=collections` to skip
///    the extra 404 round trip (docs/release/BUILD.ar.md).
/// 4. A profile that is not full admin always calls the standalone path, even
///    if the define says `collections`, so the server returns 403 `FORBIDDEN`
///    and this method never returns an empty list in place of that denial.
///    There is no `employeeId` argument and none is added to the query.
///
/// Full admin only until DEF-002. The fake enforces the same gate.
abstract interface class EmployeeTotalsRepository {
  Future<EmployeeTotalsDto> fetch({String? from, String? to});
}

class RemoteEmployeeTotalsRepository implements EmployeeTotalsRepository {
  RemoteEmployeeTotalsRepository(
    this._api, {
    required PermissionService permissions,
    required EmployeeTotalsSource source,
  }) : _permissions = permissions,
       _source = source;

  final ApiClient _api;
  final PermissionService _permissions;
  final EmployeeTotalsSource _source;

  @override
  Future<EmployeeTotalsDto> fetch({String? from, String? to}) async {
    if (_permissions.canViewEmployeeTotals &&
        _source == EmployeeTotalsSource.collections) {
      return _fromCollections();
    }
    final Object? data;
    try {
      data = (await _api.get(
        ApiEndpoints.employeeTotals,
        query: _range(from, to),
      )).data;
    } on NotFoundException catch (error) {
      // Production has no standalone route (404 ROUTE_NOT_FOUND). A full
      // admin then reads the collections array, as with the define. Any other
      // 404, and every caller without the permission, keeps the error.
      if (error.code != 'ROUTE_NOT_FOUND' ||
          !_permissions.canViewEmployeeTotals) {
        rethrow;
      }
      return _fromCollections();
    }
    return runWithMoneyEndpoint(
      ApiEndpoints.employeeTotals,
      () => EmployeeTotalsDto.fromStandalone(data),
    );
  }

  /// `employeeTotals` on GET /api/collections. No date filter is sent.
  Future<EmployeeTotalsDto> _fromCollections() async {
    final data = (await _api.get(ApiEndpoints.collections)).data;
    return runWithMoneyEndpoint(
      ApiEndpoints.collections,
      () => EmployeeTotalsDto.fromCollectionsOverview(data),
    );
  }

  /// Standalone query only. `employeeId` is intentionally absent.
  static Map<String, dynamic>? _range(String? from, String? to) {
    final query = <String, dynamic>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    return query.isEmpty ? null : query;
  }
}
