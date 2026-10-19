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

  static Map<String, dynamic> me({required bool admin}) => {
        'user': {
          'id': admin ? 'u_1' : 'u_12',
          'username':
              admin ? 'admin@example.invalid' : 'employee@example.invalid',
          'displayName': admin ? 'مدير تجريبي' : 'موظف استلام تجريبي',
          'role': admin ? 'admin' : 'employee',
          'permissions': admin ? <String>[] : employeePermissions,
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
        'hasMore': false,
        'totalDebtUnits': egp ? 15000 : 320,
        'activeCount': 1,
      };

  static Map<String, dynamic> ledger() => {
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
        'nextBefore': null,
        'hasMore': false,
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
            'submittedByName': 'موظف استلام تجريبي',
            'createdAt': '2026-10-18T12:00:00+02:00'
          },
        ],
        'unlinkedReceipts': [],
        'employeeTotals': [
          {
            'employeeName': 'موظف استلام تجريبي',
            'collectedUnits': 0,
            'approvedCount': 0,
            'pendingCount': 1
          },
        ],
        'metrics': {'collectedUnits': 0, 'dayTotalUnits': 100},
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
          'netUnits': 51000
        },
      };

  static Map<String, dynamic> cashLedger() => {
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
        'nextBefore': null,
      };

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
            'diffFromPreviousUnits': 1200,
            'status': 'normal',
            'note': ''
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
