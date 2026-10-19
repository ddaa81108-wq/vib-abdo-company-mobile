import 'common.dart';

/// GET /api/me -> { ok:true, data: { user: { id?, username, displayName, role, permissions[], mustChangePassword } } }
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
    required this.mustChangePassword,
  });

  final String id;
  final String username;
  final String displayName;
  final String role; // "admin" or other (server-reported)
  final List<String> permissions;
  final bool mustChangePassword;

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromJson(Json j) => UserProfile(
        id: str(j['id'] ?? j['userId']),
        username: str(j['username']),
        displayName: str(j['displayName'] ?? j['username']),
        role: str(j['role']),
        permissions: strList(j['permissions']),
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
