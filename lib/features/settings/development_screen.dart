import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/environment_badge.dart';
import '../../ui/widgets/section_kit.dart';
import 'firebase_debug_token.dart';

/// The version baked into this client. Not a remote changelog.
const appReleaseLabel = '1.0.0+1';

final serverHealthProvider = FutureProvider<ServerHealth>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).directory.health();
});

class DevelopmentScreen extends ConsumerWidget {
  const DevelopmentScreen({super.key});

  static const screenKey = Key('screen-settings-operations');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canDo(ManagementAction.settingsManage) &&
        !permissionsOf(ref).canViewFinancialLedger) {
      return const ForbiddenPane();
    }
    final health = ref.watch(serverHealthProvider);
    final layer = ref.watch(apiLayerProvider);
    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          const Text(
            'إصدار هذه النسخة وحالة الخادم. لا أسرار ولا محدّث عن بعد.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row('إصدار التطبيق', appReleaseLabel, 'development-app-version'),
          _row(
            'بيئة البناء',
            kBuildEnvironment.label ?? 'الخادم الرسمي',
            'development-environment',
          ),
          _row(
            'بيانات تجريبية',
            layer.useFakeApi ? 'نعم، هذه الجلسة على خادم وهمي' : 'لا',
            'development-fake-api',
          ),
          const Text(
            'لا يوجد محدّث عن بعد داخل التطبيق. الترقية تتم بتثبيت نسخة جديدة.',
            key: Key('development-no-updater'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('الخادم', style: cairo(16, 800)),
          health.when(
            loading: () => const SkeletonBox(height: 48),
            error: (error, _) => presentFailure(
              ref.read(errorHandlerProvider).toFailure(error),
              onRetry: () => ref.invalidate(serverHealthProvider),
              retryKey: const Key('health-retry'),
            ),
            data: (info) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('الحالة', info.status ?? '—', 'development-health-status'),
                _row(
                  'إصدار الواجهة',
                  info.apiVersion ?? '—',
                  'development-api-version',
                ),
                _row(
                  'إصدار المخطط',
                  info.schemaVersion ?? '—',
                  'development-schema-version',
                ),
                _row(
                  'إصدار واجهة الخادم',
                  info.uiVersion ?? '—',
                  'development-ui-version',
                ),
              ],
            ),
          ),
          if (kDebugMode)
            developmentFirebaseSection(includeDebugRow: kDebugMode),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'التشخيص لا يعرض كلمة المرور ولا رمز الجلسة ولا رمز الحماية.',
            key: Key('development-no-secrets'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, String keyName) {
    return ListTile(
      key: Key(keyName),
      dense: true,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
