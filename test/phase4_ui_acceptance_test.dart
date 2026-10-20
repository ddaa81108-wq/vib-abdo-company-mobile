import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

/// Evidence capture for the phase-4 UI acceptance review.
///
/// Product defects are recorded in `test/goldens/phase4/observations.json`.
/// They do not fail this test: `tool/check.sh` must stay green while the
/// acceptance document classifies the findings. Golden files are the screenshots.
void main() {
  final cells = <Map<String, Object?>>[];
  final overflows = <String>[];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final cairo = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-ExtraBold.ttf'));
    await cairo.load();
    await mono.load();
  });

  tearDownAll(() {
    final file = File('test/goldens/phase4/observations.json');
    file.parent.createSync(recursive: true);
    final payload = <String, Object?>{
      'tool': 'test/phase4_ui_acceptance_test.dart',
      'api': 'fake',
      'password': 'demo-only',
      'accounts': _accounts,
      'cells': cells,
    };
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  });

  setUp(() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (_isLayoutFault(message)) {
        final line = message.split('\n').first.trim();
        if (!overflows.contains(line)) overflows.add(line);
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  });

  testWidgets('login screen per theme and size', (tester) async {
    await pumpFakeApp(tester, size: _sizes.first);
    for (final brightness in _brightnesses) {
      await _ensureTheme(tester, brightness);
      for (final size in _sizes) {
        await _capture(
          tester,
          cells: cells,
          overflows: overflows,
          screen: 'login',
          role: 'anonymous',
          brightness: brightness,
          size: size,
          signedIn: false,
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  for (final role in _roleOrder) {
    testWidgets('signed-in surfaces for $role', (tester) async {
      await pumpFakeApp(tester, size: const Size(412, 915));
      await signIn(tester, username: _accounts[role]!, password: 'demo-only');
      for (final brightness in _brightnesses) {
        _setSurface(tester, const Size(412, 915));
        await tester.pump();
        await _settle(tester, overflows);
        await _ensureTheme(tester, brightness);
        for (final size in _sizes) {
          for (final screen in _signedInScreens) {
            await _capture(
              tester,
              cells: cells,
              overflows: overflows,
              screen: screen,
              role: role,
              brightness: brightness,
              size: size,
              signedIn: true,
            );
          }
        }
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}

const _roleOrder = ['admin', 'limited.admin', 'employee', 'guest'];

const _accounts = {
  'admin': 'admin.demo',
  'limited.admin': 'limited.admin',
  'employee': 'employee.demo',
  'guest': 'guest.demo',
};

const _brightnesses = [Brightness.light, Brightness.dark];

const _sizes = [Size(360, 640), Size(412, 915), Size(800, 1280)];

const _signedInScreens = [
  'home',
  'menu',
  'customers',
  'companies',
  'customer-ledger',
  'company-ledger',
  'libyan-deposits',
  'egyptian-deposits',
  'purchases',
  'collections',
  'treasury',
  'reports',
  'settings',
  'account',
  'notifications',
];

const _paths = {
  'home': '/',
  'menu': '/',
  'customers': '/customers',
  'companies': '/companies',
  'customer-ledger': '/customers/c_55',
  'company-ledger': '/companies/c_55',
  'libyan-deposits': '/libyan-deposits',
  'egyptian-deposits': '/egyptian-deposits',
  'purchases': '/purchases',
  'collections': '/collections',
  'treasury': '/treasury',
  'reports': '/reports',
  'settings': '/settings',
  'account': '/account',
  'notifications': '/notifications',
};

const _screenKeys = {
  'home': 'home-dashboard',
  'menu': 'home-dashboard',
  'customers': 'screen-customers',
  'companies': 'screen-companies',
  'customer-ledger': 'screen-ledger-customers',
  'company-ledger': 'screen-ledger-companies',
  'libyan-deposits': 'screen-libyan-deposits',
  'egyptian-deposits': 'screen-egyptian-deposits',
  'purchases': 'screen-purchases',
  'collections': 'screen-collections',
  'treasury': 'screen-treasury',
  'reports': 'screen-reports',
  'settings': 'screen-settings',
  'account': 'screen-account',
  'notifications': 'screen-notifications',
};

const _watched = [
  'add-account',
  'assign-mode',
  'zero-review',
  'pin-c_55',
  'add-debt',
  'add-payment',
  'full-payment',
  'cancel-tx_1',
  'cancel-tx_2',
  'save-rate',
  'add-purchase',
  'finalize-day',
  'edit-pe_1',
  'delete-pe_1',
  'cash-in',
  'cash-out',
  'approve-sb_1',
  'reject-sb_1',
  'cash-sb_2',
  'close-batch',
  'unlinked-collection',
  'submit-as_1',
  'unlinked-approve-ur_1',
  'unlinked-link-ur_1',
  'export-pdf',
  'financial-ledger',
  'section-customers',
  'section-collections',
  'section-companies',
  'section-libyan-deposits',
  'section-egyptian-deposits',
  'section-masraweya',
  'section-purchases',
  'section-treasury',
  'section-reports',
  'write-customers',
  'write-collections',
  'write-companies',
  'write-libyan-deposits',
  'write-egyptian-deposits',
  'write-masraweya',
  'write-purchases',
  'write-treasury',
  'write-reports',
  'action-collections.assign',
  'action-collections.decide',
  'action-collections.cash_receive',
  'action-collections.close_day',
  'action-payroll.manage',
  'action-debts.zero_review',
  'action-users.manage',
  'action-settings.manage',
];

const _adminSections = {
  'section-customers',
  'section-collections',
  'section-companies',
  'section-libyan-deposits',
  'section-egyptian-deposits',
  'section-masraweya',
  'section-purchases',
  'section-treasury',
  'section-reports',
};

const _adminWrites = {
  'write-customers',
  'write-collections',
  'write-companies',
  'write-libyan-deposits',
  'write-egyptian-deposits',
  'write-masraweya',
  'write-purchases',
  'write-treasury',
};

const _adminActions = {
  'action-collections.assign',
  'action-collections.decide',
  'action-collections.cash_receive',
  'action-collections.close_day',
  'action-payroll.manage',
  'action-debts.zero_review',
  'action-users.manage',
  'action-settings.manage',
};

bool _isLayoutFault(String message) {
  return message.contains('overflowed') ||
      message.contains('unbounded') ||
      message.contains('RenderFlex') ||
      message.contains('not laid out') ||
      message.contains('Incorrect use of ParentData') ||
      message.contains('A RenderViewport');
}

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> _settle(WidgetTester tester, List<String> overflows) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );
  } on FlutterError catch (error) {
    final line = error.message.split('\n').first.trim();
    if (!overflows.contains(line)) overflows.add(line);
    await tester.pump();
  }
}

Future<void> _closeDrawer(WidgetTester tester, List<String> overflows) async {
  final shell = find.byKey(HomeShell.shellKey);
  if (shell.evaluate().isEmpty) return;
  final state = tester.state<ScaffoldState>(shell);
  if (!state.isDrawerOpen) return;
  state.closeDrawer();
  await _settle(tester, overflows);
}

Future<void> _go(
  WidgetTester tester,
  String path,
  List<String> overflows,
) async {
  await _closeDrawer(tester, overflows);
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await _settle(tester, overflows);
}

Brightness _brightnessOf(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
}

Future<void> _ensureTheme(WidgetTester tester, Brightness target) async {
  if (find.byType(Scaffold).evaluate().isEmpty) {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );
  }
  if (_brightnessOf(tester) == target) return;
  final loginTheme = find.byKey(LoginScreen.themeKey);
  if (loginTheme.evaluate().isNotEmpty) {
    await tester.ensureVisible(loginTheme);
    await tester.tap(loginTheme);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 8),
    );
    return;
  }
  await _go(tester, '/account', <String>[]);
  final toggle = find.byKey(const Key('theme-switch'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
}

Future<void> _capture(
  WidgetTester tester, {
  required List<Map<String, Object?>> cells,
  required List<String> overflows,
  required String screen,
  required String role,
  required Brightness brightness,
  required Size size,
  required bool signedIn,
}) async {
  overflows.clear();
  _setSurface(tester, size);
  await tester.pump();
  Object? navigationError;
  if (signedIn) {
    try {
      await _go(tester, _paths[screen]!, overflows);
      if (screen == 'menu' && size.width <= 560) {
        final state = tester.state<ScaffoldState>(
          find.byKey(HomeShell.shellKey),
        );
        if (!state.isDrawerOpen) {
          await tester.tap(find.byKey(HomeShell.menuKey));
          await _settle(tester, overflows);
        }
      }
    } catch (error) {
      navigationError = error;
    }
  } else {
    await _settle(tester, overflows);
  }

  final taken = <String>[];
  Object? pending;
  while ((pending = tester.takeException()) != null) {
    final line = pending.toString().split('\n').first.trim();
    if (!taken.contains(line)) taken.add(line);
  }

  final themeName = brightness == Brightness.dark ? 'dark' : 'light';
  final sizeName = '${size.width.toInt()}x${size.height.toInt()}';
  final fileName =
      '$screen'
      '__${themeName}__${sizeName}__$role.png';
  await expectLater(
    find.byType(CompanyApp),
    matchesGoldenFile('goldens/phase4/$fileName'),
  );

  final context = tester.element(find.byType(Scaffold).first);
  final theme = Theme.of(context);
  final direction = Directionality.of(context);
  final expectedPrimary = brightness == Brightness.dark
      ? const Color(0xFF247763)
      : const Color(0xFF175F50);
  final screenKey = _screenKeys[screen];
  final keyVisible =
      screenKey != null && find.byKey(Key(screenKey)).evaluate().isNotEmpty;
  final homeVisible = find.byKey(HomeDashboard.screenKey).evaluate().isNotEmpty;
  final redirected =
      signedIn &&
      screen != 'home' &&
      screen != 'menu' &&
      !keyVisible &&
      homeVisible;
  final surface = redirected ? 'home' : screen;
  final gate = _gate(role, surface);
  final present = [
    for (final key in _watched)
      if (find.byKey(Key(key)).evaluate().isNotEmpty) key,
  ];
  final forbidden = [
    for (final key in present)
      if (!gate.allow.contains(key)) key,
  ];
  final missing = redirected
      ? const <String>[]
      : [
          for (final key in gate.require)
            if (!present.contains(key)) key,
        ];
  final mayOpen = _mayOpen(role, screen);
  final latin = _latinOnly(tester);

  double? drawerRight;
  var drawerOnStart = false;
  if (find.byType(Drawer).evaluate().isNotEmpty) {
    final rect = tester.getRect(find.byType(Drawer));
    drawerRight = rect.right;
    drawerOnStart = (rect.right - size.width).abs() < 1.5 && rect.left > 0;
  }

  String? roleLabel;
  if (find.byKey(HomeShell.roleKey).evaluate().isNotEmpty) {
    roleLabel = tester.widget<Text>(find.byKey(HomeShell.roleKey)).data;
  }

  Map<String, Object?>? probe;
  if (role == 'admin' && size == const Size(412, 915)) {
    probe = _probe(tester, screen, brightness);
  }

  cells.add({
    'screen': screen,
    'role': role,
    'theme': themeName,
    'size': sizeName,
    'golden': 'test/goldens/phase4/$fileName',
    'method': navigationError == null ? 'widget-golden' : 'widget-golden+error',
    'rtl': direction == TextDirection.rtl,
    'brightness': theme.brightness.name,
    'brightnessMatches': theme.brightness == brightness,
    'fontFamily': theme.textTheme.bodyMedium?.fontFamily,
    'fontOk': theme.textTheme.bodyMedium?.fontFamily == 'Cairo',
    'primary': _hex(theme.colorScheme.primary),
    'brandPrimaryOk': theme.colorScheme.primary == expectedPrimary,
    'overflows': [...overflows],
    'takenExceptions': taken,
    'navigationError': navigationError?.toString().split('\n').first,
    'screenKeyVisible': keyVisible,
    'redirectedToHome': redirected,
    'mayOpen': mayOpen,
    'unexpectedRedirect': mayOpen && redirected,
    'shouldHaveRedirected':
        !mayOpen &&
        !redirected &&
        signedIn &&
        screen != 'home' &&
        screen != 'menu',
    'forbiddenPresent': forbidden,
    'missingRequired': missing,
    'settingsLabel': find.text(AppStrings.settings).evaluate().isNotEmpty,
    'accountLabel': find.text(AppStrings.myAccount).evaluate().isNotEmpty,
    'noSectionsText': find.text(AppStrings.noSections).evaluate().isNotEmpty,
    'forbiddenPane': find
        .byKey(const Key('forbidden-pane'))
        .evaluate()
        .isNotEmpty,
    'roleLabel': roleLabel,
    'drawerOnStart': find.byType(Drawer).evaluate().isEmpty
        ? null
        : drawerOnStart,
    'drawerRight': drawerRight,
    'hasRail': find.byType(NavigationRail).evaluate().isNotEmpty,
    'hasBottomBar': find.byType(NavigationBar).evaluate().isNotEmpty,
    'hasDrawer': find.byType(Drawer).evaluate().isNotEmpty,
    'latinOnly': latin,
    if (probe != null && probe.isNotEmpty) 'probe': probe,
  });
}

class _Gate {
  const _Gate({this.allow = const {}, this.require = const {}});

  final Set<String> allow;
  final Set<String> require;
}

bool _mayOpen(String role, String screen) {
  if (screen == 'login') return true;
  const shared = {'home', 'menu', 'account', 'notifications'};
  if (shared.contains(screen)) return true;
  if (role == 'admin') return true;
  if (role == 'limited.admin' || role == 'employee') {
    return screen == 'customers' ||
        screen == 'customer-ledger' ||
        screen == 'collections';
  }
  return false;
}

_Gate _gate(String role, String surface) {
  if (surface == 'login') return const _Gate();
  if (surface == 'home' || surface == 'menu') return _homeGate(role);
  if (surface == 'account' || surface == 'notifications') return const _Gate();
  return switch (role) {
    'admin' => _adminSurface(surface),
    'limited.admin' => _readerSurface(surface, decide: true),
    'employee' => _readerSurface(surface, decide: false),
    _ => const _Gate(),
  };
}

_Gate _homeGate(String role) {
  return switch (role) {
    'admin' => _Gate(
      allow: {..._adminSections, ..._adminWrites, ..._adminActions},
      require: {..._adminSections, ..._adminWrites, ..._adminActions},
    ),
    'limited.admin' => const _Gate(
      allow: {
        'section-customers',
        'section-collections',
        'write-collections',
        'action-collections.decide',
      },
      require: {
        'section-customers',
        'section-collections',
        'write-collections',
        'action-collections.decide',
      },
    ),
    'employee' => const _Gate(
      allow: {'section-customers', 'section-collections', 'write-collections'},
      require: {
        'section-customers',
        'section-collections',
        'write-collections',
      },
    ),
    _ => const _Gate(),
  };
}

_Gate _adminSurface(String surface) {
  const ledger = _Gate(
    allow: {
      'add-debt',
      'add-payment',
      'full-payment',
      'cancel-tx_1',
      'cancel-tx_2',
    },
    require: {
      'add-debt',
      'add-payment',
      'full-payment',
      'cancel-tx_1',
      'cancel-tx_2',
    },
  );
  return switch (surface) {
    'customers' => const _Gate(
      allow: {'add-account', 'assign-mode', 'pin-c_55', 'zero-review'},
      require: {'add-account', 'assign-mode', 'pin-c_55', 'zero-review'},
    ),
    'companies' => const _Gate(
      allow: {'add-account', 'assign-mode', 'pin-c_55'},
      require: {'add-account', 'assign-mode', 'pin-c_55'},
    ),
    'customer-ledger' || 'company-ledger' => ledger,
    'libyan-deposits' => const _Gate(
      allow: {'add-account', 'pin-c_55'},
      require: {'add-account', 'pin-c_55'},
    ),
    'egyptian-deposits' => const _Gate(
      allow: {'add-account', 'pin-c_55', 'save-rate'},
      require: {'add-account', 'pin-c_55', 'save-rate'},
    ),
    'purchases' => const _Gate(
      allow: {'add-purchase', 'finalize-day', 'edit-pe_1', 'delete-pe_1'},
      require: {'add-purchase', 'finalize-day', 'edit-pe_1', 'delete-pe_1'},
    ),
    'collections' => const _Gate(
      allow: {
        'submit-as_1',
        'unlinked-collection',
        'approve-sb_1',
        'reject-sb_1',
        'cash-sb_2',
        'close-batch',
        'unlinked-approve-ur_1',
        'unlinked-link-ur_1',
      },
      require: {
        'submit-as_1',
        'unlinked-collection',
        'approve-sb_1',
        'reject-sb_1',
        'cash-sb_2',
        'close-batch',
        'unlinked-approve-ur_1',
        'unlinked-link-ur_1',
      },
    ),
    'treasury' => const _Gate(
      allow: {'cash-in', 'cash-out'},
      require: {'cash-in', 'cash-out'},
    ),
    'reports' => const _Gate(allow: {'export-pdf'}, require: {'export-pdf'}),
    'settings' => const _Gate(
      allow: {'financial-ledger', 'export-pdf'},
      require: {'financial-ledger', 'export-pdf'},
    ),
    _ => const _Gate(),
  };
}

_Gate _readerSurface(String surface, {required bool decide}) {
  if (surface == 'customers' || surface == 'customer-ledger') {
    return const _Gate();
  }
  if (surface == 'collections') {
    if (decide) {
      return const _Gate(
        allow: {
          'submit-as_1',
          'unlinked-collection',
          'approve-sb_1',
          'reject-sb_1',
          'unlinked-approve-ur_1',
          'unlinked-link-ur_1',
        },
        require: {
          'submit-as_1',
          'unlinked-collection',
          'approve-sb_1',
          'reject-sb_1',
          'unlinked-approve-ur_1',
          'unlinked-link-ur_1',
        },
      );
    }
    return const _Gate(
      allow: {'submit-as_1', 'unlinked-collection'},
      require: {'submit-as_1', 'unlinked-collection'},
    );
  }
  return const _Gate();
}

List<String> _latinOnly(WidgetTester tester) {
  final found = <String>{};
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data == null || data.trim().isEmpty) continue;
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(data);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(data);
    if (hasLatin && !hasArabic) found.add(data.trim());
  }
  final sorted = found.toList()..sort();
  if (sorted.length <= 24) return sorted;
  return [...sorted.take(24), '…${sorted.length - 24} more'];
}

Map<String, Object?> _probe(
  WidgetTester tester,
  String screen,
  Brightness brightness,
) {
  final probe = <String, Object?>{};
  if (screen == 'customers' ||
      screen == 'companies' ||
      screen == 'libyan-deposits' ||
      screen == 'egyptian-deposits' ||
      screen == 'home') {
    final gradients = <List<String>>[];
    for (final element in find.byType(Ink).evaluate()) {
      final decoration = (element.widget as Ink).decoration;
      if (decoration is BoxDecoration &&
          decoration.gradient is LinearGradient) {
        final gradient = decoration.gradient! as LinearGradient;
        gradients.add([for (final color in gradient.colors) _hex(color)]);
      }
    }
    probe['gradients'] = gradients;
  }
  if (screen == 'customer-ledger' || screen == 'company-ledger') {
    probe['backIconMatchesDirection'] = _backIconMatchesDirection(tester);
    probe['ledgerMoney'] = _ledgerMoney(tester);
  }
  if (screen == 'home') {
    probe['summaryMoney'] = _moneyByKey(tester, const [
      'summary-customers.netBalance',
      'summary-collections.collected',
      'summary-egyptianDeposits.netBalance',
      'summary-treasury.activeCash',
    ]);
    probe['oldDebtHasGradient'] = _elementHasGradient(
      tester,
      find.byKey(const Key('old-debt-c_55')),
    );
  }
  if (screen == 'treasury') {
    probe['cashInIcon'] = _iconColor(tester, Icons.arrow_downward);
    probe['cashOutIcon'] = _iconColor(tester, Icons.arrow_upward);
    final cashCard = find.byKey(const Key('active-cash-card'));
    if (cashCard.evaluate().isNotEmpty) {
      probe['activeCashCard'] = _hex(tester.widget<Card>(cashCard).color);
    }
  }
  if (screen == 'reports') {
    final chip = find.byKey(const Key('report-chip-normal'));
    probe['reportChipCount'] = chip.evaluate().length;
    if (chip.evaluate().isNotEmpty) {
      final widget = chip.evaluate().first.widget;
      if (widget is Container && widget.decoration is BoxDecoration) {
        probe['reportChipNormal'] = _hex(
          (widget.decoration! as BoxDecoration).color,
        );
      }
    }
  }
  probe['theme'] = brightness.name;
  return probe;
}

bool? _backIconMatchesDirection(WidgetTester tester) {
  final icon = find.byIcon(Icons.arrow_back);
  if (icon.evaluate().isEmpty) return null;
  return tester.widget<Icon>(icon.first).icon?.matchTextDirection;
}

List<Map<String, Object?>> _ledgerMoney(WidgetTester tester) {
  final rows = <Map<String, Object?>>[];
  for (final element in find.byType(Card).evaluate()) {
    final texts = <String>[];
    final money = <String>[];
    void walk(Element node) {
      final widget = node.widget;
      if (widget is Text && widget.data != null) {
        texts.add(widget.data!);
        if (widget.style?.fontFamily == 'JetBrainsMono') {
          money.add(_hex(widget.style?.color));
        }
      }
      node.visitChildElements(walk);
    }

    walk(element);
    if (texts.contains('دين') ||
        texts.contains('سداد جزئي') ||
        texts.contains('سداد')) {
      rows.add({'texts': texts, 'moneyColors': money});
    }
  }
  return rows;
}

Map<String, String> _moneyByKey(WidgetTester tester, List<String> keys) {
  final result = <String, String>{};
  for (final key in keys) {
    final card = find.byKey(Key(key));
    if (card.evaluate().isEmpty) continue;
    String? color;
    void walk(Element node) {
      final widget = node.widget;
      if (color == null &&
          widget is Text &&
          widget.style?.fontFamily == 'JetBrainsMono') {
        color = _hex(widget.style?.color);
      }
      node.visitChildElements(walk);
    }

    walk(card.evaluate().first);
    if (color != null) result[key] = color!;
  }
  return result;
}

bool _elementHasGradient(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  var found = false;
  void walk(Element node) {
    final widget = node.widget;
    if (widget is Ink && widget.decoration is BoxDecoration) {
      final decoration = widget.decoration! as BoxDecoration;
      if (decoration.gradient != null) found = true;
    }
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      final decoration = widget.decoration as BoxDecoration;
      if (decoration.gradient != null) found = true;
    }
    node.visitChildElements(walk);
  }

  walk(finder.evaluate().first);
  return found;
}

String? _iconColor(WidgetTester tester, IconData icon) {
  final finder = find.byIcon(icon);
  if (finder.evaluate().isEmpty) return null;
  return _hex(tester.widget<Icon>(finder.first).color);
}

String _hex(Color? color) {
  if (color == null) return 'null';
  return color.toARGB32().toRadixString(16).padLeft(8, '0');
}
