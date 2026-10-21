import 'package:flutter_api_layer/api_layer.dart';

import '../ui/strings.dart';

/// Signed-in users who open a section or admin path they cannot read land here.
const forbiddenLocation = '/forbidden';

/// Where the router should send the user for the current server session.
///
/// Returns null to stay on [location]. [SessionOtpRequired] is treated as
/// signed out: the current server does not issue that state.
///
/// When [permissions] is set, a signed-in user who opens a section they cannot
/// read is sent to [forbiddenLocation]. Search, notifications, the account
/// screen, and [forbiddenLocation] itself stay open.
String? authRedirect(
  SessionState session,
  String location, {
  PermissionService? permissions,
}) {
  final atSplash = location == '/splash';
  final atLogin = location == '/login';
  switch (session) {
    case SessionUnknown():
      return atSplash ? null : '/splash';
    case SessionUnauthenticated():
    case SessionOtpRequired():
      if (atLogin || location == '/signup-info') return null;
      return '/login';
    case SessionAuthenticated(:final profile):
      if (profile.mustChangePassword) {
        return location == '/change-password' ? null : '/change-password';
      }
      if (atSplash || atLogin || location == '/change-password') return '/';
      return permissions == null
          ? null
          : permissionRedirect(location, permissions);
  }
}

/// [forbiddenLocation] when [location] is a section or admin path the user
/// cannot read. Null to stay. [forbiddenLocation] itself is never redirected.
String? permissionRedirect(String location, PermissionService permissions) {
  final path = location.split('?').first;
  if (path == '/' ||
      path == forbiddenLocation ||
      path == '/search' ||
      path == '/notifications' ||
      path == '/account' ||
      path == '/account/password') {
    return null;
  }
  if (path == '/settings' || path.startsWith('/settings/')) {
    final manage = permissions.canDo(ManagementAction.settingsManage);
    if (path != '/settings') return manage ? null : forbiddenLocation;
    if (permissions.canViewFinancialLedger || manage) return null;
    return forbiddenLocation;
  }
  final section = sectionForLocation(path);
  if (section == null) return null;
  if (!permissions.canRead(section)) return forbiddenLocation;
  return null;
}

/// Section that owns [path], including a card ledger under that section.
SectionKey? sectionForLocation(String path) {
  for (final section in SectionKey.values) {
    final root = '/${section.key}';
    if (path == root || path.startsWith('$root/')) return section;
  }
  return null;
}

/// Notice when the server ended the session. Other reasons stay silent.
String? signedOutNotice(SessionState session) {
  if (session is SessionUnauthenticated &&
      session.reason == 'session_expired') {
    return AppStrings.sessionExpired;
  }
  return null;
}
