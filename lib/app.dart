import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications/realtime_lifecycle.dart';
import 'state/router_provider.dart';
import 'state/session_providers.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';

class CompanyApp extends ConsumerWidget {
  const CompanyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(startupProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) =>
          RealtimeLifecycle(child: child ?? const SizedBox.shrink()),
    );
  }
}
