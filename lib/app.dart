import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/notifications/foreground_notification_banner.dart';
import 'features/notifications/notification_permission_registration.dart';
import 'features/splash/splash_screen.dart';
import 'notifications/notification_transport_host.dart';
import 'notifications/realtime_lifecycle.dart';
import 'state/router_provider.dart';
import 'state/session_providers.dart';
import 'state/theme_controller.dart';
import 'state/user_scope.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';

class CompanyApp extends ConsumerWidget {
  const CompanyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);
    final themeMode = ref.watch(themeModeProvider);
    // The router is created only after restore settles. Building it while the
    // session is still unknown can miss that notification and stay on splash.
    if (!startup.hasValue) {
      return _material(themeMode: themeMode, child: const SplashScreen());
    }
    final router = ref.watch(routerProvider);
    ref.listen(sessionStateProvider, (previous, next) {
      onSessionTransition(ref, previous, next);
    });
    return _material(themeMode: themeMode, router: router);
  }

  Widget _material({
    required ThemeMode themeMode,
    Widget? child,
    GoRouter? router,
  }) {
    if (router != null) {
      return MaterialApp.router(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'LY'),
        supportedLocales: const [Locale('ar', 'LY')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: themeMode,
        routerConfig: router,
        builder: _live,
      );
    }
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'LY'),
      supportedLocales: const [Locale('ar', 'LY')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      builder: _live,
      home: child,
    );
  }
}

Widget _live(BuildContext context, Widget? page) {
  return NotificationPermissionRegistration(
    child: NotificationTransportHost(
      child: ForegroundNotificationBanner(
        child: RealtimeLifecycle(child: page ?? const SizedBox.shrink()),
      ),
    ),
  );
}
