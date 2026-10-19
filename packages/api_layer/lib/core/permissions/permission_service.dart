import 'package:flutter/foundation.dart';

import 'permission_codes.dart';

/// Holds permissions RETURNED BY THE SERVER (GET /api/me: `role` + `permissions[]`) for
/// UI gating only. This is NOT a security boundary: the server enforces every request.
/// `isAdmin` mirrors the server's own rule (role == "admin" sees every section).
class PermissionService extends ChangeNotifier {
  Set<Permission> _granted = const {};
  Set<String> _rawCodes = const {};
  bool _isAdmin = false;
  String? _version;

  Set<Permission> get granted => _granted;
  bool get isAdmin => _isAdmin;
  String? get version => _version;

  void applyFromServer(Iterable<String> codes,
      {required bool isAdmin, String? version}) {
    _rawCodes = codes.toSet();
    _granted =
        _rawCodes.map(Permission.fromCode).whereType<Permission>().toSet();
    _isAdmin = isAdmin;
    _version = version;
    notifyListeners();
  }

  bool has(Permission p) => _isAdmin || _granted.contains(p);
  bool hasAny(Iterable<Permission> ps) => _isAdmin || ps.any(_granted.contains);
  bool hasRaw(String code) => _isAdmin || _rawCodes.contains(code);

  bool canRead(SectionKey s) => has(s.read);
  bool canWrite(SectionKey s) => s.write != null && has(s.write!);
  bool canDo(AdminOnlyAction _) => _isAdmin;

  /// Sections in server menu order; locked ones are still shown as locked (server policy).
  List<SectionKey> get readableSections =>
      SectionKey.values.where(canRead).toList(growable: false);

  /// Record-level gate. Prefers server `allowedActions` if the server adds it (requested);
  /// otherwise falls back to the section write permission. Server still decides.
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
    _isAdmin = false;
    _version = null;
    notifyListeners();
  }
}
