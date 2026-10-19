import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../presentation.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(this.text, {super.key, this.style, this.maxLines = 1});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final extras = context.textExtras;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: true,
        style: (style ?? extras.amount).copyWith(fontFamily: 'JetBrainsMono'),
      ),
    );
  }
}

class LtrText extends StatelessWidget {
  const LtrText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(text, style: style),
    );
  }
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({
    required this.message,
    required this.onRetry,
    super.key,
    this.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                key: retryKey,
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({required this.message, super.key, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
        ],
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 112, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    );
  }
}

class ForbiddenPane extends StatelessWidget {
  const ForbiddenPane({super.key});

  static const paneKey = Key('forbidden-pane');

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: paneKey,
      child: Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.xxl),
        child: Text(AppStrings.forbidden, textAlign: TextAlign.center),
      ),
    );
  }
}

class ServerReplyText extends StatelessWidget {
  const ServerReplyText(this.ack, {super.key});

  final MutationAck? ack;

  @override
  Widget build(BuildContext context) {
    if (ack == null) return const SizedBox.shrink();
    final id = ack!.id;
    final version = ack!.version;
    final parts = <String>[
      AppStrings.serverReply,
      ?id,
      ?version?.toString(),
    ];
    return Text(parts.join(' · '), key: const Key('server-reply'));
  }
}

/// Hidden when [allowed] is false. Disabled only while loading or offline.
class GatedButton extends StatelessWidget {
  const GatedButton({
    required this.allowed,
    required this.label,
    required this.onPressed,
    super.key,
    this.buttonKey,
    this.busy = false,
    this.online = true,
    this.destructive = false,
    this.filled = true,
  });

  final bool allowed;
  final String label;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final bool busy;
  final bool online;
  final bool destructive;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (!allowed) return const SizedBox.shrink();
    final enabled = online && !busy;
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    if (!filled) {
      return TextButton(
        key: buttonKey,
        onPressed: enabled ? onPressed : null,
        child: child,
      );
    }
    return FilledButton(
      key: buttonKey,
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: context.statusColors.cashNegative,
              foregroundColor: context.statusColors.onStatus,
            )
          : null,
      onPressed: enabled ? onPressed : null,
      child: child,
    );
  }
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({required this.online, super.key});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: online ? colors.successBg : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: online ? colors.success : scheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                online ? AppStrings.online : AppStrings.offline,
                key: Key(online ? 'online-banner' : 'offline-banner'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip({required this.status, super.key});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final label = reportStatusLabel(status);
    if (label == null) return const SizedBox.shrink();
    final colors = reportChipColors(context.statusColors, status);
    return Container(
      key: Key('report-chip-$status'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors?.$1,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: cairo(11, 800, color: colors?.$2),
      ),
    );
  }
}

Future<T?> showAppForm<T>(BuildContext context, Widget child) {
  final wide = MediaQuery.sizeOf(context).width > AppBreakpoints.phone;
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
}

int? parseUnits(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

class UnitsField extends StatelessWidget {
  const UnitsField({required this.controller, required this.label, super.key});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.headlineSmall);
  }
}
