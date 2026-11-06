import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/common.dart';
import '../models/directory_models.dart';

/// Login accounts, signup requests, the server audit log, and health.
///
/// Creating an account is a separate call. The repository does not decide
/// who may create one; the server does.
abstract interface class DirectoryRepository {
  Future<LoginAccountsPage> loginAccounts();

  Future<LoginAccount> createLoginAccount(Map<String, Object?> body);

  Future<LoginAccount> updateLoginAccount(
    String id,
    Map<String, Object?> body,
  );

  Future<List<AccountRequest>> accountRequests();

  Future<AccountRequest> decideAccountRequest(
    String id,
    Map<String, Object?> body,
  );

  Future<AuditPage> auditLog({String? before});

  Future<ServerHealth> health();
}

Map<String, Object?> _withRequest(Map<String, Object?> body) {
  if (body['requestId'] != null) return body;
  return {
    ...body,
    'requestId': 'dir-${DateTime.now().microsecondsSinceEpoch}',
  };
}

class RemoteDirectoryRepository implements DirectoryRepository {
  RemoteDirectoryRepository(this._api);
  final ApiClient _api;

  @override
  Future<LoginAccountsPage> loginAccounts() async {
    final data = (await _api.get(ApiEndpoints.users)).data;
    return LoginAccountsPage.fromData(data);
  }

  @override
  Future<LoginAccount> createLoginAccount(Map<String, Object?> body) async {
    final data = asJson(
      (await _api.post(ApiEndpoints.users, body: _withRequest(body))).data,
    );
    final user = data['user'];
    return LoginAccount.fromJson(user is Map ? asJson(user) : data);
  }

  @override
  Future<LoginAccount> updateLoginAccount(
    String id,
    Map<String, Object?> body,
  ) async {
    final data = asJson(
      (await _api.patch(ApiEndpoints.user(id), body: _withRequest(body))).data,
    );
    final user = data['user'];
    return LoginAccount.fromJson(user is Map ? asJson(user) : data);
  }

  @override
  Future<List<AccountRequest>> accountRequests() async {
    final data = asJson((await _api.get(ApiEndpoints.accountRequests)).data);
    final raw = data['items'];
    return [
      for (final item in raw is List ? raw : const [])
        if (item is Map) AccountRequest.fromJson(asJson(item)),
    ];
  }

  @override
  Future<AccountRequest> decideAccountRequest(
    String id,
    Map<String, Object?> body,
  ) async {
    final data = asJson(
      (await _api.post(
        ApiEndpoints.accountRequestDecision(id),
        body: _withRequest(body),
      ))
          .data,
    );
    final request = data['request'];
    return AccountRequest.fromJson(request is Map ? asJson(request) : data);
  }

  @override
  Future<AuditPage> auditLog({String? before}) async {
    final data = (await _api.get(
      ApiEndpoints.auditLog,
      query: {if (before != null) 'before': before},
    ))
        .data;
    return AuditPage.fromData(data);
  }

  @override
  Future<ServerHealth> health() async {
    final data = (await _api.get(ApiEndpoints.health)).data;
    return ServerHealth.fromData(data);
  }
}
