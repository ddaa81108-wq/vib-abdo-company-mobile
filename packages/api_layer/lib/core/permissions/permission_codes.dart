/// REAL permission codes of the existing system (analysis doc §1.3): `<section>.read|write`
/// plus `purchases.finalize`. Gating is decided ONLY in PermissionService (codes +
/// `sectionAccess` + `fullAccess` + the exact server role flag).
enum Permission {
  debtsRead('debts.read'), // قسم ديون العملاء
  debtsWrite('debts.write'),
  collectionsRead('collections.read'), // استلامات الديون
  collectionsWrite('collections.write'),
  companiesRead('companies.read'), // ديون الشركات
  companiesWrite('companies.write'),
  libyanDepositsRead('libyan_deposits.read'), // أمانات ليبية
  libyanDepositsWrite('libyan_deposits.write'),
  egyptianDepositsRead('egyptian_deposits.read'), // أمانات مصرية
  egyptianDepositsWrite('egyptian_deposits.write'),
  masraweyaRead('masraweya.read'), // المصراوية
  masraweyaWrite('masraweya.write'),
  purchasesRead('purchases.read'), // المشتريات
  purchasesWrite('purchases.write'),
  purchasesFinalize('purchases.finalize'),
  treasuryRead('treasury.read'), // الخزينة
  treasuryWrite('treasury.write'),
  reportsRead('reports.read'); // التقارير (قراءة فقط)

  const Permission(this.code);
  final String code;

  static final Map<String, Permission> _byCode = {
    for (final p in values) p.code: p
  };

  /// Unknown codes return null and are ignored safely.
  static Permission? fromCode(String code) => _byCode[code];
}

/// Business sections (analysis doc §1.3), in the server's menu order.
enum SectionKey {
  customers('customers', Permission.debtsRead, Permission.debtsWrite,
      'customerDebts'),
  // Collections is NOT part of sectionAccess on the server (01b §1.2): gated by codes only.
  collections('collections', Permission.collectionsRead,
      Permission.collectionsWrite, null),
  companies('companies', Permission.companiesRead, Permission.companiesWrite,
      'companyDebts'),
  libyanDeposits('libyan-deposits', Permission.libyanDepositsRead,
      Permission.libyanDepositsWrite, 'libyanDeposits'),
  egyptianDeposits('egyptian-deposits', Permission.egyptianDepositsRead,
      Permission.egyptianDepositsWrite, 'egyptianDeposits'),
  masraweya('masraweya', Permission.masraweyaRead, Permission.masraweyaWrite,
      'masraweya'),
  purchases('purchases', Permission.purchasesRead, Permission.purchasesWrite,
      'purchases'),
  treasury('treasury', Permission.treasuryRead, Permission.treasuryWrite,
      'treasury'),
  reports('reports', Permission.reportsRead, null, 'reports');

  const SectionKey(this.key, this.read, this.write, this.accessKey);
  final String key;
  final Permission read;
  final Permission? write;

  /// Key inside the server's `sectionAccess` map, or null when the section is not in it.
  final String? accessKey;
}

/// Server `sectionAccess[<key>]` values: observed `none` and `manage`; `read` exists in web code.
/// Unknown or missing values are treated as [none] (fail closed for UI gating).
enum SectionAccessLevel {
  none,
  read,
  manage;

  static SectionAccessLevel parse(Object? v) => switch (v) {
        'manage' => SectionAccessLevel.manage,
        'read' => SectionAccessLevel.read,
        _ => SectionAccessLevel.none,
      };
}

/// Server role as matched (exactly) by PermissionService. Display/branching elsewhere must use
/// this enum, never the raw string.
enum AccountRole { admin, employee, unknown }

/// Management actions that the existing web gates by role name (no fine-grained code observed).
/// Each action maps to a PROPOSED explicit permission code (🔶 contract §15). Allowed if the
/// server returns that code, or the user has full access (`fullAccess`, or the admin role flag
/// with empty lists — see PermissionService precedence).
enum ManagementAction {
  collectionsAssign('collections.assign'),
  collectionsDecide('collections.decide'),
  collectionsCashReceived('collections.cash_receive'),
  collectionsCloseDay('collections.close_day'),
  payrollManage('payroll.manage'),
  customerZeroReview('debts.zero_review'),
  accountRequestsDecide('users.manage'),
  settingsManage('settings.manage');

  const ManagementAction(this.proposedCode);
  final String proposedCode;
}
