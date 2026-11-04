import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error_handling/app_failure.dart';
import '../../error_handling/error_handler.dart';
import '../bars_style.dart';
import '../date_labels.dart';
import '../presentation.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.text, {
    super.key,
    this.style,
    this.align = TextAlign.start,
  });

  final String text;
  final TextStyle? style;

  /// Alignment inside the LTR amount. The default keeps existing callers.
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final extras = context.textExtras;
    if (text == MoneyValue.invalidLabel) {
      final labelStyle = (style ?? extras.amount).copyWith(
        fontFamily: kAppFont,
      );
      return Semantics(
        label: MoneyValue.invalidLabel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final icon = Icon(
              Icons.error_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            );
            final label = Text(
              MoneyValue.invalidLabel,
              softWrap: true,
              style: labelStyle,
            );
            // A narrow card has a finite width. Wrap the words there. A
            // FittedBox parent passes infinite width and scales the line.
            if (!constraints.maxWidth.isFinite) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.xs),
                  label,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: label),
              ],
            );
          },
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        textAlign: align,
        softWrap: true,
        style: (style ?? extras.amount).copyWith(
          fontFamily: kAppFont,
          // One face for digits and the currency letters (د.ل); its digits
          // are already equal width.
        ),
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
  const EmptyPane({
    required this.message,
    super.key,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;

  /// Optional heading. Existing callers that pass only [message] stay the same.
  final String? title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: title == null ? 24 : 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Placeholder shade: in light mode a step darker than the page and card
/// backgrounds; in dark mode a step lighter than the navy page.
Color skeletonColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF263252)
    : const Color(0xFFD5DDE8);

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
        color: skeletonColor(Theme.of(context)),
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
    final theme = Theme.of(context);
    final message = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.forbidden,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // A list parent gives an unbounded height. A full-screen parent
        // centers the notice and scrolls when the text scale is large.
        if (!constraints.hasBoundedHeight) {
          return KeyedSubtree(key: paneKey, child: message);
        }
        return SingleChildScrollView(
          key: paneKey,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: message),
          ),
        );
      },
    );
  }
}

/// Copy the UI may show. An HTTP 403 never keeps the raw server sentence.
String failureText(AppFailure failure) =>
    failure.isForbidden ? AppStrings.forbidden : failure.message;

/// Section failure. 403 is [ForbiddenPane]; every other code stays [ErrorPane].
Widget presentFailure(
  AppFailure failure, {
  VoidCallback? onRetry,
  Key? retryKey,
}) {
  if (failure.isForbidden) return const ForbiddenPane();
  return ErrorPane(
    message: failure.message,
    onRetry: onRetry,
    retryKey: retryKey,
  );
}

/// One snackbar for a failure. A second 403 replaces the first instead of stacking.
void showFailureSnackBar(BuildContext context, AppFailure failure) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final forbidden = failure.isForbidden;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          failureText(failure),
          key: forbidden ? const Key('forbidden-snackbar') : null,
        ),
      ),
    );
}

class ServerReplyText extends StatelessWidget {
  const ServerReplyText(this.ack, {super.key});

  final MutationAck? ack;

  @override
  Widget build(BuildContext context) {
    if (ack == null) return const SizedBox.shrink();
    final id = ack!.id;
    final version = ack!.version;
    final parts = <String>[AppStrings.serverReply, ?id, ?version?.toString()];
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
    this.glyph,
    this.leading,
  });

  /// Shown instead of the label text (the label stays as the tooltip and
  /// screen-reader name): actions as symbols (Ali, 2026-11-04).
  final IconData? glyph;

  /// An icon before the label text (the label stays visible).
  final IconData? leading;

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
        : glyph != null
        ? Tooltip(
            message: label,
            child: Icon(glyph, semanticLabel: label),
          )
        : leading != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leading, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(label)),
            ],
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

/// Top status strip. On phones: role (start, right in RTL), the Tripoli day
/// and date in the middle, and the connection status (end, left in RTL).
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({
    required this.online,
    this.role,
    this.roleKey,
    this.showDate = false,
    this.topInset = 0,
    super.key,
  });

  final bool online;

  /// Signed-in role label, shown at the start edge.
  final String? role;
  final Key? roleKey;

  /// Day and date between the role and the status.
  final bool showDate;

  /// Extra top padding so the middle text clears the environment pill that
  /// straddles the app bar edge.
  final double topInset;

  static const dateKey = Key('strip-date');

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner>
    with WidgetsBindingObserver {
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(ConnectionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showDate != widget.showDate) _schedule();
  }

  /// One timer to the next Tripoli midnight (the date is also recomputed on
  /// every rebuild and when the app resumes).
  void _schedule() {
    _midnight?.cancel();
    _midnight = null;
    if (!widget.showDate) return;
    _midnight = Timer(untilTripoliMidnight(), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.showDate) {
      setState(() {});
      _schedule();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.online;
    final look = stripLook(context, online: online);
    final statusText = online ? AppStrings.online : AppStrings.offline;
    final statusStyle = look.statusStyle;
    // Extra width the status chip adds around its text.
    final statusChipExtra = StripLook.chipPadding.horizontal;
    Widget status({int? maxLines}) => DecoratedBox(
      decoration: look.statusChip,
      child: Padding(
        padding: StripLook.chipPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: look.dotColor),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                statusText,
                key: Key(online ? 'online-banner' : 'offline-banner'),
                maxLines: maxLines,
                style: statusStyle,
              ),
            ),
          ],
        ),
      ),
    );
    final role = widget.role;
    final Widget body;
    if (role == null && !widget.showDate) {
      body = Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: status(),
            ),
          ),
        ],
      );
    } else {
      final roleStyle = look.roleStyle;
      final dateStyle = look.dateStyle;
      final direction = Directionality.of(context);
      final inherited = DefaultTextStyle.of(context).style;
      final scaler = MediaQuery.textScalerOf(context);
      double measure(String text, TextStyle? style) {
        final painter = TextPainter(
          // Same effective style as the Text widget (merged with the
          // inherited default), so the measured width matches the paint.
          text: TextSpan(text: text, style: inherited.merge(style)),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      body = LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.md;
          final width = constraints.maxWidth;
          // Each side takes its own text width: the role up to 30% (one
          // line), the status up to half the strip. A status wider than that
          // (the offline text, or very large text) wraps and is never cut.
          var roleWidth = role == null
              ? 0.0
              : math.min(measure(role, roleStyle) + 1, width * 0.34);
          final statusNatural =
              measure(statusText, statusStyle) +
              8 +
              AppSpacing.sm +
              statusChipExtra +
              1;
          var statusWidth = math.min(statusNatural, width * 0.5);
          if (widget.showDate) {
            // Keep room for at least the digits-only date: a long status
            // (offline) wraps onto more lines instead.
            final digits =
                measure(
                  tripoliDateLabel(tripoliNow(), numeric: true),
                  look.dateStyle,
                ) +
                1;
            final room = width - roleWidth - 2 * gap - digits;
            if (statusWidth > room) {
              statusWidth = math.max(width * 0.28, room);
            }
          }
          // A status that would need more than two lines at its width (the
          // offline text with large text) goes on its own row below, so the
          // strip stays short.
          final stacked = statusNatural > 2 * statusWidth;
          if (stacked && role != null) {
            // On its own row the role may use the room the status left,
            // keeping space for the digits-only date.
            final digits = widget.showDate
                ? measure(
                        tripoliDateLabel(tripoliNow(), numeric: true),
                        dateStyle,
                      ) +
                      1 +
                      gap
                : 0.0;
            roleWidth = math.max(
              roleWidth,
              math.min(measure(role, roleStyle) + 1, width - digits),
            );
          }
          final slot = stacked
              ? width - roleWidth - gap
              : width - roleWidth - statusWidth - 2 * gap;
          String? date;
          if (widget.showDate) {
            final today = tripoliNow();
            // Longest form that fits on one line: full, then short, then
            // digits only.
            final forms = [
              tripoliDateLabel(today),
              tripoliDateLabel(today, short: true),
              tripoliDateLabel(today, numeric: true),
            ];
            date = forms.firstWhere(
              (form) => measure(form, dateStyle) <= slot,
              orElse: () => forms.last,
            );
          }
          final roleBox = SizedBox(
            width: roleWidth,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: role == null
                  ? null
                  : Text(
                      role,
                      key: widget.roleKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: roleStyle,
                    ),
            ),
          );
          final dateText = date == null
              ? const SizedBox.shrink()
              : Text(
                  date,
                  key: ConnectionBanner.dateKey,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dateStyle,
                );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    roleBox,
                    const SizedBox(width: gap),
                    Expanded(child: dateText),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: status(),
                ),
              ],
            );
          }
          return Row(
            children: [
              roleBox,
              const SizedBox(width: gap),
              Expanded(child: dateText),
              const SizedBox(width: gap),
              SizedBox(
                width: statusWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: status(),
                ),
              ),
            ],
          );
        },
      );
    }
    return Padding(
      padding: StripLook.margin,
      child: Material(
        key: const Key('status-strip'),
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: look.background,
            borderRadius: StripLook.radius,
            border: Border.all(color: look.border),
            boxShadow: look.shadow,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.sm + widget.topInset,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: body,
          ),
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
      child: Text(label, style: cairo(11, 800, color: colors?.$2)),
    );
  }
}

Future<T?> showAppForm<T>(BuildContext context, Widget child) {
  final size = MediaQuery.sizeOf(context);
  final wide = size.width > AppBreakpoints.phone;
  final maxHeight = size.height * 0.92;
  // shrinkWrap keeps a short form at its own height. primary: false so the
  // form does not steal the screen's PrimaryScrollController. A tall form,
  // including large text, scrolls inside the cap instead of overflowing.
  Widget sheet(EdgeInsetsGeometry padding) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        primary: false,
        shrinkWrap: true,
        padding: padding,
        children: [child],
      ),
    );
  }

  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: sheet(const EdgeInsetsDirectional.all(AppSpacing.lg)),
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
      child: sheet(EdgeInsets.zero),
    ),
  );
}

/// Parses the minor-unit integer the server stores. The text is not scaled,
/// rounded, or combined with any other amount.
///
/// Arabic-Indic and Persian digits are normalized. ',' and '٬' are thousands
/// separators only when the groups are valid (1-3 digits, then groups of 3).
/// A decimal mark rejects the whole value.
int? parseUnits(String raw) {
  var text = DecimalString.normalizeDigits(raw.trim());
  if (text.isEmpty) return null;
  var negative = false;
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1);
  }
  if (text.isEmpty) return null;
  if (text.contains('.') || text.contains('٫')) return null;
  const comma = ',';
  const arabicComma = '٬';
  final hasComma = text.contains(comma);
  final hasArabic = text.contains(arabicComma);
  if (hasComma && hasArabic) return null;
  if (hasComma || hasArabic) {
    final sep = hasComma ? comma : arabicComma;
    final parts = text.split(sep);
    if (parts.length < 2) return null;
    if (!RegExp(r'^\d{1,3}$').hasMatch(parts.first)) return null;
    for (final part in parts.skip(1)) {
      if (!RegExp(r'^\d{3}$').hasMatch(part)) return null;
    }
    text = parts.join();
  }
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  final value = int.tryParse(text);
  if (value == null) return null;
  return negative ? -value : value;
}

class UnitsField extends StatelessWidget {
  const UnitsField({
    required this.controller,
    required this.label,
    super.key,
    this.dense,
    this.showHint = true,
    this.autofocus = false,
    this.focusNode,
  });

  /// The ledger's add row opens with the cursor here (Ali, 2026-11-03).
  final bool autofocus;
  final FocusNode? focusNode;

  final TextEditingController controller;
  final String label;

  /// False in the ledger's compact add row (Ali asked for no notes there).
  final bool showHint;

  /// Overrides the theme density. Null keeps the theme value.
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autofocus,
      focusNode: focusNode,
      controller: controller,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        labelText: label,
        helperText: showHint ? AppStrings.unitsHint : null,
        helperMaxLines: 12,
        isDense: dense,
      ),
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

/// Keeps the last successful value when a later load fails.
///
/// The first load still shows [loading] or the error pane. A failed refresh
/// keeps the last value and adds the error with retry.
class KeptData<T> extends StatefulWidget {
  const KeptData({
    required this.value,
    required this.builder,
    required this.onRetry,
    required this.messageOf,
    super.key,
    this.loading,
    this.resetKey,
    this.retryKey,
    this.failureOf,
    this.expand = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String Function(Object error) messageOf;
  final Widget? loading;
  final Object? resetKey;
  final Key? retryKey;

  /// When set, a `FORBIDDEN` code renders [ForbiddenPane] instead of [ErrorPane].
  final AppFailure Function(Object error)? failureOf;

  /// True when [builder] returns a scrolling view that should fill the body.
  final bool expand;

  @override
  State<KeptData<T>> createState() => _KeptDataState<T>();
}

class _KeptDataState<T> extends State<KeptData<T>> {
  T? _last;
  Object? _resetKey;
  var _hasLast = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    if (widget.resetKey != _resetKey) {
      _resetKey = widget.resetKey;
      _hasLast = value.hasValue;
      _last = value.hasValue ? value.value : null;
    } else if (value.hasValue) {
      _hasLast = true;
      _last = value.value;
    }

    if (value.hasError && _hasLast) {
      if (_forbidden(value.error!)) return const ForbiddenPane();
      return _withError(widget.builder(_last as T), value.error!);
    }

    return value.when(
      skipLoadingOnReload: true,
      data: widget.builder,
      loading: () => _fill(widget.loading ?? const SkeletonBox(height: 88)),
      error: (error, _) {
        if (_forbidden(error)) return const ForbiddenPane();
        return _fill(_pane(error));
      },
    );
  }

  /// With [KeptData.expand] the pane gets a bounded height (the screen's),
  /// so a skeleton or message taller than a small phone, or than large
  /// text allows, scrolls instead of overflowing.
  Widget _fill(Widget pane) =>
      widget.expand ? SingleChildScrollView(child: pane) : pane;

  /// 403 is [ForbiddenPane] whether the screen passed [KeptData.failureOf]
  /// or only a thrown [ApiException].
  bool _forbidden(Object error) {
    final mapped = widget.failureOf?.call(error);
    if (mapped != null) return mapped.isForbidden;
    return const ErrorHandler().toFailure(error).isForbidden;
  }

  Widget _pane(Object error) {
    final failure = widget.failureOf?.call(error);
    if (failure != null) {
      return presentFailure(
        failure,
        onRetry: widget.onRetry,
        retryKey: widget.retryKey,
      );
    }
    return ErrorPane(
      message: widget.messageOf(error),
      onRetry: widget.onRetry,
      retryKey: widget.retryKey,
    );
  }

  Widget _withError(Widget body, Object error) {
    final pane = _pane(error);
    if (widget.expand) {
      // The message takes at most half the height (scrolling inside it),
      // so the kept list below always keeps room.
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
              child: SingleChildScrollView(child: pane),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [pane, body],
    );
  }
}

/// The user dragged this list to its end.
///
/// A [ScrollPosition.jumpTo] has no drag, so walking the rows in a test does
/// not load another page.
bool historyDraggedToEnd(ScrollNotification notification) {
  if (notification is! ScrollUpdateNotification) return false;
  if (notification.dragDetails == null) return false;
  final metrics = notification.metrics;
  if (metrics.maxScrollExtent <= 0) return false;
  return metrics.pixels >= metrics.maxScrollExtent - 24;
}

/// × / ÷ / «مباشر» for a calculation mode, read aloud and shown on long
/// press as ضرب / قسمة / مباشر (Ali, 2026-11-03).
class CalculationMark extends StatelessWidget {
  const CalculationMark(this.mode, {super.key, this.style});

  final CalculationMode? mode;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final word = calculationLabel(mode);
    final symbol = calculationSymbol(mode);
    final isSymbol = symbol != word;
    final text = Text(
      symbol,
      style: isSymbol
          ? (style ?? DefaultTextStyle.of(context).style).copyWith(
              fontSize: ((style?.fontSize ?? 14) * 1.35),
              fontWeight: FontWeight.w800,
            )
          : style,
    );
    if (!isSymbol) return text;
    return Tooltip(
      message: word,
      excludeFromSemantics: true,
      child: Semantics(label: word, excludeSemantics: true, child: text),
    );
  }
}
