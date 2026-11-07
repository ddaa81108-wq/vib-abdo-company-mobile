import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';

/// Code entry after `MFA_REQUIRED`. The challenge is not a signed-in session.
class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  static const screenKey = Key('mfa-screen');
  static const codeKey = Key('mfa-code');
  static const submitKey = Key('mfa-submit');
  static const cancelKey = Key('mfa-cancel');
  static const errorKey = Key('mfa-error');

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  final _code = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width <= 360 ? AppSpacing.lg : AppSpacing.xxl;
    return Scaffold(
      key: MfaScreen.screenKey,
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
                      key: const Key('mfa-theme'),
                      tooltip: dark ? AppStrings.themeLight : AppStrings.themeDark,
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
                    style: cairo(32, 800, color: context.sidebarPalette.base),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'رمز التحقق',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'الخادم طلب رمزًا لإكمال الدخول. لم تُفتح الجلسة بعد، ولا تُحمَّل الصلاحيات قبل نجاح الرمز.',
                            key: Key('mfa-not-signed-in'),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            key: MfaScreen.codeKey,
                            controller: _code,
                            enabled: !_busy,
                            obscureText: true,
                            keyboardType: TextInputType.text,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'الرمز',
                              isDense: false,
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _error!,
                              key: MfaScreen.errorKey,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            key: MfaScreen.submitKey,
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('تأكيد'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    key: MfaScreen.cancelKey,
                    onPressed: _busy ? null : _cancel,
                    child: const Text(AppStrings.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'أدخل الرمز');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiLayerProvider).session.verifyMfa(code);
      _code.clear();
    } catch (error) {
      _code.clear();
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    _code.clear();
    await ref.read(apiLayerProvider).session.cancelMfa();
  }
}
