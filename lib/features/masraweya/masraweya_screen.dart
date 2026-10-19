import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import 'package:flutter_api_layer/api_layer.dart';

class MasraweyaScreen extends ConsumerWidget {
  const MasraweyaScreen({super.key});

  static const screenKey = Key('screen-masraweya');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.masraweya)) return const ForbiddenPane();
    final day = ref.watch(masraweyaProvider);
    final money = ref.watch(apiLayerProvider).money;
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle('صفحة المصراوية'),
        day.when(
          loading: () => const SkeletonBox(height: 120),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(masraweyaProvider),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.businessDate),
              Text('${AppStrings.previousValue} ${money.formatOrDash(data.previousValueUnits, Currency.egp)}'),
              Text('${AppStrings.purchasesValue} ${money.formatOrDash(data.purchasesUnits, Currency.egp)}'),
              Text('${AppStrings.workTotal} ${money.formatOrDash(data.workTotalUnits, Currency.egp)}'),
              Text('${AppStrings.remaining} ${money.formatOrDash(data.remainingUnits, Currency.egp)}'),
              Text('${AppStrings.adjustment} ${money.formatOrDash(data.historicalAdjustmentUnits, Currency.egp)}'),
              Text(data.status ?? AppStrings.dash),
            ],
          ),
        ),
      ],
    );
  }
}
