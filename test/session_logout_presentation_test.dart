import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/authentication/auth_gate.dart';
import 'package:vib_abdo_company_mobile/features/home/home_drawer.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/account_screen.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/session_expired_notice.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
const _phone = Size(320, 568);

/// The row is inside the drawer and the screen, and taps at its centre and
/// near its corners land on it (nothing drawn over it).
void _expectFullyVisible(WidgetTester tester, Finder row, Finder drawer) {
  final rect = tester.getRect(row);
  final box = tester.getRect(drawer);
  final screen = Offset.zero & tester.view.physicalSize;
  expect(box.contains(rect.topLeft), isTrue, reason: '$rect in $box');
  expect(
    box.contains(rect.bottomRight - const Offset(0.5, 0.5)),
    isTrue,
    reason: '$rect in $box',
  );
  expect(screen.contains(rect.bottomRight - const Offset(0.5, 0.5)), isTrue);
  for (final at in const [
    Alignment.center,
    Alignment(-0.9, -0.6),
    Alignment(0.9, 0.6),
  ]) {
    expect(row.hitTestable(at: at), findsOneWidget, reason: '$at');
  }
}

void main() {
  testWidgets(
    'logout asks first, cancel stays signed in, confirm uses the existing logout',
    (tester) async {
      await pumpFakeApp(tester, size: _phone);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');

      await tester.tap(find.byKey(HomeShell.logoutKey));
      await settle(tester);
      expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
      expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(LogoutConfirmDialog.dialogKey)),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(LogoutConfirmDialog.cancelKey));
      await settle(tester);
      expect(find.byKey(HomeShell.shellKey), findsOneWidget);
      expect(find.byKey(LoginScreen.submitKey), findsNothing);
      expect(find.byKey(LogoutConfirmDialog.dialogKey), findsNothing);

      GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
          .go('/account');
      await settle(tester);
      final logoutTile = find.byKey(const Key('account-logout'));
      await tester.scrollUntilVisible(
        logoutTile,
        240,
        scrollable: find.descendant(
          of: find.byKey(AccountScreen.screenKey),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(logoutTile);
      await tester.tap(logoutTile);
      await settle(tester);
      expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
      await settle(tester);
      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
      expect(find.byKey(SessionExpiredNotice.noticeKey), findsNothing);
      expect(find.text(AppStrings.sessionExpired), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a small phone shows the dialog in both themes without overflow',
    (tester) async {
      await pumpFakeApp(tester, size: _phone);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await _openLogout(tester);
      expect(Theme.of(_dialogContext(tester)).brightness, Brightness.light);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(LogoutConfirmDialog.cancelKey));
      await settle(tester);

      await tester.tap(find.byKey(HomeShell.menuKey));
      await settle(tester);
      await tester.tap(find.text(AppStrings.themeDark));
      await settle(tester);
      if (find.byType(Drawer).evaluate().isNotEmpty) {
        Navigator.of(tester.element(find.byType(Drawer))).pop();
        await settle(tester);
      }
      await _openLogout(tester);
      expect(Theme.of(_dialogContext(tester)).brightness, Brightness.dark);
      expect(Directionality.of(_dialogContext(tester)), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale) in const [
    (Size(430, 932), 1.0),
    (_phone, 1.0),
    (_phone, 2.0),
  ]) {
    testWidgets(
      'the drawer logout row (${size.width.toInt()}x${size.height.toInt()} '
      'text x$scale) is last, visible, and uses the existing logout flow',
      (tester) async {
        await pumpFakeApp(tester, size: size, textScale: scale);
        await signIn(tester, username: 'employee.demo', password: 'demo-only');
        for (final dark in [false, true]) {
          await tester.tap(find.byKey(HomeShell.menuKey));
          await settle(tester);
          final drawer = find.byType(Drawer);
          final row = find.byKey(StyledDrawer.logoutKey);
          // One logout entry in the drawer, reached by scrolling.
          expect(row, findsOneWidget);
          expect(
            find.descendant(of: drawer, matching: find.byIcon(Icons.logout)),
            findsOneWidget,
          );
          final themeRow = find.descendant(
            of: drawer,
            matching: find.text(
              dark ? AppStrings.themeLight : AppStrings.themeDark,
            ),
          );
          if (size.width >= 430 && scale == 1.0) {
            // Normal phone: fully visible as soon as the drawer opens.
            _expectFullyVisible(tester, row, drawer);
          }
          await tester.scrollUntilVisible(
            row,
            120,
            scrollable: find.descendant(
              of: drawer,
              matching: find.byType(Scrollable),
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'dark $dark');
          // Logout is the last row, below the theme row, not overlapped.
          expect(
            tester.getRect(row).top,
            greaterThanOrEqualTo(tester.getRect(themeRow).bottom),
          );
          _expectFullyVisible(tester, row, drawer);
          expect(Directionality.of(tester.element(row)), TextDirection.rtl);
          expect(
            Theme.of(tester.element(row)).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(
            tester.getSemantics(row),
            matchesSemantics(
              label: AppStrings.logout,
              isButton: true,
              hasTapAction: true,
              hasFocusAction: true,
              isFocusable: true,
            ),
          );
          final rowHeight = tester.getSize(row).height;
          expect(rowHeight, greaterThanOrEqualTo(48));

          // Same confirmation as the app bar; cancel keeps the session.
          await tester.tap(row);
          await settle(tester);
          expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(LogoutConfirmDialog.cancelKey));
          await settle(tester);
          expect(find.byKey(LogoutConfirmDialog.dialogKey), findsNothing);
          expect(find.byKey(HomeShell.shellKey), findsOneWidget);
          expect(find.byKey(LoginScreen.submitKey), findsNothing);

          if (!dark) {
            await tester.scrollUntilVisible(
              find.text(AppStrings.themeDark),
              120,
              scrollable: find.descendant(
                of: drawer,
                matching: find.byType(Scrollable),
              ),
            );
            await tester.tap(find.text(AppStrings.themeDark));
            await settle(tester);
          }
          if (find.byType(Drawer).evaluate().isNotEmpty) {
            Navigator.of(tester.element(find.byType(Drawer))).pop();
            await settle(tester);
          }
        }

        // Confirm signs out through the existing logout.
        await tester.tap(find.byKey(HomeShell.menuKey));
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(StyledDrawer.logoutKey),
          120,
          scrollable: find.descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.byKey(StyledDrawer.logoutKey));
        await settle(tester);
        await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
        await settle(tester);
        expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
        expect(find.byKey(SessionExpiredNotice.noticeKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('login shows the session-expired notice from signedOutNotice', (
    tester,
  ) async {
    const session = SessionUnauthenticated(reason: 'session_expired');
    expect(signedOutNotice(session), AppStrings.sessionExpired);

    await pumpFakeApp(
      tester,
      size: _phone,
      overrides: [
        sessionStateProvider.overrideWith(() => _FixedSession(session)),
      ],
    );

    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    expect(find.byKey(SessionExpiredNotice.noticeKey), findsOneWidget);
    expect(find.text(AppStrings.sessionExpired), findsOneWidget);
    expect(find.byKey(LoginScreen.errorKey), findsNothing);
    expect(
      Directionality.of(tester.element(find.byKey(LoginScreen.screenKey))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(LoginScreen.themeKey));
    await settle(tester);
    expect(
      Theme.of(tester.element(find.byKey(SessionExpiredNotice.noticeKey)))
          .brightness,
      Brightness.dark,
    );
    expect(find.text(AppStrings.sessionExpired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logging out on purpose does not show the expiry notice', (
    tester,
  ) async {
    const session = SessionUnauthenticated(reason: 'logout');
    expect(signedOutNotice(session), isNull);
    await pumpFakeApp(
      tester,
      size: _phone,
      overrides: [
        sessionStateProvider.overrideWith(() => _FixedSession(session)),
      ],
    );
    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    expect(find.byKey(SessionExpiredNotice.noticeKey), findsNothing);
    expect(find.text(AppStrings.sessionExpired), findsNothing);
  });

  testWidgets(
    'screenshots of the notice and logout dialog at 320',
    (tester) async {
      await tester.runAsync(loadScreenshotFonts);
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        await _pumpSurface(
          tester,
          brightness: dark ? Brightness.dark : Brightness.light,
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topCenter,
                child: SessionExpiredNotice(message: AppStrings.sessionExpired),
              ),
            ),
          ),
        );
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        expect(find.byKey(SessionExpiredNotice.noticeKey), findsOneWidget);
        await saveShot(tester, 'session-expired-$theme-320');

        await _pumpSurface(
          tester,
          brightness: dark ? Brightness.dark : Brightness.light,
          child: const Scaffold(body: SizedBox.shrink()),
        );
        showDialog<void>(
          context: tester.element(find.byType(Scaffold)),
          builder: (context) => const LogoutConfirmDialog(),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
        await saveShot(tester, 'logout-dialog-$theme-320');
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

class _FixedSession extends SessionStateNotifier {
  _FixedSession(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

Future<void> _openLogout(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeShell.logoutKey));
  await settle(tester);
  expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
  expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
}

BuildContext _dialogContext(WidgetTester tester) {
  return tester.element(find.byKey(LogoutConfirmDialog.dialogKey));
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget child,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'LY'),
      supportedLocales: const [Locale('ar', 'LY')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(brightness),
      themeAnimationDuration: Duration.zero,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
