import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../state/collection_request_journal.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';

/// The signed-in user id, or null.
String? collectionsUserId(WidgetRef ref) {
  final session = ref.read(sessionStateProvider);
  return session is SessionAuthenticated ? session.profile.id : null;
}

String submitSlot(String assignmentId) => 'submit:$assignmentId';
const unlinkedSlot = 'unlinked';

String submitFingerprint(String mode, int amountUnits) => '$mode|$amountUnits';
String unlinkedFingerprint(String name, int amountUnits) =>
    '$name|$amountUnits';

/// How a receipt send ended.
enum CollectionSendOutcome {
  /// The server accepted this send.
  sent,

  /// An earlier send whose reply was lost had already been recorded; nothing
  /// was resent.
  alreadyRecorded,
}

/// Sends one receipt on an assigned card, safely for a retry.
///
/// 537f073 does not replay submissions by `requestId`. So the attempt is
/// saved (and survives an app restart) BEFORE the request leaves, with the
/// submission ids already on the card. A retry of an open attempt first reads
/// the server: a new submission on this card with the same mode and amount
/// means the lost send was recorded, and nothing is resent. A
/// PENDING_SUBMISSION_EXISTS answer to a retry means the same. Any final
/// server answer closes the attempt; a network or server failure keeps it, so
/// the next tap is the same request with the same id and inputs.
Future<CollectionSendOutcome> sendAssignmentReceipt(
  WidgetRef ref, {
  required String assignmentId,
  required String mode,
  required int amountUnits,
}) async {
  final userId = collectionsUserId(ref);
  if (userId == null) throw const SessionExpiredException();
  final journal = ref.read(collectionRequestJournalProvider.notifier);
  final api = ref.read(apiLayerProvider).collections;
  final slot = submitSlot(assignmentId);
  final fingerprint = submitFingerprint(mode, amountUnits);

  final open = await journal.pendingAsync(userId, slot);
  final retry = open != null;
  if (retry) {
    if (open.fingerprint != fingerprint) {
      throw StateError('An unconfirmed receipt is open for $assignmentId');
    }
    final overview = await api.overview();
    if (_recorded(overview, assignmentId, open)) {
      await journal.settle(userId, slot);
      ref.invalidate(collectionsProvider);
      return CollectionSendOutcome.alreadyRecorded;
    }
  }

  final known = retry
      ? open.knownSubmissionIds
      : _knownIds(ref.read(collectionsProvider).value, assignmentId);
  final attempt = await journal.begin(
    userId: userId,
    slot: slot,
    fingerprint: fingerprint,
    knownSubmissionIds: known,
  );
  try {
    await api.submit(
      assignmentId,
      mode: mode,
      amountUnits: amountUnits,
      meta: MutationMeta(requestId: attempt.requestId),
    );
  } on PendingSubmissionExistsException {
    await journal.settle(userId, slot);
    ref.invalidate(collectionsProvider);
    if (retry) return CollectionSendOutcome.alreadyRecorded;
    rethrow;
  } catch (error) {
    if (isFinalCollectionAnswer(error)) {
      await journal.settle(userId, slot);
      ref.invalidate(collectionsProvider);
    }
    rethrow;
  }
  await journal.settle(userId, slot);
  ref.invalidate(collectionsProvider);
  return CollectionSendOutcome.sent;
}

/// Sends one standalone (unlinked) receipt. 537f073 replays this route by
/// `requestId`, so a retry resends the saved id with the saved inputs.
Future<CollectionSendOutcome> sendUnlinkedReceipt(
  WidgetRef ref, {
  required String customerName,
  required int amountUnits,
}) async {
  final userId = collectionsUserId(ref);
  if (userId == null) throw const SessionExpiredException();
  final journal = ref.read(collectionRequestJournalProvider.notifier);
  final attempt = await journal.begin(
    userId: userId,
    slot: unlinkedSlot,
    fingerprint: unlinkedFingerprint(customerName, amountUnits),
  );
  try {
    await ref
        .read(apiLayerProvider)
        .collections
        .createUnlinkedReceipt(
          customerName: customerName,
          amountUnits: amountUnits,
          meta: MutationMeta(requestId: attempt.requestId),
        );
  } catch (error) {
    if (isFinalCollectionAnswer(error)) {
      await journal.settle(userId, unlinkedSlot);
    }
    rethrow;
  }
  await journal.settle(userId, unlinkedSlot);
  ref.invalidate(collectionsProvider);
  return CollectionSendOutcome.sent;
}

List<String> _knownIds(CollectionsOverviewDto? data, String assignmentId) => [
  for (final row in data?.submissions ?? const <CollectionSubmissionDto>[])
    if (row.assignmentId == assignmentId) row.id,
];

bool _recorded(
  CollectionsOverviewDto overview,
  String assignmentId,
  CollectionAttempt attempt,
) {
  for (final row in overview.submissions) {
    if (row.assignmentId != assignmentId) continue;
    if (attempt.knownSubmissionIds.contains(row.id)) continue;
    if (row.mode == attempt.mode &&
        row.amountUnits?.asInt == attempt.amountUnits) {
      return true;
    }
  }
  return false;
}
