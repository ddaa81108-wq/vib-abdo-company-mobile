import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/performance/history_window.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

/// Ali, 2026-11-03: the ledger is the website's table. Oldest row on top,
/// one continuous record, the total card pinned, the screen opens at the
/// entry buttons, and a correction opens in its own row.
void main() {
  testWidgets('columns carry the website labels', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final header = find.byKey(const Key('ledger-column-header'));
    for (final label in [
      AppStrings.ledgerColSeq,
      AppStrings.ledgerColWhen,
      AppStrings.ledgerColType,
      AppStrings.ledgerColNote,
      AppStrings.ledgerColValue,
      AppStrings.ledgerColOperation,
      AppStrings.ledgerColRate,
      AppStrings.ledgerColDebt,
      AppStrings.ledgerColPaid,
      AppStrings.ledgerColEdit,
      AppStrings.ledgerColCancel,
    ]) {
      expect(
        find.descendant(of: header, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('rows run oldest first by server sequence', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final ids = [
      for (final element
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'ledger-row-',
                    ),
              )
              .evaluate())
        (element.widget.key! as ValueKey<String>).value,
    ];
    expect(ids.length, greaterThanOrEqualTo(2));
    final tops = [
      for (final id in ids) tester.getTopLeft(find.byKey(ValueKey(id))).dy,
    ];
    final sequences = <int>[];
    for (final id in ids) {
      final mark = find.byKey(
        Key('ledger-sequence-${id.substring('ledger-row-'.length)}'),
      );
      final text = find.descendant(of: mark, matching: find.byType(Text));
      sequences.add(int.parse(tester.widget<Text>(text).data!));
    }
    final order = [for (var i = 0; i < ids.length; i++) i]
      ..sort((a, b) => tops[a].compareTo(tops[b]));
    final shown = [for (final i in order) sequences[i]];
    expect(shown, [...shown]..sort());
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a long ledger opens at the entry buttons, card pinned', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(430, 932),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('ledger-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(scroll.position.pixels, closeTo(scroll.position.maxScrollExtent, 1));
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    final composer = tester.getRect(find.byKey(const Key('ledger-composer')));
    expect(composer.bottom, lessThanOrEqualTo(view.height));
    final header = tester.getRect(find.byKey(const Key('ledger-header')));
    expect(header.top, greaterThanOrEqualTo(0));

    scroll.position.jumpTo(0);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const Key('ledger-header'))).top,
      header.top,
      reason: 'the total card does not scroll away',
    );
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a correction opens in its own row and closes there', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final button = find.byKey(const Key('correct-tx_1'));
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    final inline = find.byKey(const Key('ledger-inline-edit-tx_1'));
    expect(inline, findsOneWidget);
    expect(
      find.descendant(
        of: inline,
        matching: find.byKey(const Key('correction-form')),
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    final row = tester.getRect(find.byKey(const ValueKey('ledger-row-tx_1')));
    expect(tester.getRect(inline).top, greaterThanOrEqualTo(row.top));

    final close = find.byKey(const Key('close-inline-edit-tx_1'));
    await tester.ensureVisible(close);
    await settle(tester);
    await tester.tap(close);
    await settle(tester);
    expect(inline, findsNothing);
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  for (final (units, word) in [(320, 'دين'), (-80, 'أمانة'), (0, 'صفر')]) {
    testWidgets('the total card is glossy for $word', (tester) async {
      await pumpFakeApp(
        tester,
        size: const Size(430, 932),
        overrides: [
          accountCardProvider.overrideWith((ref, key) async {
            return AccountCardDto.fromJson({
              'id': key.$2,
              'name': 'عميل تجريبي',
              'balanceUnits': units,
              'version': 2,
            }, key.$1);
          }),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final card = find.byKey(const Key('ledger-header'));
      final look = tester.element(card).look;
      final gloss = switch (units) {
        > 0 => look.glossDebt,
        < 0 => look.glossCredit,
        _ => look.glossZero,
      };
      final ink = tester.widget<Ink>(
        find.descendant(of: card, matching: find.byType(Ink)).first,
      );
      final decoration = ink.decoration! as BoxDecoration;
      expect(
        (decoration.gradient! as LinearGradient).colors,
        gloss.fill.colors,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('ledger-header-kind')),
          matching: find.text(word),
        ),
        findsOneWidget,
      );
      final shown = find.descendant(
        of: find.byKey(const Key('ledger-header-balance')),
        matching: find.textContaining('-'),
      );
      expect(shown, findsNothing);
      expect(tester.takeException(), isNull);
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('the add row sits under the table with the three types', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final table = find.byKey(const Key('ledger-table'));
    for (final key in ['add-debt', 'add-payment', 'composer-full']) {
      expect(
        find.descendant(of: table, matching: find.byKey(Key(key))),
        findsOneWidget,
        reason: key,
      );
    }
    expect(find.text(AppStrings.debtMovement), findsWidgets);
    expect(find.text(AppStrings.paymentMovement), findsWidgets);
    expect(find.text(AppStrings.fullPayment), findsWidgets);
    // Debt is chosen first, so its fields are open.
    expect(find.byKey(const Key('movement-amount')), findsOneWidget);
    expect(find.byKey(const Key('full-payment')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-full')));
    await tester.pump();
    expect(find.byKey(const Key('full-payment')), findsOneWidget);
    expect(find.byKey(const Key('movement-amount')), findsNothing);
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('multiply and divide show × and ÷, read as ضرب and قسمة', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final table = find.byKey(const Key('ledger-table'));
    expect(
      find.descendant(of: table, matching: find.text('\u00D7')),
      findsWidgets,
    );
    expect(
      find.descendant(of: table, matching: find.text('\u00F7')),
      findsWidgets,
    );
    expect(
      find.descendant(of: table, matching: find.text(AppStrings.multiply)),
      findsNothing,
    );
    expect(
      find.descendant(of: table, matching: find.text(AppStrings.divide)),
      findsNothing,
    );
    expect(find.bySemanticsLabel(AppStrings.multiply), findsWidgets);
    expect(find.bySemanticsLabel(AppStrings.divide), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  for (final dark in [false, true]) {
    testWidgets(
      'grid: column lines and row lines (${dark ? 'dark' : 'light'})',
      (tester) async {
        await pumpFakeApp(tester, size: const Size(430, 932));
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        final home = find.byKey(HomeShell.shellKey);
        final current = Theme.of(tester.element(home)).brightness;
        if ((current == Brightness.dark) != dark) {
          ProviderScope.containerOf(tester.element(home))
              .read(themeModeProvider.notifier)
              .toggle();
          await settle(tester);
        }
        await go(tester, '/customers/c_55');
        expect(
          Theme.of(tester.element(find.byKey(const Key('ledger-table'))))
              .brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        final line = dark ? const Color(0xFF2E3A57) : const Color(0xFFD3DCE8);
        bool columnLine(Widget w) {
          if (w is! Container) return false;
          final d = w.decoration;
          if (d is! BoxDecoration) return false;
          final b = d.border;
          return b is BorderDirectional && b.end.color == line;
        }

        final header = find.byKey(const Key('ledger-column-header'));
        // Every column but the last has a divider: 12 columns -> 11 lines
        // (11 -> 10 when الرصيد is hidden).
        final headLines = find
            .descendant(
              of: header,
              matching: find.byWidgetPredicate(columnLine),
            )
            .evaluate()
            .length;
        expect(headLines, anyOf(10, 11));
        final row = find.byKey(const Key('ledger-entry-tx_1'));
        expect(
          find
              .descendant(of: row, matching: find.byWidgetPredicate(columnLine))
              .evaluate()
              .length,
          headLines,
        );
        // Row line along the bottom of each row.
        final rowBox = tester.widget<DecoratedBox>(
          find.descendant(of: row, matching: find.byType(DecoratedBox)).first,
        );
        final border = (rowBox.decoration as BoxDecoration).border as Border;
        expect(border.bottom.color, line);
        // Lines run the full row height.
        final rowHeight = tester
            .getSize(find.descendant(of: row, matching: find.byType(Row)).first)
            .height;
        final cell = find
            .descendant(of: row, matching: find.byWidgetPredicate(columnLine))
            .first;
        expect(tester.getSize(cell).height, rowHeight);
        expect(tester.takeException(), isNull);
        await settle(tester);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }

  testWidgets('a cancelled row is hidden like the website; corrected stays', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 1600),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          final items = raw['items'] as List;
          (items[0] as Map)['status'] = 'reversed';
          (items[1] as Map)['status'] = 'corrected';
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const ValueKey('ledger-row-tx_1')), findsNothing);
    expect(find.byKey(const ValueKey('ledger-row-tx_2')), findsOneWidget);
    expect(find.text(AppStrings.reversed), findsNothing);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('م runs 1..n over every page, oldest first, without gaps', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 1600),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = FakeFixtures.ledger();
          ((raw['items'] as List)[0] as Map)['status'] = 'reversed';
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await settle(tester);
    String mark(String id) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key('ledger-sequence-$id')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    // The older page loaded by itself; the cancelled tx_1 is not drawn
    // and leaves no gap in the numbers.
    expect(mark('tx_old'), '1');
    expect(mark('tx_2'), '2');
    expect(find.byKey(const Key('ledger-sequence-tx_1')), findsNothing);
    expect(find.byKey(const Key('load-older')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('entry: ديون is chosen and the value field has the cursor', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await settle(tester);
    expect(find.byKey(const ValueKey('movement-debt-0')), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const Key('movement-amount')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('after a save the row is fresh and back on ديون', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('add-payment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-payment')));
    await tester.pump();
    expect(find.byKey(const ValueKey('movement-payment-0')), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('movement-amount')),
        matching: find.byType(TextField),
      ),
      '10',
    );
    await tester.pump();
    final save = find.byKey(const Key('save-movement'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await settle(tester);
    // GuardedMutation asks to confirm; accept when it does.
    final confirm = find.byKey(const Key('confirm-mutation'));
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await settle(tester);
    }
    expect(find.byKey(const ValueKey('movement-debt-1')), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const Key('movement-amount')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).controller.text, isEmpty);
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the column names stay pinned and follow the sideways scroll', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(430, 932),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byKey(const Key('ledger-loading-older')).evaluate().isEmpty &&
          HistoryWindowTrace.ledgerExtra.isNotEmpty) {
        break;
      }
    }
    final header = find.byKey(const Key('ledger-sticky-header'));
    expect(header, findsOneWidget);
    final before = tester.getRect(header);
    // Scroll the rows up a long way: the names do not move.
    await tester.drag(
      find.byKey(const Key('ledger-entries-list')),
      const Offset(0, 600),
    );
    await tester.pump();
    expect(tester.getRect(header), before);
    // Sideways: the names follow the rows.
    final rows = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('ledger-columns-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    rows.position.jumpTo(rows.position.maxScrollExtent);
    await tester.pump();
    final names = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('ledger-header-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(names.position.pixels, rows.position.pixels);
    // Away from the ends: the jump buttons show and work.
    await tester.pump();
    expect(find.byKey(const Key('ledger-jump-top')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ledger-jump-top')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('ledger-jump-bottom')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ledger-jump-bottom')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('ledger-jump-bottom')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  for (final dark in [false, true]) {
    testWidgets(
      'with the keyboard up the value field and the names stay visible '
      '(${dark ? 'dark' : 'light'})',
      (tester) async {
        await pumpFakeApp(tester, size: const Size(430, 932));
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await settle(tester);
        }
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/customers/c_55');
        await settle(tester);
        // A phone keyboard: about a third of the screen.
        tester.view.viewInsets = FakeViewPadding(
          bottom: 320 * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await settle(tester);
        final visibleBottom = 932 - 320.0;
        final field = find.byKey(const Key('movement-amount'));
        expect(tester.getRect(field).bottom, lessThanOrEqualTo(visibleBottom));
        expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
        final names = find.byKey(const Key('ledger-sticky-header'));
        expect(names, findsOneWidget);
        expect(tester.getRect(names).bottom, lessThan(visibleBottom));
        expect(find.byKey(const Key('ledger-header')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
