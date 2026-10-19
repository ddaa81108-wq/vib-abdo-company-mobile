import 'common.dart';

/// GET /api/me user object. Fields are stored as the server sent them.
/// Access decisions are made only in [PermissionService].
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
    this.sectionAccess = const {},
    required this.mustChangePassword,
  });

  final String id;
  final String username;
  final String displayName;

  /// Server role string, uninterpreted. Only [PermissionService] matches it.
  final String role;
  final List<String> permissions;

  /// Server map of section key to access level, uninterpreted.
  final Map<String, String> sectionAccess;
  final bool mustChangePassword;

  factory UserProfile.fromJson(Json j) => UserProfile(
        id: str(j['id'] ?? j['userId']),
        username: str(j['username']),
        displayName: str(j['displayName'] ?? j['username']),
        role: str(j['role']),
        permissions: strList(j['permissions']),
        sectionAccess: _sectionAccess(j['sectionAccess']),
        mustChangePassword: boolOf(j['mustChangePassword']),
      );
}

Map<String, String> _sectionAccess(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is String) out['${entry.key}'] = value;
  }
  return Map.unmodifiable(out);
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
