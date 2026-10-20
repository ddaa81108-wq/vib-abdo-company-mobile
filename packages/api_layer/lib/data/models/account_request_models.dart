import 'common.dart';

/// Admin account requests (`GET /api/account-requests`).
///
/// The path is already on the mobile client. The JSON shape is 🔶 proposed:
/// the backend has not confirmed these fields. Parsing is defensive and keeps
/// [AccountRequestDto.raw]. Nothing here is calculated.
///
/// Proposed item fields:
/// - `id`, `status` (`pending` | `approved` | `rejected`; other values stay raw)
/// - `version` (sent back as `expectedVersion` on the decision)
/// - `createdAt`, `decidedAt`
/// - `username` (alias `requestedUsername`)
/// - `displayName` (aliases `applicantName`, `name`)
/// - `phone`
/// - `requestedRole` (alias `role`; raw server text, not matched here)
/// - `note` (alias `reason`)
/// - `decisionNote`
/// - `allowedActions` (record-level gate; absent means the server did not send it)
///
/// This model has no password field. A temporary password must not be read
/// until the backend confirms one, and it would have to be redacted.
class AccountRequestDto {
  const AccountRequestDto({
    required this.id,
    required this.status,
    this.version,
    this.createdAt,
    this.decidedAt,
    this.username,
    this.displayName,
    this.phone,
    this.requestedRole,
    this.note,
    this.decisionNote,
    this.allowedActions,
    this.raw = const {},
  });

  final String id;

  /// Server value, kept as sent. Proposed known values: see [knownStatus].
  final String status;
  final int? version;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String? username;
  final String? displayName;
  final String? phone;

  /// 🔶 Proposed. Not a server role flag; only PermissionService matches roles.
  final String? requestedRole;
  final String? note;
  final String? decisionNote;

  /// 🔶 Proposed. Null when the key is absent (the caller uses the management
  /// gate). An empty list means the server sent no actions.
  final List<String>? allowedActions;
  final Json raw;

  /// 🔶 Proposed status names. Unknown or missing server text -> null.
  AccountRequestStatus? get knownStatus =>
      AccountRequestStatus.fromWire(status);

  factory AccountRequestDto.fromJson(Json j) => AccountRequestDto(
    id: str(j['id']),
    status: str(j['status']),
    version: intOrNull(j['version']),
    createdAt: dateOrNull(j['createdAt']),
    decidedAt: dateOrNull(j['decidedAt']),
    username: strOrNull(j['username'] ?? j['requestedUsername']),
    displayName: strOrNull(j['displayName'] ?? j['applicantName'] ?? j['name']),
    phone: strOrNull(j['phone']),
    requestedRole: strOrNull(j['requestedRole'] ?? j['role']),
    note: strOrNull(j['note'] ?? j['reason']),
    decisionNote: strOrNull(j['decisionNote']),
    allowedActions: j.containsKey('allowedActions')
        ? strList(j['allowedActions'])
        : null,
    raw: j,
  );
}

/// 🔶 Proposed wire values for `status`. Not confirmed by the backend.
enum AccountRequestStatus {
  pending,
  approved,
  rejected;

  static AccountRequestStatus? fromWire(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return null;
  }
}

/// 🔶 Proposed wire values for `decision`. Same names as collection decisions,
/// not confirmed for this path.
enum AccountRequestDecision {
  approve,
  reject;

  static AccountRequestDecision? fromWire(Object? value) {
    for (final decision in values) {
      if (decision.name == value) return decision;
    }
    return null;
  }
}

/// `GET /api/account-requests` page. Pagination keys match the rest of the API
/// (`items`, `nextCursor`, `hasMore`). 🔶 Whether this path pages at all is
/// unconfirmed; missing keys mean a single page.
class AccountRequestsPage {
  const AccountRequestsPage({required this.page});

  final Paged<AccountRequestDto> page;

  List<AccountRequestDto> get items => page.items;

  factory AccountRequestsPage.fromData(Object? data) => AccountRequestsPage(
    page: Paged.fromData(data, AccountRequestDto.fromJson),
  );
}
