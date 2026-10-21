import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/export_pdf_button.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('a failed account card is a full-screen error and hides writes', (
    tester,
  ) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          gate.calls++;
          if (gate.failing) {
            return AccountCardDto.fromJson({
              'id': key.$2,
              'name': 'عميل',
              'balanceUnits': '125000',
            }, key.$1);
          }
          return ref.read(apiLayerProvider).accounts.get(key.$1, key.$2);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.textContaining('غير صالحة'), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsNothing);
    expect(find.byKey(const Key('add-payment')), findsNothing);
    expect(find.byKey(const Key('full-payment')), findsNothing);

    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    expect(find.byKey(const Key('add-payment')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('a corrupt lifetime total fails the purchases screen', (
    tester,
  ) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          gate.calls++;
          if (gate.failing) {
            return PurchasesBookPage.fromData({
              'days': [],
              'lifetimeTotals': {'resultUnits': 50000, 'paidUnits': '1'},
            });
          }
          return ref
              .read(apiLayerProvider)
              .purchases
              .list(PurchaseBook.alBayan);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.textContaining('50,000'), findsNothing);
    expect(find.textContaining('47,447'), findsNothing);

    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    final lifetime = find.byKey(const Key('purchases-lifetime'));
    expect(lifetime, findsOneWidget);
    expect(
      find.descendant(of: lifetime, matching: find.textContaining('50,000')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lifetime, matching: find.textContaining('47,447')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lifetime, matching: find.textContaining('2,553')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.retry), findsNothing);
  });

  testWidgets('custom purchase item requires a free-text label', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.tap(find.byKey(const Key('add-purchase')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('purchase-kind-custom')));
    await tester.pump();
    expect(find.byKey(const Key('purchase-custom-label')), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pump();
    expect(find.text(AppStrings.customItemRequired), findsOneWidget);
    expect(fake.mutationRequestIds, isEmpty);

    await tester.enterText(
      find.byKey(const Key('purchase-custom-label')),
      'صنف خاص',
    );
    await fillLabeled(tester, AppStrings.egpValue, '10000');
    await fillLabeled(tester, AppStrings.exchangeRate, '9.5');
    await fillLabeled(tester, AppStrings.paid, '500');
    final gate = Completer<void>();
    fake.pauseMutations = gate;
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pump();
    await tester.pump(Duration.zero);
    expect(find.byKey(const Key('mutation-error')), findsNothing);
    final body = fake.lastWireBody;
    gate.complete();
    fake.pauseMutations = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));

    expect(body, contains('صنف خاص'));
    expect(body, contains('"itemCode":"custom"'));
    expect(body, isNot(contains(PurchaseItemCodes.customCaption)));
  });

  testWidgets('an open form save is disabled while offline', (tester) async {
    final link = ToggleConnectivity(true);
    await pumpFakeApp(tester, size: const Size(800, 1600), connectivity: link);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.tap(find.byKey(const Key('add-account')));
    await settle(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-account')))
          .onPressed,
      isNotNull,
    );

    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-account')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a confirm dialog stays up while the send is in flight', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    final gate = Completer<void>();
    fake.pauseMutations = gate;

    await tester.tap(find.byKey(const Key('finalize-day')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.text(AppStrings.finalizeConfirm), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-mutation')))
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text(AppStrings.finalizeConfirm), findsOneWidget);

    gate.complete();
    fake.pauseMutations = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'awaiting cash uses the muted ink colour and the contract label',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 1800));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      final label = find.byKey(const Key('awaiting-cash'));
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      expect(text.data, 'ينتظر النقد');
      final color = text.style?.color;
      final theme = Theme.of(tester.element(label));
      expect(color, theme.colorScheme.onSurfaceVariant);
      expect(color, isNot(AppStatusColors.light.unlinkedPending));
    },
  );

  testWidgets('missing platform connectivity follows the last API result', (
    tester,
  ) async {
    const channel = MethodChannel('app/connectivity');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    ApiReachability.instance.reset();
    addTearDown(ApiReachability.instance.reset);
    final port = PlatformConnectivity();
    expect(await port.current(), isTrue);
    ApiReachability.instance.recordTransportFailure();
    expect(await port.current(), isFalse);
    ApiReachability.instance.recordSuccess();
    expect(await port.current(), isTrue);
  });

  testWidgets('real mode hides PDF export', (tester) async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://staging.example.invalid',
        useFakeApi: false,
      ),
      cookieStore: InMemoryCookieStore(),
    );
    addTearDown(layer.dispose);
    layer.permissions.applyFromServer(const [], role: 'admin');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiLayerProvider.overrideWithValue(layer)],
        child: const MaterialApp(home: Scaffold(body: ExportPdfButton())),
      ),
    );
    await tester.pump();
    expect(layer.useFakeApi, isFalse);
    expect(find.byKey(const Key('export-pdf')), findsNothing);
  });

  testWidgets('a missing cash tone and a missing reason amount stay neutral', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1600),
      overrides: [
        treasuryProvider.overrideWith((ref) async {
          return TreasurySummaryDto.fromData({
            'version': 1,
            'totals': {
              'receivablesUnits': 10,
              'liabilitiesUnits': 4,
              'activeCashUnits': 8,
              'netUnits': 14,
            },
          });
        }),
        reportsProvider.overrideWith((ref) async {
          return ReportsDto.fromData({
            'items': [
              {
                'sequence': 1,
                'date': '2026-10-18',
                'netUnits': 14,
                'reasons': [
                  {'text': 'سبب بلا مبلغ'},
                ],
              },
            ],
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/treasury');
    final card = tester.widget<Card>(find.byKey(const Key('active-cash-card')));
    expect(card.color, isNull);
    expect(find.text(AppStrings.retry), findsNothing);

    await go(tester, '/reports');
    await tester.tap(find.text('2026-10-18').last);
    await settle(tester);
    expect(find.textContaining('سبب بلا مبلغ —'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });
}

class _FailGate {
  var failing = true;
  var calls = 0;
}

Future<void> fillLabeled(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.enterText(field.hitTestable(), value);
  await tester.pump();
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
