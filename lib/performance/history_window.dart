/// Bounds for long histories (P7-24, P7-25).
///
/// Lists at or under [eagerLimit] keep the existing eager tree so the short
/// fixture screens still build every row. Longer pages use a lazy builder and
/// keep at most [retainLimit] older rows while the server walk continues.
abstract final class HistoryWindow {
  static const eagerLimit = 24;

  /// Older ledger and account rows retained after a load-more.
  static const retainLimit = 80;

  /// Notification rows retained after walking older pages.
  static const notificationRetain = 120;
}
