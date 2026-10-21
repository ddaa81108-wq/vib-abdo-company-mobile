import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One write the server did not accept because the session ended.
///
/// The protected route is disposed by the login redirect, so the form's text
/// controllers are gone with it. This snapshot is what a later
/// [GuardedMutation] uses to reuse [requestId] when the same user submits the
/// same inputs and expected version again. Nothing here sends the write.
class PendingMutation {
  const PendingMutation({
    required this.userId,
    required this.inputs,
    required this.expectedVersion,
    required this.requestId,
  });

  final String userId;
  final String inputs;
  final int? expectedVersion;
  final String requestId;

  bool matches(String userId, String inputs, int? expectedVersion) =>
      this.userId == userId &&
      this.inputs == inputs &&
      this.expectedVersion == expectedVersion;
}

class PendingMutationController extends Notifier<PendingMutation?> {
  @override
  PendingMutation? build() => null;

  void remember(PendingMutation draft) => state = draft;

  /// Drops the snapshot when someone else signs in.
  void discardUnless(String? userId) {
    final saved = state;
    if (saved != null && saved.userId != userId) state = null;
  }

  void complete({required String? userId, required String requestId}) {
    final saved = state;
    if (saved == null) return;
    if (saved.userId == userId && saved.requestId == requestId) state = null;
  }
}

final pendingMutationProvider =
    NotifierProvider<PendingMutationController, PendingMutation?>(
      PendingMutationController.new,
    );
