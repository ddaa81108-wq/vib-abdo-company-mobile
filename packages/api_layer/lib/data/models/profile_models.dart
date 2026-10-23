import 'common.dart';

/// GET /api/me -> { ok:true, data: { user: { id, username, displayName, role,
///   isOwner, permissions[], mustChangePassword } } }
///
/// Observed `/api/me` omits `sectionAccess`. Null (missing key or JSON null)
/// means absent, so permission codes alone grant a section. A present map,
/// including `{}`, keeps the current rule: a missing entry is none. A
/// non-object value is stored as `{}` and does not widen access.
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
        sectionAccess: sectionAccessFromJson(j['sectionAccess']),
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

/// `sectionAccess` from `/api/me`.
///
/// A missing key or JSON null is absent: permission codes alone grant a section.
/// A JSON object, including `{}`, is present. Any other value (string, list,
/// number) is an empty map, so a missing section key stays `none`.
Map<String, String>? sectionAccessFromJson(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) return const {};
  return {for (final e in raw.entries) '${e.key}': '${e.value}'};
}
