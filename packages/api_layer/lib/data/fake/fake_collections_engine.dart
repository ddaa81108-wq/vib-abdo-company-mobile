/// Card access the collections engine needs from the fake client.
///
/// [section] is the app path (`customers`, `companies`, `libyan-deposits`,
/// `egyptian-deposits`). A missing card is null.
abstract interface class FakeCollectionCards {
  FakeCollectionCard? card(String section, String id);

  /// Adds [deltaUnits] (negative for a payment) and returns the new balance.
  int post(String section, String id, int deltaUnits);

  /// Server-side name search over the four linkable sections.
  List<FakeCollectionCard> search(String query);
}

class FakeCollectionCard {
  const FakeCollectionCard({
    required this.id,
    required this.section,
    required this.name,
    required this.balanceUnits,
    this.phone,
    this.version,
  });
  final String id;
  final String section;
  final String name;
  final int balanceUnits;
  final String? phone;
  final int? version;
}

/// A failure the fake client turns into its HTTP error body.
class FakeCollectionsFailure implements Exception {
  const FakeCollectionsFailure(this.status, this.code, this.message,
      [this.details]);
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic>? details;
}

/// The signed-in caller as the 537f073 collections server sees it.
class FakeCollectionsCaller {
  const FakeCollectionsCaller({
    required this.id,
    required this.name,
    required this.seesEverything,
  });
  final String? id;
  final String name;

  /// Admin scope (role admin on the server). Employees see their own rows.
  final bool seesEverything;
}

/// In-memory copy of the collections rules deployed on staging (537f073,
/// `src/server/domain/collections.ts` and `collectionPayroll.ts`).
///
/// Rules kept on purpose, because the app must match them:
/// - one pending submission per assignment (PENDING_SUBMISSION_EXISTS),
///   for partial and full alike;
/// - a full receipt needs a positive debt and, when `amountUnits` is sent,
///   it must equal the current debt (FULL_AMOUNT_CHANGED);
/// - submissions do not replay by `requestId` (537f073 ignores it);
///   unlinked receipts and payroll entries do;
/// - approve posts a payment of the amount onto the card; reject cancels the
///   assignment;
/// - rejected unlinked receipts are not listed;
/// - closing a batch is refused while anything is pending or cash is owed,
///   and then deletes the batch rows.
/// Metrics are computed here the same way the server SQL does.
class FakeCollectionsEngine {
  FakeCollectionsEngine(
    this._cards, {
    required this.demoEmployeeId,
    required this.otherEmployeeId,
  }) {
    _seed();
  }

  /// Fixture employees (`demoEmployeeId` / `otherEmployeeId`).
  final String demoEmployeeId;
  final String otherEmployeeId;

  final FakeCollectionCards _cards;

  final List<Map<String, dynamic>> _assignments = [];
  final List<Map<String, dynamic>> _submissions = [];
  final List<Map<String, dynamic>> _unlinked = [];
  final List<Map<String, dynamic>> _batches = [];
  final List<Map<String, dynamic>> _payroll = [];
  final List<Map<String, dynamic>> _payrollEntries = [];
  var _clock = 0;
  var _ids = 0;

  /// Submissions accepted, including any duplicate a retry created.
  int get submissionCount => _submissions.length;

  late final Map<String, String> employees = {
    demoEmployeeId: 'موظف استلام تجريبي',
    otherEmployeeId: 'موظف آخر تجريبي',
  };

  String _now() {
    _clock++;
    final t = DateTime.utc(2026, 10, 18, 10).add(Duration(minutes: _clock));
    return t.toIso8601String();
  }

  String _id(String prefix) => '${prefix}_posted_${++_ids}';

  void _seed() {
    _batches.add({
      'id': 'b_1',
      'businessDate': '2026-10-18',
      'batchNumber': 1,
      'openedAt': '2026-10-18T06:00:00.000Z',
      'status': 'open',
    });
    void assign(String id, String customerId, String assignee, String at,
        {String section = 'customers'}) {
      _assignments.add({
        'id': id,
        'customerId': customerId,
        'section': section,
        'assigneeUserId': assignee,
        'status': 'active',
        'businessDate': '2026-10-18',
        'batchId': 'b_1',
        'assignedAt': at,
      });
    }

    assign('as_1', 'c_55', demoEmployeeId, '2026-10-18T07:00:00.000Z');
    assign('as_2', 'c_56', demoEmployeeId, '2026-10-18T06:30:00.000Z');
    assign('as_9', 'c_58', otherEmployeeId, '2026-10-18T06:40:00.000Z');
    void submit(String id, String assignmentId, String customerId,
        String collector, String mode, int amount, String status, String at,
        {String? decidedAt}) {
      _submissions.add({
        'id': id,
        'assignmentId': assignmentId,
        'customerId': customerId,
        'collectorUserId': collector,
        'mode': mode,
        'amountUnits': amount,
        'status': status,
        'businessDate': '2026-10-18',
        'batchId': 'b_1',
        'submittedAt': at,
        'decidedAt': decidedAt,
        'decisionNote': '',
        'cashReceivedAt': null,
      });
    }

    submit('sb_2', 'as_2', 'c_56', demoEmployeeId, 'partial', 250, 'approved',
        '2026-10-18T07:30:00.000Z',
        decidedAt: '2026-10-18T07:40:00.000Z');
    submit('sb_1', 'as_2', 'c_56', demoEmployeeId, 'partial', 100, 'pending',
        '2026-10-18T10:00:00.000Z');
    submit('sb_9', 'as_9', 'c_58', otherEmployeeId, 'partial', 900, 'pending',
        '2026-10-18T13:00:00.000Z');
    void receipt(String id, String name, int amount, String status,
        String collector, String at) {
      _unlinked.add({
        'id': id,
        'customerName': name,
        'amountUnits': amount,
        'status': status,
        'submittedAt': at,
        'businessDate': '2026-10-18',
        'batchId': 'b_1',
        'linkedCustomerId': null,
        'entryType': null,
        'decidedAt': status == 'pending' ? null : at,
        'decisionNote': '',
        'cashReceivedAt': null,
        'collectorUserId': collector,
        'requestId': 'seed-$id',
      });
    }

    receipt('ur_1', 'اسم غير مربوط تجريبي', 50, 'pending', demoEmployeeId,
        '2026-10-18T09:00:00.000Z');
    receipt('ur_2', 'استلام مرفوض تجريبي', 40, 'rejected', demoEmployeeId,
        '2026-10-18T08:00:00.000Z');
    receipt('ur_9', 'إيصال موظف آخر', 900, 'pending', otherEmployeeId,
        '2026-10-18T11:00:00.000Z');

    _payroll.addAll([
      {
        'employeeId': demoEmployeeId,
        'username': 'employee.demo',
        'baseSalaryUnits': 1500,
        'openingCarryUnits': 0,
      },
      {
        'employeeId': otherEmployeeId,
        'username': 'other.employee.demo',
        'baseSalaryUnits': 2400,
        'openingCarryUnits': 100,
      },
    ]);
    _payrollEntries.addAll([
      {
        'id': 'pe_1',
        'employeeId': demoEmployeeId,
        'kind': 'withdrawal',
        'amountUnits': 300,
        'reason': 'سلفة تجريبية',
        'createdAt': '2026-10-05T09:00:00.000Z',
        'createdByName': 'مدير تجريبي',
        'confirmedAt': null,
        'confirmedByName': null,
        'requestId': 'seed-pe_1',
      },
      {
        'id': 'pe_2',
        'employeeId': demoEmployeeId,
        'kind': 'commission',
        'amountUnits': 50,
        'reason': 'عمولة تجريبية',
        'createdAt': '2026-10-04T09:00:00.000Z',
        'createdByName': 'مدير تجريبي',
        'confirmedAt': '2026-10-04T10:00:00.000Z',
        'confirmedByName': 'موظف استلام تجريبي',
        'requestId': 'seed-pe_2',
      },
      {
        'id': 'pe_9',
        'employeeId': otherEmployeeId,
        'kind': 'commission',
        'amountUnits': 80,
        'reason': 'مكافأة تجريبية',
        'createdAt': '2026-10-03T09:00:00.000Z',
        'createdByName': 'مدير تجريبي',
        'confirmedAt': null,
        'confirmedByName': null,
        'requestId': 'seed-pe_9',
      },
    ]);
  }

  Never _fail(int status, String code, String message,
          [Map<String, dynamic>? details]) =>
      throw FakeCollectionsFailure(status, code, message, details);

  Never _notFound(String entity) =>
      _fail(404, 'NOT_FOUND', 'السجل المطلوب غير موجود.', {'entity': entity});

  Never _forbidden(String permission) => _fail(403, 'PERMISSION_DENIED',
      'ليست لديك صلاحية لهذه العملية.', {'permission': permission});

  int _positiveWhole(Object? value, String field) {
    if (value is! int || value <= 0) {
      _fail(
          400,
          'INVALID_AMOUNT',
          'القيمة المالية يجب أن تكون رقمًا صحيحًا موجبًا بدون كسور.',
          {'field': field});
    }
    return value;
  }

  String _requestId(Object? value) {
    if (value is! String || value.length < 8 || value.length > 128) {
      _fail(
          400, 'REQUEST_ID_REQUIRED', 'يلزم requestId ثابت وآمن لهذه العملية.');
    }
    return value;
  }

  Map<String, dynamic> _openBatch() {
    for (final batch in _batches.reversed) {
      if (batch['status'] == 'open') return batch;
    }
    final next = {
      'id': _id('b'),
      'businessDate': '2026-10-18',
      'batchNumber': _batches.length + 1,
      'openedAt': _now(),
      'status': 'open',
    };
    _batches.add(next);
    return next;
  }

  FakeCollectionCard? _cardOf(Map<String, dynamic> assignment) =>
      _cards.card('${assignment['section']}', '${assignment['customerId']}');

  List<Map<String, dynamic>> _subsOf(String assignmentId) => [
        for (final s in _submissions)
          if (s['assignmentId'] == assignmentId) s,
      ];

  /// `GET /api/collections`, scoped like the server.
  Map<String, dynamic> overview(FakeCollectionsCaller caller) {
    final mine = caller.seesEverything
        ? (Map<String, dynamic> row, String field) => true
        : (Map<String, dynamic> row, String field) => row[field] == caller.id;
    final assignments = <Map<String, dynamic>>[];
    for (final a in _assignments) {
      if (a['status'] != 'active' || !mine(a, 'assigneeUserId')) continue;
      final card = _cardOf(a);
      if (card == null) continue;
      final subs = _subsOf('${a['id']}')
        ..sort(
            (x, y) => '${y['submittedAt']}'.compareTo('${x['submittedAt']}'));
      final latest = subs.isEmpty ? null : subs.first;
      final external = a['externalFinancialUpdatedAt'] ?? a['assignedAt'];
      assignments.add({
        'id': a['id'],
        'customerId': a['customerId'],
        'assigneeUserId': a['assigneeUserId'],
        'status': a['status'],
        'businessDate': a['businessDate'],
        'batchId': a['batchId'],
        'assignedAt': a['assignedAt'],
        'customerName': card.name,
        'phone': card.phone,
        'customerVersion': card.version,
        'assigneeName': employees[a['assigneeUserId']] ?? '',
        'balanceUnits': card.balanceUnits,
        'assignedBalanceUnits': card.balanceUnits,
        'hasPending': subs.any((s) => s['status'] == 'pending') ? 1 : 0,
        'latestMode': latest?['mode'],
        'latestStatus': latest?['status'],
        'latestCashReceivedAt': latest?['cashReceivedAt'],
        'latestDecisionAt': latest?['decidedAt'],
        'externalFinancialUpdatedAt': external,
        'latestSubmissionAt': latest?['submittedAt'],
        'cashOutstandingCount': subs
            .where(
                (s) => s['status'] == 'approved' && s['cashReceivedAt'] == null)
            .length,
        // App-side hint kept from the older fake: the section path.
        'section': a['section'],
      });
    }
    assignments.sort(compareCollectionCards);
    final submissions = <Map<String, dynamic>>[];
    for (final s in _submissions) {
      if (!mine(s, 'collectorUserId')) continue;
      final a = _assignments.firstWhere((x) => x['id'] == s['assignmentId']);
      final card = _cardOf(a);
      submissions.add({
        ...s,
        'customerName': card?.name ?? '',
        'phone': card?.phone,
        'collectorName': employees[s['collectorUserId']] ?? '',
      });
    }
    submissions
        .sort((x, y) => '${y['submittedAt']}'.compareTo('${x['submittedAt']}'));
    final unlinked = <Map<String, dynamic>>[
      for (final r in _unlinked)
        if (r['status'] != 'rejected' && mine(r, 'collectorUserId'))
          {
            for (final e in r.entries)
              if (e.key != 'collectorUserId' && e.key != 'requestId')
                e.key: e.value,
            'collectorName': employees[r['collectorUserId']] ?? '',
          },
    ];
    unlinked.sort((x, y) {
      int rank(Map r) => r['status'] == 'pending' ? 0 : 1;
      final byStatus = rank(x) - rank(y);
      if (byStatus != 0) return byStatus;
      return '${y['submittedAt']}'.compareTo('${x['submittedAt']}');
    });
    var collected = 0, pending = 0, executed = 0, cash = 0, unlinkedPending = 0;
    for (final s in _submissions) {
      if (!mine(s, 'collectorUserId')) continue;
      final amount = s['amountUnits'] as int;
      if (s['status'] == 'pending') pending++;
      if (s['status'] == 'approved') {
        collected += amount;
        executed++;
        if (s['cashReceivedAt'] == null) cash += amount;
      }
    }
    for (final r in _unlinked) {
      if (!mine(r, 'collectorUserId')) continue;
      final amount = r['amountUnits'] as int;
      if (r['status'] == 'pending') unlinkedPending++;
      if (r['status'] == 'approved') {
        collected += amount;
        executed++;
        if (r['cashReceivedAt'] == null) cash += amount;
      }
    }
    final outstanding = <Map<String, dynamic>>[];
    for (final s in _submissions) {
      if (!mine(s, 'collectorUserId')) continue;
      final a = _assignments.firstWhere((x) => x['id'] == s['assignmentId']);
      if (a['status'] != 'cancelled') continue;
      if (s['status'] != 'approved' || s['cashReceivedAt'] != null) continue;
      outstanding.add({
        'id': s['id'],
        'amountUnits': s['amountUnits'],
        'customerName': _cardOf(a)?.name ?? '',
        'collectorName': employees[s['collectorUserId']] ?? '',
      });
    }
    return {
      'assignments': assignments,
      'submissions': submissions,
      'unlinkedReceipts': unlinked,
      'outstandingCancelledSubmissions': outstanding,
      'metrics': {
        'collectedUnits': collected,
        'pendingCount': pending,
        'executedCount': executed,
        'cashOutstandingUnits': cash,
        'unlinkedPendingCount': unlinkedPending,
      },
      if (caller.seesEverything) 'employeeTotals': _employeeTotals(),
      'assignedCount': assignments.length,
      'openBatches': [
        for (final b in _batches.reversed)
          if (b['status'] == 'open')
            {
              'id': b['id'],
              'businessDate': b['businessDate'],
              'batchNumber': b['batchNumber'],
              'openedAt': b['openedAt'],
            },
      ],
    };
  }

  List<Map<String, dynamic>> _employeeTotals() {
    final rows = <Map<String, dynamic>>[];
    for (final entry in employees.entries) {
      var collected = 0, approved = 0, pending = 0;
      for (final row in [..._submissions, ..._unlinked]) {
        if (row['collectorUserId'] != entry.key) continue;
        if (row['status'] == 'approved') {
          collected += row['amountUnits'] as int;
          approved++;
        }
        if (row['status'] == 'pending') pending++;
      }
      rows.add({
        'employeeId': entry.key,
        'employeeName': entry.value,
        'collectedUnits': collected,
        'approvedCount': approved,
        'pendingCount': pending,
      });
    }
    return rows;
  }

  /// `GET /api/collections/assignees`.
  Map<String, dynamic> assignees() => {
        'items': [
          for (final e in employees.entries)
            {'id': e.key, 'username': e.key, 'displayName': e.value},
        ],
      };

  /// The account list's `activeAssigneeName` on 537f073: the assignee of
  /// the card's active assignment in [section], or null.
  String? activeAssigneeName(String section, String customerId) {
    for (final a in _assignments) {
      if (a['status'] == 'active' &&
          a['customerId'] == customerId &&
          (a['section'] ?? 'customers') == section) {
        return employees['${a['assigneeUserId']}'];
      }
    }
    return null;
  }

  /// `POST /api/collections/assignments`.
  Map<String, dynamic> assign(Map body) {
    final assignee =
        body['assigneeUserId'] is String ? '${body['assigneeUserId']}' : '';
    final section = body['section'] == 'companies' ? 'companies' : 'customers';
    final raw = body['customerIds'] is List ? body['customerIds'] as List : [];
    if (raw.any((id) => id is! String || id.trim().isEmpty)) {
      _fail(400, 'INVALID_ASSIGNMENT', 'أحد معرّفات الكروت غير صالح.');
    }
    final ids = {for (final id in raw) '$id'.trim()}.toList();
    if (assignee.isEmpty || ids.isEmpty) {
      _fail(400, 'INVALID_ASSIGNMENT', 'اختر الموظف وكارتًا واحدًا على الأقل.');
    }
    if (!employees.containsKey(assignee)) {
      _fail(400, 'INVALID_ASSIGNEE',
          'الموظف غير نشط أو ليست لديه صلاحية الاستلام.');
    }
    final batch = _openBatch();
    final at = _now();
    final created = <String>[];
    final staged = <Map<String, dynamic>>[];
    for (final customerId in ids) {
      final card = _cards.card(section, customerId);
      if (card == null) {
        _notFound(section == 'companies' ? 'company' : 'customer');
      }
      if (card.balanceUnits <= 0) {
        _fail(409, 'ASSIGNMENT_REQUIRES_POSITIVE_DEBT',
            'يمكن توجيه الكروت ذات الدين الموجب فقط. كارت الصفر أو الأمانة لا يقبل التوجيه.');
      }
      if (_assignments.any(
          (a) => a['customerId'] == customerId && a['status'] == 'active')) {
        _fail(
            409, 'CUSTOMER_ALREADY_ASSIGNED', 'أحد الكروت محدد لموظف بالفعل.');
      }
      final id = _id('as');
      staged.add({
        'id': id,
        'customerId': customerId,
        'section': section,
        'assigneeUserId': assignee,
        'status': 'active',
        'businessDate': batch['businessDate'],
        'batchId': batch['id'],
        'assignedAt': at,
      });
      created.add(id);
    }
    _assignments.addAll(staged);
    return {
      'assignmentIds': created,
      'eventSequences': [1]
    };
  }

  /// `POST /api/collections/assignments/{id}/submissions`.
  Map<String, dynamic> submit(
      FakeCollectionsCaller caller, String assignmentId, Map body) {
    final mode = body['mode'];
    if (mode != 'full' && mode != 'partial') {
      _fail(400, 'INVALID_MODE', 'نوع الاستلام غير صالح.');
    }
    final index = _assignments.indexWhere((a) => a['id'] == assignmentId);
    if (index < 0) _notFound('assignment');
    final a = _assignments[index];
    final card = _cardOf(a);
    if (card == null) _notFound('assignment');
    if (a['status'] != 'active') {
      _fail(409, 'ASSIGNMENT_CLOSED', 'هذا التكليف غير نشط.');
    }
    if (!caller.seesEverything && a['assigneeUserId'] != caller.id) {
      _forbidden('collections.write');
    }
    final debt = card.balanceUnits;
    if (mode == 'full' && debt <= 0) {
      _fail(409, 'NO_POSITIVE_DEBT', 'لا يوجد دين موجب للاستلام الكلي.');
    }
    final amount = _positiveWhole(
        mode == 'full' ? debt : body['amountUnits'], 'amountUnits');
    if (mode == 'full' &&
        body.containsKey('amountUnits') &&
        body['amountUnits'] != null &&
        body['amountUnits'] != debt) {
      _fail(409, 'FULL_AMOUNT_CHANGED',
          'الاستلام الكلي يجب أن يساوي الدين الحالي بالضبط.');
    }
    if (_subsOf(assignmentId).any((s) => s['status'] == 'pending')) {
      _fail(409, 'PENDING_SUBMISSION_EXISTS',
          'يوجد استلام معلّق لهذا الكارت وينتظر مراجعة الإدارة.');
    }
    final id = _id('sb');
    _submissions.add({
      'id': id,
      'assignmentId': assignmentId,
      'customerId': a['customerId'],
      'collectorUserId': a['assigneeUserId'],
      'mode': mode,
      'amountUnits': amount,
      'status': 'pending',
      'businessDate': a['businessDate'],
      'batchId': a['batchId'],
      'submittedAt': _now(),
      'decidedAt': null,
      'decisionNote': '',
      'cashReceivedAt': null,
    });
    return {
      'id': id,
      'status': 'pending',
      'amountUnits': amount,
      'eventSequences': [2]
    };
  }

  /// `POST /api/collections/submissions/{id}/decision`.
  Map<String, dynamic> decide(String id, Map body) {
    final decision = body['decision'];
    if (decision != 'approve' && decision != 'reject') {
      _fail(400, 'INVALID_DECISION', 'قرار المراجعة غير صالح.');
    }
    final s = _submissions.firstWhere((x) => x['id'] == id,
        orElse: () => _notFound('submission'));
    if (s['status'] != 'pending') {
      _fail(
          409, 'SUBMISSION_ALREADY_DECIDED', 'تمت مراجعة هذا الاستلام من قبل.');
    }
    final at = _now();
    final note = body['note'] is String ? '${body['note']}'.trim() : '';
    final a = _assignments.firstWhere((x) => x['id'] == s['assignmentId']);
    if (decision == 'reject') {
      s
        ..['status'] = 'rejected'
        ..['decidedAt'] = at
        ..['decisionNote'] = note;
      if (a['status'] == 'active') {
        a
          ..['status'] = 'cancelled'
          ..['cancelledAt'] = at;
      }
      return {
        'id': id,
        'status': 'rejected',
        'eventSequences': [3, 4]
      };
    }
    final balance = _cards.post(
        '${a['section']}', '${a['customerId']}', -(s['amountUnits'] as int));
    s
      ..['status'] = 'approved'
      ..['decidedAt'] = at
      ..['decisionNote'] = note
      ..['approvedTransactionId'] = 'tx-$id';
    // A collection posting is not an "administrative movement" (website rule).
    return {
      'id': id,
      'status': 'approved',
      'transactionId': 'tx-$id',
      'balanceUnits': balance,
      'eventSequences': [3]
    };
  }

  /// `POST /api/collections/submissions/{id}/cash-received`.
  Map<String, dynamic> cashReceived(String id) {
    final s = _submissions.firstWhere((x) => x['id'] == id,
        orElse: () => _notFound('submission'));
    return _cash(s, id);
  }

  Map<String, dynamic> _cash(Map<String, dynamic> row, String id) {
    if (row['status'] != 'approved') {
      _fail(409, 'SUBMISSION_NOT_APPROVED',
          'لا يمكن استلام النقدية قبل اعتماد الاستلام.');
    }
    if (row['cashReceivedAt'] != null) {
      return {
        'id': id,
        'cashReceivedAt': row['cashReceivedAt'],
        'replayed': true,
        'eventSequences': <int>[],
      };
    }
    final at = _now();
    row['cashReceivedAt'] = at;
    return {
      'id': id,
      'cashReceivedAt': at,
      'eventSequences': [4]
    };
  }

  /// `POST /api/collections/unlinked-receipts` (employees only).
  Map<String, dynamic> createUnlinked(FakeCollectionsCaller caller, Map body) {
    if (caller.seesEverything) _forbidden('collections.employee_receipt');
    final requestId = _requestId(body['requestId']);
    final rawName = body['customerName'];
    if (rawName is! String) {
      _fail(400, 'CUSTOMER_NAME_REQUIRED', 'اسم العميل مطلوب.');
    }
    final name = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > 160) {
      _fail(400, 'INVALID_CUSTOMER_NAME',
          'اسم العميل يجب أن يكون بين حرفين و160 حرفًا.');
    }
    final amount = _positiveWhole(body['amountUnits'], 'amountUnits');
    for (final r in _unlinked) {
      if (r['collectorUserId'] == caller.id && r['requestId'] == requestId) {
        return {
          'id': r['id'],
          'status': r['status'],
          'amountUnits': r['amountUnits'],
          'replayed': true,
          'eventSequences': <int>[],
        };
      }
    }
    final batch = _openBatch();
    final id = _id('ur');
    _unlinked.add({
      'id': id,
      'customerName': name,
      'amountUnits': amount,
      'status': 'pending',
      'submittedAt': _now(),
      'businessDate': batch['businessDate'],
      'batchId': batch['id'],
      'linkedCustomerId': null,
      'entryType': null,
      'decidedAt': null,
      'decisionNote': '',
      'cashReceivedAt': null,
      'collectorUserId': caller.id,
      'requestId': requestId,
    });
    return {
      'id': id,
      'status': 'pending',
      'amountUnits': amount,
      'eventSequences': [5]
    };
  }

  int get unlinkedCount => _unlinked.length;

  static const _sectionKeys = {
    'customers': 'customer_debts',
    'companies': 'company_debts',
    'libyan-deposits': 'libyan_deposits',
    'egyptian-deposits': 'egyptian_deposits',
  };

  /// `GET /api/collections/link-candidates?q=`.
  Map<String, dynamic> linkCandidates(String? query) {
    final q = (query ?? '').trim();
    if (q.length < 2) return {'items': <Map<String, dynamic>>[]};
    // 537f073 reads one customers table, so an id appears once. The fake
    // fixtures reuse ids across sections; keep the first.
    final seen = <String>{};
    return {
      'items': [
        for (final card
            in _cards.search(q).where((c) => seen.add(c.id)).take(12))
          {
            'id': card.id,
            'name': card.name,
            'balanceUnits': card.balanceUnits,
            'sectionKey': _sectionKeys[card.section] ?? card.section,
          },
      ],
    };
  }

  /// `POST /api/collections/unlinked-receipts/{id}/decision`.
  Map<String, dynamic> decideUnlinked(String id, Map body) {
    final decision = body['decision'];
    if (decision != 'approve' && decision != 'reject') {
      _fail(400, 'INVALID_DECISION', 'قرار المراجعة غير صالح.');
    }
    final r = _unlinked.firstWhere((x) => x['id'] == id,
        orElse: () => _notFound('unlinked_collection_receipt'));
    if (r['status'] != 'pending') {
      _fail(
          409, 'SUBMISSION_ALREADY_DECIDED', 'تمت مراجعة هذا الاستلام من قبل.');
    }
    final at = _now();
    final note = body['note'] is String ? '${body['note']}'.trim() : '';
    if (decision == 'reject') {
      r
        ..['status'] = 'rejected'
        ..['decidedAt'] = at
        ..['decisionNote'] = note;
      return {
        'id': id,
        'status': 'rejected',
        'eventSequences': [6]
      };
    }
    final entryType = body['entryType'];
    if (entryType != 'debt' && entryType != 'payment') {
      _fail(400, 'UNLINKED_RECEIPT_LINK_REQUIRED',
          'اختر الكارت الأصلي ونوع الحركة قبل الاعتماد.');
    }
    var customerId =
        body['customerId'] is String ? '${body['customerId']}'.trim() : '';
    String section;
    if (customerId.isEmpty) {
      final kind = body['newAccountKind'];
      if (kind != 'customer' && kind != 'company') {
        _fail(400, 'UNLINKED_RECEIPT_LINK_REQUIRED',
            'اختر حسابًا موجودًا أو حدد قسم الحساب الجديد.');
      }
      section = kind == 'company' ? 'companies' : 'customers';
      customerId = 'new-${r['id']}';
      newAccounts['$section|$customerId'] = '${r['customerName']}';
    } else {
      String? found;
      for (final s in _sectionKeys.keys) {
        if (_cards.card(s, customerId) != null) {
          found = s;
          break;
        }
      }
      if (found == null) _notFound('customer');
      section = found;
    }
    final amount = r['amountUnits'] as int;
    final delta = entryType == 'payment' ? -amount : amount;
    final balance = newAccounts.containsKey('$section|$customerId')
        ? delta
        : _cards.post(section, customerId, delta);
    r
      ..['status'] = 'approved'
      ..['linkedCustomerId'] = customerId
      ..['entryType'] = entryType
      ..['decidedAt'] = at
      ..['decisionNote'] = note
      ..['approvedTransactionId'] = 'tx-$id';
    return {
      'id': id,
      'status': 'approved',
      'transactionId': 'tx-$id',
      'balanceUnits': balance,
      'eventSequences': [6]
    };
  }

  /// Accounts created by «عميل جديد», keyed by `section|id`, value = name.
  final Map<String, String> newAccounts = {};

  /// `POST /api/collections/unlinked-receipts/{id}/cash-received`.
  Map<String, dynamic> unlinkedCashReceived(String id) {
    final r = _unlinked.firstWhere((x) => x['id'] == id,
        orElse: () => _notFound('unlinked_collection_receipt'));
    return _cash(r, id);
  }

  /// `POST /api/collections/days/close`.
  Map<String, dynamic> closeDay(Map body) {
    final batchId = body['batchId'] is String ? '${body['batchId']}' : '';
    if (batchId.isEmpty) _fail(400, 'INVALID_BATCH', 'دفعة العمل غير صالحة.');
    if (body['confirmed'] != true) {
      _fail(400, 'CONFIRMATION_REQUIRED',
          'يلزم تأكيد استلام النقدية قبل مسح اليوم.');
    }
    final batch = _batches.firstWhere((b) => b['id'] == batchId,
        orElse: () => _notFound('collection_batch'));
    if (batch['status'] == 'closed') {
      return {
        'batchId': batchId,
        'businessDate': batch['businessDate'],
        'closed': true,
        'replayed': true
      };
    }
    var pending = 0, cash = 0;
    final rows = [
      ..._submissions.where((s) => s['batchId'] == batchId),
      ..._unlinked.where((r) => r['batchId'] == batchId),
    ];
    for (final row in rows) {
      if (row['status'] == 'pending') pending++;
      if (row['status'] == 'approved' && row['cashReceivedAt'] == null) cash++;
    }
    if (pending > 0 || cash > 0) {
      _fail(
          409,
          'COLLECTION_DAY_NOT_SETTLED',
          'لا يمكن مسح اليوم قبل اعتماد جميع العمليات واستلام كل النقدية.',
          {'pendingCount': pending, 'cashPendingCount': cash});
    }
    final deletedSubmissions =
        _submissions.where((s) => s['batchId'] == batchId).length;
    final deletedAssignments =
        _assignments.where((a) => a['batchId'] == batchId).length;
    _submissions.removeWhere((s) => s['batchId'] == batchId);
    _unlinked.removeWhere((r) => r['batchId'] == batchId);
    _assignments.removeWhere((a) => a['batchId'] == batchId);
    batch['status'] = 'closed';
    return {
      'batchId': batchId,
      'businessDate': batch['businessDate'],
      'closed': true,
      'deletedAssignments': deletedAssignments,
      'deletedSubmissions': deletedSubmissions,
      'eventSequences': [7]
    };
  }

  /// Test hook: an outside ledger movement on an assigned card (the website's
  /// "administrative movement"), stamped now.
  void markExternalMovement(String assignmentId) {
    final a = _assignments.firstWhere((x) => x['id'] == assignmentId);
    a['externalFinancialUpdatedAt'] = _now();
  }

  // ---- payroll (collectionPayroll.ts) ----

  Map<String, dynamic> _snapshot(Map<String, dynamic> row) {
    final id = row['employeeId'];
    final entries = [
      for (final e in _payrollEntries)
        if (e['employeeId'] == id)
          {
            for (final kv in e.entries)
              if (kv.key != 'employeeId' && kv.key != 'requestId')
                kv.key: kv.value,
          },
    ]..sort((x, y) => '${y['createdAt']}'.compareTo('${x['createdAt']}'));
    var withdrawals = 0, commissions = 0;
    for (final e in entries) {
      if (e['kind'] == 'withdrawal') withdrawals += e['amountUnits'] as int;
      if (e['kind'] == 'commission') commissions += e['amountUnits'] as int;
    }
    final base = row['baseSalaryUnits'] as int;
    final carry = row['openingCarryUnits'] as int;
    return {
      'employeeId': id,
      'employeeName': employees[id] ?? '',
      'username': row['username'],
      'period': '2026-10',
      'baseSalaryUnits': base,
      'openingCarryUnits': carry,
      'showOpeningCarry': false,
      'withdrawalsUnits': withdrawals,
      'commissionsUnits': commissions,
      'remainingUnits': base + carry + commissions - withdrawals,
      'entries': entries,
    };
  }

  /// `GET /api/collections/payroll`.
  Map<String, dynamic> payroll(FakeCollectionsCaller caller) => {
        'period': '2026-10',
        'employees': [
          for (final row in _payroll)
            if (caller.seesEverything || row['employeeId'] == caller.id)
              _snapshot(row),
        ],
      };

  Map<String, dynamic> _payrollRow(String employeeId) =>
      _payroll.firstWhere((r) => r['employeeId'] == employeeId,
          orElse: () => _notFound('collection_employee'));

  /// `POST /api/collections/payroll/entries` (admin).
  Map<String, dynamic> addPayrollEntry(FakeCollectionsCaller caller, Map body) {
    if (!caller.seesEverything) _forbidden('collections.payroll.manage');
    final kind = body['kind'];
    if (kind != 'withdrawal' && kind != 'commission') {
      _fail(400, 'INVALID_PAYROLL_KIND', 'نوع حركة المرتب غير صالح.');
    }
    final amount = body['amountUnits'];
    if (amount is! int || amount <= 0) {
      _fail(400, 'INVALID_PAYROLL_AMOUNT', 'اكتب قيمة صحيحة أكبر من صفر.');
    }
    final reason = body['reason'] is String ? '${body['reason']}'.trim() : '';
    if (reason.length < 2) {
      _fail(400, 'PAYROLL_REASON_REQUIRED', 'اكتب سبب الحركة بوضوح.');
    }
    final requestId = _requestId(body['requestId']);
    final employeeId = '${body['employeeUserId']}';
    _payrollRow(employeeId);
    for (final e in _payrollEntries) {
      if (e['requestId'] == requestId) {
        final same = e['employeeId'] == employeeId &&
            e['kind'] == kind &&
            e['amountUnits'] == amount &&
            e['reason'] == reason;
        if (!same) {
          _fail(409, 'IDEMPOTENCY_KEY_REUSED',
              'مفتاح الطلب مستخدم في حركة مختلفة.');
        }
        return {'id': e['id'], 'replayed': true, 'eventSequences': <int>[]};
      }
    }
    final id = _id('pe');
    _payrollEntries.add({
      'id': id,
      'employeeId': employeeId,
      'kind': kind,
      'amountUnits': amount,
      'reason': reason,
      'createdAt': _now(),
      'createdByName': caller.name,
      'confirmedAt': null,
      'confirmedByName': null,
      'requestId': requestId,
    });
    return {
      'id': id,
      'eventSequences': [8]
    };
  }

  /// `PUT /api/collections/payroll/employees/{id}/salary` (admin).
  Map<String, dynamic> setSalary(
      FakeCollectionsCaller caller, String employeeId, Map body) {
    if (!caller.seesEverything) _forbidden('collections.payroll.manage');
    final value = body['baseSalaryUnits'];
    if (value is! int || value < 0) {
      _fail(400, 'INVALID_BASE_SALARY',
          'المرتب الثابت يجب أن يكون رقمًا صحيحًا غير سالب.');
    }
    _payrollRow(employeeId)['baseSalaryUnits'] = value;
    return {
      'employeeId': employeeId,
      'baseSalaryUnits': value,
      'eventSequences': [9]
    };
  }

  /// `POST /api/collections/payroll/entries/{id}/confirm` (the employee).
  Map<String, dynamic> confirmPayrollEntry(
      FakeCollectionsCaller caller, String entryId) {
    if (caller.seesEverything) _forbidden('collections.payroll.confirm');
    final e = _payrollEntries.firstWhere((x) => x['id'] == entryId,
        orElse: () => _notFound('payroll_entry'));
    if (e['employeeId'] != caller.id) _forbidden('collections.payroll.confirm');
    if (e['confirmedAt'] != null) {
      _fail(409, 'PAYROLL_ALREADY_CONFIRMED', 'تم تأكيد الحركة من قبل.');
    }
    final at = _now();
    e
      ..['confirmedAt'] = at
      ..['confirmedByName'] = caller.name;
    return {
      'id': entryId,
      'confirmedAt': at,
      'eventSequences': [10]
    };
  }
}

/// Website `collectionCardState.ts` at 537f073: tone and the list order.
String collectionCardTone(Map<String, dynamic> card) {
  final balance = card['balanceUnits'] as int;
  final rejected = card['latestStatus'] == 'rejected';
  if (rejected && !hasAdministrativeMovement(card)) {
    return 'collection-rejected';
  }
  if (balance < 0) return 'collection-green';
  if (balance == 0) {
    final cashAt = card['latestCashReceivedAt'];
    final external = '${card['externalFinancialUpdatedAt']}';
    return cashAt is String &&
            cashAt.compareTo(external) >= 0 &&
            card['hasPending'] != 1 &&
            (card['cashOutstandingCount'] ?? 0) == 0
        ? 'collection-red'
        : 'zero-collection-card';
  }
  if (hasAdministrativeMovement(card)) return 'collection-base';
  return card['latestMode'] == 'partial'
      ? 'collection-yellow'
      : 'collection-base';
}

bool hasAdministrativeMovement(Map<String, dynamic> card) {
  final rejected = card['latestStatus'] == 'rejected';
  final decided = card['latestDecisionAt'];
  final last = rejected && decided is String
      ? decided
      : card['latestSubmissionAt'] as String?;
  final external = '${card['externalFinancialUpdatedAt']}';
  return external.compareTo('${card['assignedAt']}') > 0 &&
      (last == null || external.compareTo(last) > 0);
}

int _rank(Map<String, dynamic> card) {
  final tone = collectionCardTone(card);
  if (tone == 'collection-rejected') return 5;
  if (tone == 'collection-red') return 4;
  if (card['balanceUnits'] == 0) return 3;
  if (hasAdministrativeMovement(card)) return 0;
  if (tone == 'collection-base') return 0;
  if (tone == 'collection-yellow') return 1;
  if (tone == 'collection-green') return 2;
  return 3;
}

int compareCollectionCards(Map<String, dynamic> a, Map<String, dynamic> b) {
  final priority = _rank(a) - _rank(b);
  if (priority != 0) return priority;
  String time(Map<String, dynamic> card) {
    final assigned = '${card['assignedAt']}';
    final external = '${card['externalFinancialUpdatedAt']}';
    if (_rank(card) == 0 && external.compareTo(assigned) > 0) return external;
    return assigned;
  }

  final byTime = time(b).compareTo(time(a));
  if (byTime != 0) return byTime;
  final byAssigned = '${b['assignedAt']}'.compareTo('${a['assignedAt']}');
  if (byAssigned != 0) return byAssigned;
  return '${b['id']}'.compareTo('${a['id']}');
}
