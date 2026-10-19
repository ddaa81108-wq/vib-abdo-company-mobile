import 'package:flutter/foundation.dart';

import 'permission_codes.dart';

/// Holds permissions RETURNED BY THE SERVER (GET /api/me: `role`, `permissions[]`,
/// `sectionAccess{}`, and the proposed 🔶 `fullAccess` flag) for UI gating only.
/// NOT a security boundary: the server enforces every request.
///
/// FINAL PM DECISION (contract v0.2.3):
/// - The server `role` is treated as an explicit server flag ONLY HERE, by EXACT
///   (case-sensitive, untrimmed) match with the real system's values `"admin"` /
///   `"employee"` (frontend `role === "admin"`, analysis 01 §4.2 / 01b §1.1).
///   No role comparison anywhere else (guarded by test/permission_service_test.dart).
/// - Unknown or missing role grants NOTHING (even if codes are present).
/// - Precedence: (1) `fullAccess` if the server sends it (true or false);
///   (2) for an admin, an explicit non-empty `permissions[]` or `sectionAccess{}` applies
///   (same rules as an employee); (3) admin with both empty -> unrestricted (role flag).
/// - Disallowed buttons/tiles/sections are HIDDEN, never shown disabled.
/// - For sections in `sectionAccess` BOTH are required (open question §15, priority):
///     read  = `<section>.read`  AND sectionAccess != none
///     write = `<section>.write` AND sectionAccess == manage
///   Collections (not in `sectionAccess`) use the codes only. Missing/unknown entry = none.
class PermissionService extends ChangeNotifier {
  /// Exact role values of the real system. Matched ONLY in this class.
  static const adminRoleValue = 'admin';
  static const employeeRoleValue = 'employee';

  Set<Permission> _granted = const {};
  Set<String> _rawCodes = const {};
  Map<String, SectionAccessLevel> _sectionAccess = const {};
  bool _fullAccess = false;
  AccountRole _role = AccountRole.unknown;
  String? _version;

  Set<Permission> get granted => _granted;

  /// True when everything is allowed (explicit `fullAccess` or the admin role flag).
  bool get fullAccess => _fullAccess;
  AccountRole get role => _role;
  String? get version => _version;

  void applyFromServer(
    Iterable<String> codes, {
    required String? role,
    Map<String, String> sectionAccess = const {},
    bool? fullAccess,
    String? version,
  }) {
    _version = version;
    _role = role == adminRoleValue
        ? AccountRole.admin
        : (role == employeeRoleValue
            ? AccountRole.employee
            : AccountRole.unknown);
    final rawCodes = codes.where((c) => c.isNotEmpty).toSet();

    if (_role == AccountRole.unknown) {
      _setNothing();
    } else if (fullAccess != null) {
      _setLists(rawCodes, sectionAccess,
          full: fullAccess); // (1) explicit flag wins
    } else if (_role == AccountRole.admin &&
        rawCodes.isEmpty &&
        sectionAccess.isEmpty) {
      _setLists(const {}, const {}, full: true); // (3) role flag
    } else {
      _setLists(rawCodes, sectionAccess,
          full: false); // (2) explicit lists / employee
    }
    notifyListeners();
  }

  void _setNothing() {
    _rawCodes = const {};
    _granted = const {};
    _sectionAccess = const {};
    _fullAccess = false;
  }

  void _setLists(Set<String> rawCodes, Map<String, String> sectionAccess,
      {required bool full}) {
    _rawCodes = rawCodes;
    _granted =
        rawCodes.map(Permission.fromCode).whereType<Permission>().toSet();
    _sectionAccess = {
      for (final e in sectionAccess.entries)
        e.key: SectionAccessLevel.parse(e.value)
    };
    _fullAccess = full;
  }

  /// Single code check.
  bool can(Permission p) => _fullAccess || _granted.contains(p);
  bool canAny(Iterable<Permission> ps) =>
      _fullAccess || ps.any(_granted.contains);
  bool canRaw(String code) => _fullAccess || _rawCodes.contains(code);

  /// Server-reported access level; sections outside `sectionAccess` return null.
  SectionAccessLevel? accessLevel(SectionKey s) => s.accessKey == null
      ? null
      : (_sectionAccess[s.accessKey] ?? SectionAccessLevel.none);

  bool canRead(SectionKey s) {
    if (_fullAccess) return true;
    if (!_granted.contains(s.read)) return false;
    final level = accessLevel(s);
    return level == null || level != SectionAccessLevel.none;
  }

  bool canWrite(SectionKey s) {
    final w = s.write;
    if (w == null) {
      return false; // read-only section (reports), even with full access
    }
    if (_fullAccess) return true;
    if (!_granted.contains(w)) return false;
    final level = accessLevel(s);
    return level == null || level == SectionAccessLevel.manage;
  }

  /// Day finalize in purchases: `purchases.finalize` AND purchases write access.
  bool get canFinalizePurchases =>
      _fullAccess ||
      (_granted.contains(Permission.purchasesFinalize) &&
          canWrite(SectionKey.purchases));

  /// Management actions: explicit (proposed) code, or full access (flag / admin role flag).
  bool canDo(ManagementAction a) => canRaw(a.proposedCode);

  /// Sections to SHOW (in server menu order). Non-readable sections are hidden, not locked.
  List<SectionKey> get visibleSections =>
      SectionKey.values.where(canRead).toList(growable: false);

  /// Record-level gate: server `allowedActions` if present (requested), else section write.
  /// `false` means HIDE the control.
  bool canOnRecord(
      {required String action,
      List<String>? allowedActions,
      required SectionKey section}) {
    if (allowedActions != null) return allowedActions.contains(action);
    return canWrite(section);
  }

  void clear() {
    _granted = const {};
    _rawCodes = const {};
    _sectionAccess = const {};
    _fullAccess = false;
    _role = AccountRole.unknown;
    _version = null;
    notifyListeners();
  }
}
