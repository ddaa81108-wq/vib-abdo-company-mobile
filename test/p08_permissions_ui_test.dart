import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

/// P-08 UI. The widgets and [PermissionService] are real. Only the transport
/// is the fake that returns the observed `/api/me` shapes.
void main() {
  const readable = [
    SectionKey.customers,
    SectionKey.collections,
    SectionKey.companies,
    SectionKey.libyanDeposits,
    SectionKey.egyptianDeposits,
    SectionKey.purchases,
    SectionKey.treasury,
    SectionKey.reports,
  ];

  testWidgets('a limited reader sees eight sections and no write actions', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2800));
    await signIn(tester, username: 'limited.reader', password: 'demo-only');

    expect(find.text('قارئ محدود تجريبي'), findsWidgets);
    expect(layer.permissions.visibleSections, readable);
    expect(layer.permissions.canViewFinancialLedger, isFalse);
    for (final section in SectionKey.values) {
      expect(
        find.byKey(HomeShell.sectionKey(section), skipOffstage: false),
        readable.contains(section) ? findsOneWidget : findsNothing,
        reason: section.key,
      );
      expect(
        find.byKey(HomeShell.writeKey(section), skipOffstage: false),
        findsNothing,
        reason: 'write-${section.key}',
      );
    }
    expect(
      find.byKey(const Key('financial-ledger'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('PERMISSION_DENIED is the forbidden pane and is not retried', (
    tester,
  ) async {
    var reads = 0;
    await pumpFakeApp(
      tester,
      size: const Size(800, 1400),
      overrides: [
        collectionsProvider.overrideWith((ref) async {
          reads++;
          throw const ForbiddenException(
            code: 'PERMISSION_DENIED',
            message: 'نص الخادم لا يُعرض',
            statusCode: 403,
          );
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    final readsAfterSignIn = reads;
    await _go(tester, '/collections');
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsWidgets);
    expect(find.text('نص الخادم لا يُعرض'), findsNothing);
    expect(find.text(AppStrings.retry), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, readsAfterSignIn + 1);
  });
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
