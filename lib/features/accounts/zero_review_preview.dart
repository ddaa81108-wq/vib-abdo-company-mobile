import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';

/// Preview of one zero card. Confirm is the only action that calls the server.
class ZeroReviewPreview extends ConsumerStatefulWidget {
  const ZeroReviewPreview({
    required this.name,
    required this.balance,
    required this.financialVersion,
    required this.onConfirm,
    super.key,
  });

  final String name;
  final String balance;

  /// Null when the card has no financial version. Confirm stays closed.
  final int? financialVersion;

  /// Null when the review must not be sent. Returns a message to keep open.
  final Future<String?> Function()? onConfirm;

  static const dialogKey = Key('zero-preview');
  static const confirmKey = Key('zero-preview-confirm');
  static const cancelKey = Key('zero-preview-cancel');
  static const errorKey = Key('zero-preview-error');

  @override
  ConsumerState<ZeroReviewPreview> createState() => _ZeroReviewPreviewState();
}

class _ZeroReviewPreviewState extends ConsumerState<ZeroReviewPreview> {
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gold = sectionGold(context);
    final online = ref.watch(onlineProvider);
    final canConfirm = widget.onConfirm != null && online && !_busy;
    return AlertDialog(
      key: ZeroReviewPreview.dialogKey,
      title: const Text('معاينة الكارت الصفري'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: cairo(16, 800)),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: MoneyText(widget.balance),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.financialVersion == null
                  ? 'لا يوجد إصدار مالي. لا يمكن إرسال المراجعة.'
                  : 'الإصدار المالي: ${widget.financialVersion}',
              key: const Key('zero-preview-version'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'المعاينة لا تغيّر الرصيد. الاعتماد يرسل مراجعة التصفير فقط.',
              style: cairo(12, 600, color: scheme.onSurfaceVariant),
            ),
            if (!online)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                child: Text(
                  AppStrings.offline,
                  style: cairo(13, 700, color: scheme.error),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  key: ZeroReviewPreview.errorKey,
                  style: cairo(13, 700, color: scheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ZeroReviewPreview.cancelKey,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          key: ZeroReviewPreview.confirmKey,
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF1A1300),
            minimumSize: const Size(48, 48),
          ),
          onPressed: canConfirm ? _confirm : null,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('اعتماد المراجعة'),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final send = widget.onConfirm;
    if (send == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await send();
      if (!mounted) return;
      if (message == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
