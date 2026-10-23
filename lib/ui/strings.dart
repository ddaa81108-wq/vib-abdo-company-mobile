import 'package:flutter_api_layer/api_layer.dart';

/// User-facing copy. Arabic is the only locale of this app.
abstract final class AppStrings {
  static const appTitle = 'سجل التحصيل';
  static const brandMark = 'ع';
  static const brandWord = 'VIB';
  static const organization = 'المؤسسة الرئيسية';
  static const slogan = 'إدارة أسهل .. لعمل أكثر نجاحًا';
  static const loginTitle = 'تسجيل الدخول';
  static const loginSubtitle = slogan;
  static const username = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const showPassword = 'إظهار كلمة المرور';
  static const hidePassword = 'إخفاء كلمة المرور';
  static const signIn = 'تسجيل الدخول';
  static const emptyCredentials = 'أدخل البريد الإلكتروني وكلمة المرور.';
  static const sessionExpired = 'انتهت الجلسة، يرجى تسجيل الدخول';
  static const homeTitle = 'الرئيسية';
  static const logout = 'تسجيل الخروج';
  static const logoutConfirm = 'هل تريد تسجيل الخروج؟';
  static const signedInAs = 'الحساب';
  static const roleAdmin = 'مدير النظام';
  static const roleEmployee = 'موظف';
  static const roleUnknown = 'صلاحية غير معروفة';
  static const writeAction = 'كتابة';
  static const homeCardsTitle = 'ملخص الخادم';
  static const oldDebtsTitle = 'نشرة الديون';
  static const actionsTitle = 'إجراءات متاحة';
  static const sectionsTitle = 'الأقسام المتاحة';
  static const sectionsHint = 'ما يظهر هنا يتبع صلاحيات الخادم فقط.';
  static const comingSoon = 'قريبًا';
  static const noSections = 'لا توجد أقسام مفعّلة لحسابك — راجع الإدارة';
  static const noSummaries = 'لا توجد ملخصات متاحة لحسابك';
  static const notifications = 'الإشعارات';
  static const passwordChangeRequired =
      'يجب تغيير كلمة المرور قبل متابعة العمل.';
  static const loading = 'جارٍ التحميل…';
  static const genericError = 'تعذر تنفيذ الطلب.';
  static const retry = 'إعادة المحاولة';
  static const forbidden = 'القسم غير مصرح لهذا الحساب';
  static const emptyAccounts = 'لا توجد حسابات';
  static const emptyTicker = 'لا توجد ديون تجاوزت 3 أيام';
  static const emptyLedger = 'لا توجد حركات';
  static const emptyCollections = 'لا توجد استلامات';
  static const emptyAssignments = 'لا توجد كروت موجهة';
  static const emptyEmployeeTotals = 'لا توجد إجماليات من الخادم';
  static const emptyPayroll = 'لا توجد بيانات مرتبات';
  static const emptyReports = 'لا توجد بيانات';
  static const emptyPurchases = 'لا توجد أيام مسجّلة في هذا الدفتر';
  static const online = 'متصل • جميع التغييرات محفوظة';
  static const offline = 'غير متصل — تُعرض آخر بيانات محمّلة للقراءة';
  static const more = 'المزيد';
  static const menu = 'القائمة';
  static const searchHint = 'بحث موحد في كل الحسابات…';
  static const search = 'بحث';
  static const noResults = 'لا توجد نتائج';
  static const themeLight = 'المظهر النهاري';
  static const themeDark = 'المظهر الليلي';
  static const myAccount = 'حسابي';
  static const settings = 'الإعدادات';
  static const createEmployee = 'إنشاء حساب موظف';
  static const createEmployeeBody =
      'الحسابات ينشئها المسؤول. لا يوجد تسجيل ذاتي في التطبيق.';
  static const back = 'رجوع';
  static const save = 'حفظ';
  static const cancel = 'إلغاء';
  static const confirm = 'تأكيد';
  static const add = 'إضافة';
  static const dash = '—';
  static const showAll = 'عرض الكل';
  static const loadOlder = 'تحميل الأقدم';
  static const loadMore = 'تحميل المزيد';
  static const netDebt = 'صافي إجمالي الديون';
  static const totalDebt = 'إجمالي الديون';
  static const lastActivity = 'آخر حركة';
  static const withEmployee = 'لدى';
  static const systemCard = 'نظامي';
  static const rateTitle = 'كم جنيه لكل دينار';
  static const rateMissing = 'يلزم سعر تحويل معتمد';
  static const serverReply = 'رد الخادم';
  static const passwordCurrent = 'كلمة المرور الحالية';
  static const passwordNew = 'كلمة المرور الجديدة';
  static const passwordConfirm = 'تأكيد كلمة المرور';
  static const passwordTooShort = 'كلمة المرور الجديدة 10 أحرف على الأقل.';
  static const passwordMismatch = 'التأكيد غير مطابق.';
  static const markAllRead = 'قراءة الكل';
  static const sound = 'الصوت';
  static const speech = 'النطق';
  static const insight = 'ملخص آلي للمراجعة';
  static const noNotifications = 'لا توجد إشعارات';
  static const refresh = 'تحديث';
  static const integerOnly = 'أدخل عددًا صحيحًا كما هو، بلا كسور.';
  static const invalidAmount = MoneyValue.invalidLabel;

  /// Direct partial payment compared with the card balance the server sent.
  /// The app does not subtract or store a new balance.
  static const amountAboveRemaining = 'المبلغ أكبر من المتبقي المسجّل.';
  static const dateInvalid = 'أدخل التاريخ بصيغة سنة-شهر-يوم.';
  static const unitsHint =
      'عدد صحيح بالوحدة الصغرى التي يخزّنها الخادم. بلا فواصل وبلا كسور. التطبيق لا يحوّل هذا الرقم ولا يحسبه.';
  static const rateInvalid = 'أدخل السعر نصًا كما هو.';
  static const noPreview = 'الناتج يظهر من الخادم بعد الحفظ فقط.';
  static const reversed = 'ملغاة';
  static const corrected = 'معدّل';
  static const awaitingCash = 'ينتظر النقد';
  static const closeBatch = 'إغلاق ومسح الدفعة';
  static const closeBatchConfirm = 'تأكيد إغلاق الدفعة ومسحها؟';
  static const finalizeDay = 'ترحيل اليوم';
  static const finalizeConfirm =
      'ترحيل اليوم سيحوّل معاملاته إلى قراءة فقط. هل تريد المتابعة؟';
  static const purchaseOpening = 'الرصيد الافتتاحي';
  static const saveOpening = 'حفظ الرصيد الافتتاحي';
  static const saveDayConfirm =
      'تأكيد حفظ اليوم؟ تُرسل القيم كما أدخلتها، وما يظهر بعد الحفظ هو رد الخادم.';
  static const openingConfirm =
      'تأكيد حفظ الرصيد الافتتاحي؟ يُرسل المبلغ كما أدخلته، والرصيد الجديد يظهر من الخادم فقط.';
  static const openDayCorrection = 'فتح تصحيح اليوم';
  static const closeDayCorrection = 'إغلاق تصحيح اليوم';
  static const openCorrectionConfirm =
      'تأكيد فتح تصحيح اليوم؟ بعد التأكيد يُرسل الطلب كما هو، وتظهر حالة اليوم من الخادم.';
  static const closeCorrectionConfirm =
      'تأكيد إغلاق تصحيح اليوم؟ بعد التأكيد يُرسل الطلب كما هو، وتظهر حالة اليوم من الخادم.';
  static const correctionClosed = 'التصحيح مغلق';
  static const cashIn = 'دخول';
  static const cashOut = 'خروج';
  static const cashMovements = 'حركات النقد';
  static const formulaCaption = 'ديون لنا + النشط + المصري − ديون علينا';
  static const pinnedColumn = 'التاريخ';
  static const changePassword = 'تغيير كلمة المرور';
  static const notificationPrefs = 'تفضيلات الإشعارات';
  static const financialLedger = 'سجل الأستاذ المالي';
  static const exportPdf = 'تصدير PDF';
  static const employeesTile = 'الموظفون والإداريون';
  static const auditTile = 'سجل التدقيق';
  static const operationsTile = 'مركز التشغيل';
  static const unavailable =
      'لا تتوفر بيانات من الخادم لهذه الشاشة في تطبيق الجوال.';
  static const noLanguage = 'اللغة العربية فقط.';
  static const pageTotals = 'إجماليات الصفحة';
  static const draft = 'مسودة';
  static const finalized = 'مرحّل';
  static const correctionOpen = 'تصحيح مفتوح';
  static const vodafoneOurs = 'باقي فودافون لصالحنا';
  static const vodafoneOwed = 'استهلاك فودافون علينا';
  static const vodafoneCashRemaining = 'باقي فودافون كاش';
  static const balanceAfter = 'الرصيد بعد الحركة';
  static const fullPayment = 'سداد كلي';
  static const partialPayment = 'سداد جزئي';
  static const debtMovement = 'دين';
  static const paymentMovement = 'سداد';
  static const depositIn = 'دخول';
  static const depositOut = 'خروج';
  static const egpIn = 'إيداع مصري';
  static const egpOut = 'سحب مصري';
  static const direct = 'مباشر';
  static const divide = 'قسمة';
  static const multiply = 'ضرب';
  static const note = 'البيان';
  static const amount = 'المبلغ';
  static const date = 'التاريخ';
  static const name = 'الاسم';
  static const nameRequired = 'أدخل الاسم.';
  static const similarNames = 'أسماء مشابهة';
  static const phone = 'الهاتف';
  static const factor = 'المعامل';
  static const sinceDays = 'منذ';
  static const days = 'أيام';
  static const activeTab = 'نشطة';
  static const smartTab = 'الذكية';
  static const todayTab = 'اليوم';
  static const debtsTab = 'ديون';
  static const settledTab = 'مسدد';
  static const pinnedTab = 'مثبت';
  static const zeroTab = 'صفر ينتظر المراجعة';
  static const pin = 'تثبيت';
  static const unpin = 'إلغاء التثبيت';
  static const assign = 'توجيه';
  static const zeroReview = 'مراجعة التصفير';
  static const addCustomer = 'إضافة عميل';
  static const addCompany = 'إضافة شركة';
  static const addDeposit = 'إضافة أمانة';
  static const addMovement = 'إضافة حركة';
  static const cancelMovement = 'إلغاء الحركة';
  static const correctMovement = 'تعديل الحركة';
  static const approve = 'اعتماد';
  static const reject = 'رفض';
  static const cashReceived = 'تم استلام النقدية';
  static const submitReceipt = 'تسجيل استلام';
  static const unlinkedReceipt = 'استلام غير مربوط';
  static const myPayroll = 'مرتبي';
  static const payroll = 'المرتبات';
  static const statementHidden = 'عمود الرصيد يظهر فقط عندما يرسله الخادم.';
  static const customerLedger = 'سجل العميل';
  static const companyLedger = 'سجل الشركة';
  static const libyanLedger = 'سجل الأمانة الليبية';
  static const egyptianLedger = 'سجل الأمانة المصرية';
  static const bell = 'الجرس';
  static const connection = 'حالة الاتصال';
  static const openSection = 'فتح القسم';
  static const hideSidebar = 'إخفاء الشريط الجانبي';
  static const showSidebar = 'إظهار الشريط الجانبي';
  static const receivables = 'إجمالي الديون لنا';
  static const liabilities = 'إجمالي الديون علينا';
  static const activeCash = 'الفلوس النشطة';
  static const egyptianTransfers = 'ترحيلات الأمانات المصرية';
  static const netTreasury = 'صافي الخزينة الشامل';
  static const egyptianSource = 'المصدر بالجنيه';
  static const rate = 'سعر التحويل';
  static const converted = 'بالدينار من الخادم';
  static const description = 'البيان';
  static const byActor = 'بواسطة';
  static const sequence = 'التسلسل';
  static const status = 'الحالة';
  static const todayResult = 'إجمالي شغل اليوم';
  static const todayPaid = 'إجمالي المسدد';
  static const exchangeRate = 'سعر الصرف';
  static const paid = 'المسدد';
  static const egpValue = 'القيمة ج.م';
  static const operation = 'العملية';
  static const vodafoneConsumed = 'مستهلك فودافون';
  static const registerTotals = 'إجماليات السجل من البداية';

  /// Day total on the purchases card. The customers headline stays
  /// [totalDebt].
  static const purchaseTotalDebt = 'إجمالي الديون';

  /// Purchases column. Other sections keep [remaining].
  static const purchaseRemaining = 'الباقي';

  /// Purchases rate column. The entry form keeps [exchangeRate].
  static const purchasePrice = 'السعر';

  /// Purchases add button. Other sections keep [add].
  static const addPurchaseEntry = 'إضافة معاملة';

  /// Register-total cells. The column headers stay [resultFromServer],
  /// [paid], [purchaseRemaining], and [vodafoneConsumed].
  static const registerResult = 'إجمالي الناتج';
  static const registerRemaining = 'الباقي الحالي';
  static const registerVodafoneConsumed = 'إجمالي مستهلك فودافون';

  /// Second register row in PurchasesSection. Not the signed day metric.
  static const registerVodafoneRemaining = 'باقي فودافون كاش الحالي';

  /// Opening editor. The day bar uses [previousValue] for the same amount.
  static const carriedVodafone = 'فودافون المرحّل';
  static const actions = 'الإجراءات';

  /// `registerTotals.remainingUnits` and `vodafoneRemainingUnits`.
  /// Both are the open day's carried balance. The screen does not add them.
  static const remainingRunningBalance =
      'الباقي الحالي وباقي فودافون كاش الحالي رصيد متراكم لليوم المفتوح، وليس مجموع البطاقات.';
  static const kind = 'النوع';
  static const customerName = 'اسم العميل';
  static const modeFull = 'كلي';
  static const modePartial = 'جزئي';
  static const pendingApproval = 'ينتظر الاعتماد';
  static const approved = 'معتمد';
  static const rejected = 'مرفوض';
  static const unlinked = 'غير مربوط';
  static const normal = 'طبيعي';
  static const review = 'يحتاج مراجعة';
  static const critical = 'مراجعة فورية';
  static const missingRate = 'سعر التحويل مفقود';
  static const trustCustomer = 'أمانة للعميل';
  static const debtOnCustomer = 'دين على العميل';
  static const forOrg = 'لصالح المنظومة — دين على العميل';
  static const debtOnOrg = 'دين علينا للعميل';
  static const zeroAccount = 'حساب صفر';
  static const trust = 'أمانة';
  static const overdue = 'دين متأخر';
  static const warningAge = 'مرّ عليه 3 أيام';
  static const newDebt = 'دين جديد';
  static const methodology = 'المنهجية';
  static const reasons = 'الأسباب';
  static const netChange = 'الفرق عن اليوم السابق';
  static const ourDebts = 'ديون لنا';
  static const activeFunds = 'الأموال النشطة';
  static const egyptian = 'المصري';
  static const egyptianLyd = 'المصري بالليبي';
  static const owedDebts = 'ديون علينا';
  static const net = 'صافي الخزينة';
  static const systemNote = 'ملاحظة النظام';
  static const currentDay = 'اليوم الحالي';
  static const remaining = 'المتبقي';
  static const workTotal = 'إجمالي العمل';
  static const previousValue = 'القيمة السابقة';
  static const purchases = 'المشتريات';
  static const purchasesValue = purchases;
  static const reports = 'التقارير الذكية';
  static const reportsReadOnly = 'للقراءة فقط. الأرقام كما أرسلها الخادم.';
  static const scrollColumns = 'اسحب أفقيًا لعرض بقية الأعمدة';
  static const treasury = 'الخزينة';
  static const adjustment = 'تسوية تاريخية';
  static const period = 'الفترة';
  static const baseSalary = 'المرتب الثابت';
  static const commissions = 'العمولة';
  static const withdrawals = 'السحب';
  static const employeeTotals = 'إجماليات الموظفين';
  static const assignments = 'الكروت الموجهة';
  static const collected = 'إجمالي المعتمد';
  static const dayTotal = 'إجمالي اليوم';
  static const pendingCount = 'ينتظر الاعتماد';
  static const unlinkedCount = 'غير مربوط';
  static const cashOutstanding = 'النقدية غير المسلّمة';
  static const noAssignees = 'لا يوجد موظفون من الخادم.';
  static const confirmCancel = 'تأكيد إلغاء الحركة؟';
  static const versionConflict = 'تم تعديل البيانات. أُعيد الجلب من الخادم.';
  static const savedReply = 'تم استلام الرد من الخادم.';
  static const prefsFailed = 'تعذر حفظ التفضيل. أُعيدت قيمة الخادم.';
  static const unreadFull = 'غير المقروء';
  static const homeError = 'تعذر تحميل الرئيسية.';
  static const homeFallbackNote =
      'تعذر مسار ملخص الرئيسية. الأرقام أدناه من أقسام الخادم كما هي، دون جمع أو تحويل.';
  static const updatedAt = 'آخر تحديث';
  static const serverCount = 'العدد من الخادم';
  static const appearance = 'المظهر';
  static const employeesEmpty =
      'لا تتوفر قائمة الموظفين والإداريين من الخادم في تطبيق الجوال. لا يمكن إضافة حساب أو تعديل صلاحية من هنا.';
  static const auditEmpty =
      'لا تتوفر أحداث سجل التدقيق من الخادم في تطبيق الجوال. لا تُعرض سجلات من هذا الجهاز.';
  static const operationsEmpty =
      'لا تتوفر حالة مركز التشغيل من الخادم في تطبيق الجوال. لا توجد إجراءات تشغيل من هنا.';
  static const readLabel = 'مقروء';
  static const unreadLabel = 'غير مقروء';
  static const filterSearch = 'بحث بالاسم أو الهاتف';
  static const openingBalance = 'رصيد أول المدة';
  static const calculation = 'طريقة الحساب';
  static const reference = 'المرجع';
  static const actor = 'المنفّذ';
  static const inputValue = 'المدخل';
  static const resultFromServer = 'الناتج';
  static const lock = 'مقفل';
  static const expand = 'توسيع';
  static const collapse = 'طي';
  static const alBayan = 'البيان';
  static const simsim = 'سمسم';
  static const otherKind = 'نوع آخر';
  static const customItemName = 'اسم النوع';
  static const customItemRequired = 'أدخل اسم النوع.';
  static const kindVodafone = 'فودافون';
  static const kindKafr = 'كفر الشيخ';
  static const kindCairo = 'القاهرة';
  static const kindMansoura = 'المنصورة';
  static const kindFawry = 'فوري';
  static const kindBanks = 'بنوك';
  static const chooseKind = 'اختر نوع العملية';
  static const assignee = 'الموظف';
  static const chooseAssignee = 'اختر الموظف.';
  static const enterReference = 'أدخل المرجع.';
  static const edit = 'تعديل';
  static const editCard = 'تعديل الكارت';
  static const editCardTitle = 'تعديل بيانات الكارت';
  static const editCardScope =
      'يُحفظ الاسم والهاتف فقط. الرصيد والحركات تبقى كما يرسلها الخادم.';
  static const editCardUnavailable = 'تعديل هذا الكارت غير متاح لهذا الحساب.';
  static const cardVersionMissing =
      'تعذر الحفظ قبل وصول إصدار الكارت من الخادم. أُعيد الجلب.';
  static const delete = 'حذف';
  static const confirmDelete = 'تأكيد حذف هذا السطر';
  static const confirmPayroll = 'تأكيد حركة المرتب';
  static const link = 'ربط';
  static const batch = 'الدفعة';
  static const toneNeutral = 'محايد';
  static const correctTransaction = 'تصحيح الحركة';
  static const confirmCorrect =
      'تأكيد إرسال تصحيح هذه الحركة؟ المبلغ والرصيد بعد الحفظ يظهران من الخادم فقط.';
  static const currentServerAmount = 'المبلغ الحالي من الخادم';
  static const receipts = 'الاستلامات';
  static const cashReceivedAt = 'تاريخ استلام النقد';
  static const assignmentOpen = 'مفتوح';
  static const openingCarry = 'رصيد مرحّل';
  static const approvedCount = 'عدد المعتمد';

  // Account-list presentation only. Grouped at the end so ledger and
  // collections edits to the catalogue above can merge without overlap.
  static const dayOne = 'يوم';
  static const dayTwo = 'يومين';
  static const dayMany = 'يومًا';
  static const clearSearch = 'مسح البحث';

  // Employee totals screen. After the account-list block so those edits merge.
  static const pendingUnits = 'المبلغ المنتظر';
  static const rejectedCount = 'عدد المرفوض';
  static const serverTotals = 'الإجمالي من الخادم';

  // Phase 6 notifications presentation. After the totals block so those edits merge.
  static const notificationSystemFallback = 'منظومة VIB';
  static const notificationNotFound = 'هذا الإشعار غير موجود.';
  static const notificationNoTarget = 'لا يوجد قسم مرتبط بهذا الإشعار.';
  static const notificationPermissionTitle = 'إذن الإشعارات';
  static const notificationPermissionBody =
      'نحتاج إذن الإشعارات لعرض التنبيهات الجديدة وأنت تستخدم التطبيق.';
  static const notificationPermissionAgree = 'موافق';
  static const notificationPermissionLater = 'ليس الآن';
  static const notificationPermissionDenied =
      'لم يُمنح إذن الإشعارات. يمكنك تفعيله من إعدادات التطبيق.';
  static const notificationPermissionSettings = 'فتح الإعدادات';
}
