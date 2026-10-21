/// Static server-like fixtures in the REAL shapes (`*Units` integers, `{ok,data}` unwrapped).
/// All totals are HARDCODED as the server would return them — the fake never computes.
/// Values are invented; nothing here comes from the production system.
class FakeFixtures {
  FakeFixtures._();

  static const employeePermissions = [
    'collections.read',
    'collections.write',
    'debts.read',
  ];

  /// Proposed management codes, per API contract, used by the limited-admin fixture.
  static const limitedAdminPermissions = [
    'collections.read',
    'collections.write',
    'collections.decide',
    'debts.read',
  ];

  /// Employee `sectionAccess`: customer debts are read-only; every other section is none.
  static const employeeSectionAccess = {
    'customerDebts': 'read', // has debts.read only -> read-only in the app
    'companyDebts': 'none',
    'libyanDeposits': 'none',
    'egyptianDeposits': 'none',
    'masraweya': 'none',
    'purchases': 'none',
    'treasury': 'none',
    'reports': 'none',
  };

  /// Fixture picked by username (FAKE ONLY):
  /// - `admin…`          -> like the real server today: role "admin", EMPTY permissions, no
  ///                        sectionAccess, no fullAccess -> full access via the role flag.
  /// - `limited.admin…`  -> role "admin" with an explicit list + sectionAccess -> lists apply.
  /// - `flag.admin…`     -> role "admin", empty lists, explicit `fullAccess: false` -> nothing.
  /// - `guest…`          -> unknown role -> nothing.
  /// - `mustchange…`     -> collections employee with `mustChangePassword: true` until
  ///                        `POST /api/auth/change-password` succeeds on this fake client.
  /// - anything else     -> collections employee.
  static Map<String, dynamic> meFor(String username) {
    if (username.startsWith('limited.admin')) {
      return _me(
        id: 'u_2',
        username: 'limited.admin@example.invalid',
        name: 'إداري محدود تجريبي',
        role: 'admin',
        permissions: limitedAdminPermissions,
        sectionAccess: const {'customerDebts': 'read'},
      );
    }
    if (username.startsWith('flag.admin')) {
      return _me(
        id: 'u_3',
        username: 'flag.admin@example.invalid',
        name: 'إداري بعلم صريح',
        role: 'admin',
        permissions: const [],
        sectionAccess: const {},
        fullAccess: false,
      );
    }
    if (username.startsWith('guest')) {
      return _me(
        id: 'u_9',
        username: 'guest@example.invalid',
        name: 'دور غير معروف',
        role: 'guest',
        permissions: employeePermissions,
        sectionAccess: const {'customerDebts': 'manage'},
      );
    }
    if (username.startsWith('mustchange')) {
      return _me(
        id: 'u_4',
        username: 'mustchange@example.invalid',
        name: 'مستخدم تغيير كلمة المرور',
        role: 'employee',
        permissions: employeePermissions,
        sectionAccess: employeeSectionAccess,
        mustChangePassword: true,
      );
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
          sectionAccess: null,
        )
      : _me(
          id: 'u_12',
          username: 'employee@example.invalid',
          name: 'موظف استلام تجريبي',
          role: 'employee',
          permissions: employeePermissions,
          sectionAccess: employeeSectionAccess,
        );

  static Map<String, dynamic> _me({
    required String id,
    required String username,
    required String name,
    required String role,
    required List<String> permissions,
    required Map<String, String>? sectionAccess,
    bool? fullAccess,
    bool mustChangePassword = false,
  }) => {
    'user': {
      'id': id,
      'username': username,
      'displayName': name,
      'role': role,
      'permissions': permissions,
      if (sectionAccess != null) 'sectionAccess': sectionAccess,
      if (fullAccess != null) 'fullAccess': fullAccess,
      'mustChangePassword': mustChangePassword,
    },
  };

  /// Ten cards per account section so QA can open a list (P2-01).
  /// `c_55` keeps the original demo balance. Customers include one system card (P2-07).
  ///
  /// `summary` figures are literals. This fixture does not add card balances.
  static Map<String, dynamic> accountsFor(String section) => switch (section) {
    'companies' => _companies(),
    'libyan-deposits' => _libyanDeposits(),
    'egyptian-deposits' => _egyptianDeposits(),
    _ => _customers(),
  };

  /// Same card list the fake used when every section shared one shape.
  /// Egyptian deposits keep the EGP balance of `c_55`.
  static Map<String, dynamic> accounts({required bool egp}) =>
      accountsFor(egp ? 'egyptian-deposits' : 'customers');

  static Map<String, dynamic> cardById(String section, String id) {
    final items = accountsFor(section)['items'] as List;
    for (final item in items) {
      if (item is Map && item['id'] == id) return item.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _customers() => _page(
    [
      _card(
        id: 'c_55',
        name: 'عميل تجريبي',
        phone: '0910000000',
        balanceUnits: 320,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_56',
        name: 'عميل تجريبي ٢',
        phone: '0910000002',
        balanceUnits: 150,
        debtAgeDays: 1,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_57',
        name: 'عميل تجريبي ٣',
        phone: '0910000003',
        balanceUnits: 0,
        debtAgeDays: 0,
        ageStatus: 'zero',
      ),
      _card(
        id: 'c_58',
        name: 'عميل تجريبي ٤',
        phone: '0910000004',
        balanceUnits: 900,
        debtAgeDays: 12,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_59',
        name: 'عميل تجريبي ٥',
        phone: '0910000005',
        balanceUnits: 40,
        debtAgeDays: 5,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_60',
        name: 'عميل تجريبي ٦',
        phone: '0910000006',
        balanceUnits: 25,
        debtAgeDays: 2,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_61',
        name: 'عميل تجريبي ٧',
        phone: '0910000007',
        balanceUnits: 80,
        debtAgeDays: 9,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_62',
        name: 'عميل تجريبي ٨',
        phone: '0910000008',
        balanceUnits: 60,
        debtAgeDays: 6,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_63',
        name: 'عميل تجريبي ٩',
        phone: '0910000009',
        balanceUnits: 110,
        debtAgeDays: 3,
        ageStatus: 'credit',
      ),
      _card(
        id: 'c_masraweya_remainder',
        name: 'متبقي المصراوية تجريبي',
        phone: '0910000010',
        balanceUnits: 8950,
        debtAgeDays: 4,
        ageStatus: 'warning',
        systemManaged: true,
        systemLinkKey: 'masraweya_remainder',
      ),
    ],
    netBalance: 10635,
    totalDebt: 10635,
    activeCards: 10,
  );

  static Map<String, dynamic> _companies() => _page(
    [
      _card(
        id: 'c_55',
        name: 'عميل تجريبي',
        phone: '0910000000',
        balanceUnits: 320,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_co_02',
        name: 'شركة تجريبية ٢',
        phone: '0920000002',
        balanceUnits: 100,
        debtAgeDays: 1,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_co_03',
        name: 'شركة تجريبية ٣',
        phone: '0920000003',
        balanceUnits: 200,
        debtAgeDays: 8,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_co_04',
        name: 'شركة تجريبية ٤',
        phone: '0920000004',
        balanceUnits: 0,
        debtAgeDays: 0,
        ageStatus: 'zero',
      ),
      _card(
        id: 'c_co_05',
        name: 'شركة تجريبية ٥',
        phone: '0920000005',
        balanceUnits: 50,
        debtAgeDays: 3,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_co_06',
        name: 'شركة تجريبية ٦',
        phone: '0920000006',
        balanceUnits: 75,
        debtAgeDays: 2,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_co_07',
        name: 'شركة تجريبية ٧',
        phone: '0920000007',
        balanceUnits: 125,
        debtAgeDays: 11,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_co_08',
        name: 'شركة تجريبية ٨',
        phone: '0920000008',
        balanceUnits: 30,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_co_09',
        name: 'شركة تجريبية ٩',
        phone: '0920000009',
        balanceUnits: 45,
        debtAgeDays: 6,
        ageStatus: 'credit',
      ),
      _card(
        id: 'c_co_10',
        name: 'شركة تجريبية ١٠',
        phone: '0920000010',
        balanceUnits: 90,
        debtAgeDays: 7,
        ageStatus: 'warning',
      ),
    ],
    netBalance: 1035,
    totalDebt: 1035,
    activeCards: 10,
  );

  static Map<String, dynamic> _libyanDeposits() => _page(
    [
      _card(
        id: 'c_55',
        name: 'عميل تجريبي',
        phone: '0910000000',
        balanceUnits: 320,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_ly_02',
        name: 'أمانة ليبية تجريبية ٢',
        phone: '0930000002',
        balanceUnits: 10,
        debtAgeDays: 1,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_ly_03',
        name: 'أمانة ليبية تجريبية ٣',
        phone: '0930000003',
        balanceUnits: 20,
        debtAgeDays: 2,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_ly_04',
        name: 'أمانة ليبية تجريبية ٤',
        phone: '0930000004',
        balanceUnits: 30,
        debtAgeDays: 3,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_ly_05',
        name: 'أمانة ليبية تجريبية ٥',
        phone: '0930000005',
        balanceUnits: 40,
        debtAgeDays: 0,
        ageStatus: 'zero',
      ),
      _card(
        id: 'c_ly_06',
        name: 'أمانة ليبية تجريبية ٦',
        phone: '0930000006',
        balanceUnits: 50,
        debtAgeDays: 5,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_ly_07',
        name: 'أمانة ليبية تجريبية ٧',
        phone: '0930000007',
        balanceUnits: 60,
        debtAgeDays: 9,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_ly_08',
        name: 'أمانة ليبية تجريبية ٨',
        phone: '0930000008',
        balanceUnits: 70,
        debtAgeDays: 6,
        ageStatus: 'credit',
      ),
      _card(
        id: 'c_ly_09',
        name: 'أمانة ليبية تجريبية ٩',
        phone: '0930000009',
        balanceUnits: 80,
        debtAgeDays: 8,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_ly_10',
        name: 'أمانة ليبية تجريبية ١٠',
        phone: '0930000010',
        balanceUnits: 15,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
    ],
    netBalance: 695,
    totalDebt: 695,
    activeCards: 10,
  );

  static Map<String, dynamic> _egyptianDeposits() => _page(
    [
      _card(
        id: 'c_55',
        name: 'عميل تجريبي',
        phone: '0910000000',
        balanceUnits: 15000,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_eg_02',
        name: 'أمانة مصرية تجريبية ٢',
        phone: '0940000002',
        balanceUnits: 1000,
        debtAgeDays: 1,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_eg_03',
        name: 'أمانة مصرية تجريبية ٣',
        phone: '0940000003',
        balanceUnits: 2500,
        debtAgeDays: 10,
        ageStatus: 'overdue',
      ),
      _card(
        id: 'c_eg_04',
        name: 'أمانة مصرية تجريبية ٤',
        phone: '0940000004',
        balanceUnits: 0,
        debtAgeDays: 0,
        ageStatus: 'zero',
      ),
      _card(
        id: 'c_eg_05',
        name: 'أمانة مصرية تجريبية ٥',
        phone: '0940000005',
        balanceUnits: 750,
        debtAgeDays: 3,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_eg_06',
        name: 'أمانة مصرية تجريبية ٦',
        phone: '0940000006',
        balanceUnits: 500,
        debtAgeDays: 2,
        ageStatus: 'new',
      ),
      _card(
        id: 'c_eg_07',
        name: 'أمانة مصرية تجريبية ٧',
        phone: '0940000007',
        balanceUnits: 1250,
        debtAgeDays: 7,
        ageStatus: 'credit',
      ),
      _card(
        id: 'c_eg_08',
        name: 'أمانة مصرية تجريبية ٨',
        phone: '0940000008',
        balanceUnits: 300,
        debtAgeDays: 4,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_eg_09',
        name: 'أمانة مصرية تجريبية ٩',
        phone: '0940000009',
        balanceUnits: 450,
        debtAgeDays: 6,
        ageStatus: 'warning',
      ),
      _card(
        id: 'c_eg_10',
        name: 'أمانة مصرية تجريبية ١٠',
        phone: '0940000010',
        balanceUnits: 2000,
        debtAgeDays: 12,
        ageStatus: 'overdue',
      ),
    ],
    netBalance: 23750,
    totalDebt: 23750,
    activeCards: 10,
  );

  static Map<String, dynamic> _page(
    List<Map<String, dynamic>> items, {
    required int netBalance,
    required int totalDebt,
    required int activeCards,
  }) => {
    'items': items,
    'nextCursor': null,
    'totalItems': items.length,
    'summary': {
      'netBalance': netBalance,
      'totalDebt': totalDebt,
      'activeCards': activeCards,
      'pendingReviewCount': 0,
    },
  };

  /// [ageStatusLabel] names [debtAgeDays] (`منذ N أيام`). One card, one age.
  /// `systemKind` is omitted: that field is still pending server confirmation.
  static Map<String, dynamic> _card({
    required String id,
    required String name,
    required String phone,
    required int balanceUnits,
    required int debtAgeDays,
    required String ageStatus,
    bool systemManaged = false,
    String? systemLinkKey,
  }) => {
    'id': id,
    'name': name,
    'phone': phone,
    'balanceUnits': balanceUnits,
    'activeAssigneeName': 'موظف استلام تجريبي',
    'lastActivityAt': '2026-10-18T14:03:00+02:00',
    'pinned': false,
    'version': 4,
    'nextSequence': 3,
    'debtAgeDays': debtAgeDays,
    'ageStatus': ageStatus,
    'ageStatusLabel': _ageLabel(debtAgeDays),
    if (systemManaged) 'systemManaged': true,
    if (systemLinkKey != null) 'systemLinkKey': systemLinkKey,
  };

  static String _ageLabel(int debtAgeDays) => 'منذ $debtAgeDays أيام';

  /// Home bulletin for one card. Age fields are the card's own fields.
  static Map<String, dynamic> _oldDebt(Map<String, dynamic> card) => {
    'id': card['id'],
    'section': 'customers',
    'name': card['name'],
    'balanceUnits': card['balanceUnits'],
    'currency': 'LYD',
    'debtAgeDays': card['debtAgeDays'],
    'ageStatus': card['ageStatus'],
    'ageStatusLabel': card['ageStatusLabel'],
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
            'version': 1,
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
          'version': 1,
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
          'version': 1,
        },
      ],
      'pageOpeningBalanceUnits': 0,
      'nextBefore': 'tx_1',
      'hasMore': true,
    };
  }

  /// Proposed GET /api/home. Each amount and counter is a field already stored
  /// on the matching section fixture. This method does not add card balances.
  /// [FakeApiClient] drops any section the signed-in profile cannot read.
  static Map<String, dynamic> home() {
    final customers = _summaryOf('customers');
    final egyptian = _summaryOf('egyptian-deposits');
    final treasuryTotals = treasury()['totals'] as Map;
    final collectionMetrics = collections()['metrics'] as Map;
    return {
      'businessDate': '2026-10-19',
      'generatedAt': '2026-10-19T02:00:00+02:00',
      'summaries': [
        {
          'key': 'customers.netBalance',
          'section': 'customers',
          'title': 'صافي ديون العملاء',
          'valueUnits': customers['netBalance'],
          'currency': 'LYD',
          'tone': 'negative',
          'note': 'من ملخص القسم',
          'updatedAt': '2026-10-19T02:00:00+02:00',
        },
        {
          'key': 'collections.collected',
          'section': 'collections',
          'title': 'الاستلامات المعتمدة اليوم',
          'valueUnits': collectionMetrics['collectedUnits'],
          'currency': 'LYD',
          'tone': 'neutral',
          'updatedAt': '2026-10-19T02:00:00+02:00',
        },
        {
          'key': 'egyptianDeposits.netBalance',
          'section': 'egyptian-deposits',
          'title': 'صافي الأمانات المصرية',
          'valueUnits': egyptian['netBalance'],
          'currency': 'EGP',
          'tone': 'positive',
          'updatedAt': '2026-10-19T02:00:00+02:00',
        },
        {
          'key': 'treasury.activeCash',
          'section': 'treasury',
          'title': 'الفلوس النشطة',
          'valueUnits': treasuryTotals['activeCashUnits'],
          'currency': 'LYD',
          'tone': treasuryTotals['activeCashTone'],
          'updatedAt': '2026-10-19T02:00:00+02:00',
        },
        {
          'key': 'reports.status',
          'section': 'reports',
          'title': 'حالة اليوم',
          'valueUnits': null,
          'status': 'normal',
          'note': 'صافي المركز المالي ارتفع مقارنة باليوم السابق',
          'updatedAt': '2026-10-19T02:00:00+02:00',
        },
      ],
      'counters': {
        'collections': collections()['assignedCount'],
        'customers': customers['activeCards'],
      },
      'oldDebts': [_oldDebt(cardById('customers', 'c_55'))],
    };
  }

  static Map<String, dynamic> _summaryOf(String section) =>
      Map<String, dynamic>.from(accountsFor(section)['summary'] as Map);

  static Map<String, dynamic> collections() => {
    'assignments': [
      {
        'id': 'as_1',
        'customerId': 'c_55',
        'customerName': 'عميل تجريبي',
        'section': 'customers',
        'phone': '0910000000',
        'balanceUnits': 320,
        'status': 'open',
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
        'createdAt': '2026-10-18T12:00:00+02:00',
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
        'createdAt': '2026-10-18T09:30:00+02:00',
      },
    ],
    'unlinkedReceipts': [
      {
        'id': 'ur_1',
        'customerName': 'اسم غير مربوط تجريبي',
        'amountUnits': 50,
        'status': 'pending',
        'version': 1,
        'cashStatus': 'not_applicable',
      },
      {
        'id': 'ur_2',
        'customerName': 'استلام مرفوض تجريبي',
        'amountUnits': 40,
        'status': 'rejected',
        'version': 4,
        'cashStatus': 'pending',
        'cashPending': true,
      },
    ],
    'employeeTotals': [
      {
        'employeeName': 'موظف استلام تجريبي',
        'collectedUnits': 0,
        'approvedCount': 0,
        'pendingCount': 1,
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
    'version': 1,
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
        'entries': [],
      },
    ],
  };

  static Map<String, dynamic> masraweyaDay() => {
    'businessDate': '2026-10-19',
    'version': 2,
    'previousValueUnits': 10000,
    'purchasesUnits': 2000,
    'entries': [
      {'valueUnits': 3000, 'commissionUnits': 50},
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
            'version': 1,
          },
        ],
        'totals': {
          'previousDebtUnits': 2000,
          'todayResultUnits': 1053,
          'todayPaidUnits': 500,
          'totalDebtUnits': 2553,
          'vodafoneRemainingUnits': 0,
          'dayClosingDebtUnits': 2553,
        },
      },
    ],
    'lifetimeTotals': {
      'resultUnits': 50000,
      'paidUnits': 47447,
      'remainingUnits': 2553,
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
      'activeCashTone': 'positive',
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
            'createdByName': 'مدير تجريبي',
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
          'createdByName': 'مدير تجريبي',
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
          {'text': 'سبب تجريبي', 'changeUnits': 1200},
        ],
      },
    ],
    'methodology': {
      'formula': 'ديون لنا + النشط + المصري − ديون علينا',
      'note': 'نص من الخادم',
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
        'createdAt': '2026-10-18T12:00:00+02:00',
      },
    ],
    'unreadCount': unread,
    'nextBefore': null,
  };
}
