import '../permissions/permission_service.dart';
import '../session/session_manager.dart';

/// Release capture role taken from the session [SessionManager] built from
/// GET /api/me. Null keeps the window secure.
///
/// Debug builds do not use this value to open the window. The Android
/// build type clears FLAG_SECURE for every debug window, including signed
/// out. FLAG_SECURE still couples screenshots, recording, and recents.
String? releaseVerifiedRole(SessionState state) {
  if (state is! SessionAuthenticated) return null;
  return PermissionService.verifiedCaptureRole(state.profile.role);
}

/// Same rule the native window applies. A debug build is never secure.
/// Release is secure unless [releaseVerifiedRole] is present.
bool captureWindowIsSecure({
  required bool debuggable,
  required SessionState state,
}) {
  if (debuggable) return false;
  return releaseVerifiedRole(state) == null;
}
