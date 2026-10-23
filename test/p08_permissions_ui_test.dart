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

  testWidgets('limited reader screens show no write buttons', (tester) async {
    await pumpFakeApp(tester, size: const Size(900, 2800));
    await signIn(tester, username: 'limited.reader', password: 'demo-only');

    const screens = <String, Key>{
      '/customers': Key('screen-customers'),
      '/customers/c_55': Key('screen-ledger-customers'),
      '/companies': Key('screen-companies'),
      '/companies/c_co_02': Key('screen-ledger-companies'),
      '/libyan-deposits': Key('screen-libyan-deposits'),
      '/libyan-deposits/c_55': Key('screen-ledger-libyan-deposits'),
      '/egyptian-deposits': Key('screen-egyptian-deposits'),
      '/egyptian-deposits/c_55': Key('screen-ledger-egyptian-deposits'),
      '/purchases': Key('screen-purchases'),
      '/treasury': Key('screen-treasury'),
      '/reports': Key('screen-reports'),
      '/collections': Key('screen-collections'),
    };
    const writeKeys = <Key>[
      Key('add-account'),
      Key('assign-mode'),
      Key('add-debt'),
      Key('add-payment'),
      Key('full-payment'),
      Key('cancel-tx_1'),
      Key('correct-tx_1'),
      Key('edit-account-card'),
      Key('save-account-card'),
      Key('save-rate'),
      Key('cash-in'),
      Key('cash-out'),
      Key('add-purchase-12'),
      Key('finalize-day-12'),
      Key('submit-as_1'),
      Key('unlinked-collection'),
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('cash-sb_2'),
      Key('close-batch'),
      Key('export-pdf'),
      Key('save-masraweya'),
    ];

    const renderedRows = <String, Key>{
      '/customers/c_55': Key('ledger-amount-tx_1'),
      '/companies/c_co_02': Key('ledger-amount-tx_1'),
      '/libyan-deposits/c_55': Key('ledger-amount-tx_1'),
      '/egyptian-deposits/c_55': Key('ledger-amount-tx_1'),
      '/purchases': Key('purchase-day-12'),
    };

    for (final entry in screens.entries) {
      await _go(tester, entry.key);
      expect(find.byKey(entry.value), findsOneWidget, reason: entry.key);
      final row = renderedRows[entry.key];
      if (row != null) {
        expect(
          find.byKey(row, skipOffstage: false),
          findsOneWidget,
          reason: '${entry.key} $row',
        );
      }
      for (final key in writeKeys) {
        expect(find.byKey(key), findsNothing, reason: '${entry.key} $key');
      }
    }
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
