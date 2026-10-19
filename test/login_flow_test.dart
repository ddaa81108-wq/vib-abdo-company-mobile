import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiConfigProvider.overrideWithValue(
            const ApiConfig(
              baseUrl: 'https://fake.invalid',
              useFakeApi: true,
              fakeLatency: Duration.zero,
            ),
          ),
        ],
        child: const CompanyApp(),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  }

  Future<void> signIn(
    WidgetTester tester, {
    required String username,
    required String password,
  }) async {
    await tester.enterText(find.byKey(LoginScreen.usernameKey), username);
    await tester.enterText(find.byKey(LoginScreen.passwordKey), password);
    await tester.tap(find.byKey(LoginScreen.submitKey));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  }

  testWidgets(
    'employee sees only server-granted sections and the server unread count',
    (tester) async {
      await pumpApp(tester);
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
        find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.reports)),
        findsNothing,
      );
      final badge = tester.widget<Text>(find.byKey(UnreadBadge.badgeKey));
      expect(badge.data, '1');
      expect(find.textContaining('د.ل'), findsNothing);
      expect(find.textContaining('ج.م'), findsNothing);

      await tester.tap(find.byKey(HomeShell.logoutKey));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    },
  );

  testWidgets('admin sees the sections the server opens for that role', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    expect(find.text('مدير تجريبي'), findsOneWidget);
    expect(find.text(AppStrings.roleAdmin), findsOneWidget);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
      findsOneWidget,
    );
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.reports)),
      findsOneWidget,
    );
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.purchases)),
      findsOneWidget,
    );
  });

  testWidgets(
    'rejected sign-in stays on the login screen and shows the server message',
    (tester) async {
      await pumpApp(tester);
      await signIn(tester, username: 'employee.demo', password: 'wrong');

      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
      expect(find.byKey(HomeShell.shellKey), findsNothing);
    },
  );

  testWidgets('empty sign-in does not call the session', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(LoginScreen.submitKey));
    await tester.pump();

    expect(find.text(AppStrings.emptyCredentials), findsOneWidget);
    expect(find.byKey(HomeShell.shellKey), findsNothing);
  });
}
