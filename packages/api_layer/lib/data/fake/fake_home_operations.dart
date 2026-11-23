/// Synthetic read-only contract fixtures, never used with the remote API.
Map<String, dynamic> fakeClosingOverview() => {
      'latestClosing': {
        'state': 'recorded',
        'businessDate': '2026-11-22',
        'netUnits': 162665
      },
      'closings': [
        {
          'businessDate': '2026-11-22',
          'netUnits': 162665,
          'changeUnits': 4000,
          'previousBusinessDate': '2026-11-21'
        },
      ],
    };

Map<String, dynamic> fakeReportActivity() => {
      'items': [
        {
          'id': 9001,
          'description': 'استلام دفعة من عميل',
          'name': 'عميل اختبار',
          'currency': 'LYD',
          'amountUnits': 6500,
          'occurredAt': '2026-11-23T09:18:00Z'
        },
        {
          'id': 9000,
          'description': 'شراء — دفتر اليوم',
          'name': 'مورد اختبار',
          'currency': 'LYD',
          'amountUnits': 12000,
          'occurredAt': '2026-11-23T08:30:00Z'
        },
      ],
      'hasMore': false,
    };
