/// Screenshot / app-switcher protection for sensitive screens
/// (ledger, treasury, totals, reports, login).
/// Implement with a platform channel or a package such as `screen_protector`
/// (Android FLAG_SECURE, iOS secure overlay on inactive). Chosen package TBD.
abstract interface class ScreenSecurity {
  Future<void> enable();
  Future<void> disable();
}

class NoopScreenSecurity implements ScreenSecurity {
  const NoopScreenSecurity();
  @override
  Future<void> enable() async {}
  @override
  Future<void> disable() async {}
}
