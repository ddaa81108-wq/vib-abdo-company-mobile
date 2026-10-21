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
import '../../ui/widgets/session_expired_notice.dart';

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
    final message = failure?.message;
    final busy = login.isLoading;
    final theme = Theme.of(context);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width <= 360 ? AppSpacing.lg : AppSpacing.xxl;

    return Scaffold(
      key: LoginScreen.screenKey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              pad,
              AppSpacing.lg,
              pad,
              pad + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      key: LoginScreen.themeKey,
                      tooltip: dark
                          ? AppStrings.themeLight
                          : AppStrings.themeDark,
                      onPressed: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                      icon: Icon(
                        dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppStrings.loginTitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextField(
                              key: LoginScreen.usernameKey,
                              controller: _username,
                              enabled: !busy && online,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: AppStrings.username,
                                isDense: false,
                              ),
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
                                isDense: false,
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? AppStrings.showPassword
                                      : AppStrings.hidePassword,
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (notice != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              SessionExpiredNotice(message: notice),
                            ],
                            if (message != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                message,
                                key: LoginScreen.errorKey,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ],
                            if (!online) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppStrings.offline,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
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
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : const Text(AppStrings.signIn),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    key: LoginScreen.signupKey,
                    onPressed: () => context.push('/signup-info'),
                    child: const Text(AppStrings.createEmployee),
                  ),
                  Text(
                    AppStrings.noLanguage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
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
    ref
        .read(loginControllerProvider.notifier)
        .submit(_username.text, _password.text);
  }
}
