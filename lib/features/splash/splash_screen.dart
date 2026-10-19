import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error_handling/error_handler.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  static const screenKey = Key('splash');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);
    final message = startup.hasError
        ? ref.watch(errorHandlerProvider).toFailure(startup.error!).message
        : AppStrings.loading;
    return Scaffold(
      key: screenKey,
      body: Center(child: Text(message)),
    );
  }
}
