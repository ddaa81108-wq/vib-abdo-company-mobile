import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets(
    'employee sees only server-granted sections and the server unread count',
    (tester) async {
      await pumpFakeApp(tester);
      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);

      await signIn(tester, username: 'employee.demo', password: 'demo-only');

      expect(find.byKey(HomeShell.shellKey), findsOneWidget);
      expect(find.text('موظف استلام تجريبي'), findsOneWidget);
      expect(find.text(AppStrings.roleEmployee), findsOneWidget);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.collections)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.writeKey(SectionKey.collections)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.writeKey(SectionKey.customers)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.reports)),
        findsNothing,
      );
      final collectionsWrite = tester.widget<TextButton>(
        find.byKey(HomeShell.writeKey(SectionKey.collections)),
      );
      expect(collectionsWrite.enabled, isTrue);
      final badge = tester.widget<Text>(find.byKey(UnreadBadge.badgeKey));
      expect(badge.data, '1');
      expect(find.text('2026-10-19'), findsOneWidget);
      expect(find.textContaining('320 د.ل'), findsNothing);
      expect(find.text('0 د.ل'), findsOneWidget);
      expect(find.textContaining('10,635 د.ل'), findsNothing);
      expect(find.textContaining('ج.م'), findsNothing);

      await tester.tap(find.byKey(HomeShell.logoutKey));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('logout-confirm')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    },
  );

  testWidgets(
    'admin with no permission list sees the sections the flag opens',
    (tester) async {
      await pumpFakeApp(tester);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');

      expect(find.text('مدير تجريبي'), findsOneWidget);
      expect(find.text(AppStrings.roleAdmin), findsOneWidget);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.writeKey(SectionKey.treasury)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(HomeShell.writeKey(SectionKey.treasury)),
            )
            .enabled,
        isTrue,
      );
      expect(
        find.byKey(HomeShell.actionKey(ManagementAction.collectionsDecide)),
        findsOneWidget,
      );
      expect(
        find.byKey(
          HomeShell.actionKey(ManagementAction.collectionsCashReceived),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('23,750 ج.م'), findsOneWidget);
      expect(find.textContaining('8,000 د.ل'), findsOneWidget);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.reports)),
        findsOneWidget,
      );
      expect(find.byKey(HomeShell.writeKey(SectionKey.reports)), findsNothing);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.purchases)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'rejected sign-in stays on the login screen and shows the server message',
    (tester) async {
      await pumpFakeApp(tester);
      await signIn(tester, username: 'employee.demo', password: 'wrong');

      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
      expect(find.byKey(HomeShell.shellKey), findsNothing);
    },
  );

  testWidgets('empty sign-in does not call the session', (tester) async {
    await pumpFakeApp(tester);
    await tester.tap(find.byKey(LoginScreen.submitKey));
    await tester.pump();

    expect(find.text(AppStrings.emptyCredentials), findsOneWidget);
    expect(find.byKey(HomeShell.shellKey), findsNothing);
  });
}
