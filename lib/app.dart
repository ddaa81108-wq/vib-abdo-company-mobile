import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications/realtime_lifecycle.dart';
import 'security/screen_protection.dart';
import 'state/router_provider.dart';
import 'state/session_providers.dart';
import 'state/theme_controller.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';

class CompanyApp extends ConsumerWidget {
  const CompanyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(startupProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
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
      builder: (context, child) => ScreenProtection(
        child: RealtimeLifecycle(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
