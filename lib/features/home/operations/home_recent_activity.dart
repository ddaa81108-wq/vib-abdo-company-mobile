import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_providers.dart';
import '../../../state/home_operations_providers.dart';
import '../../../state/notification_providers.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/common.dart';
import '../../notifications/notification_content.dart';
import 'operations_style.dart';

class HomeRecentActivity extends ConsumerWidget {
  const HomeRecentActivity({required this.financial, super.key});
  final bool financial;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look, money = ref.watch(apiLayerProvider).money;
    final Widget content;
    if (financial) {
      content = ref
          .watch(homeActivityProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(homeActivityProvider),
              child: const Text('تعذر قراءة العمليات — إعادة المحاولة'),
            ),
            data: (rows) => rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('لا توجد عمليات مسجلة'),
                  )
                : Column(
                    children: [
                      for (final row in rows.take(2))
                        _ActivityRow(
                          title: row.description,
                          note: row.name ?? '',
                          value: Currency.fromCode(row.currency) == null
                              ? '—'
                              : money.formatOrDash(
                                  row.amountUnits,
                                  Currency.fromCode(row.currency)!,
                                ),
                          icon: Icons.receipt_long_outlined,
                        ),
                    ],
                  ),
          );
    } else {
      content = ref
          .watch(notificationsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(notificationsProvider),
              child: const Text('إعادة قراءة الإشعارات'),
            ),
            data: (page) => page.appNotifications.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('لا توجد إشعارات حديثة'),
                  )
                : Column(
                    children: [
                      for (final note in page.appNotifications.take(2))
                        _ActivityRow(
                          title: notificationHeadline(note),
                          note: notificationWhen(note),
                          icon: Icons.notifications_none,
                        ),
                    ],
                  ),
          );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                financial ? 'آخر العمليات' : 'آخر الإشعارات',
                style: cairo(17, 700, color: look.ink),
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.go(financial ? '/reports' : '/notifications'),
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        Container(
          key: const Key('home-recent-activity'),
          decoration: OperationsStyle.panel(context),
          child: content,
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.title,
    required this.note,
    required this.icon,
    this.value,
  });
  final String title, note;
  final String? value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(icon, color: context.look.muted, size: 23),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: cairo(12, 600, color: context.look.ink)),
              if (note.isNotEmpty)
                Text(note, style: cairo(10, 500, color: context.look.muted)),
              if (value != null)
                MoneyText(
                  value!,
                  style: cairo(15, 700, color: context.look.ink),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
