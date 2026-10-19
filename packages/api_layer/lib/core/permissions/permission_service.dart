import 'package:flutter/foundation.dart';

import 'permission_codes.dart';

/// Role the server sent, after the only exact string match in the app.
enum AccountRole { admin, employee, unknown }

/// UI gate built only from the server profile.
///
/// The role string is matched here and nowhere else. An unknown or missing
/// role grants nothing. A non-admin is limited to `permissions` plus
/// `sectionAccess`. A write needs both the write code and section access
/// `manage`. An admin with a non-empty permission list is limited to that
/// list; an empty list keeps the unrestricted role flag.
/// This is not enforcement. The server still rejects every request.
class PermissionService extends ChangeNotifier {
  static const roleAdmin = 'admin';
  static const roleEmployee = 'employee';
  static const accessView = 'view';
  static const accessManage = 'manage';

  Set<Permission> _granted = const {};
  Set<String> _rawCodes = const {};
  Map<String, String> _sectionAccess = const {};
  AccountRole _accountRole = AccountRole.unknown;
  bool _unrestricted = false;
  String? _version;

  Set<Permission> get granted => _granted;
  AccountRole get accountRole => _accountRole;
  String? get version => _version;

  void applyFromServer({
    required String role,
    required Iterable<String> permissions,
    Map<String, String> sectionAccess = const {},
    String? version,
  }) {
    _version = version;
    _accountRole = _matchRole(role);
    final codes = permissions.where((code) => code.isNotEmpty).toSet();

    if (_accountRole == AccountRole.unknown) {
      _granted = const {};
      _rawCodes = const {};
      _sectionAccess = const {};
      _unrestricted = false;
      notifyListeners();
      return;
    }

    if (_accountRole == AccountRole.admin && codes.isEmpty) {
      _unrestricted = true;
      _granted = Permission.values.toSet();
      _rawCodes = {for (final permission in Permission.values) permission.code};
      _sectionAccess = {
        for (final section in SectionKey.values) section.key: accessManage,
      };
      notifyListeners();
      return;
    }

    _unrestricted = false;
    _rawCodes = codes;
    _granted = codes.map(Permission.fromCode).whereType<Permission>().toSet();
    _sectionAccess = Map<String, String>.unmodifiable(sectionAccess);
    notifyListeners();
  }

  AccountRole _matchRole(String role) {
    if (role == roleAdmin) return AccountRole.admin;
    if (role == roleEmployee) return AccountRole.employee;
    return AccountRole.unknown;
  }

  /// `view` or `manage` from the server. Any other value is no access.
  String? _level(SectionKey section) {
    final value = _sectionAccess[section.key];
    if (value == accessView || value == accessManage) return value;
    return null;
  }

  bool has(Permission permission) => _granted.contains(permission);
  bool hasAny(Iterable<Permission> permissions) =>
      permissions.any(_granted.contains);
  bool hasRaw(String code) => _rawCodes.contains(code);

  bool canRead(SectionKey section) =>
      has(section.read) && _level(section) != null;

  bool canWrite(SectionKey section) {
    final write = section.write;
    if (write == null || !has(write)) return false;
    return _level(section) == accessManage;
  }

  bool canDo(AdminOnlyAction _) => _unrestricted;

  /// Sections in server menu order that this profile may see.
  List<SectionKey> get readableSections =>
      SectionKey.values.where(canRead).toList(growable: false);

  /// Sections whose write control may be shown.
  List<SectionKey> get writableSections =>
      SectionKey.values.where(canWrite).toList(growable: false);

  /// Record-level gate. An explicit server `allowedActions` list wins.
  /// Otherwise the section write rule applies. The server still decides.
  bool canOnRecord({
    required String action,
    List<String>? allowedActions,
    required SectionKey section,
  }) {
    if (allowedActions != null) return allowedActions.contains(action);
    return canWrite(section);
  }

  void clear() {
    _granted = const {};
    _rawCodes = const {};
    _sectionAccess = const {};
    _accountRole = AccountRole.unknown;
    _unrestricted = false;
    _version = null;
    notifyListeners();
  }
}
