import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';

final auditLogProvider = FutureProvider<AuditPage>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).directory.auditLog();
});

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  static const screenKey = Key('screen-settings-audit');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canDo(ManagementAction.settingsManage)) {
      return const ForbiddenPane();
    }
    final session = ref.watch(sessionStateProvider);
    final profile = session is SessionAuthenticated ? session.profile : null;
    final audit = ref.watch(auditLogProvider);
    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          Text('الأمان', style: cairo(18, 800)),
          const SizedBox(height: AppSpacing.sm),
          Card(
            key: const Key('security-current-session'),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الجلسة الحالية على هذا الجهاز', style: cairo(14, 800)),
                  const Text('هذه ليست قائمة بكل جلسات الحساب على الخادم.'),
                  if (profile != null) ...[
                    Text(profile.displayName),
                    Text(profile.username),
                    Text('الدور: ${profile.role ?? '—'}'),
                    Text(
                      profile.isOwner
                          ? 'المدير الأساسي: نعم'
                          : 'المدير الأساسي: لا',
                      key: const Key('security-is-owner'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'التحقق بخطوتين يقرره الخادم عند الدخول. لا يوجد مفتاح في التطبيق لتفعيله أو لإيقافه. إذا طلب الخادم الرمز، الإكمال يكون عبر خدمته وليس من هذه الشاشة.',
            key: Key('security-mfa-note'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'لقطات الشاشة في الإصدار تُفتح فقط لدور الإدارة أو الموظف بعد التحقق من الجلسة، وتُقفل لغير ذلك. لا يفصل النظام اللقطة عن التسجيل. لا يوجد هنا تجاوز لذلك.',
            key: Key('security-capture-note'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('سجل الخادم', style: cairo(16, 800)),
          const Text(
            'العمليات التي أعادها الخادم. صف الدخول أو الجلسة يظهر فقط إذا كان اسم العملية نفسه كذلك.',
            key: Key('security-audit-scope'),
          ),
          audit.when(
            loading: () => const SkeletonBox(height: 72),
            error: (error, _) => presentFailure(
              ref.read(errorHandlerProvider).toFailure(error),
              onRetry: () => ref.invalidate(auditLogProvider),
              retryKey: const Key('audit-retry'),
            ),
            data: (page) {
              final sessionRows = page.items
                  .where((item) => item.isSessionAction)
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionRows == 0
                        ? 'لا عملية دخول أو جلسة في هذه الصفحة.'
                        : 'عمليات دخول أو جلسة في الصفحة: $sessionRows',
                    key: const Key('security-session-count'),
                  ),
                  if (page.items.isEmpty)
                    const EmptyPane(message: AppStrings.auditEmpty)
                  else
                    for (final item in page.items)
                      ListTile(
                        key: Key('audit-event-${item.id}'),
                        title: Text(item.action),
                        subtitle: Text(
                          '${item.actorName ?? item.actorUsername ?? '—'} · ${item.createdAt ?? '—'}',
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
