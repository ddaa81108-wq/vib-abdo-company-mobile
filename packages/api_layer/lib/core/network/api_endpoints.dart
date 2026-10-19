/// Paths per API contract, taken from the public client. Not called live.
/// Paths still unknown are marked 🔶.
/// Changing the backend should only require editing this file + mappers.
class ApiEndpoints {
  ApiEndpoints._();

  // Public / health
  static const health = '/api/health';
  static const setupStatus = '/api/setup/status';

  // Auth & session (cookie + X-CSRF-Token)
  static const login = '/api/auth/login';
  static const csrf = '/api/auth/csrf';
  static const me = '/api/me';
  static const logout = '/api/auth/logout';
  static const changePassword = '/api/auth/change-password';

  // 🔶 PROPOSED mobile token scheme (does NOT exist yet; request to server owner).
  static const proposedMobileLogin = '/api/auth/mobile/login';
  static const proposedMobileRefresh = '/api/auth/mobile/refresh';
  static const proposedMobileLogout = '/api/auth/mobile/logout';

  // Account cards: {section} ∈ customers | companies | libyan-deposits | egyptian-deposits
  static String accounts(String section) => '/api/$section';
  static String accountSuggestions(String section) =>
      '/api/$section/suggestions';
  static String account(String section, String id) => '/api/$section/$id';
  static String accountLedger(String section, String id) =>
      '/api/$section/$id/ledger';
  static String accountTransactions(String section, String id) =>
      '/api/$section/$id/transactions';
  static String accountTxCorrection(String section, String id, String tx) =>
      '/api/$section/$id/transactions/$tx/corrections';
  static String accountTxCancel(String section, String id, String tx) =>
      '/api/$section/$id/transactions/$tx/cancel';
  static String accountPin(String section, String id) =>
      '/api/$section/$id/pin';
  static String customerZeroReview(String id) =>
      '/api/customers/$id/zero-review';
  static const egyptianExchangeRate = '/api/egyptian-deposits/exchange-rate';

  // Collections (استلامات الديون)
  static const collections = '/api/collections';
  static const collectionAssignees = '/api/collections/assignees';
  static const collectionAssignments = '/api/collections/assignments';
  static String collectionSubmissions(String assignmentId) =>
      '/api/collections/assignments/$assignmentId/submissions';
  static String collectionSubmissionDecision(String id) =>
      '/api/collections/submissions/$id/decision';
  static String collectionSubmissionCashReceived(String id) =>
      '/api/collections/submissions/$id/cash-received';
  static const collectionUnlinkedReceipts =
      '/api/collections/unlinked-receipts';
  static const collectionLinkCandidates = '/api/collections/link-candidates';
  static String collectionUnlinkedDecision(String id) =>
      '/api/collections/unlinked-receipts/$id/decision';
  static String collectionUnlinkedCashReceived(String id) =>
      '/api/collections/unlinked-receipts/$id/cash-received';
  static const collectionDaysClose = '/api/collections/days/close';
  static const payroll = '/api/collections/payroll';
  static const payrollEntries = '/api/collections/payroll/entries';
  static String payrollSalary(String employeeId) =>
      '/api/collections/payroll/employees/$employeeId/salary';
  static String payrollEntryConfirm(String entryId) =>
      '/api/collections/payroll/entries/$entryId/confirm';

  // Masraweya (EGP daily book)
  static const masraweyaDay = '/api/masraweya/day';

  // Purchases: {book} ∈ al_bayan | simsim
  static String purchases(String book) => '/api/purchases/$book';
  static String purchaseEntry(String book, String id) =>
      '/api/purchases/$book/entries/$id';
  static String purchasesOpening(String book) => '/api/purchases/$book/opening';
  static String purchasesFinalize(String book) =>
      '/api/purchases/$book/finalize';
  static String purchasesDayCorrection(String book, String day) =>
      '/api/purchases/$book/days/$day/correction';

  // Treasury, reports, financial ledger
  static const treasury = '/api/treasury';
  static const treasuryCashLedger = '/api/treasury/cash-ledger';
  static const treasuryCashEntries = '/api/treasury/cash-entries';
  static const reports = '/api/reports';
  static const financialLedger = '/api/financial-ledger';
  static const statementPdf = '/api/statements/pdf';

  // Admin (only the parts relevant to a mobile client)
  static const accountRequests = '/api/account-requests';
  static String accountRequestDecision(String id) =>
      '/api/account-requests/$id/decision';

  // Realtime & notifications
  static const events = '/api/events'; // SSE
  static const eventChanges = '/api/event-changes'; // polling fallback
  static const notifications = '/api/notifications';
  static String notificationRead(String id) => '/api/notifications/$id/read';
  static const notificationsReadAll = '/api/notifications/read-all';
  static const notificationPreferences = '/api/notification-preferences';

  // 🔶 Do not exist — requested from the server owner (see contract §14).
  static const proposedUnreadCount = '/api/notifications/unread-count';
  static const proposedMobilePushDevices = '/api/mobile-push/devices';
  static const proposedHome =
      '/api/home'; // aggregated home screen (contract §5.0)
}
