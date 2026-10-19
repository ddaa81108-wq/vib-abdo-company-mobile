import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_providers.dart';
import '../authentication/auth_gate.dart';
import '../features/home/home_shell.dart';
import '../features/login/login_screen.dart';
import '../features/splash/splash_screen.dart';

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
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
