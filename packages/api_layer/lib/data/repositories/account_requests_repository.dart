import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/idempotency.dart';
import '../models/account_request_models.dart';
import '../models/common.dart';

/// Account requests an admin decides (`/api/account-requests`).
///
/// The server enforces access. Hide the action unless
/// `PermissionService.canDo(ManagementAction.accountRequestsDecide)`
/// (`users.manage`, 🔶 proposed) or the user has full access. This class does
/// not check that code — hiding a control is not enforcement.
///
/// There is no create call. The app has no self-signup, and no create path is
/// listed for this client.
abstract interface class AccountRequestsRepository {
  /// 🔶 `status` is a proposed filter (`pending` | `approved` | `rejected`).
  /// It is sent only when the caller passes it. `limit` and `cursor` follow
  /// the shared pagination query.
  Future<AccountRequestsPage> list({
    String? cursor,
    int limit = 100,
    String? status,
  });

  /// [meta] must carry `expectedVersion` = the request's `version`.
  /// 🔶 That version field, `decision`, and `note` are proposed for this path.
  /// The same `requestId` is reused when the user retries the same decision.
  Future<MutationAck> decide(
    String id,
    AccountRequestDecision decision, {
    String? note,
    required MutationMeta meta,
  });
}

class RemoteAccountRequestsRepository implements AccountRequestsRepository {
  RemoteAccountRequestsRepository(this._api);

  final ApiClient _api;

  /// 🔶 `expectedVersion` is not confirmed for this path. This client requires
  /// it, as it does for other decision endpoints, so two concurrent decisions
  /// cannot both be sent with no version.
  static Json _versioned(MutationMeta meta) {
    if (meta.expectedVersion == null) {
      throw ArgumentError(
        'expectedVersion is required for account-request decisions',
      );
    }
    return meta.toBody();
  }

  @override
  Future<AccountRequestsPage> list({
    String? cursor,
    int limit = 100,
    String? status,
  }) async {
    final res = await _api.get(
      ApiEndpoints.accountRequests,
      query: {
        'limit': limit,
        'cursor': cursor,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return AccountRequestsPage.fromData(res.data);
  }

  @override
  Future<MutationAck> decide(
    String id,
    AccountRequestDecision decision, {
    String? note,
    required MutationMeta meta,
  }) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('account request id is required');
    }
    final body = <String, dynamic>{
      ..._versioned(meta),
      'decision': decision.name,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await _api.post(
      ApiEndpoints.accountRequestDecision(id),
      body: body,
    );
    return MutationAck.fromData(res.data);
  }
}
