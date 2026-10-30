import 'dart:math' as math;

/// Opt-in fake history. Debug, profile, and test only.
///
/// `FAKE_DATASET=large` selects this catalog. The default stays [standard],
/// which is the short fixture library. Release builds never
/// construct a fake client (`ReleaseFakeApiGuard`), and the release builder
/// does not import this file.
abstract final class FakeDataset {
  static const standard = 'standard';
  static const large = 'large';

  /// [explicit] wins over the compile-time define so a single test process
  /// can build one large client without rebuilding the suite.
  static String resolve(String? explicit) {
    final name = explicit ??
        const String.fromEnvironment('FAKE_DATASET', defaultValue: standard);
    if (name.isEmpty || name == standard) return standard;
    if (name == large) return large;
    throw ArgumentError.value(
      name,
      'FAKE_DATASET',
      'expected "$standard" or "$large"',
    );
  }
}

/// Deterministic pages for P7-25 and the long-history scroll in P7-24.
///
/// Rows are generated from the index. Nothing here retains the whole catalog.
/// Money fields are stored literals (a function of the index), not a sum of
/// other rows. Summary figures below are constants, not reductions.
abstract final class FakeLargeCatalog {
  static const customerCount = 4000;
  static const companyCount = 2000;
  static const collectionCount = 3000;
  static const notificationCount = 3000;

  /// 20 pages. P7-25 walks every page through the real load-more control.
  static const ledgerLineCount = 800;
  static const pageSize = 40;

  /// Stored unread total for each large-history user. Not counted from rows
  /// at request time. The seed uses even indexes as the unread half, and this
  /// constant is that half so a mark-read can decrement a known literal.
  static const notificationUnreadLiteral = 1500;

  static const longLedgerAccountId = 'lc_00000';

  /// Same ids as the short fixture users. Duplicated so this file does not
  /// import the fixture library (the release scan allow-list).
  static const adminUserId = 'u_1';
  static const demoEmployeeId = 'u_12';
  static const otherEmployeeId = 'u_20';

  static const noticeUsers = <String>[
    adminUserId,
    demoEmployeeId,
    otherEmployeeId,
  ];

  static int get ledgerPageCount => (ledgerLineCount / pageSize).ceil();

  static int accountCount(String section) => switch (section) {
        'companies' => companyCount,
        'customers' => customerCount,
        _ => 0,
      };

  static bool pagesAccounts(String section) => accountCount(section) > 0;

  static int offsetFromCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return 0;
    if (!cursor.startsWith('o:')) return -1;
    return int.tryParse(cursor.substring(2)) ?? -1;
  }

  static Map<String, dynamic>? cardOrNull(String section, String id) {
    final index = _accountIndex(section, id);
    if (index == null) return null;
    return accountCard(section, index);
  }

  static Map<String, dynamic> accountPage({
    required String section,
    required String? cursor,
    required int limit,
    String? q,
    String? filter,
  }) {
    final total = accountCount(section);
    final start = offsetFromCursor(cursor);
    if (start < 0 || total == 0) {
      return _accountBody(section, const [], total, null);
    }
    final capped = _cap(limit);
    final items = <Map<String, dynamic>>[];
    var index = start;
    while (index < total && items.length < capped) {
      if (_accountVisible(section, index, q: q, filter: filter)) {
        items.add(accountCard(section, index));
      }
      index++;
    }
    final more =
        index < total && _anyFrom(section, index, q: q, filter: filter);
    return _accountBody(
      section,
      items,
      total,
      more ? 'o:$index' : null,
    );
  }

  static Map<String, dynamic> accountCard(String section, int index) {
    final balance = index % 29 == 0 ? 0 : (index * 17) % 4000;
    final age = index % 90;
    return {
      'id': _accountId(section, index),
      'name': section == 'companies'
          ? 'شركة سجل ${index + 1}'
          : 'عميل سجل ${index + 1}',
      'phone': _phone(index),
      'balanceUnits': balance,
      'debtAgeDays': age,
      'ageStatus': _ageStatus(age, balance),
      'ageStatusLabel': _ageLabel(age, balance),
      'pinned': index % 17 == 0,
      'version': 4,
      'systemManaged': false,
      if (index % 23 == 0) 'zeroReview': {'status': 'pending', 'pending': true},
    };
  }

  /// One known customer card owns the long ledger. Other cards stay one page
  /// so opening them does not pretend to be the longest book.
  static bool isLongLedger(String section, String accountId) =>
      section == 'customers' && accountId == longLedgerAccountId;

  static Map<String, dynamic> ledgerPage({String? before}) {
    final start = _ledgerStart(before);
    if (start < 0) {
      return {
        'items': <Map<String, dynamic>>[],
        'pageOpeningBalanceUnits': 0,
        'nextBefore': null,
        'hasMore': false,
        'historyPageCount': ledgerPageCount,
      };
    }
    final end = math.min(start + pageSize, ledgerLineCount);
    final items = <Map<String, dynamic>>[
      for (var index = start; index < end; index++) ledgerLine(index),
    ];
    final more = end < ledgerLineCount;
    return {
      'items': items,
      'pageOpeningBalanceUnits': 0,
      'nextBefore': more ? items.last['id'] : null,
      'hasMore': more,
      'historyPageCount': ledgerPageCount,
    };
  }

  static Map<String, dynamic> ledgerLine(int index) {
    final amount = 20 + (index % 80);
    return {
      'id': 'ltx_${index.toString().padLeft(5, '0')}',
      'sequence': index + 1,
      'type': index.isEven ? 'debt' : 'payment',
      'status': 'posted',
      'transactionDate': _stamp(index),
      'note': 'سطر سجل ${index + 1}',
      'amountUnits': amount,
      'inputValue': amount,
      'calculationMode': 'direct',
      // Stored on the row. Not a running total of earlier lines.
      'balanceAfterUnits': 100 + (index % 400),
      'createdByName': 'كاتب السجل',
    };
  }

  static int visibleCollections({
    required bool seesAll,
    required String? userId,
  }) {
    if (seesAll) return collectionCount;
    if (userId == demoEmployeeId || userId == otherEmployeeId) {
      return collectionCount ~/ 2;
    }
    return 0;
  }

  static Map<String, dynamic> collectionsPage({
    required String? cursor,
    required int limit,
    required bool seesAll,
    required String? userId,
  }) {
    final visible = visibleCollections(seesAll: seesAll, userId: userId);
    final start = offsetFromCursor(cursor);
    if (start < 0 || visible == 0) {
      return {
        'assignments': <Map<String, dynamic>>[],
        'submissions': <Map<String, dynamic>>[],
        'nextCursor': null,
        'visibleCount': visible,
        'historyPageCount': (visible / pageSize).ceil(),
      };
    }
    final capped = _cap(limit);
    final assignments = <Map<String, dynamic>>[];
    final submissions = <Map<String, dynamic>>[];
    var index = start;
    while (index < collectionCount && assignments.length < capped) {
      if (_ownsCollection(index, seesAll: seesAll, userId: userId)) {
        assignments.add(_assignment(index));
        submissions.add(_submission(index));
      }
      index++;
    }
    final more = index < collectionCount &&
        _ownsAnyFrom(index, seesAll: seesAll, userId: userId);
    return {
      'assignments': assignments,
      'submissions': submissions,
      'nextCursor': more ? 'o:$index' : null,
      'visibleCount': visible,
      'historyPageCount': (visible / pageSize).ceil(),
    };
  }

  static bool hasNotices(String? userId) =>
      userId != null && noticeUsers.contains(userId);

  static Map<String, int> get unreadLiterals => {
        for (final userId in noticeUsers) userId: notificationUnreadLiteral,
      };

  static Map<String, dynamic> notificationPage({
    required String userId,
    required String? before,
  }) {
    if (!hasNotices(userId)) {
      return {
        'items': <Map<String, dynamic>>[],
        'nextBefore': null,
        'historyPageCount': 0,
      };
    }
    var start = 0;
    if (before != null && before.isNotEmpty) {
      final index = _noticeIndex(userId, before);
      if (index == null) {
        return {
          'items': <Map<String, dynamic>>[],
          'nextBefore': null,
          'historyPageCount': (notificationCount / pageSize).ceil(),
        };
      }
      start = index + 1;
    }
    final end = math.min(start + pageSize, notificationCount);
    final items = <Map<String, dynamic>>[
      for (var index = start; index < end; index++) notice(userId, index),
    ];
    final more = end < notificationCount;
    return {
      'items': items,
      'nextBefore': more ? items.last['id'] : null,
      'historyPageCount': (notificationCount / pageSize).ceil(),
    };
  }

  static Map<String, dynamic>? noticeOrNull(String? userId, String id) {
    if (userId == null || !hasNotices(userId)) return null;
    final index = _noticeIndex(userId, id);
    if (index == null) return null;
    return notice(userId, index);
  }

  static Map<String, dynamic> notice(String userId, int index) {
    final padded = index.toString().padLeft(5, '0');
    return {
      'id': 'ln_${userId}_$padded',
      'action': 'collection.submit',
      'title': 'سجل إشعار ${index + 1}',
      'body': 'صف من التجهيز الكبير',
      'section': 'collections',
      'entityId': 'ls_$padded',
      'readAt': null,
      'createdAt': _stamp(index),
      'systemName': 'الاستلامات',
      'employeeName': 'اسم السجل',
      'recipientUserId': userId,
    };
  }

  static int _cap(int limit) {
    if (limit < 1) return 1;
    if (limit > pageSize) return pageSize;
    return limit;
  }

  static Map<String, dynamic> _accountBody(
    String section,
    List<Map<String, dynamic>> items,
    int total,
    String? nextCursor,
  ) {
    return {
      'items': items,
      'nextCursor': nextCursor,
      'totalItems': total,
      'summary': _summary(section),
      'historyPageCount': total == 0 ? 0 : (total / pageSize).ceil(),
    };
  }

  /// Constants. Not the sum of [accountCard] balances.
  static Map<String, dynamic> _summary(String section) {
    if (section == 'companies') {
      return {
        'netBalance': 4000000,
        'totalDebt': 4000000,
        'activeCards': companyCount,
        'pendingReviewCount': 80,
      };
    }
    return {
      'netBalance': 12800000,
      'totalDebt': 12800000,
      'activeCards': customerCount,
      'pendingReviewCount': 174,
    };
  }

  static bool _accountVisible(
    String section,
    int index, {
    String? q,
    String? filter,
  }) {
    final card = accountCard(section, index);
    final query = q?.trim() ?? '';
    if (query.isNotEmpty && !'${card['name']}'.contains(query)) return false;
    return switch (filter) {
      null || '' => true,
      'today' => index % 10 == 0,
      'debts' => card['balanceUnits'] != 0,
      'settled' => card['balanceUnits'] == 0,
      'pinned' => card['pinned'] == true,
      'pendingReview' => index % 23 == 0,
      _ => true,
    };
  }

  static bool _anyFrom(
    String section,
    int start, {
    String? q,
    String? filter,
  }) {
    final total = accountCount(section);
    for (var index = start; index < total; index++) {
      if (_accountVisible(section, index, q: q, filter: filter)) return true;
    }
    return false;
  }

  static bool _ownsCollection(
    int index, {
    required bool seesAll,
    required String? userId,
  }) {
    if (seesAll) return true;
    final owner = index.isEven ? demoEmployeeId : otherEmployeeId;
    return owner == userId;
  }

  static bool _ownsAnyFrom(
    int start, {
    required bool seesAll,
    required String? userId,
  }) {
    for (var index = start; index < collectionCount; index++) {
      if (_ownsCollection(index, seesAll: seesAll, userId: userId)) {
        return true;
      }
    }
    return false;
  }

  static Map<String, dynamic> _assignment(int index) {
    final padded = index.toString().padLeft(5, '0');
    return {
      'id': 'la_$padded',
      'customerId': 'lc_$padded',
      'customerName': 'عميل سجل ${index + 1}',
      'section': 'customers',
      'phone': _phone(index),
      'balanceUnits': (index * 13) % 2000,
      'status': 'open',
      'assigneeUserId': index.isEven ? demoEmployeeId : otherEmployeeId,
    };
  }

  static Map<String, dynamic> _submission(int index) {
    final padded = index.toString().padLeft(5, '0');
    return {
      'id': 'ls_$padded',
      'mode': index.isEven ? 'partial' : 'full',
      'amountUnits': 10 + (index % 50),
      'status': 'pending',
      'version': 1,
      'cashStatus': 'not_applicable',
      'submittedByName': 'كاتب السجل',
      'submittedByUserId': index.isEven ? demoEmployeeId : otherEmployeeId,
      'createdAt': _stamp(index),
    };
  }

  static String _accountId(String section, int index) {
    final prefix = section == 'companies' ? 'lf_' : 'lc_';
    return '$prefix${index.toString().padLeft(5, '0')}';
  }

  static int? _accountIndex(String section, String id) {
    final prefix = section == 'companies'
        ? 'lf_'
        : section == 'customers'
            ? 'lc_'
            : null;
    if (prefix == null || !id.startsWith(prefix)) return null;
    final index = int.tryParse(id.substring(prefix.length));
    final total = accountCount(section);
    if (index == null || index < 0 || index >= total) return null;
    return index;
  }

  static int _ledgerStart(String? before) {
    if (before == null || before.isEmpty) return 0;
    if (!before.startsWith('ltx_')) return -1;
    final index = int.tryParse(before.substring(4));
    if (index == null || index < 0 || index >= ledgerLineCount) return -1;
    return index + 1;
  }

  static int? _noticeIndex(String userId, String id) {
    final prefix = 'ln_${userId}_';
    if (!id.startsWith(prefix)) return null;
    final index = int.tryParse(id.substring(prefix.length));
    if (index == null || index < 0 || index >= notificationCount) return null;
    return index;
  }

  static String _phone(int index) =>
      '092${(1000000 + index).toString().padLeft(7, '0')}';

  static String _stamp(int index) => DateTime.utc(
        2026,
        1,
        1,
      ).subtract(Duration(minutes: index)).toIso8601String();

  static String _ageStatus(int age, int balance) {
    if (balance == 0) return 'zero';
    if (age < 3) return 'new';
    if (age < 7) return 'warning';
    return 'overdue';
  }

  static String _ageLabel(int age, int balance) {
    if (balance == 0) return 'صفر';
    if (age < 3) return 'جديد';
    if (age < 7) return 'متابعة';
    return 'متأخر';
  }
}
