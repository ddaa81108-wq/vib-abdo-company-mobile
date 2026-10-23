import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

const _candidates = {
  'items': [
    {'id': 'c_55', 'name': 'عميل تجريبي', 'sectionKey': 'customer_debts'},
    {
      'id': 'ld_1',
      'name': 'أمانة ليبية تجريبية',
      'sectionKey': 'libyan_deposits',
    },
    {
      'id': 'eg_1',
      'name': 'أمانة مصرية تجريبية',
      'sectionKey': 'egyptian_deposits',
    },
  ],
};

void main() {
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 2600), const Size(430, 2400)]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets(
        'DEF-035 $theme ${size.width.toInt()} hides the Egyptian card and still links LYD',
        (tester) async {
          final layer = await pumpFakeApp(tester, size: size);
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/collections');
          final fake = layer.client as FakeApiClient;
          fake.scriptedGetJson[ApiEndpoints.collectionLinkCandidates] =
              jsonEncode(_candidates);
          final postsBefore = fake.mutationPaths.length;

          await _openLink(tester);
          await tester.enterText(find.byKey(const Key('link-customer')), 'ab');
          await settle(tester);

          expect(find.byKey(const Key('link-candidate-eg_1')), findsNothing);
          expect(find.text('أمانة مصرية تجريبية'), findsNothing);
          expect(find.byKey(const Key('link-candidate-c_55')), findsOneWidget);
          expect(find.byKey(const Key('link-candidate-ld_1')), findsOneWidget);
          expect(find.byKey(const Key('egyptian-link-paused')), findsOneWidget);
          expect(
            Directionality.of(
              tester.element(find.byKey(const Key('link-form'))),
            ),
            TextDirection.rtl,
          );
          expect(
            Theme.of(tester.element(find.byKey(const Key('link-form'))))
                .brightness,
            dark ? Brightness.dark : Brightness.light,
          );

          await tester.enterText(
            find.byKey(const Key('link-customer')),
            'eg_1',
          );
          await settle(tester);
          await tester.ensureVisible(find.byKey(const Key('save-link')));
          await tester.tap(find.byKey(const Key('save-link')));
          await settle(tester);
          expect(fake.mutationPaths, hasLength(postsBefore));
          expect(find.text(AppStrings.egyptianLinkPaused), findsWidgets);
          expect(find.byKey(const Key('link-candidate-eg_1')), findsNothing);

          if (size.width == 430 && !dark) {
            await tester.ensureVisible(
              find.byKey(const Key('link-candidate-c_55')),
            );
            await tester.tap(find.byKey(const Key('link-candidate-c_55')));
            await settle(tester);
            await tester.ensureVisible(find.byKey(const Key('save-link')));
            await tester.tap(find.byKey(const Key('save-link')));
            await settle(tester);
            final body =
                jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
            expect(body['customerId'], 'c_55');
            expect(body.containsKey('rate'), isFalse);
            expect(body.containsKey('egpPerLyd'), isFalse);
            expect(find.byKey(const Key('unlinked-link-ur_1')), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'DEF-035 Egyptian link pause screenshots',
    (tester) async {
      await tester.runAsync(loadScreenshotFonts);
      for (final dark in [false, true]) {
        for (final width in [320.0, 430.0]) {
          final open = Size(width, width == 320 ? 2600 : 2400);
          final layer = await pumpFakeApp(tester, size: open);
          await tester.pump();
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/collections');
          (layer.client as FakeApiClient).scriptedGetJson[ApiEndpoints
              .collectionLinkCandidates] = jsonEncode(
            _candidates,
          );
          await _openLink(tester);
          await tester.enterText(find.byKey(const Key('link-customer')), 'ab');
          await settle(tester);
          expect(find.byKey(const Key('link-candidate-eg_1')), findsNothing);
          expect(find.byKey(const Key('link-candidate-c_55')), findsOneWidget);
          tester.view.physicalSize = Size(width, width == 320 ? 780 : 932);
          await tester.pump();
          expect(find.byKey(const Key('link-candidate-eg_1')), findsNothing);
          expect(find.text('أمانة مصرية تجريبية'), findsNothing);
          expect(find.byKey(const Key('egyptian-link-paused')), findsOneWidget);
          final theme = dark ? 'dark' : 'light';
          await saveShot(
            tester,
            'egyptian-link-paused-$theme-${width.toInt()}',
          );
        }
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

Future<void> _openLink(WidgetTester tester) async {
  final link = find.byKey(const Key('unlinked-link-ur_1'));
  await tester.ensureVisible(link);
  await tester.tap(link);
  await settle(tester);
}
