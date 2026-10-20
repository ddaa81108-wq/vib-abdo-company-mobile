import 'dart:async';

/// Realtime change SIGNALS from the existing system:
///   SSE      GET `/api/events?after=<seq>`         (event name = topic, id = sequence)
///   fallback GET `/api/event-changes?after=<seq>`  -> {events[], latest, fullResync}
/// RULE: a signal only says "something changed" -> invalidate/refetch from the server.
/// Payloads are deliberately DROPPED: no number from an event is ever displayed or applied.
class RealtimeSignal {
  const RealtimeSignal(
      {required this.sequence,
      required this.topic,
      this.aggregateId,
      this.fullResync = false});
  final int sequence;
  final String topic;
  final String? aggregateId;

  /// `full_resync_required`, or (re)connect: refetch everything visible.
  final bool fullResync;

  static const resync = RealtimeSignal(
      sequence: 0, topic: 'full_resync_required', fullResync: true);
}

/// Topics observed in the web client (per API contract).
class RealtimeTopics {
  RealtimeTopics._();
  static const customerChanged = 'customer.changed';
  static const customerLedgerChanged = 'customer.ledger.changed';
  static const companyChanged = 'company.changed';
  static const companyLedgerChanged = 'company.ledger.changed';
  static const libyanDepositChanged = 'libyan-deposit.changed';
  static const libyanDepositLedgerChanged = 'libyan-deposit.ledger.changed';
  static const egyptianDepositChanged = 'egyptian-deposit.changed';
  static const egyptianDepositLedgerChanged = 'egyptian-deposit.ledger.changed';
  static const collectionChanged = 'collection.changed';
  static const masraweyaChanged = 'masraweya.changed';
  static const purchasesChanged = 'purchases.changed';
  static const treasuryChanged = 'treasury.changed';
  static const fullResyncRequired = 'full_resync_required';

  static const all = {
    customerChanged,
    customerLedgerChanged,
    companyChanged,
    companyLedgerChanged,
    libyanDepositChanged,
    libyanDepositLedgerChanged,
    egyptianDepositChanged,
    egyptianDepositLedgerChanged,
    collectionChanged,
    masraweyaChanged,
    purchasesChanged,
    treasuryChanged,
  };
}

enum RealtimeMode { stopped, sse, polling }

abstract interface class RealtimeService {
  Stream<RealtimeSignal> get signals;
  RealtimeMode get mode;

  /// Start while the app is in the foreground and a session exists.
  Future<void> start();

  /// Stop on background / logout.
  Future<void> stop();
}

/// Last seen sequence, shared by SSE and polling. In memory only (cleared on logout).
class SequenceCursor {
  int value = 0;
  void advance(int seq) {
    if (seq > value) value = seq;
  }

  void reset() => value = 0;
}
