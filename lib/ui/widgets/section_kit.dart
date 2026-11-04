import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'common.dart';

/// Shared building blocks for the redesigned sections (المصراوية،
/// المشتريات، الخزينة، التقارير، الإعدادات), in the app's own dark/light
/// look: soft cards, pill titles, coloured edges and grid tables.
/// Display only; every figure is passed in already formatted.

/// Page heading: a bold title with an optional muted line under it.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {this.note, this.trailing, super.key});

  final String title;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: cairo(18, 800, color: look.ink)),
                if (note != null)
                  Text(note!, style: cairo(12, 500, color: look.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

BoxDecoration sectionCardDecoration(BuildContext context, {Color? border}) {
  final look = context.look;
  return BoxDecoration(
    color: look.card,
    borderRadius: BorderRadius.circular(AppRadii.xl),
    border: Border.all(color: border ?? look.cardBorder),
    boxShadow: look.glass
        ? null
        : const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
  );
}

/// The app's gold (the collections amber), readable on both themes.
Color sectionGold(BuildContext context) =>
    context.look.glass ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

/// Ink on a solid gold fill.
Color onSectionGold(BuildContext context) =>
    context.look.glass ? const Color(0xFF1A1300) : Colors.white;

/// Buttons inside a section use the app's gold, not the default blue.
/// Display only: wraps [child] in a theme with gold filled/elevated buttons.
class SectionTheme extends StatelessWidget {
  const SectionTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    final on = onSectionGold(context);
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      side: BorderSide(color: Color.lerp(gold, Colors.white, 0.25)!),
    );
    ButtonStyle gild(ButtonStyle? base) =>
        (base ?? const ButtonStyle()).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? gold.withValues(alpha: 0.30)
                : gold,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? on.withValues(alpha: 0.75)
                : on,
          ),
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(2),
          shadowColor: WidgetStatePropertyAll(gold.withValues(alpha: 0.45)),
        );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: gild(theme.filledButtonTheme.style),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: gild(theme.elevatedButtonTheme.style),
        ),
      ),
      child: child,
    );
  }
}

/// The statement header strip: glossy black with light text (Ali's device
/// shots), in both themes.
const sectionStripGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2A2F3A), Color(0xFF0B0B0F)],
);
const sectionStripInk = Color(0xFFF5F5F4);

/// A title in a gold-bordered pill, like the app's section headers.
class PillTitle extends StatelessWidget {
  const PillTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gold = sectionGold(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: sectionStripGradient,
        border: Border.all(color: gold.withValues(alpha: 0.8), width: 1.2),
        boxShadow: look.glass
            ? null
            : const [
                BoxShadow(
                  color: Color(0x330B0B0F),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(text, style: cairo(15, 800, color: sectionStripInk)),
      ),
    );
  }
}

/// A card with a pill title, an optional line under it, a trailing
/// widget (date, button) and its body.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.note,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.md),
    super.key,
  });

  final String? title;
  final String? note;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: sectionCardDecoration(context),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || trailing != null) ...[
                // Wraps under large text instead of overflowing.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (title != null) PillTitle(title!),
                    ?trailing,
                  ],
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: Text(
                      note!,
                      style: cairo(11.5, 500, color: look.muted),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled figure in a stack of rows with lines between them.
/// [highlight] tints the row (e.g. الرصيد المتبقي).
class FigureRow extends StatelessWidget {
  const FigureRow({
    required this.label,
    required this.value,
    this.hint,
    this.highlight,
    this.last = false,
    this.money = true,
    this.boxed = false,
    super.key,
  });

  final String label;
  final String? hint;
  final String value;
  final Color? highlight;
  final bool last;
  final bool money;

  /// The value sits in a field-like box (display only).
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final figure = context.textExtras.amount.copyWith(
      color: highlight ?? look.ink,
      fontSize: highlight == null ? 16 : 20,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight?.withValues(alpha: 0.10),
        border: last
            ? null
            : Border(bottom: BorderSide(color: look.cardBorder)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: cairo(14, 800, color: highlight ?? look.ink),
                  ),
                  if (hint != null)
                    Text(hint!, style: cairo(11, 500, color: look.muted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: boxed
                  ? Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: look.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: sectionGold(context).withValues(alpha: 0.6),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: money
                            ? MoneyText(value, style: figure)
                            : Text(value, style: figure),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: money
                          ? MoneyText(value, style: figure)
                          : Text(value, style: figure),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows of [FigureRow] inside one bordered box with an optional dark
/// header strip (title + date), like a statement.
class FigureBox extends StatelessWidget {
  const FigureBox({required this.rows, this.title, this.trailing, super.key});

  final String? title;
  final String? trailing;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: sectionGold(context).withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                decoration: const BoxDecoration(gradient: sectionStripGradient),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: cairo(13, 800, color: sectionStripInk),
                      ),
                    ),
                    if (trailing != null)
                      LtrText(
                        trailing!,
                        style: cairo(12.5, 800, color: sectionStripInk),
                      ),
                  ],
                ),
              ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// A summary card with a coloured start edge (as in collections).
class EdgeSummary extends StatelessWidget {
  const EdgeSummary({
    required this.title,
    required this.value,
    required this.edge,
    this.note,
    this.money = true,
    super.key,
  });

  final String title;
  final String value;
  final Color edge;
  final String? note;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final figure = context.textExtras.amount.copyWith(color: look.ink);
    return DecoratedBox(
      decoration: sectionCardDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: edge, width: 5)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: cairo(13, 800, color: look.ink)),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: money
                      ? MoneyText(value, style: figure)
                      : Text(value, style: figure),
                ),
                if (note != null)
                  Text(note!, style: cairo(11, 500, color: look.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two cards side by side; one column when narrow or text is large.
class PairGrid extends StatelessWidget {
  const PairGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final one = c.maxWidth < 330 || scale >= 1.3;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += one ? 1 : 2) {
          rows.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: one || i + 1 >= children.length
                  ? children[i]
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: children[i]),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: children[i + 1]),
                      ],
                    ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// A simple grid table: header strip, lined rows, optional footer row.
/// [flex] gives each column's share of the width.
class GridTable extends StatelessWidget {
  const GridTable({
    required this.headers,
    required this.rows,
    this.flex,
    this.footer,
    this.empty,
    super.key,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final List<Widget>? footer;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final line = BorderSide(color: look.cardBorder);
    final radius = BorderRadius.circular(AppRadii.card);
    Widget row(List<Widget> cells, {Color? color, bool head = false}) =>
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            gradient: head ? sectionStripGradient : null,
            border: Border(bottom: line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cells.length; i++)
                  Expanded(
                    flex: flex?[i] ?? 1,
                    child: Container(
                      decoration: i == cells.length - 1
                          ? null
                          : BoxDecoration(border: BorderDirectional(end: line)),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 6,
                        vertical: AppSpacing.sm,
                      ),
                      alignment: AlignmentDirectional.center,
                      child: cells[i],
                    ),
                  ),
              ],
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: look.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row([
              for (final h in headers)
                Text(
                  h,
                  textAlign: TextAlign.center,
                  style: cairo(11.5, 800, color: sectionStripInk),
                ),
            ], head: true),
            if (rows.isEmpty && empty != null)
              Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Text(
                  empty!,
                  textAlign: TextAlign.center,
                  style: cairo(12.5, 600, color: look.muted),
                ),
              ),
            for (final r in rows) row(r),
            if (footer != null)
              row(footer!, color: sectionGold(context).withValues(alpha: 0.10)),
          ],
        ),
      ),
    );
  }
}

/// A cell text for [GridTable].
Widget gridText(BuildContext context, String text, {bool bold = false}) => Text(
  text,
  textAlign: TextAlign.center,
  style: cairo(12.5, bold ? 800 : 600, color: context.look.ink),
);

/// A money cell for [GridTable].
Widget gridMoney(BuildContext context, String text, {bool bold = false}) =>
    FittedBox(
      fit: BoxFit.scaleDown,
      child: MoneyText(
        text,
        style: context.textExtras.amount.copyWith(
          fontSize: 13,
          color: context.look.ink,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );

/// A muted footnote strip (e.g. «محفوظ تلقائياً …»).
class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return DecoratedBox(
      decoration: sectionCardDecoration(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(text, style: cairo(11.5, 600, color: look.muted)),
      ),
    );
  }
}
