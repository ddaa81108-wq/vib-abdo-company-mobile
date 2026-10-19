/// Static server-like fixtures in the REAL shapes (`*Units` integers, `{ok,data}` unwrapped).
/// All totals are HARDCODED as the server would return them — the fake never computes.
/// Values are invented; nothing here comes from the production system.
class FakeFixtures {
  FakeFixtures._();

  static const employeePermissions = [
    'collections.read',
    'collections.write',
    'debts.read'
  ];

  /// Proposed management codes (🔶 contract §4) used by the limited-admin fixture.
  static const limitedAdminPermissions = [
    'collections.read',
    'collections.write',
    'collections.decide',
    'debts.read'
  ];

  /// Fixture picked by username (FAKE ONLY):
  /// - `admin…`          -> like the real server today: role "admin", EMPTY permissions, no
  ///                        sectionAccess, no fullAccess -> full access via the role flag.
  /// - `limited.admin…`  -> role "admin" with an explicit list + sectionAccess -> lists apply.
  /// - `flag.admin…`     -> role "admin", empty lists, explicit `fullAccess: false` -> nothing.
  /// - `guest…`          -> unknown role -> nothing.
  /// - anything else     -> collections employee.
  static Map<String, dynamic> meFor(String username) {
    if (username.startsWith('limited.admin')) {
      return _me(
          id: 'u_2',
          username: 'limited.admin@example.invalid',
          name: 'إداري محدود تجريبي',
          role: 'admin',
          permissions: limitedAdminPermissions,
          sectionAccess: const {'customerDebts': 'read'});
    }
    if (username.startsWith('flag.admin')) {
      return _me(
          id: 'u_3',
          username: 'flag.admin@example.invalid',
          name: 'إداري بعلم صريح',
          role: 'admin',
          permissions: const [],
          sectionAccess: const {},
          fullAccess: false);
    }
    if (username.startsWith('guest')) {
      return _me(
          id: 'u_9',
          username: 'guest@example.invalid',
          name: 'دور غير معروف',
          role: 'guest',
          permissions: employeePermissions,
          sectionAccess: const {'customerDebts': 'manage'});
    }
    return me(admin: username.startsWith('admin'));
  }

  static Map<String, dynamic> me({required bool admin}) => admin
      ? _me(
          id: 'u_1',
          username: 'admin@example.invalid',
          name: 'مدير تجريبي',
          role: 'admin',
          permissions: const [],
          sectionAccess: null)
      : _me(
          id: 'u_12',
          username: 'employee@example.invalid',
          name: 'موظف استلام تجريبي',
          role: 'employee',
          permissions: employeePermissions,
          sectionAccess: const {
              'customerDebts':
                  'read', // has debts.read only -> read-only in the app
              'companyDebts': 'none', 'libyanDeposits': 'none',
              'egyptianDeposits': 'none',
              'masraweya': 'none', 'purchases': 'none', 'treasury': 'none',
              'reports': 'none',
            });

  static Map<String, dynamic> _me({
    required String id,
    required String username,
    required String name,
    required String role,
    required List<String> permissions,
    required Map<String, String>? sectionAccess,
    bool? fullAccess,
  }) =>
      {
        'user': {
          'id': id,
          'username': username,
          'displayName': name,
          'role': role,
          'permissions': permissions,
          if (sectionAccess != null) 'sectionAccess': sectionAccess,
          if (fullAccess != null) 'fullAccess': fullAccess,
          'mustChangePassword': false,
        },
      };

  static Map<String, dynamic> accounts({required bool egp}) => {
        'items': [
          {
            'id': 'c_55',
            'name': 'عميل تجريبي',
            'phone': '0910000000',
            'balanceUnits': egp ? 15000 : 320,
            'activeAssigneeName': 'موظف استلام تجريبي',
            'lastActivityAt': '2026-10-18T14:03:00+02:00',
            'pinned': false,
            'version': 4,
            'nextSequence': 3,
            'debtAgeDays': 4,
            'ageStatus': 'warning',
            'ageStatusLabel': 'مرّ عليه 3 أيام',
          },
        ],
        'nextCursor': null,
        'totalItems': 1,
        'summary': {
          'netBalance': egp ? 15000 : 320,
          'totalDebt': egp ? 15000 : 320,
          'activeCards': 1,
          'pendingReviewCount': 0
        },
      };

  static Map<String, dynamic> ledger({String? before}) {
    if (before != null && before.isNotEmpty) {
      return {
        'items': [
          {
            'id': 'tx_old',
            'sequence': 0,
            'type': 'debt',
            'status': 'posted',
            'date': '2026-09-01T10:00:00+02:00',
            'note': 'دين أقدم',
            'amountUnits': 40,
            'inputValue': 40,
            'calculationMode': 'direct',
            'balanceAfterUnits': 40,
            'createdByName': 'مدير تجريبي',
            'version': 1
          },
        ],
        'pageOpeningBalanceUnits': 0,
        'nextBefore': null,
        'hasMore': false,
      };
    }
    return {
        'items': [
          {
            'id': 'tx_1',
            'sequence': 1,
            'type': 'debt',
            'status': 'posted',
            'date': '2026-10-02T10:00:00+02:00',
            'note': 'دين',
            'amountUnits': 500,
            'inputValue': 500,
            'calculationMode': 'direct',
            'balanceAfterUnits': 500,
            'createdByName': 'مدير تجريبي',
            'version': 1
          },
          {
            'id': 'tx_2',
            'sequence': 2,
            'type': 'payment',
            'status': 'posted',
            'date': '2026-10-10T10:00:00+02:00',
            'note': 'سداد جزئي',
            'amountUnits': 180,
            'inputValue': 180,
            'calculationMode': 'direct',
            'balanceAfterUnits': 320,
            'createdByName': 'مدير تجريبي',
            'version': 1
          },
        ],
        'pageOpeningBalanceUnits': 0,
        'nextBefore': 'tx_1',
        'hasMore': true,
      };
  }

  /// Proposed GET /api/home — HARDCODED server-style values (nothing computed), filtered per user.
  static Map<String, dynamic> home({required bool admin}) => {
        'businessDate': '2026-10-19',
        'generatedAt': '2026-10-19T02:00:00+02:00',
        'summaries': [
          {
            'key': 'customers.netBalance',
            'section': 'customers',
            'title': 'صافي ديون العملاء',
            'valueUnits': 320,
            'currency': 'LYD',
            'tone': 'negative',
            'note': 'من ملخص القسم',
            'updatedAt': '2026-10-19T02:00:00+02:00'
          },
          {
            'key': 'collections.collected',
            'section': 'collections',
            'title': 'الاستلامات المعتمدة اليوم',
            'valueUnits': 250,
            'currency': 'LYD',
            'tone': 'neutral',
            'updatedAt': '2026-10-19T02:00:00+02:00'
          },
          if (admin) ...[
            {
              'key': 'egyptianDeposits.netBalance',
              'section': 'egyptian-deposits',
              'title': 'صافي الأمانات المصرية',
              'valueUnits': 15000,
              'currency': 'EGP',
              'tone': 'positive',
              'updatedAt': '2026-10-19T02:00:00+02:00'
            },
            {
              'key': 'treasury.activeCash',
              'section': 'treasury',
              'title': 'الفلوس النشطة',
              'valueUnits': 5000,
              'currency': 'LYD',
              'tone': 'positive',
              'updatedAt': '2026-10-19T02:00:00+02:00'
            },
            {
              'key': 'reports.status',
              'section': 'reports',
              'title': 'حالة اليوم',
              'valueUnits': null,
              'status': 'normal',
              'note': 'صافي المركز المالي ارتفع مقارنة باليوم السابق',
              'updatedAt': '2026-10-19T02:00:00+02:00'
            },
          ],
        ],
        'counters': {'collections': 1, if (admin) 'customers': 1},
        'oldDebts': [
          {
            'id': 'c_55',
            'section': 'customers',
            'name': 'عميل تجريبي',
            'balanceUnits': 320,
            'currency': 'LYD',
            'debtAgeDays': 4,
            'ageStatus': 'warning',
            'ageStatusLabel': 'منذ 4 أيام'
          },
        ],
      };

  static Map<String, dynamic> collections() => {
        'assignments': [
          {
            'id': 'as_1',
            'customerId': 'c_55',
            'customerName': 'عميل تجريبي',
            'section': 'customers',
            'phone': '0910000000',
            'balanceUnits': 320,
            'status': 'open'
          },
        ],
        'submissions': [
          {
            'id': 'sb_1',
            'mode': 'partial',
            'amountUnits': 100,
            'status': 'pending',
            'version': 1,
            'cashStatus': 'not_applicable',
            'submittedByName': 'موظف استلام تجريبي',
            'createdAt': '2026-10-18T12:00:00+02:00'
          },
          {
            'id': 'sb_2',
            'mode': 'full',
            'amountUnits': 250,
            'status': 'approved',
            'version': 3,
            'cashStatus': 'pending',
            'cashPending': true,
            'cashReceivedAt': null,
            'submittedByName': 'موظف استلام تجريبي',
            'createdAt': '2026-10-18T09:30:00+02:00'
          },
        ],
        'unlinkedReceipts': [
          {
            'id': 'ur_1',
            'customerName': 'اسم غير مربوط تجريبي',
            'amountUnits': 50,
            'status': 'pending',
            'version': 1,
            'cashStatus': 'not_applicable'
          },
        ],
        'employeeTotals': [
          {
            'employeeName': 'موظف استلام تجريبي',
            'collectedUnits': 0,
            'approvedCount': 0,
            'pendingCount': 1
          },
        ],
        'metrics': {
          'collectedUnits': 0,
          'dayTotalUnits': 100,
          'pendingCount': 1,
          'unlinkedPendingCount': 1,
          'cashOutstandingUnits': 250,
        },
        'assignedCount': 1,
        'batchId': 'b_1',
      };

  static Map<String, dynamic> payroll() => {
        'period': '2026-10',
        'employees': [
          {
            'userId': 'u_12',
            'displayName': 'موظف استلام تجريبي',
            'baseSalaryUnits': 1500,
            'openingCarryUnits': 0,
            'commissionsUnits': 50,
            'withdrawalsUnits': 300,
            'remainingUnits': 1250,
            'entries': []
          },
        ],
      };

  static Map<String, dynamic> masraweyaDay() => {
        'businessDate': '2026-10-19',
        'version': 2,
        'previousValueUnits': 10000,
        'purchasesUnits': 2000,
        'entries': [
          {'valueUnits': 3000, 'commissionUnits': 50}
        ],
        'workTotalUnits': 3050,
        'remainingUnits': 8950,
        'historicalAdjustmentUnits': 0,
        'status': 'open',
      };

  static Map<String, dynamic> purchases() => {
        'days': [
          {
            'day': '12',
            'version': 3,
            'status': 'draft',
            'entries': [
              {
                'id': 'pe_1',
                'kind': 'entry',
                'itemCode': 'vodafone_cash',
                'itemLabel': 'فودافون كاش',
                'egpValueUnits': 10000,
                'calculationMode': 'divide',
                'exchangeRate': '9.5',
                'resultUnits': 1053,
                'paidUnits': 500,
                'remainingUnits': 553,
                'vodafoneConsumedUnits': 0,
                'version': 1
              },
            ],
            'totals': {
              'previousDebtUnits': 2000,
              'todayResultUnits': 1053,
              'todayPaidUnits': 500,
              'totalDebtUnits': 2553,
              'vodafoneRemainingUnits': 0,
              'dayClosingDebtUnits': 2553
            },
          },
        ],
        'lifetimeTotals': {
          'resultUnits': 50000,
          'paidUnits': 47447,
          'remainingUnits': 2553
        },
        'nextBefore': null,
      };

  static Map<String, dynamic> treasury() => {
        'version': 7,
        'totals': {
          'receivablesUnits': 45000,
          'liabilitiesUnits': 12000,
          'activeCashUnits': 8000,
          'egyptianSourceUnits': 95000,
          'egyptianRate': '9.5',
          'egyptianConvertedUnits': 10000,
          'netUnits': 51000,
          'activeCashTone': 'positive'
        },
      };

  static Map<String, dynamic> cashLedger({String? before}) {
    if (before != null && before.isNotEmpty) {
      return {
        'items': [
          {
            'id': 'ce_old',
            'direction': 'out',
            'amountUnits': 200,
            'description': 'خروج أقدم',
            'balanceAfterUnits': 7000,
            'createdAt': '2026-09-01T09:00:00+02:00',
            'createdByName': 'مدير تجريبي'
          },
        ],
        'nextBefore': null,
        'hasMore': false,
      };
    }
    return {
        'items': [
          {
            'id': 'ce_1',
            'direction': 'in',
            'amountUnits': 1000,
            'description': 'إيداع تجريبي',
            'balanceAfterUnits': 8000,
            'createdAt': '2026-10-18T09:00:00+02:00',
            'createdByName': 'مدير تجريبي'
          },
        ],
        'nextBefore': 'ce_1',
        'hasMore': true,
      };
  }

  static Map<String, dynamic> reports() => {
        'items': [
          {
            'sequence': 30,
            'date': '2026-10-18',
            'receivablesUnits': 45000,
            'activeCashUnits': 8000,
            'egyptianSourceUnits': 95000,
            'egyptianConvertedUnits': 10000,
            'liabilitiesUnits': 12000,
            'netUnits': 51000,
            'netChangeUnits': 1200,
            'status': 'normal',
            'note': 'ملاحظة النظام',
            'reasons': [
              {'text': 'سبب تجريبي', 'changeUnits': 1200}
            ]
          },
        ],
        'methodology': {
          'formula': 'ديون لنا + النشط + المصري − ديون علينا',
          'note': 'نص من الخادم'
        },
      };

  static Map<String, dynamic> notifications(int unread) => {
        'items': [
          {
            'id': '77',
            'action': 'collection.submit',
            'title': 'استلام جديد بانتظار المراجعة',
            'body': 'افتح قسم الاستلامات',
            'section': 'collections',
            'entityId': 'sb_1',
            'readAt': null,
            'createdAt': '2026-10-18T12:00:00+02:00'
          },
        ],
        'unreadCount': unread,
        'nextBefore': null,
      };
}
