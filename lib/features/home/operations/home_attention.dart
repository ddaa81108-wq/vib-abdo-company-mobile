import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/section_providers.dart';
import '../../../ui/theme.dart';
import 'operations_style.dart';

class HomeAttention extends ConsumerWidget {
  const HomeAttention({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(collectionsProvider);
    final look = context.look;
    return Container(
      key: const Key('home-attention'),
      padding: const EdgeInsets.all(12),
      decoration: OperationsStyle.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions_outlined, size: 19, color: look.muted),
              const SizedBox(width: 6),
              Text('يحتاج إجراء', style: cairo(13, 700, color: look.ink)),
            ],
          ),
          const SizedBox(height: 7),
          data.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(collectionsProvider),
              child: const Text('تعذر قراءة المتابعة — إعادة المحاولة'),
            ),
            data: (value) => Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (value.pendingCount != null)
                  ActionChip(
                    key: const Key('home-pending-collections'),
                    label: Text('${value.pendingCount} تحصيلات تنتظر الاعتماد'),
                    onPressed: () => context.go('/collections'),
                  ),
                if (value.unlinkedPendingCount != null)
                  ActionChip(
                    key: const Key('home-unlinked-collections'),
                    label: Text(
                      '${value.unlinkedPendingCount} استلامات غير مرتبطة',
                    ),
                    onPressed: () => context.go('/collections'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
