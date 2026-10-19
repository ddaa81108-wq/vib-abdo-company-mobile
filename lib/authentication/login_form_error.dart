import '../error_handling/user_facing_exception.dart';

/// Local form rejection, before any request is sent.
class LoginFormError implements UserFacingException {
  const LoginFormError(this.message);

  @override
  final String message;
}
