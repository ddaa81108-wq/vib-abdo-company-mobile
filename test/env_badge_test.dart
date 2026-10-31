import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/environment_badge.dart';

import 'contrast_tokens_test.dart' show contrastRatio;
import 'support/pump_app.dart';

final _fake = resolveBuildEnvironment(useFakeApi: true, apiBase: '');
final _staging = resolveBuildEnvironment(
  useFakeApi: false,
  apiBase: 'https://staging.vip2100.com',
);
final _production = resolveBuildEnvironment(
  useFakeApi: false,
  apiBase: 'https://vip2100.com',
);
final _other = resolveBuildEnvironment(
  useFakeApi: false,
  apiBase: 'https://api.example.test',
);

final _badge = find.byKey(EnvironmentBadgeOverlay.badgeKey);

void main() {
  group('env badge resolution', () {
    test('fake: USE_FAKE_API=true is fake whatever API_BASE says', () {
      expect(_fake.kind, BuildEnvironmentKind.fake);
      expect(_fake.label, AppStrings.envFake);
      final withHost = resolveBuildEnvironment(
        useFakeApi: true,
        apiBase: 'https://vip2100.com',
      );
      expect(withHost.kind, BuildEnvironmentKind.fake);
      expect(withHost.label, 'بيانات وهمية (Fake API)');
    });

    test('staging: host staging.vip2100.com, any scheme, port or case', () {
      expect(_staging.kind, BuildEnvironmentKind.staging);
      expect(_staging.label, 'خادم التجربة');
      for (final base in [
        'https://staging.vip2100.com/',
        'http://STAGING.vip2100.com:8443',
        ' https://staging.vip2100.com ',
      ]) {
        final env = resolveBuildEnvironment(useFakeApi: false, apiBase: base);
        expect(env.kind, BuildEnvironmentKind.staging, reason: base);
      }
    });

    test('production: https://vip2100.com has no label', () {
      expect(_production.kind, BuildEnvironmentKind.production);
      expect(_production.label, isNull);
    });

    test('production is only https://vip2100.com on the default port', () {
      for (final base in [
        'https://vip2100.com',
        'https://vip2100.com/',
        'https://VIP2100.com',
        'HTTPS://vip2100.com',
        'https://vip2100.com:443',
      ]) {
        final env = resolveBuildEnvironment(useFakeApi: false, apiBase: base);
        expect(env.kind, BuildEnvironmentKind.production, reason: base);
        expect(env.label, isNull, reason: base);
      }
    });

    test('production mismatch: http or another port shows a warning', () {
      const cases = {
        'http://vip2100.com': 'http://vip2100.com',
        'http://vip2100.com:80': 'http://vip2100.com',
        'https://vip2100.com:8443': 'https://vip2100.com:8443',
        'http://vip2100.com:443': 'http://vip2100.com:443',
        'https://vip2100.com:80': 'https://vip2100.com:80',
      };
      for (final entry in cases.entries) {
        final env = resolveBuildEnvironment(
          useFakeApi: false,
          apiBase: entry.key,
        );
        expect(
          env.kind,
          BuildEnvironmentKind.productionMismatch,
          reason: entry.key,
        );
        expect(
          env.label,
          'عنوان إنتاج غير معتمد: ${entry.value}',
          reason: entry.key,
        );
      }
    });

    test('lookalike hosts are neither production nor staging', () {
      for (final base in [
        'https://vip2100.com.evil.test',
        'https://evilvip2100.com',
        'https://staging.vip2100.com.evil.test',
        'https://evilstaging.vip2100.com',
        'https://vip2100.com@evil.test',
        'https://staging.vip2100.com@evil.test',
        'https://vip2100.com.',
        'https://vip2100.co',
      ]) {
        final env = resolveBuildEnvironment(useFakeApi: false, apiBase: base);
        expect(env.kind, BuildEnvironmentKind.other, reason: base);
        expect(env.label, startsWith('خادم آخر: '), reason: base);
      }
    });

    test('other host shows the host; missing or bad API_BASE is unknown', () {
      expect(_other.kind, BuildEnvironmentKind.other);
      expect(_other.label, AppStrings.envOtherHost('api.example.test'));
      final www = resolveBuildEnvironment(
        useFakeApi: false,
        apiBase: 'https://www.vip2100.com',
      );
      expect(www.kind, BuildEnvironmentKind.other);
      for (final base in ['', 'not a url', '::']) {
        final env = resolveBuildEnvironment(useFakeApi: false, apiBase: base);
        expect(env.kind, BuildEnvironmentKind.other, reason: base);
        expect(env.label, AppStrings.envUnknown, reason: base);
      }
    });

    test('this test build reads the defines: USE_FAKE_API default is fake', () {
      expect(kBuildEnvironment, _fake);
    });
  });

  group('env badge widget', () {
    testWidgets('fake: on login and every shell route, RTL, with Semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpFakeApp(tester, size: const Size(360, 800));
      expect(_badge, findsOneWidget);
      expect(find.text(AppStrings.envFake), findsOneWidget);
      expect(_fill(tester), AppStatusColors.light.chipReviewBg);
      expect(Directionality.of(tester.element(_badge)), TextDirection.rtl);
      expect(
        find.bySemanticsLabel(
          '${AppStrings.envSemanticsPrefix}${AppStrings.envFake}',
        ),
        findsOneWidget,
      );

      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.byKey(HomeShell.shellKey), findsOneWidget);
      for (final path in ['/', '/settings', '/notifications', '/account']) {
        GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(path);
        await _settle(tester);
        expect(_badge, findsOneWidget, reason: path);
        expect(find.text(AppStrings.envFake), findsOneWidget, reason: path);
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('staging: the app shows خادم التجربة in the neutral colour', (
      tester,
    ) async {
      await pumpFakeApp(
        tester,
        size: const Size(360, 800),
        environment: _staging,
      );
      expect(find.text(AppStrings.envStaging), findsOneWidget);
      expect(find.text(AppStrings.envFake), findsNothing);
      expect(
        _fill(tester),
        Theme.of(tester.element(_badge)).colorScheme.inverseSurface,
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.text(AppStrings.envStaging), findsOneWidget);
    });

    testWidgets('production: the app draws no badge', (tester) async {
      await pumpFakeApp(
        tester,
        size: const Size(360, 800),
        environment: _production,
      );
      expect(_badge, findsNothing);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.byKey(HomeShell.shellKey), findsOneWidget);
      expect(_badge, findsNothing);
      expect(find.byType(EnvironmentBadge), findsNothing);
      expect(find.text(AppStrings.envFake), findsNothing);
      expect(find.text(AppStrings.envStaging), findsNothing);
    });

    testWidgets('other host: the badge names the host, unknown when empty', (
      tester,
    ) async {
      await pumpFakeApp(
        tester,
        size: const Size(360, 800),
        environment: _other,
      );
      expect(
        find.text(AppStrings.envOtherHost('api.example.test')),
        findsOneWidget,
      );
      await pumpFakeApp(
        tester,
        size: const Size(360, 800),
        environment: resolveBuildEnvironment(useFakeApi: false, apiBase: ''),
      );
      expect(find.text(AppStrings.envUnknown), findsOneWidget);
    });

    testWidgets('a tap on the badge reaches the content underneath', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: EnvironmentBadgeOverlay(environment: _fake, child: child!),
          ),
          home: Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      expect(find.byType(IgnorePointer), findsWidgets);
      await tester.tapAt(tester.getCenter(_badge));
      expect(taps, 1);
    });

    for (final size in const [Size(320, 568), Size(430, 932)]) {
      for (final dark in [false, true]) {
        final name =
            '${dark ? 'dark' : 'light'} ${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('RTL layout $name: on the toolbar edge, clear of its '
            'icons and title, no overflow', (tester) async {
          await pumpFakeApp(tester, size: size);
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await _settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          expect(tester.takeException(), isNull);
          final badge = tester.getRect(_badge);
          expect(badge.left, greaterThanOrEqualTo(0));
          expect(badge.right, lessThanOrEqualTo(size.width));
          expect(badge.center.dx, closeTo(size.width / 2, 1));
          expect(
            badge.top,
            closeTo(kToolbarHeight - EnvironmentBadgeOverlay.lift, 0.5),
          );
          expect(badge.height, EnvironmentBadgeOverlay.height);
          final bar = find.byType(AppBar).first;
          for (final finder in [
            // Glyphs, not the 48px touch boxes: those reach 4px under the
            // badge, and IgnorePointer passes those taps through.
            find.descendant(of: bar, matching: find.byType(Icon)),
            find.descendant(of: bar, matching: find.byType(Text)),
          ]) {
            for (final element in finder.evaluate()) {
              final box = element.renderObject! as RenderBox;
              final rect = box.localToGlobal(Offset.zero) & box.size;
              expect(
                rect.overlaps(badge),
                isFalse,
                reason: '$element at $rect overlaps the badge $badge',
              );
            }
          }
          final theme = Theme.of(tester.element(_badge));
          expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
        });
      }
    }

    testWidgets('a long host is cut with an ellipsis on a 320 phone', (
      tester,
    ) async {
      await pumpFakeApp(
        tester,
        size: const Size(320, 568),
        environment: resolveBuildEnvironment(
          useFakeApi: false,
          apiBase: 'https://a-very-long-internal-test-server-name.example.test',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_badge).width, lessThanOrEqualTo(320 - 24));
    });

    testWidgets('colours: fake is the review chip, servers the inverse '
        'surface of each theme, AA in light and dark', (tester) async {
      final mismatch = resolveBuildEnvironment(
        useFakeApi: false,
        apiBase: 'http://vip2100.com',
      );
      final unknown = resolveBuildEnvironment(useFakeApi: false, apiBase: '');
      final fills = <Brightness, Color>{};
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final status = theme.extension<AppStatusColors>()!;
        for (final env in [_fake, _staging, _other, mismatch, unknown]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Center(child: EnvironmentBadge(environment: env)),
              ),
            ),
          );
          // MaterialApp animates a theme change. Read the settled colours.
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(
            find.descendant(
              of: find.byType(EnvironmentBadge),
              matching: find.byType(Text),
            ),
          );
          final fill = _fill(tester);
          final ink = text.style!.color!;
          final fake = env.kind == BuildEnvironmentKind.fake;
          expect(
            fill,
            fake ? status.chipReviewBg : theme.colorScheme.inverseSurface,
            reason: '$brightness ${env.kind}',
          );
          expect(
            ink,
            fake ? status.chipReviewFg : theme.colorScheme.onInverseSurface,
            reason: '$brightness ${env.kind}',
          );
          expect(
            fill,
            isNot(AppStatusColors.light.chipCriticalBg),
            reason: 'no critical-debt red',
          );
          expect(text.style!.fontSize, 11);
          // 11px bold is normal text: 4.5:1.
          expect(
            contrastRatio(ink, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness ${env.kind}',
          );
          if (env == _staging) fills[brightness] = fill;
        }
      }
      // The neutral pair flips with the theme, so both pairs were checked.
      expect(fills[Brightness.light], isNot(fills[Brightness.dark]));
    });

    testWidgets('notched phone: the badge sits below a 47px safe area on a '
        'shell screen and on login (no AppBar), unclipped', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 47);
      tester.view.viewPadding = const FakeViewPadding(top: 47);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      const size = Size(390, 844);
      await pumpFakeApp(tester, size: size, environment: _staging);
      expect(find.byType(AppBar), findsNothing);
      _expectBelowSafeArea(tester, size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.byType(AppBar), findsWidgets);
      _expectBelowSafeArea(tester, size);
      final bar = tester.getRect(find.byType(AppBar).first);
      expect(
        tester.getRect(_badge).top,
        closeTo(bar.bottom - EnvironmentBadgeOverlay.lift, 0.5),
      );
      expect(
        _fill(tester),
        Theme.of(tester.element(_badge)).colorScheme.inverseSurface,
      );
    });

    testWidgets('http production: the app shows the warning badge', (
      tester,
    ) async {
      await pumpFakeApp(
        tester,
        size: const Size(320, 568),
        environment: resolveBuildEnvironment(
          useFakeApi: false,
          apiBase: 'http://vip2100.com',
        ),
      );
      expect(
        find.text(AppStrings.envProductionMismatch('http://vip2100.com')),
        findsOneWidget,
      );
      expect(
        _fill(tester),
        Theme.of(tester.element(_badge)).colorScheme.inverseSurface,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Color _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_badge);
  return (box.decoration as BoxDecoration).color!;
}

void _expectBelowSafeArea(WidgetTester tester, Size size) {
  final badge = tester.getRect(_badge);
  expect(badge.top, greaterThanOrEqualTo(47));
  expect(
    badge.top,
    closeTo(47 + kToolbarHeight - EnvironmentBadgeOverlay.lift, 0.5),
  );
  expect(badge.height, EnvironmentBadgeOverlay.height);
  expect(badge.left, greaterThanOrEqualTo(0));
  expect(badge.right, lessThanOrEqualTo(size.width));
  expect(badge.bottom, lessThanOrEqualTo(size.height));
  expect(tester.takeException(), isNull);
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
