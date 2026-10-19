import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../authentication/login_form_error.dart';
import '../error_handling/error_handler.dart';
import '../ui/strings.dart';

class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit(String username, String password) async {
    final user = username.trim();
    if (user.isEmpty || password.isEmpty) {
      state = AsyncError(
        const LoginFormError(AppStrings.emptyCredentials),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    try {
      await ref
          .read(apiLayerProvider)
          .session
          .login(username: user, password: password);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      ref.read(errorHandlerProvider).report(error, stackTrace);
      state = AsyncError(error, stackTrace);
    }
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);
