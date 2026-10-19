import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/auth_gate.dart';
import '../../error_handling/error_handler.dart';
import '../../state/auth_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const screenKey = Key('login-screen');
  static const usernameKey = Key('username-field');
  static const passwordKey = Key('password-field');
  static const submitKey = Key('login-button');
  static const errorKey = Key('login-error');
  static const themeKey = Key('login-theme');
  static const signupKey = Key('signup-link');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final login = ref.watch(loginControllerProvider);
    final session = ref.watch(sessionStateProvider);
    final online = ref.watch(onlineProvider);
    final failure = login.hasError
        ? ref.watch(errorHandlerProvider).toFailure(login.error!)
        : null;
    final notice = failure == null ? signedOutNotice(session) : null;
    final message = failure?.message ?? notice;
    final busy = login.isLoading;
    final theme = Theme.of(context);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      key: LoginScreen.screenKey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      key: LoginScreen.themeKey,
                      tooltip: dark ? AppStrings.themeLight : AppStrings.themeDark,
                      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                    ),
                  ),
                  Text(
                    AppStrings.brandMark,
                    textAlign: TextAlign.center,
                    style: cairo(40, 800, color: context.sidebarPalette.base),
                  ),
                  Text(
                    AppStrings.brandWord,
                    textAlign: TextAlign.center,
                    style: cairo(18, 800, color: context.sidebarPalette.base),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.slogan,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  TextField(
                    key: LoginScreen.usernameKey,
                    controller: _username,
                    enabled: !busy && online,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: AppStrings.username),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: LoginScreen.passwordKey,
                    controller: _password,
                    enabled: !busy && online,
                    obscureText: _obscure,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? AppStrings.showPassword : AppStrings.hidePassword,
                        onPressed: busy ? null : () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      message,
                      key: LoginScreen.errorKey,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (!online) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(AppStrings.offline, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: LoginScreen.submitKey,
                    onPressed: busy || !online ? null : _submit,
                    child: busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Text(AppStrings.signIn),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    key: LoginScreen.signupKey,
                    onPressed: () => context.push('/signup-info'),
                    child: const Text(AppStrings.createEmployee),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    ref.read(loginControllerProvider.notifier).submit(_username.text, _password.text);
  }
}
