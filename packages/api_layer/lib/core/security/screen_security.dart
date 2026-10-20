/// Screenshot and recents protection.
///
/// Android enforces this with `FLAG_SECURE` on the activity window
/// (`MainActivity`, channel `app/screen_security`). The flag is process-wide:
/// it blocks screenshots and blanks the recents thumbnail for every route,
/// including login, ledgers, treasury, and reports. [disable] must not clear
/// it. [NoopScreenSecurity] is the fallback for tests and for targets that
/// do not have the channel.
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
