import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/common.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.blocking = false});

  final bool blocking;

  static const screenKey = Key('change-password-screen');
  static const currentKey = Key('current-password');
  static const nextKey = Key('new-password');
  static const confirmKey = Key('confirm-password');
  static const submitKey = Key('change-password-button');

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _message;
  var _saved = false;
  var _busy = false;
  var _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = online && !_busy;
    return Scaffold(
      key: ChangePasswordScreen.screenKey,
      appBar: AppBar(title: const Text(AppStrings.changePassword)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
          children: [
            if (widget.blocking)
              Text(
                AppStrings.passwordChangeRequired,
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: ChangePasswordScreen.currentKey,
              controller: _current,
              enabled: enabled,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                labelText: AppStrings.passwordCurrent,
                isDense: false,
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? AppStrings.showPassword
                      : AppStrings.hidePassword,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ChangePasswordScreen.nextKey,
              controller: _next,
              enabled: enabled,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                labelText: AppStrings.passwordNew,
                isDense: false,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ChangePasswordScreen.confirmKey,
              controller: _confirm,
              enabled: enabled,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                labelText: AppStrings.passwordConfirm,
                isDense: false,
              ),
            ),
            if (!online) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.offline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _message!,
                key: const Key('change-password-message'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _saved ? context.appColors.success : scheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: ChangePasswordScreen.submitKey,
              onPressed: enabled ? _submit : null,
              child: _busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy || !ref.read(onlineProvider)) return;
    if (_next.text.length < 10) {
      setState(() {
        _saved = false;
        _message = AppStrings.passwordTooShort;
      });
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() {
        _saved = false;
        _message = AppStrings.passwordMismatch;
      });
      return;
    }
    setState(() {
      _busy = true;
      _saved = false;
      _message = null;
    });
    try {
      await ref
          .read(apiLayerProvider)
          .session
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _message = AppStrings.savedReply;
      });
      if (!widget.blocking && context.mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saved = false;
        _message = failureText(ref.read(errorHandlerProvider).toFailure(error));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
