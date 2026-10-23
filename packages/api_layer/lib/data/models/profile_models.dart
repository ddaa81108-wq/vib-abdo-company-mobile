import 'common.dart';

/// GET /api/me -> { ok:true, data: { user: { id, username, displayName, role,
///   isOwner, permissions[], mustChangePassword } } }
///
/// Observed `/api/me` omits `sectionAccess`. Null means the key was absent, so
/// permission codes alone grant a section. A present map, including `{}`,
/// keeps the current rule: a missing entry is none.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
    this.sectionAccess,
    this.fullAccess,
    required this.mustChangePassword,
  });

  final String id;
  final String username;
  final String displayName;

  /// Server role string, uninterpreted. Matched ONLY in PermissionService (exact value).
  final String? role;
  final List<String> permissions;

  /// Null when the server omitted `sectionAccess`.
  final Map<String, String>? sectionAccess;
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
        sectionAccess: _sectionAccess(j['sectionAccess']),
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

/// A missing or non-object value is absent. An object, including `{}`, is present.
Map<String, String>? _sectionAccess(Object? raw) {
  if (raw is! Map) return null;
  return {for (final e in raw.entries) '${e.key}': '${e.value}'};
}
