import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../ui/strings.dart';
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
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _message;
  var _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ChangePasswordScreen.screenKey,
      appBar: AppBar(title: const Text(AppStrings.changePassword)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
          children: [
            if (widget.blocking) const Text(AppStrings.passwordChangeRequired),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: ChangePasswordScreen.currentKey,
              controller: _current,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.passwordCurrent),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ChangePasswordScreen.nextKey,
              controller: _next,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.passwordNew),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ChangePasswordScreen.confirmKey,
              controller: _confirm,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.passwordConfirm),
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(_message!, key: const Key('change-password-message')),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: ChangePasswordScreen.submitKey,
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_next.text.length < 10) {
      setState(() => _message = AppStrings.passwordTooShort);
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _message = AppStrings.passwordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(apiLayerProvider).session.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      setState(() => _message = AppStrings.savedReply);
      if (!widget.blocking && context.mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = ref.read(errorHandlerProvider).toFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
