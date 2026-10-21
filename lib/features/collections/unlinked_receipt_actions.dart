import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
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

    return Wrap(
      key: Key('unlinked-actions-${receipt.id}'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (showReject)
          GuardedMutation(
            buttonKey: Key('unlinked-reject-${receipt.id}'),
            inputs: 'ureject:${receipt.id}:${receipt.version}',
            expectedVersion: receipt.version,
            label: AppStrings.reject,
            filled: false,
            onVersionConflict: () => ref.invalidate(collectionsProvider),
            onSubmit: (meta) => _reject(context, ref, meta),
          ),
        if (showCash)
          GuardedMutation(
            buttonKey: Key('unlinked-cash-${receipt.id}'),
            inputs: 'ucash:${receipt.id}:${receipt.version}',
            expectedVersion: receipt.version,
            label: AppStrings.cashReceived,
            onVersionConflict: () => ref.invalidate(collectionsProvider),
            onSubmit: (meta) => _cash(context, ref, meta),
          ),
      ],
    );
  }

  Future<String?> _reject(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) async {
    final ack = await ref
        .read(apiLayerProvider)
        .collections
        .decideUnlinked(
          receipt.id,
          decision: CollectionDecision.reject,
          meta: meta,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
    }
    ref.invalidate(collectionsProvider);
    return null;
  }

  Future<String?> _cash(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) async {
    final ack = await ref
        .read(apiLayerProvider)
        .collections
        .markUnlinkedCashReceived(receipt.id, meta);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
    }
    ref.invalidate(collectionsProvider);
    return null;
  }
}
