import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_providers.dart';
import '../authentication/auth_gate.dart';
import '../features/accounts/account_list_screen.dart';
import '../features/accounts/ledger_screen.dart';
import '../features/collections/collections_screen.dart';
import '../features/home/home_dashboard.dart';
import '../features/home/home_shell.dart';
import '../features/login/change_password_screen.dart';
import '../features/login/login_screen.dart';
import '../features/login/signup_info_screen.dart';
import '../features/masraweya/masraweya_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/purchases/purchases_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/treasury/treasury_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(apiLayerProvider).session;
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: session.listenable,
    redirect: (context, state) => authRedirect(session.state, state.uri.path),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup-info',
        builder: (context, state) => const SignupInfoScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(blocking: true),
      ),
      GoRoute(
        path: '/account/password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeDashboard()),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/collections',
            builder: (context, state) => const CollectionsScreen(),
          ),
          GoRoute(
            path: '/masraweya',
            builder: (context, state) => const MasraweyaScreen(),
          ),
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesScreen(),
          ),
          GoRoute(
            path: '/treasury',
            builder: (context, state) => const TreasuryScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          ..._accountRoutes(AccountSection.customers),
          ..._accountRoutes(AccountSection.companies),
          ..._accountRoutes(AccountSection.libyanDeposits),
          ..._accountRoutes(AccountSection.egyptianDeposits),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

List<RouteBase> _accountRoutes(AccountSection section) => [
  GoRoute(
    path: '/${section.path}',
    builder: (context, state) => AccountListScreen(section: section),
    routes: [
      GoRoute(
        path: ':id',
        builder: (context, state) => LedgerScreen(
          section: section,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
  ),
];
