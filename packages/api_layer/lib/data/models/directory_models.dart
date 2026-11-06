import 'common.dart';

/// One login account from `GET /api/users`. Not a collections employee card.
class LoginAccount {
  const LoginAccount({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isOwner,
    required this.isActive,
    required this.version,
    required this.email,
    required this.mustChangePassword,
    required this.permissions,
    required this.sectionAccess,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? role;

  /// Boolean true from the server only.
  final bool isOwner;
  final bool isActive;
  final int? version;
  final String? email;
  final bool mustChangePassword;
  final List<String> permissions;
  final Map<String, String> sectionAccess;

  factory LoginAccount.fromJson(Json j) => LoginAccount(
        id: str(j['id']),
        username: str(j['username']),
        displayName: strOrNull(j['displayName']),
        role: j['role'] is String ? j['role'] as String : null,
        isOwner: boolOf(j['isOwner']),
        isActive: j['isActive'] == false ? false : true,
        version: j['version'] is int ? j['version'] as int : null,
        email: j['email'] is String ? j['email'] as String : null,
        mustChangePassword: boolOf(j['mustChangePassword']),
        permissions: strList(j['permissions']),
        sectionAccess: {
          for (final entry in (j['sectionAccess'] is Map
                  ? j['sectionAccess'] as Map
                  : const <Object?, Object?>{})
              .entries)
            '${entry.key}': '${entry.value}',
        },
      );
}

class LoginAccountsPage {
  const LoginAccountsPage({
    required this.items,
    required this.assignablePermissions,
  });

  final List<LoginAccount> items;
  final List<String> assignablePermissions;

  factory LoginAccountsPage.fromData(Object? data) {
    final json = asJson(data);
    final raw = json['items'];
    return LoginAccountsPage(
      items: [
        for (final item in raw is List ? raw : const [])
          if (item is Map) LoginAccount.fromJson(asJson(item)),
      ],
      assignablePermissions: strList(json['assignablePermissions']),
    );
  }
}

/// A Google signup waiting for an admin decision. Approving it is not
/// the same as creating a session.
class AccountRequest {
  const AccountRequest({
    required this.id,
    required this.provider,
    required this.email,
    required this.displayName,
    required this.status,
    required this.version,
    required this.decisionNote,
    required this.requestedAt,
  });

  final String id;
  final String? provider;
  final String? email;
  final String? displayName;
  final String? status;
  final int? version;
  final String? decisionNote;
  final String? requestedAt;

  bool get pending => status == 'pending';

  factory AccountRequest.fromJson(Json j) => AccountRequest(
        id: str(j['id']),
        provider: j['provider'] is String ? j['provider'] as String : null,
        email: j['email'] is String ? j['email'] as String : null,
        displayName:
            j['displayName'] is String ? j['displayName'] as String : null,
        status: j['status'] is String ? j['status'] as String : null,
        version: j['version'] is int ? j['version'] as int : null,
        decisionNote:
            j['decisionNote'] is String ? j['decisionNote'] as String : null,
        requestedAt:
            j['requestedAt'] is String ? j['requestedAt'] as String : null,
      );
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.outcome,
    required this.actorName,
    required this.actorUsername,
    required this.createdAt,
    required this.entityType,
  });

  final String id;
  final String action;
  final String? outcome;
  final String? actorName;
  final String? actorUsername;
  final String? createdAt;
  final String? entityType;

  /// True only when the server action itself names a login or a session.
  bool get isSessionAction {
    final name = action.toLowerCase();
    return name.startsWith('auth.') ||
        name.startsWith('session.') ||
        name.contains('login');
  }

  factory AuditEvent.fromJson(Json j) => AuditEvent(
        id: str(j['id']),
        action: str(j['action']),
        outcome: j['outcome'] is String ? j['outcome'] as String : null,
        actorName: j['actorName'] is String ? j['actorName'] as String : null,
        actorUsername:
            j['actorUsername'] is String ? j['actorUsername'] as String : null,
        createdAt: j['createdAt'] is String ? j['createdAt'] as String : null,
        entityType:
            j['entityType'] is String ? j['entityType'] as String : null,
      );
}

class AuditPage {
  const AuditPage({required this.items, required this.nextBefore});

  final List<AuditEvent> items;
  final String? nextBefore;

  factory AuditPage.fromData(Object? data) {
    final json = asJson(data);
    final raw = json['items'];
    final cursor = json['nextBefore'];
    return AuditPage(
      items: [
        for (final item in raw is List ? raw : const [])
          if (item is Map) AuditEvent.fromJson(asJson(item)),
      ],
      nextBefore: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}

class ServerHealth {
  const ServerHealth({
    required this.status,
    required this.apiVersion,
    required this.schemaVersion,
    required this.uiVersion,
  });

  final String? status;
  final String? apiVersion;
  final String? schemaVersion;
  final String? uiVersion;

  factory ServerHealth.fromData(Object? data) {
    final json = asJson(data);
    return ServerHealth(
      status: json['status'] is String ? json['status'] as String : null,
      apiVersion:
          json['apiVersion'] is String ? json['apiVersion'] as String : null,
      schemaVersion: json['schemaVersion'] is String
          ? json['schemaVersion'] as String
          : null,
      uiVersion:
          json['uiVersion'] is String ? json['uiVersion'] as String : null,
    );
  }
}
