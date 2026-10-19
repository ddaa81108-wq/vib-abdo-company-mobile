/// An error whose [message] is safe to show. It must not carry secrets.
abstract interface class UserFacingException implements Exception {
  String get message;
}
