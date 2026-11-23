import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_providers.dart';
import '../../../state/home_operations_providers.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/common.dart';
import 'operations_style.dart';

class HomeClosingCard extends ConsumerWidget {
  const HomeClosingCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closing = ref.watch(homeClosingProvider);
    final money = ref.watch(apiLayerProvider).money;
    return Container(
      key: const Key('home-five-am'),
      padding: const EdgeInsets.all(18),
      decoration: OperationsStyle.panel(context, featured: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.layers_outlined,
                color: OperationsStyle.gold,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لقطة الخامسة صباحًا',
                  style: cairo(18, 700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          closing.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 17),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعذر قراءة اللقطة',
                  style: cairo(13, 500, color: Colors.white),
                ),
                TextButton(
                  key: const Key('home-closing-retry'),
                  onPressed: () => ref.invalidate(homeClosingProvider),
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(color: OperationsStyle.gold),
                  ),
                ),
              ],
            ),
            data: (data) {
              final recorded = data.state == 'recorded';
              final net = recorded ? data.netUnits : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.businessDate != null)
                    Text(
                      data.businessDate!,
                      style: cairo(11, 500, color: const Color(0xFFCDD7E1)),
                    ),
                  const SizedBox(height: 10),
                  MoneyText(
                    money.formatOrDash(net, Currency.lyd),
                    key: const Key('home-closing-net'),
                    style: cairo(32, 700, color: Colors.white),
                  ),
                  const SizedBox(height: 9),
                  if (recorded && data.changeUnits != null)
                    Text(
                      '${data.changeUnits!.asInt != null && data.changeUnits!.asInt! > 0 ? '+' : ''}${money.formatOrDash(data.changeUnits, Currency.lyd)}  ·  عن لقطة ${data.previousBusinessDate ?? 'السابقة'}',
                      key: const Key('home-closing-change'),
                      style: cairo(12, 600, color: OperationsStyle.gold),
                    )
                  else
                    Text(switch (data.state) {
                      'pending' => 'لم يحِن موعد اللقطة بعد',
                      'missed' => 'لم تُسجّل لقطة لهذا اليوم',
                      'missing_rate' => 'اللقطة تحتاج سعر تحويل معتمدًا',
                      _ => 'المقارنة غير متاحة',
                    }, style: cairo(12, 500, color: OperationsStyle.gold)),
                ],
              );
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.go('/reports'),
              child: Text(
                'فتح التقارير',
                style: cairo(11, 600, color: OperationsStyle.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
