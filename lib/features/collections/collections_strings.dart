/// Collections section words, as the deployed website (537f073) shows them.
/// Kept beside the section so the shared catalogue is not touched.
abstract final class CollectionsText {
  static const title = 'قسم استلامات الديون';
  static const adminDescription = 'متابعة الموظفين، الاعتماد، واستلام النقدية';
  static const employeeDescription = 'الكروت الموجهة إليك للاستلام';

  // Metrics (website CollectionsOverview + server cashOutstandingUnits).
  static const totalApproved = 'إجمالي المعتمد';
  static const assigned = 'الكروت الموجهة';
  static const executed = 'المنفذ';
  static const pending = 'ينتظر الاعتماد';
  static const unlinked = 'غير مربوط';
  static const cashOutstanding = 'نقدية لم تُستلم';

  static const employeeTotals = 'إجماليات الموظفين';
  static const employeeTotalsNote = 'تفصيل إداري';
  static const approvedShort = 'معتمد';
  static const waitingShort = 'ينتظر';

  static const outstandingTitle = 'نقدية سابقة لم تُسلّم';
  static const outstandingNote =
      'دفعات معتمدة سابقة، ما زالت تنتظر تسليم النقدية.';

  static const unlinkedAdminTitle = 'استلامات بلا كارت موجه';
  static const unlinkedAdminNote =
      'لا تؤثر على أي حساب حتى تربطها الإدارة بكارت أصلي وتعتمدها.';
  static const unlinkedApproved = 'تم الربط والاعتماد';
  static const unlinkedRejected = 'مرفوض';
  static const rejectedNoEffect = 'تم الرفض دون تأثير مالي';
  static const existingCustomer = 'عميل قديم';
  static const newCustomer = 'عميل جديد';

  static const followTitle = 'متابعة استلامات الموظفين';
  static const noCards = 'لا توجد كروت موجهة.';
  static const noHistory = 'لم يسجل الموظف استلامًا بعد.';
  static const fullReceipt = 'استلام كلي';
  static const partialReceipt = 'استلام جزئي';
  static String partialReceiptN(int n) => 'استلام جزئي $n';
  static const awaitingApproval = 'ينتظر الاعتماد';
  static const awaitingCash = 'ينتظر استلام النقدية';
  static const cashReceived = 'تم استلام النقدية';

  static const closeBatch = 'إغلاق ومسح الدفعة';
  static const closeConfirm =
      'هل تم اعتماد جميع العمليات واستلام النقدية بالكامل؟ ستُمسح الدفعة نهائيًا، ولن يتأثر سجل ديون العملاء.';
  static String batchLabel(String? date, int? number) =>
      [?date, if (number != null) 'دفعة $number'].join(' • ');
  static const batchClosed = 'تم إغلاق الدفعة ومسحها.';

  // Employee.
  static const createStandalone = 'إنشاء عميل مستقل';
  static const createNote =
      'سجّل الاسم والقيمة فقط. لن تتغير أي أرصدة حتى تربطه الإدارة بكارت أصلي وتعتمده.';
  static const customerName = 'اسم العميل';
  static const receivedAmount = 'القيمة المستلمة';
  static const registerPending = 'تسجيل كارت معلّق';
  static const myUnlinkedTitle = 'استلامات سجلتها بدون كارت موجه';
  static const myUnlinkedPending = 'معلّق — لا يؤثر على الحسابات';
  static const rejectedByAdmin = 'رفضته الإدارة';
  static const waitingCashFromAdmin = 'ينتظر استلام النقدية من الإدارة';
  static const myCardsTitle = 'الكروت الموجهة إليك';
  static const noMyCards = 'لا توجد كروت موجهة حاليًا.';
  static const noPhone = 'لا يوجد رقم هاتف';
  static const call = 'اتصال';
  static const phoneCopied = 'تعذر فتح الاتصال، تم نسخ الرقم.';
  static String fullConfirm(String amount) =>
      'تسجيل استلام كلي بقيمة الرصيد الحالي $amount؟';
  static const amount = 'القيمة';
  static const save = 'حفظ';
  static const unconfirmed =
      'لم يصل رد الخادم على الإرسال السابق. أعد الإرسال بنفس القيمة.';
  static const retrySend = 'إعادة الإرسال';
  static const alreadyRecorded = 'كان الإرسال السابق مسجلًا لدى الخادم.';
  static const sent = 'تم الإرسال، ينتظر الاعتماد.';
  static const amountRequired = 'اكتب قيمة صحيحة أكبر من صفر.';
  static const nameRequired = 'اكتب اسم العميل بوضوح.';

  // Link dialog.
  static const linkTitle = 'ربط استلام بكارت أصلي';
  static const linkExisting = 'عميل قديم — ربط بحساب موجود';
  static const linkNew = 'عميل جديد — إنشاء حساب جديد';
  static const searchAll = 'ابحث عن العميل في كل الأقسام';
  static const search = 'بحث';
  static const searchHint =
      'ابحث ثم اختر الكارت الأصلي. إذا لم يوجد، أنشئه في قسمه أولًا ثم أعد البحث.';
  static const minTwo = 'اكتب حرفين على الأقل من اسم العميل.';
  static const searchFailed = 'تعذر البحث. أعد المحاولة.';
  static const entryType = 'نوع الحركة عند الاعتماد';
  static const entryPayment = 'خصم القيمة من رصيد الكارت (تسديد / خروج)';
  static const entryDebt = 'إضافة القيمة إلى رصيد الكارت (دين / دخول)';
  static const noEffectUntil =
      'لن يحدث أي تأثير مالي إلا بعد الضغط على «ربط واعتماد».';
  static const linkApprove = 'ربط واعتماد';
  static const newPlace = 'مكان إنشاء الكارت الجديد';
  static const newCustomers = 'قسم ديون العملاء';
  static const newCompanies = 'قسم ديون الشركات';
  static String newNote(String name) =>
      'سينشأ الكارت باسم «$name» ثم تُسجل عليه الحركة بعد اعتمادك فقط.';
  static const newApprove = 'إنشاء الكارت وربطه واعتماده';
  static const chooseCard = 'اختر الكارت الأصلي أولًا أو أنشئ حسابًا جديدًا.';
  static String candidateSection(String? key) => switch (key) {
    'customer_debts' => 'ديون العملاء',
    'company_debts' => 'ديون الشركات',
    'libyan_deposits' => 'أمانات ليبية',
    'egyptian_deposits' => 'أمانات مصرية',
    _ => '',
  };

  // Payroll (website CollectionPayrollPanel).
  static const payrollTitle = 'مرتبات موظفي الاستلام';
  static const myPayrollTitle = 'مرتبي';
  static const currentPeriod = 'الفترة الحالية: ';
  static const base = 'المرتب الثابت';
  static const carryOld = 'الباقي من الشهر القديم';
  static const carryPrevious = 'المرحل السابق';
  static const commissions = 'العمولات والمكافآت';
  static const withdrawals = 'إجمالي السحب';
  static const remaining = 'الباقي من المرتب';
  static const addEntry = 'إضافة حركة للموظف';
  static const addWithdrawal = 'إضافة سحب';
  static const addCommission = 'إضافة عمولة أو مكافأة';
  static const reason = 'السبب';
  static const withdrawalReason = 'سبب السحب';
  static const commissionReason = 'سبب العمولة أو المكافأة';
  static const add = 'إضافة';
  static const editSalary = 'تعديل المرتب';
  static const saveSalary = 'حفظ المرتب';
  static const ledgerTitle = 'سجل المرتب — ';
  static const noEntries = 'لا توجد حركات في هذه الفترة.';
  static const withdrawal = 'سحب';
  static const commission = 'عمولة / مكافأة';
  static const confirmed = 'تم التأكيد';
  static const awaitingEmployee = 'بانتظار تأكيد الموظف';
  static const confirmReceipt = 'تأكيد الاستلام';
  static const reasonRequired = 'اكتب سبب الحركة بوضوح.';
  static const salaryRequired = 'اكتب مرتبًا ثابتًا صحيحًا غير سالب.';
  static const noEmployees = 'لا يوجد موظف استلام مفعّل حاليًا.';

  // Layout from Ali's two pictures (2026-11-03).
  static const filterBatch = 'دفعة العمل';
  static const filterEmployee = 'الموظف';
  static const allEmployees = 'كل الموظفين';
  static const noOpenBatches = 'لا توجد دفعات مفتوحة';
  static const searchView = 'بحث في العرض';
  static const searchViewHint = 'اسم العميل أو الموظف أو الهاتف';
  static const payrollButton = 'المرتبات';
  static const payrollBack = 'رجوع إلى الاستلامات';
  static const exportBatch = 'كشف PDF للدفعة';
  static const exportDay = 'كشف PDF لليوم';
  static const closeBatchTitle = 'إغلاق دفعة العمل';
  static const closeScopeNote =
      'الإغلاق يشمل الدفعة كاملة، مهما كان الموظف أو البحث المختار.';
  static String reviewCount(int n) => 'مراجعة: $n';
  static const cashNotReceived = 'نقدية غير مستلمة:';
  static const sumApproved = 'المعتمد';
  static const sumCashReceived = 'المستلم نقداً';
  static const sumRemaining = 'المتبقي تسليمه';
  static const sumPending = 'بانتظار الاعتماد';
  static const operations = 'عملية';
  static const cardsUnit = 'كارت';
  static String unlinkedWithin(int n) => 'غير المربوط ضمن هذا العدد: $n';
  static const summaryNote =
      'الملخص للدفعة والموظف المختارين. البحث والتبويب لا يغيّران الإجماليات. النقدية السابقة منفصلة.';
  static const tabAll = 'كل الكروت';
  static const tabReview = 'بانتظار المراجعة';
  static const tabCash = 'بانتظار تسليم النقدية';
  static const tabPrevious = 'نقدية سابقة';
  static const liveSync = 'متصل بالمزامنة الحية';
  static const offlineSync = 'غير متصل — آخر بيانات محمّلة';
  static const emptyReview = 'لا توجد عمليات بانتظار المراجعة.';
  static const emptyCash = 'لا توجد نقدية بانتظار التسليم.';
  static const emptyPrevious = 'لا توجد نقدية سابقة.';
  static const noMatch = 'لا توجد نتائج مطابقة للبحث.';
  static const cashToHand = 'النقدية المطلوب تسليمها';
  static const cashToHandNote = 'تشمل أي نقدية سابقة لم تُسلّم';
  static const tabMyCards = 'كروتي';
  static const tabMyReceipts = 'تحصيلاتي';
  static const tabMyCash = 'النقدية';
  static const searchNameOrPhone = 'بحث بالاسم أو الهاتف';
  static const searchNameOrPhoneHint = 'اسم العميل أو رقم الهاتف';
  static const employeeSearchNote =
      'البحث يغيّر العرض فقط؛ ملخصك يشمل كل تحصيلاتك. اعتماد التحصيل واستلام النقدية من اختصاص الإدارة.';
  static const noMyReceipts = 'لا توجد تحصيلات مسجلة.';
  static const approved = 'معتمد';
  static const rejected = 'مرفوض';
  static const previousCash = 'نقدية سابقة لم تُسلّم';
}
