import 'common.dart';

/// GET /api/me -> { ok:true, data: { user: { id?, username, displayName, role, permissions[],
///   sectionAccess{ customerDebts: none|read|manage, ... }, mustChangePassword } } }
/// sectionAccess was observed on GET /api/users (per API contract); presence on /api/me to confirm.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
    this.sectionAccess = const {},
    this.fullAccess,
    required this.mustChangePassword,
  });

  final String id;
  final String username;
  final String displayName;

  /// Server role string, uninterpreted. Matched ONLY in PermissionService (exact value).
  final String? role;
  final List<String> permissions;
  final Map<String, String> sectionAccess;
  final bool mustChangePassword;

  /// 🔶 PROPOSED explicit server flag (`fullAccess`, alias `isSuperuser`). null = not sent.
  /// When sent (true/false) it takes precedence over the role (PermissionService).
  final bool? fullAccess;

  factory UserProfile.fromJson(Json j) => UserProfile(
        id: str(j['id'] ?? j['userId']),
        username: str(j['username']),
        displayName: str(j['displayName'] ?? j['username']),
        role: j['role'] is String ? j['role'] as String : null,
        permissions: strList(j['permissions']),
        sectionAccess: {
          for (final e in asJson(j['sectionAccess']).entries)
            e.key: '${e.value}'
        },
        fullAccess: _boolOrNull(j['fullAccess'] ?? j['isSuperuser']),
        mustChangePassword: boolOf(j['mustChangePassword']),
      );
}

class MeResponse {
  const MeResponse({required this.user});
  final UserProfile user;
  factory MeResponse.fromData(Object? data) {
    final d = asJson(data);
    return MeResponse(
        user: UserProfile.fromJson(d['user'] is Map ? asJson(d['user']) : d));
  }
}

bool? _boolOrNull(Object? v) => v is bool ? v : null;
