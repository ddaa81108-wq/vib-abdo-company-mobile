import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 2400), const Size(430, 2400)]) {
      final theme = dark ? 'dark' : 'light';
      testWidgets(
        'DEF-035 $theme ${size.width.toInt()} hides cash on a rejected receipt',
        (tester) async {
          final layer = await pumpFakeApp(
            tester,
            size: size,
            overrides: [
              // 537f073 does not list a rejected standalone receipt; one that
              // still arrives (older server, race) must never offer cash.
              collectionsProvider.overrideWith((ref) async {
                final live = await ref
                    .read(apiLayerProvider)
                    .collections
                    .overview();
                return CollectionsOverviewDto(
                  assignments: live.assignments,
                  submissions: live.submissions,
                  unlinkedReceipts: [
                    ...live.unlinkedReceipts,
                    const UnlinkedReceiptDto(
                      id: 'ur_2',
                      customerName: 'استلام مرفوض تجريبي',
                      amountUnits: MoneyValue.known(40),
                      status: 'rejected',
                    ),
                  ],
                  employeeTotals: live.employeeTotals,
                );
              }),
            ],
          );
          if (dark) {
            await tester.tap(find.byKey(LoginScreen.themeKey));
            await settle(tester);
          }
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/collections');

          final overview = await tester.runAsync(
            () => layer.collections.overview(),
          );
          expect(
            overview!.unlinkedReceipts.any((row) => row.id == 'ur_2'),
            isFalse,
          );

          final card = find.byKey(const Key('unlinked-card-ur_2'));
          await tester.ensureVisible(card);
          expect(card, findsOneWidget);
          expect(
            find.descendant(
              of: card,
              matching: find.byKey(const Key('unlinked-cash-ur_2')),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text(AppStrings.cashReceived),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text('تم الرفض دون تأثير مالي'),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(find.byKey(const Key('cash-sb_2')));
          expect(find.byKey(const Key('cash-sb_2')), findsOneWidget);
          expect(
            Directionality.of(
              tester.element(find.byKey(CollectionsScreen.screenKey)),
            ),
            TextDirection.rtl,
          );
          expect(
            Theme.of(tester.element(find.byKey(CollectionsScreen.screenKey)))
                .brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
