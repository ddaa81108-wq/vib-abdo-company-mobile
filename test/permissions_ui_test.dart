import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('unknown role opens nothing even when codes are present', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'guest.demo', password: 'demo-only');

    expect(find.text('دور غير معروف'), findsOneWidget);
    expect(find.text(AppStrings.noSections), findsOneWidget);
    expect(find.text(AppStrings.roleUnknown), findsOneWidget);
    expect(find.text(AppStrings.writeAction), findsNothing);
    expect(find.textContaining('د.ل'), findsNothing);
    for (final section in SectionKey.values) {
      expect(find.byKey(HomeShell.sectionKey(section)), findsNothing);
      expect(find.byKey(HomeShell.writeKey(section)), findsNothing);
    }
    for (final action in ManagementAction.values) {
      expect(find.byKey(HomeShell.actionKey(action)), findsNothing);
    }
  });

  testWidgets('explicit fullAccess false opens no sections and no actions', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'flag.admin.demo', password: 'demo-only');

    expect(find.text('إداري بعلم صريح'), findsOneWidget);
    expect(find.text(AppStrings.roleAdmin), findsOneWidget);
    expect(find.text(AppStrings.noSections), findsOneWidget);
    expect(find.text(AppStrings.writeAction), findsNothing);
    expect(find.byKey(HomeShell.sectionKey(SectionKey.treasury)), findsNothing);
    expect(
      find.byKey(HomeShell.actionKey(ManagementAction.settingsManage)),
      findsNothing,
    );
  });

  testWidgets(
    'employee sections follow server keys; collections is codes only',
    (tester) async {
      await pumpFakeApp(tester);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');

      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.writeKey(SectionKey.customers)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.collections)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(HomeShell.writeKey(SectionKey.collections)),
            )
            .enabled,
        isTrue,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.libyanDeposits)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'admin with an explicit list is limited to that list and its actions',
    (tester) async {
      await pumpFakeApp(tester);
      await signIn(
        tester,
        username: 'limited.admin.demo',
        password: 'demo-only',
      );

      expect(find.text('إداري محدود تجريبي'), findsOneWidget);
      expect(find.text(AppStrings.roleAdmin), findsOneWidget);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.writeKey(SectionKey.customers)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.collections)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(HomeShell.writeKey(SectionKey.collections)),
            )
            .enabled,
        isTrue,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.actionKey(ManagementAction.collectionsDecide)),
        findsOneWidget,
      );
      expect(
        find.byKey(
          HomeShell.actionKey(ManagementAction.collectionsCashReceived),
        ),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.actionKey(ManagementAction.settingsManage)),
        findsNothing,
      );
    },
  );
}
