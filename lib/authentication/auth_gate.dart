import 'package:flutter_api_layer/api_layer.dart';

import '../ui/strings.dart';

/// Where the router should send the user for the current server session.
///
/// Returns null to stay on [location]. [SessionOtpRequired] is treated as
/// signed out: the current server does not issue that state.
String? authRedirect(SessionState session, String location) {
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
      return null;
  }
}

/// Notice when the server ended the session. Other reasons stay silent.
String? signedOutNotice(SessionState session) {
  if (session is SessionUnauthenticated &&
      session.reason == 'session_expired') {
    return AppStrings.sessionExpired;
  }
  return null;
}
