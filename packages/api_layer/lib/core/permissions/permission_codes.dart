/// Permission codes the server may return: `<section>.read|write` plus `purchases.finalize`.
/// Whether a code grants anything is decided only by [PermissionService].
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
  customers('customers', Permission.debtsRead, Permission.debtsWrite),
  collections(
      'collections', Permission.collectionsRead, Permission.collectionsWrite),
  companies('companies', Permission.companiesRead, Permission.companiesWrite),
  libyanDeposits('libyan-deposits', Permission.libyanDepositsRead,
      Permission.libyanDepositsWrite),
  egyptianDeposits('egyptian-deposits', Permission.egyptianDepositsRead,
      Permission.egyptianDepositsWrite),
  masraweya('masraweya', Permission.masraweyaRead, Permission.masraweyaWrite),
  purchases('purchases', Permission.purchasesRead, Permission.purchasesWrite),
  treasury('treasury', Permission.treasuryRead, Permission.treasuryWrite),
  reports('reports', Permission.reportsRead, null);

  const SectionKey(this.key, this.read, this.write);
  final String key;
  final Permission read;
  final Permission? write;
}

/// Actions with no permission code. [PermissionService.canDo] allows them only when
/// the server role flag grants unrestricted access.
enum AdminOnlyAction {
  collectionsAssign,
  collectionsDecide,
  collectionsCashReceived,
  collectionsCloseDay,
  payrollManage,
  customerZeroReview,
  accountRequestsDecide,
}
