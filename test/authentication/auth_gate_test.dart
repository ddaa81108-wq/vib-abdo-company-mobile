import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/authentication/auth_gate.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

void main() {
  const profile = UserProfile(
    id: 'u_test',
    username: 'person@example.invalid',
    displayName: 'شخص تجريبي',
    role: 'employee',
    permissions: ['collections.read'],
    mustChangePassword: false,
  );

  test('unknown session stays on the splash route', () {
    expect(authRedirect(const SessionUnknown(), '/splash'), isNull);
    expect(authRedirect(const SessionUnknown(), '/login'), '/splash');
  });

  test('signed-out session is sent to login', () {
    expect(authRedirect(const SessionUnauthenticated(), '/login'), isNull);
    expect(
      authRedirect(const SessionUnauthenticated(reason: 'logout'), '/'),
      '/login',
    );
    expect(
      authRedirect(
        const SessionOtpRequired(LoginChallenge(loginTicket: 'ticket')),
        '/home',
      ),
      '/login',
    );
  });

  test('authenticated session leaves login and splash', () {
    const session = SessionAuthenticated(profile);
    expect(authRedirect(session, '/login'), '/');
    expect(authRedirect(session, '/splash'), '/');
    expect(authRedirect(session, '/'), isNull);
    expect(authRedirect(session, '/account/password'), isNull);
    expect(authRedirect(session, '/change-password'), '/');
  });

  test('a required password change blocks every other route', () {
    const session = SessionAuthenticated(
      UserProfile(
        id: 'u_test',
        username: 'person@example.invalid',
        displayName: 'شخص تجريبي',
        role: 'employee',
        permissions: ['collections.read'],
        mustChangePassword: true,
      ),
    );
    expect(authRedirect(session, '/'), '/change-password');
    expect(authRedirect(session, '/customers'), '/change-password');
    expect(authRedirect(session, '/change-password'), isNull);
  });

  test('signed-out users can read the signup notice', () {
    expect(authRedirect(const SessionUnauthenticated(), '/signup-info'), isNull);
  });

  test('session expiry notice uses the signed-out reason only', () {
    expect(
      signedOutNotice(const SessionUnauthenticated(reason: 'session_expired')),
      AppStrings.sessionExpired,
    );
    expect(
      signedOutNotice(const SessionUnauthenticated(reason: 'logout')),
      isNull,
    );
    expect(signedOutNotice(const SessionAuthenticated(profile)), isNull);
  });
}
