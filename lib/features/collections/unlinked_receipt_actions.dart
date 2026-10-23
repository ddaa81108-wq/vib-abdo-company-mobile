import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';

/// Reject, and cash confirmation, for one unlinked receipt (استلام غير مربوط).
///
/// Buttons are omitted entirely when the signed-in user lacks the action.
/// Reject follows a pending server status. Cash follows the server cash flag
/// only — the same rule as a linked submission — including after a rejection.
///
/// TODO(pending server answer): `cashStatus` / `cashPending` are proposed (🔶).
/// Until the server sends `pending`, the cash button stays hidden. Do not
/// infer it from `status == rejected`.
class UnlinkedReceiptActions extends ConsumerWidget {
  const UnlinkedReceiptActions({required this.receipt, super.key});

  final UnlinkedReceiptDto receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final showReject =
        permissions.canDo(ManagementAction.collectionsDecide) &&
        receipt.status == 'pending';
    final showCash =
        permissions.canDo(ManagementAction.collectionsCashReceived) &&
        receipt.cashStatus == CashStatus.pending;
    if (!showReject && !showCash) return const SizedBox.shrink();

    return Column(
      key: Key('unlinked-actions-${receipt.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showReject)
          GuardedMutation(
            buttonKey: Key('unlinked-reject-${receipt.id}'),
            inputs: 'ureject:${receipt.id}:${receipt.version}',
            expectedVersion: receipt.version,
            label: AppStrings.reject,
            filled: false,
            onSubmit: (meta) => _reject(context, ref, meta),
          ),
        if (showReject && showCash) const SizedBox(height: AppSpacing.sm),
        if (showCash)
          GuardedMutation(
            buttonKey: Key('unlinked-cash-${receipt.id}'),
            inputs: 'ucash:${receipt.id}:${receipt.version}',
            expectedVersion: receipt.version,
            label: AppStrings.cashReceived,
            onSubmit: (meta) => _cash(context, ref, meta),
          ),
      ],
    );
  }

  Future<String?> _reject(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) {
    return _send(
      context,
      ref,
      () => ref
          .read(apiLayerProvider)
          .collections
          .decideUnlinked(
            receipt.id,
            decision: CollectionDecision.reject,
            meta: meta,
          ),
    );
  }

  Future<String?> _cash(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) {
    return _send(
      context,
      ref,
      () => ref
          .read(apiLayerProvider)
          .collections
          .markUnlinkedCashReceived(receipt.id, meta),
    );
  }

  /// Null when the server accepts the send. A conflict refetches the overview
  /// and returns the refresh message; any other failure returns the mapped
  /// server message and keeps the same request id for a retry.
  Future<String?> _send(
    BuildContext context,
    WidgetRef ref,
    Future<MutationAck> Function() send,
  ) async {
    try {
      final ack = await send();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(collectionsProvider);
      return null;
    } catch (error) {
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      final message = failure.code == 'VERSION_CONFLICT'
          ? AppStrings.versionConflict
          : failure.message;
      final refresh = failure.code == 'VERSION_CONFLICT' ||
          failure.code == 'SUBMISSION_ALREADY_DECIDED' ||
          failure.code == 'SUBMISSION_NOT_APPROVED';
      if (!context.mounted) return refresh ? message : failureText(failure);
      if (refresh) {
        _announce(context, message);
        ref.invalidate(collectionsProvider);
        return message;
      }
      return failureText(failure);
    }
  }

  void _announce(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
