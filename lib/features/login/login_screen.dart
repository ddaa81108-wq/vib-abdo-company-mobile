import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/auth_gate.dart';
import '../../error_handling/error_handler.dart';
import '../../state/auth_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/session_expired_notice.dart';
import 'login_preview_045.dart';

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
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final ink = const Color(0xFF16130C);
    final cream = const Color(0xFFF8F4EC);
    final field = const Color(0xFFF1EBE0);
    final hint = const Color(0xFF4E463C);
    return Scaffold(
      key: LoginScreen.screenKey,
      backgroundColor: const Color(0xFF07111C),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: LoginWavePainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DesignCard(
                          cream: cream,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'VIB',
                                  textAlign: TextAlign.left,
                                  style: previewType(
                                    22,
                                    700,
                                    color: const Color(0xFF071525),
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'أهلًا بك',
                                  style: previewType(
                                    26,
                                    700,
                                    color: ink,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  key: LoginScreen.usernameKey,
                                  controller: _username,
                                  enabled: !busy && online,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  style: previewType(15, 600, color: ink),
                                  decoration: _fieldDecoration(
                                    'اسم المستخدم',
                                    fill: field,
                                    hintColor: hint,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        key: LoginScreen.passwordKey,
                                        controller: _password,
                                        enabled: !busy && online,
                                        obscureText: _obscure,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        onSubmitted: (_) => _submit(),
                                        style: previewType(15, 600, color: ink),
                                        decoration: _fieldDecoration(
                                          AppStrings.password,
                                          fill: field,
                                          hintColor: hint,
                                        ),
                                      ),
                                    ),
                                    IconButton(
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
                                        color: ink,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                if (notice != null) ...[
                                  const SizedBox(height: 12),
                                  SessionExpiredNotice(message: notice),
                                ],
                                if (message != null) ...[
                                  const SizedBox(height: 12),
                                  _LoginError(
                                    message: message,
                                    noticeKey: LoginScreen.errorKey,
                                  ),
                                ],
                                if (!online) ...[
                                  const SizedBox(height: 12),
                                  _LoginError(message: AppStrings.offline),
                                ],
                                const SizedBox(height: 14),
                                FilledButton(
                                  key: LoginScreen.submitKey,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF071525),
                                    foregroundColor: const Color(0xFFF6E7A8),
                                    disabledBackgroundColor: const Color(
                                      0xFF243044,
                                    ),
                                    disabledForegroundColor: const Color(
                                      0xFFD9C89A,
                                    ),
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    textStyle: previewType(16, 700),
                                  ),
                                  onPressed: busy || !online ? null : _submit,
                                  child: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFF6E7A8),
                                          ),
                                        )
                                      : const Text(AppStrings.signIn),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 4,
            start: 4,
            child: SafeArea(
              child: IconButton(
                key: LoginScreen.themeKey,
                tooltip: dark ? AppStrings.themeLight : AppStrings.themeDark,
                color: const Color(0xFFF6E7A8),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    ref
        .read(loginControllerProvider.notifier)
        .submit(_username.text, _password.text);
  }
}

InputDecoration _fieldDecoration(
  String hint, {
  required Color fill,
  required Color hintColor,
}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: previewType(14, 500, color: hintColor),
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE7AE12)),
    ),
  );
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.cream, required this.child});

  final Color cream;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cream,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(36),
        ),
        border: Border.all(color: const Color(0xFFE7AE12), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(top: 10, right: 10, child: LoginGoldCorner()),
          const Positioned(
            bottom: 10,
            left: 10,
            child: LoginGoldCorner(flip: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message, this.noticeKey});

  final String message;
  final Key? noticeKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: noticeKey,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9F1C14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: Color(0xFF9F1C14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: previewType(13, 700, color: const Color(0xFF9F1C14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
