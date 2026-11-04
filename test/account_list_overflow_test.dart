import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

// Account list screens (customers, companies, Libyan and Egyptian deposits)
// must not overflow on a small phone or with large text, in any state.
const _sizes = [Size(320, 568), Size(430, 932)];
const _scales = [1.0, 2.0];

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byKey(HomeShell.shellKey)));

Future<void> _dark(WidgetTester tester) async {
  _container(tester).read(themeModeProvider.notifier).toggle();
  await settle(tester);
  expect(
    Theme.of(tester.element(find.byKey(HomeShell.shellKey))).brightness,
    Brightness.dark,
  );
}

void _noOverflow(WidgetTester tester, String reason) {
  expect(tester.takeException(), isNull, reason: reason);
  expect(
    Directionality.of(tester.element(find.byKey(HomeShell.shellKey))),
    TextDirection.rtl,
  );
}

void main() {
  for (final size in _sizes) {
    for (final scale in _scales) {
      for (final dark in [false, true]) {
        final tag =
            '${size.width.toInt()}x${size.height.toInt()} '
            'x$scale ${dark ? 'dark' : 'light'}';

        testWidgets('account lists: loading then loaded, $tag', (tester) async {
          final layer = await pumpFakeApp(tester, size: size, textScale: scale);
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          if (dark) await _dark(tester);
          final client = layer.client as FakeApiClient;
          for (final section in AccountSection.values) {
            final gate = Completer<void>();
            client.pauseAccountLists = gate;
            goNow(tester, '/${section.path}');
            await pumpUntilFound(
              tester,
              find.byKey(const Key('accounts-loading')),
            );
            await tester.pump(const Duration(milliseconds: 300));
            _noOverflow(tester, '${section.path} loading $tag');

            gate.complete();
            client.pauseAccountLists = null;
            await settle(tester);
            expect(find.byKey(Key('screen-${section.path}')), findsOneWidget);
            _noOverflow(tester, '${section.path} loaded $tag');
          }
        });

        testWidgets('account lists: empty, error and offline, $tag', (
          tester,
        ) async {
          final failing = <AccountSection>{};
          final connectivity = ToggleConnectivity();
          await pumpFakeApp(
            tester,
            size: size,
            textScale: scale,
            connectivity: connectivity,
            overrides: [
              accountsProvider.overrideWith((ref, section) async {
                if (failing.contains(section)) {
                  throw const NetworkException();
                }
                // Same read as the app's provider.
                final query = ref.watch(accountQueryProvider(section)).trim();
                final filter = ref.watch(accountFilterProvider(section));
                return ref
                    .read(apiLayerProvider)
                    .accounts
                    .list(
                      section,
                      q: query.isEmpty ? null : query,
                      filter: filter,
                    );
              }),
            ],
          );
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          if (dark) await _dark(tester);
          for (final section in AccountSection.values) {
            await go(tester, '/${section.path}');
            // Empty: a search that matches nothing.
            _container(tester)
                    .read(accountQueryProvider(section).notifier)
                    .state =
                'zzz-no-such-name';
            await settle(tester);
            _noOverflow(tester, '${section.path} empty $tag');

            // Error over kept data (a reload fails).
            failing.add(section);
            _container(tester).invalidate(accountsProvider(section));
            await settle(tester);
            expect(find.text(AppStrings.retry), findsWidgets);
            _noOverflow(tester, '${section.path} error over data $tag');

            // Error with no kept data (first load fails).
            await go(tester, '/');
            await go(tester, '/${section.path}');
            expect(find.text(AppStrings.retry), findsWidgets);
            _noOverflow(tester, '${section.path} error $tag');
            failing.remove(section);
            _container(tester)
                    .read(accountQueryProvider(section).notifier)
                    .state =
                '';
            _container(tester).invalidate(accountsProvider(section));
            await settle(tester);
          }
          connectivity.setOnline(false);
          await settle(tester);
          await go(tester, '/${AccountSection.customers.path}');
          _noOverflow(tester, 'customers offline $tag');
          connectivity.setOnline(true);
          await settle(tester);
        });
      }
    }
  }

  // Ledger and edit-card screens share the same expanded KeptData panes.
  for (final scale in _scales) {
    for (final dark in [false, true]) {
      final tag = '320x568 x$scale ${dark ? 'dark' : 'light'}';
      testWidgets('ledger and edit card: loading and error, $tag', (
        tester,
      ) async {
        var gate = Completer<void>();
        var failing = false;
        Future<void> hold() async {
          await gate.future;
          if (failing) throw const NetworkException();
        }

        await pumpFakeApp(
          tester,
          size: const Size(320, 568),
          textScale: scale,
          overrides: [
            accountCardProvider.overrideWith((ref, key) async {
              await hold();
              return ref.read(apiLayerProvider).accounts.get(key.$1, key.$2);
            }),
            ledgerProvider.overrideWith((ref, key) async {
              await hold();
              return ref.read(apiLayerProvider).accounts.ledger(key.$1, key.$2);
            }),
          ],
        );
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        if (dark) await _dark(tester);
        for (final path in ['/customers/c_55', '/customers/c_55/edit']) {
          gate = Completer<void>();
          failing = false;
          goNow(tester, path);
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          _noOverflow(tester, '$path loading $tag');
          gate.complete();
          await settle(tester);
          _noOverflow(tester, '$path loaded $tag');

          gate = Completer<void>()..complete();
          failing = true;
          await go(tester, '/');
          _container(tester).invalidate(accountCardProvider);
          _container(tester).invalidate(ledgerProvider);
          await go(tester, path);
          expect(find.text(AppStrings.retry), findsWidgets);
          _noOverflow(tester, '$path error $tag');
          failing = false;
          _container(tester).invalidate(accountCardProvider);
          _container(tester).invalidate(ledgerProvider);
          await go(tester, '/');
        }
      });
    }
  }
}
