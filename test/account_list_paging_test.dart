import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('a failed account page keeps the list and can be retried', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    final fake = layer.client as FakeApiClient;
    fake.accountNextCursor = 'page-2';
    fake.accountNextItems = [
      {'id': 'c_extra', 'name': 'صفحة ثانية', 'balanceUnits': 10, 'version': 1},
    ];
    fake.failNextAccountPageRemaining = 1;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/libyan-deposits');
    expect(find.text('صفحة ثانية'), findsNothing);

    final depositsScroll = find
        .descendant(
          of: find.byKey(const Key('screen-libyan-deposits')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
          ),
        )
        .first;
    final depositsPosition = tester
        .state<ScrollableState>(depositsScroll)
        .position;
    depositsPosition.jumpTo(depositsPosition.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.byKey(const Key('load-more-accounts')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('load-more-accounts-error')), findsOneWidget);
    expect(find.text('صفحة ثانية'), findsNothing);
    expect(find.text('عميل تجريبي'), findsOneWidget);

    await tester.tap(find.byKey(const Key('load-more-accounts')));
    await tester.pumpAndSettle();
    expect(find.text('صفحة ثانية'), findsOneWidget);
    expect(find.byKey(const Key('load-more-accounts-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
