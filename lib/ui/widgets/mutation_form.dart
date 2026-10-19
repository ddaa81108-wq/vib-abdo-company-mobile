import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../strings.dart';
import 'common.dart';

/// One request id for one open form or confirm dialog.
///
/// [metaFor] keeps that id while [inputs] is unchanged, including after a failed
/// send. A different [inputs] value, a different [expectedVersion], [succeed],
/// or a new lock starts a new id.
class SubmissionLock {
  SubmissionLock({this.expectedVersion});

  int? expectedVersion;
  MutationMeta? _meta;
  String? _inputs;
  bool busy = false;

  MutationMeta metaFor(String inputs) {
    if (_meta == null ||
        _inputs != inputs ||
        _meta!.expectedVersion != expectedVersion) {
      _meta = MutationMeta(expectedVersion: expectedVersion);
      _inputs = inputs;
    }
    return _meta!;
  }

  void succeed() {
    _meta = null;
    _inputs = null;
  }
}

/// Submit control for a write.
///
/// The request id is chosen when this control is first used and is reused until
/// the send succeeds or [inputs] / [expectedVersion] change. The button is
/// disabled, with a progress indicator, for the whole send.
class GuardedMutation extends ConsumerStatefulWidget {
  const GuardedMutation({
    required this.inputs,
    required this.onSubmit,
    required this.label,
    super.key,
    this.expectedVersion,
    this.buttonKey,
    this.allowed = true,
    this.filled = true,
    this.destructive = false,
    this.confirmText,
    this.normalizedValue,
    this.icon,
    this.tooltip,
  });

  /// Fields that define this attempt. A change starts a new request id.
  final String inputs;
  final int? expectedVersion;

  /// Null when the server accepted the send. Any other string is shown and the
  /// request id is kept for a retry of the same inputs.
  final Future<String?> Function(MutationMeta meta) onSubmit;
  final String label;
  final Key? buttonKey;
  final bool allowed;
  final bool filled;
  final bool destructive;
  final String? confirmText;

  /// Normalized amount or rate shown in the confirm dialog, when one is used.
  final String? normalizedValue;
  final IconData? icon;
  final String? tooltip;

  @override
  ConsumerState<GuardedMutation> createState() => _GuardedMutationState();
}

class _GuardedMutationState extends ConsumerState<GuardedMutation> {
  final _lock = SubmissionLock();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineProvider);
    final button = widget.icon == null
        ? GatedButton(
            buttonKey: widget.buttonKey,
            allowed: widget.allowed,
            online: online,
            busy: _lock.busy,
            filled: widget.filled,
            destructive: widget.destructive,
            label: widget.label,
            onPressed: _run,
          )
        : widget.allowed
        ? IconButton(
            key: widget.buttonKey,
            tooltip: widget.tooltip ?? widget.label,
            onPressed: online && !_lock.busy ? _run : null,
            icon: _lock.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(widget.icon),
          )
        : const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button,
        if (_error != null) Text(_error!, key: const Key('mutation-error')),
      ],
    );
  }

  Future<void> _run() async {
    if (_lock.busy) return;
    setState(() {
      _lock.busy = true;
      _error = null;
    });
    _lock.expectedVersion = widget.expectedVersion;
    final meta = _lock.metaFor(widget.inputs);
    var accepted = false;
    try {
      final error = widget.confirmText == null
          ? await widget.onSubmit(meta)
          : await _confirm(meta);
      accepted = error == null;
      if (!accepted && mounted && error.isNotEmpty) {
        setState(() => _error = error);
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = ref.read(errorHandlerProvider).toFailure(error).message,
      );
    } finally {
      if (accepted) _lock.succeed();
      if (mounted) setState(() => _lock.busy = false);
    }
  }

  /// Null when the confirmed send is accepted.
  /// An empty string when the dialog is dismissed without a successful send.
  /// Any other string is the failure message.
  Future<String?> _confirm(MutationMeta meta) async {
    final result = await showDialog<_DialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var sending = false;
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return PopScope(
              canPop: !sending,
              child: Consumer(
                builder: (dialogContext, dialogRef, _) {
                  final online = dialogRef.watch(onlineProvider);
                  final preview = widget.normalizedValue;
                  return AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.confirmText!),
                        if (preview != null && preview.isNotEmpty)
                          Text(preview, key: const Key('normalized-value')),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: sending
                            ? null
                            : () => Navigator.pop(
                                dialogContext,
                                const _DialogResult.cancel(),
                              ),
                        child: const Text(AppStrings.cancel),
                      ),
                      FilledButton(
                        key: const Key('confirm-mutation'),
                        onPressed: sending || !online
                            ? null
                            : () async {
                                setLocal(() => sending = true);
                                try {
                                  final error = await widget.onSubmit(meta);
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(
                                    dialogContext,
                                    error == null
                                        ? const _DialogResult.ok()
                                        : _DialogResult.fail(error),
                                  );
                                } catch (error) {
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(
                                    dialogContext,
                                    _DialogResult.fail(
                                      dialogRef
                                          .read(errorHandlerProvider)
                                          .toFailure(error)
                                          .message,
                                    ),
                                  );
                                }
                              },
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(AppStrings.confirm),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
    if (result == null || result.cancelled) return '';
    return result.message;
  }
}

class _DialogResult {
  const _DialogResult.ok() : message = null, cancelled = false;
  const _DialogResult.cancel() : message = null, cancelled = true;
  const _DialogResult.fail(this.message) : cancelled = false;

  final String? message;
  final bool cancelled;
}

/// Disables a write that does not carry a business request id.
class BusyAction extends StatefulWidget {
  const BusyAction({
    required this.onSubmit,
    required this.label,
    super.key,
    this.buttonKey,
    this.enabled = true,
  });

  final Future<void> Function() onSubmit;
  final String label;
  final Key? buttonKey;
  final bool enabled;

  @override
  State<BusyAction> createState() => _BusyActionState();
}

class _BusyActionState extends State<BusyAction> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: widget.buttonKey,
      onPressed: widget.enabled && !_busy ? _run : null,
      child: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.label),
    );
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
