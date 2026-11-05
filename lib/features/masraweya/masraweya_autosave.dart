import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/widgets/common.dart';

/// Why a draft cannot be sent. No money is derived here.
enum MasraweyaDraftIssue {
  none,
  partialRow,
  previousUnits,
  purchasesUnits,
  offline,
}

enum MasraweyaSavePhase { saved, dirty, saving, error, conflict }

/// One work row as typed. Empty rows are omitted. A half-filled row blocks.
class MasraweyaRowDraft {
  const MasraweyaRowDraft({
    required this.valueText,
    required this.commissionText,
  });

  final String valueText;
  final String commissionText;

  bool get isEmpty => valueText.trim().isEmpty && commissionText.trim().isEmpty;

  /// PUT items require both integers and `minimum: 0`.
  bool get isComplete {
    final value = parseUnits(valueText);
    final commission = parseUnits(commissionText);
    return value != null && value >= 0 && commission != null && commission >= 0;
  }

  bool get isPartial => !isEmpty && !isComplete;
}

/// The day as typed. Totals are not part of the draft.
class MasraweyaDraft {
  const MasraweyaDraft({
    required this.businessDate,
    required this.previousText,
    required this.previousEditable,
    required this.lockedPreviousUnits,
    required this.purchasesText,
    required this.rows,
    required this.summaryLeave,
  });

  final String businessDate;
  final String previousText;
  final bool previousEditable;
  final int? lockedPreviousUnits;
  final String purchasesText;
  final List<MasraweyaRowDraft> rows;

  /// Focus left القيمة السابقة or مشتريات اليوم.
  final bool summaryLeave;
}

class MasraweyaSavePlan {
  const MasraweyaSavePlan._({
    required this.canSend,
    required this.issue,
    required this.request,
    required this.fingerprint,
  });

  final bool canSend;
  final MasraweyaDraftIssue issue;
  final SaveMasraweyaDayRequest? request;
  final String fingerprint;

  static MasraweyaSavePlan of(MasraweyaDraft draft) {
    if (draft.rows.any((row) => row.isPartial)) {
      return const MasraweyaSavePlan._(
        canSend: false,
        issue: MasraweyaDraftIssue.partialRow,
        request: null,
        fingerprint: '',
      );
    }
    final int? previous;
    if (draft.previousEditable) {
      previous = parseUnits(draft.previousText);
      if (previous == null) {
        return const MasraweyaSavePlan._(
          canSend: false,
          issue: MasraweyaDraftIssue.previousUnits,
          request: null,
          fingerprint: '',
        );
      }
    } else {
      previous = draft.lockedPreviousUnits;
    }
    final purchases = parseUnits(draft.purchasesText);
    if (purchases == null || purchases < 0) {
      return const MasraweyaSavePlan._(
        canSend: false,
        issue: MasraweyaDraftIssue.purchasesUnits,
        request: null,
        fingerprint: '',
      );
    }
    final entries = <MasraweyaEntryDto>[
      for (final row in draft.rows)
        if (!row.isEmpty)
          MasraweyaEntryDto(
            valueUnits: MoneyValue.known(parseUnits(row.valueText)!),
            commissionUnits: MoneyValue.known(parseUnits(row.commissionText)!),
          ),
    ];
    final request = SaveMasraweyaDayRequest(
      businessDate: draft.businessDate,
      previousValueUnits: previous,
      purchasesUnits: purchases,
      entries: entries,
    );
    return MasraweyaSavePlan._(
      canSend: true,
      issue: MasraweyaDraftIssue.none,
      request: request,
      fingerprint: masraweyaDraftFingerprint(request),
    );
  }
}

/// Display-only row total Ali confirmed: القيمة + العمولة.
///
/// Integer units from [parseUnits]. Empty, partial, negative, or invalid
/// text is null so the cell stays a dash. The sum is not sent and is not
/// `workTotalUnits` or `remainingUnits`.
int? masraweyaRowDisplayUnits(String valueText, String commissionText) {
  final value = parseUnits(valueText);
  final commission = parseUnits(commissionText);
  if (value == null || value < 0 || commission == null || commission < 0) {
    return null;
  }
  return value + commission;
}

/// Stable identity of a PUT body. Does not include `requestId` or totals.
String masraweyaDraftFingerprint(SaveMasraweyaDayRequest request) {
  final rows = request.entries
      .map(
        (entry) =>
            '${entry.valueUnits?.asInt ?? ''}|${entry.commissionUnits?.asInt ?? ''}',
      )
      .join(';');
  return '${request.businessDate}#${request.previousValueUnits}#'
      '${request.purchasesUnits}#$rows';
}

/// One in-flight PUT. A newer complete draft waits. Nothing is retried
/// by itself after an error or a version conflict.
class MasraweyaAutosave {
  MasraweyaAutosave({required this.send});

  final Future<MasraweyaDayDto> Function(
    SaveMasraweyaDayRequest request,
    MutationMeta meta,
  )
  send;

  MasraweyaSavePhase phase = MasraweyaSavePhase.saved;
  MasraweyaDraftIssue issue = MasraweyaDraftIssue.none;
  Object? lastError;
  int? serverVersion;
  MasraweyaDayDto? authoritative;
  String? savedFingerprint;
  bool announceSaved = false;

  final List<String> sentRequestIds = [];
  final List<int?> sentVersions = [];

  MasraweyaDraft? _pending;
  bool _wantsSend = false;
  Future<void>? _flight;
  String? _retryId;
  String? _retryFingerprint;
  int? _retryVersion;

  bool get blocksNavigation =>
      _flight != null ||
      _wantsSend ||
      phase == MasraweyaSavePhase.dirty ||
      phase == MasraweyaSavePhase.saving ||
      phase == MasraweyaSavePhase.error ||
      phase == MasraweyaSavePhase.conflict;

  /// The loaded day matches [draft]. A later leave of an unchanged day
  /// does not PUT.
  void bindLoaded(MasraweyaDayDto day, MasraweyaDraft draft) {
    authoritative = day;
    serverVersion = day.version;
    final plan = MasraweyaSavePlan.of(draft);
    savedFingerprint = plan.canSend ? plan.fingerprint : null;
    _pending = null;
    _wantsSend = false;
    phase = MasraweyaSavePhase.saved;
    issue = MasraweyaDraftIssue.none;
    lastError = null;
    announceSaved = false;
    _retryId = null;
    _retryFingerprint = null;
    _retryVersion = null;
  }

  /// Updates server figures without touching the typed draft.
  void noteServerTotals(MasraweyaDayDto day) {
    authoritative = day;
    if (day.version != null) serverVersion = day.version;
  }

  /// [leftRowIndex] is the work row focus just left, when there was one.
  /// A save starts only for a complete row, or when focus leaves a summary
  /// field, and only when the whole draft can be sent.
  void noteLeave(
    MasraweyaDraft draft, {
    required int? leftRowIndex,
    required bool online,
  }) {
    _pending = draft;
    if (phase == MasraweyaSavePhase.conflict) {
      issue = MasraweyaDraftIssue.none;
      return;
    }
    if (!online) {
      phase = MasraweyaSavePhase.dirty;
      issue = MasraweyaDraftIssue.offline;
      _wantsSend = false;
      return;
    }
    final plan = MasraweyaSavePlan.of(draft);
    final leftComplete =
        leftRowIndex != null &&
        leftRowIndex >= 0 &&
        leftRowIndex < draft.rows.length &&
        draft.rows[leftRowIndex].isComplete;
    final trigger = leftComplete || draft.summaryLeave;
    if (!plan.canSend) {
      phase = MasraweyaSavePhase.dirty;
      issue = plan.issue;
      _wantsSend = false;
      return;
    }
    if (!trigger) {
      if (plan.fingerprint != savedFingerprint) {
        phase = MasraweyaSavePhase.dirty;
        issue = MasraweyaDraftIssue.none;
      }
      _wantsSend = false;
      return;
    }
    if (plan.fingerprint == savedFingerprint) {
      phase = MasraweyaSavePhase.saved;
      issue = MasraweyaDraftIssue.none;
      lastError = null;
      _wantsSend = false;
      return;
    }
    issue = MasraweyaDraftIssue.none;
    _wantsSend = true;
  }

  /// Explicit retry of the current draft. A conflict does nothing until
  /// [adoptFreshVersion] replaces the expected version.
  Future<void> retry() {
    if (phase == MasraweyaSavePhase.conflict) return Future<void>.value();
    _wantsSend = true;
    return pump();
  }

  /// User chose to send the kept draft against [version]. New request id.
  void adoptFreshVersion(int? version) {
    serverVersion = version;
    phase = MasraweyaSavePhase.dirty;
    issue = MasraweyaDraftIssue.none;
    lastError = null;
    _retryId = null;
    _retryFingerprint = null;
    _retryVersion = null;
    _wantsSend = true;
  }

  Future<void> pump() {
    final current = _flight;
    if (current != null) {
      return current.then((_) => pump());
    }
    if (!_wantsSend || phase == MasraweyaSavePhase.conflict) {
      return Future<void>.value();
    }
    late final Future<void> flight;
    flight = _sendOne().whenComplete(() {
      if (identical(_flight, flight)) _flight = null;
    });
    _flight = flight;
    return flight.then((_) {
      if (_wantsSend && phase != MasraweyaSavePhase.conflict) return pump();
    });
  }

  Future<void> _sendOne() async {
    final draft = _pending;
    if (draft == null) {
      _wantsSend = false;
      return;
    }
    final plan = MasraweyaSavePlan.of(draft);
    if (!plan.canSend || plan.request == null) {
      _wantsSend = false;
      phase = MasraweyaSavePhase.dirty;
      issue = plan.issue;
      return;
    }
    if (plan.fingerprint == savedFingerprint) {
      _wantsSend = false;
      phase = MasraweyaSavePhase.saved;
      issue = MasraweyaDraftIssue.none;
      lastError = null;
      return;
    }
    _wantsSend = false;
    phase = MasraweyaSavePhase.saving;
    final version = serverVersion;
    final fingerprint = plan.fingerprint;
    final requestId = _idFor(fingerprint, version);
    final meta = MutationMeta(expectedVersion: version, requestId: requestId);
    sentRequestIds.add(requestId);
    sentVersions.add(version);
    try {
      final day = await send(plan.request!, meta);
      serverVersion = day.version ?? serverVersion;
      authoritative = day;
      savedFingerprint = fingerprint;
      _retryId = null;
      _retryFingerprint = null;
      _retryVersion = null;
      lastError = null;
      issue = MasraweyaDraftIssue.none;
      final pendingPlan = _pending == null
          ? null
          : MasraweyaSavePlan.of(_pending!);
      if (pendingPlan != null &&
          pendingPlan.canSend &&
          pendingPlan.fingerprint != fingerprint) {
        phase = MasraweyaSavePhase.dirty;
        _wantsSend = true;
        announceSaved = false;
      } else {
        phase = MasraweyaSavePhase.saved;
        announceSaved = true;
      }
    } catch (error) {
      lastError = error;
      if (_isVersionConflict(error)) {
        phase = MasraweyaSavePhase.conflict;
        issue = MasraweyaDraftIssue.none;
        _wantsSend = false;
        _retryId = null;
        _retryFingerprint = null;
        _retryVersion = null;
        return;
      }
      phase = MasraweyaSavePhase.error;
      issue = MasraweyaDraftIssue.none;
      _retryId = requestId;
      _retryFingerprint = fingerprint;
      _retryVersion = version;
      _wantsSend = false;
    }
  }

  String _idFor(String fingerprint, int? version) {
    if (_retryId != null &&
        _retryFingerprint == fingerprint &&
        _retryVersion == version) {
      return _retryId!;
    }
    return RequestIds.newRequestId();
  }
}

bool _isVersionConflict(Object error) =>
    error is ConflictException && error.code == 'VERSION_CONFLICT';

/// Calendar step for the `date` query. Not a business-day rule and not
/// the server's 04:00 closure.
String? shiftIsoDate(String iso, int days) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null || days == 0) return null;
  final next = DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
  ).add(Duration(days: days));
  final month = next.month.toString().padLeft(2, '0');
  final day = next.day.toString().padLeft(2, '0');
  return '${next.year}-$month-$day';
}

/// Writers may edit only when the server did not mark the day read-only.
/// A missing `editable` flag is not treated as a 7-day policy.
/// Offline does not hide the draft; the save itself waits.
bool masraweyaFieldsEditable({
  required bool canWrite,
  required bool? serverEditable,
}) {
  if (!canWrite) return false;
  if (serverEditable == false) return false;
  return true;
}
