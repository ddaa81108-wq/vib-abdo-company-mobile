import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

/// P7-19. Socket loss is simulated on the real Dio stack. Connectivity is also
/// flipped to none during the in-flight call. An on-device airplane-mode pass
/// is still manual.
void main() {
  testWidgets(
    'P7-19 a read that loses the connection keeps the list and the draft',
    (tester) async {
      final transport = _ScreenTransport();
      final connectivity = ToggleConnectivity(true);
      final layer = await _layer(transport);
      await tester.runAsync(
        () => layer.session.login(username: 'admin', password: 'demo-only'),
      );
      addTearDown(layer.dispose);
      await _pumpList(tester, layer, connectivity);

      expect(find.text('زبون القراءة'), findsWidgets);
      await tester.enterText(find.byKey(const Key('account-search')), 'مسودة بحث');
      await tester.pump();

      final seen = transport.calls.length;
      final hold = Completer<void>();
      transport.hold = hold.future;
      transport.holdPath = ApiEndpoints.accounts('customers');
      transport.releaseHoldAsConnectionError = true;
      await tester.testTextInput.receiveAction(TextInputAction.search);
      for (var turn = 0; turn < 10 && transport.calls.length == seen; turn++) {
        await tester.pump(Duration.zero);
      }
      expect(transport.calls.length, greaterThan(seen));
      connectivity.setOnline(false);
      await tester.pump();
      hold.complete();
      await tester.pump();
      // GET retries use the real backoff. The clock advances; nothing sleeps.
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('زبون القراءة'), findsWidgets);
      expect(find.text(const NetworkException().message), findsWidgets);
      expect(find.text('مسودة بحث'), findsWidgets);
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('demo-only'), findsNothing);
      expect(find.text(AppStrings.offline), findsWidgets);
    },
  );

  testWidgets(
    'P7-19 a write that loses the connection keeps the form and does not commit',
    (tester) async {
      final transport = _ScreenTransport();
      final connectivity = ToggleConnectivity(true);
      final layer = await _layer(transport);
      await tester.runAsync(
        () => layer.session.login(username: 'admin', password: 'demo-only'),
      );
      addTearDown(layer.dispose);
      await _pumpList(tester, layer, connectivity);

      await tester.tap(find.byKey(const Key('add-account')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('create-name')), 'مسودة زبون');
      await tester.pump();

      final hold = Completer<void>();
      transport.hold = hold.future;
      transport.holdPath = ApiEndpoints.accounts('customers');
      transport.releaseHoldAsConnectionError = true;
      await tester.tap(find.byKey(const Key('save-account')));
      await tester.pump();
      expect(find.text('مسودة زبون'), findsWidgets);
      connectivity.setOnline(false);
      await tester.pump();
      hold.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('مسودة زبون'), findsWidgets);
      expect(find.text(const NetworkException().message), findsWidgets);
      expect(find.textContaining('demo-only'), findsNothing);
      expect(find.textContaining('DioException'), findsNothing);
      final posts = transport.calls.where(
        (call) =>
            call.method == 'POST' && call.path == ApiEndpoints.accounts('customers'),
      );
      expect(posts, hasLength(1));
      expect(find.text('زبون القراءة'), findsWidgets);
    },
  );
}

Future<ApiLayer> _layer(_ScreenTransport transport) {
  return Future.value(
    ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://api.example.invalid',
        useFakeApi: false,
      ),
      cookieStore: InMemoryCookieStore(),
      tokenStorage: InMemoryTokenStorage(),
      httpClientAdapter: transport,
    ),
  );
}

Future<void> _pumpList(
  WidgetTester tester,
  ApiLayer layer,
  ToggleConnectivity connectivity,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        connectivityPortProvider.overrideWithValue(connectivity),
      ],
      child: const _CustomersShell(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Real [HomeShell] so the production offline banner is on screen. The shell
/// is what shows [AppStrings.offline]. SSE is not started.
class _CustomersShell extends StatefulWidget {
  const _CustomersShell();

  @override
  State<_CustomersShell> createState() => _CustomersShellState();
}

class _CustomersShellState extends State<_CustomersShell> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/customers',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/customers',
            builder: (context, state) =>
                const AccountListScreen(section: AccountSection.customers),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(theme: buildAppTheme(), routerConfig: _router);
  }
}

class _Call {
  _Call(this.method, this.path);
  final String method;
  final String path;
}

class _ScreenTransport implements HttpClientAdapter {
  final List<_Call> calls = [];
  Future<void>? hold;
  String? holdPath;
  bool releaseHoldAsConnectionError = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.isEmpty ? options.path : options.uri.path;
    calls.add(_Call(options.method.toUpperCase(), path));
    if (hold != null && holdPath == path) {
      await hold;
      if (releaseHoldAsConnectionError) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'simulated-offline',
        );
      }
    }
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: ['application/json'],
    };
    if (path == ApiEndpoints.login) {
      headers['set-cookie'] = [
        '${ApiConfig.sessionCookieName}=phase7-session; Path=/; HttpOnly; Secure; SameSite=Strict',
      ];
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': _data(path, options.method)}),
      200,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}

  Object? _data(String path, String method) {
    const user = {
      'id': 'u_1',
      'username': 'admin@example.invalid',
      'displayName': 'مدير تجريبي',
      'role': 'admin',
      'permissions': <String>[],
      'mustChangePassword': false,
    };
    if (path == ApiEndpoints.login) {
      return {'user': user, 'csrfToken': 'csrf-phase7'};
    }
    if (path == ApiEndpoints.me) return {'user': user};
    if (path == ApiEndpoints.proposedHome) {
      return {
        'businessDate': '2026-10-21',
        'summaries': [
          {
            'key': 'customers.net',
            'section': 'customers',
            'title': 'ديون',
            'valueUnits': 1500,
            'currency': 'LYD',
          },
        ],
      };
    }
    if (path.endsWith('/suggestions')) return {'items': <Object>[]};
    if (path == ApiEndpoints.accounts('customers') && method == 'GET') {
      return {
        'items': [
          {
            'id': 'c1',
            'name': 'زبون القراءة',
            'balanceUnits': 1500,
            'currency': 'LYD',
            'version': 4,
          },
        ],
        'totalItems': 1,
        'summary': {'netBalanceUnits': 1500, 'totalDebtUnits': 1500},
      };
    }
    return {'id': 'ack-1', 'version': 5};
  }
}
