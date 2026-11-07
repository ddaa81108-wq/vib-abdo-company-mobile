import 'common.dart';
import 'profile_models.dart';

/// POST /api/auth/login -> { ok:true, data: { user: {...}, csrfToken } }.
/// The CSRF token is handed to the AuthStrategy and never logged.
class LoginResult {
  const LoginResult({required this.raw, this.user});
  final Json raw;
  final UserProfile? user;

  factory LoginResult.fromData(Object? data) {
    final d = asJson(data);
    final u = d['user'] is Map
        ? asJson(d['user'])
        : (d.containsKey('username') ? d : null);
    return LoginResult(
        raw: d, user: u == null ? null : UserProfile.fromJson(u));
  }

  @override
  String toString() => 'LoginResult(***)';
}

/// Marker that login is waiting for `POST /api/auth/mfa/verify`.
///
/// The challenge is the `abdo_mfa` cookie. This object does not hold the
/// code or the cookie value.
class LoginChallenge {
  const LoginChallenge(
      {this.loginTicket = '', this.channel, this.maskedDestination});
  final String loginTicket;
  final String? channel;
  final String? maskedDestination;
}
