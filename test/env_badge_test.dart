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
      expect(_staging.label, 'Staging');
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

    testWidgets('staging: the app shows Staging', (tester) async {
      await pumpFakeApp(
        tester,
        size: const Size(360, 800),
        environment: _staging,
      );
      expect(find.text(AppStrings.envStaging), findsOneWidget);
      expect(find.text(AppStrings.envFake), findsNothing);
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

    testWidgets('fake and staging text meet AA in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final env in [_fake, _staging, _other]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Center(child: EnvironmentBadge(environment: env)),
              ),
            ),
          );
          final text = tester.widget<Text>(
            find.descendant(
              of: find.byType(EnvironmentBadge),
              matching: find.byType(Text),
            ),
          );
          final box = tester.widget<DecoratedBox>(_badge);
          final fill = (box.decoration as BoxDecoration).color!;
          final style = text.style!;
          expect(style.fontSize, 11);
          // 11px bold is normal text: 4.5:1.
          expect(
            contrastRatio(style.color!, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness ${env.kind}',
          );
        }
      }
    });
  });
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
