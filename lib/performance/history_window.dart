/// Bounds for long histories (P7-24, P7-25).
///
/// Lists at or under [eagerLimit] keep the existing eager tree so the short
/// fixture screens still build every row. Longer pages use a lazy builder.
/// The builder does not drop rows.
///
/// [trimEnabled] drops older ledger rows past [retainLimit] and notification
/// rows past [notificationRetain]. Approved by Ali on 2026-10-22, enabled by
/// default. `--dart-define=HISTORY_WINDOW_TRIM=false` turns it off.
/// See docs/testing/PHASE7_PERFORMANCE.md.
abstract final class HistoryWindow {
  static const eagerLimit = 24;

  /// Older ledger and account rows kept when [trimEnabled] is on.
  static const retainLimit = 80;

  /// Notification rows kept when [trimEnabled] is on.
  static const notificationRetain = 120;

  /// Compile-time default. Tests assign [trimEnabled] and restore this.
  static const trimEnabledFromEnvironment = bool.fromEnvironment(
    'HISTORY_WINDOW_TRIM',
    defaultValue: true,
  );

  /// On by default. Assign false in a test, or pass the define, to keep
  /// every loaded row.
  static bool trimEnabled = trimEnabledFromEnvironment;
}
