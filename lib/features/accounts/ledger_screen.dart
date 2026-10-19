import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({required this.section, required this.id, super.key});

  final AccountSection section;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(section.sectionKey)) return const ForbiddenPane();
    final ledger = ref.watch(ledgerProvider((section, id)));
    final card = ref.watch(accountCardProvider((section, id)));
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final system = card.asData?.value.systemManaged ?? false;
    final canWrite = permissions.canWrite(section.sectionKey) && !system;

    return Scaffold(
      key: Key('screen-ledger-${section.path}'),
      body: ledger.when(
        loading: () => const SkeletonBox(key: Key('ledger-loading'), height: 240),
        error: (error, _) => ErrorPane(
          message: ref.read(errorHandlerProvider).toFailure(error).message,
          onRetry: () => ref.invalidate(ledgerProvider((section, id))),
        ),
        data: (page) {
          final showBalance = page.page.items.any((entry) => entry.balanceAfterUnits != null);
          return ListView(
            padding: pagePadding(MediaQuery.sizeOf(context).width),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: AppStrings.back,
                    onPressed: () => context.go('/${section.path}'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(child: _Header(section: section, card: card, money: money)),
                ],
              ),
              if (canWrite)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    GatedButton(
                      buttonKey: const Key('add-debt'),
                      allowed: true,
                      online: online,
                      label: section == AccountSection.libyanDeposits
                          ? AppStrings.depositIn
                          : section == AccountSection.egyptianDeposits
                          ? AppStrings.egpIn
                          : AppStrings.debtMovement,
                      onPressed: () => _movement(context, ref, type: 'debt'),
                    ),
                    GatedButton(
                      buttonKey: const Key('add-payment'),
                      allowed: true,
                      online: online,
                      label: section == AccountSection.libyanDeposits
                          ? AppStrings.depositOut
                          : section == AccountSection.egyptianDeposits
                          ? AppStrings.egpOut
                          : AppStrings.paymentMovement,
                      onPressed: () => _movement(context, ref, type: 'payment'),
                    ),
                    GatedButton(
                      buttonKey: const Key('full-payment'),
                      allowed: section != AccountSection.libyanDeposits &&
                          section != AccountSection.egyptianDeposits,
                      online: online,
                      filled: false,
                      label: AppStrings.fullPayment,
                      onPressed: () => _full(context, ref, card.asData?.value.version),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              const Text(AppStrings.noPreview),
              if (!showBalance)
                Text(
                  AppStrings.statementHidden,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              if (page.page.items.isEmpty)
                const EmptyPane(message: AppStrings.emptyLedger)
              else
                for (final entry in page.page.items)
                  _EntryTile(
                    section: section,
                    entry: entry,
                    money: money,
                    showBalance: showBalance,
                    canWrite: canWrite,
                    online: online,
                    onCancel: () => _cancel(context, ref, entry),
                  ),
              if (page.page.hasMore)
                TextButton(
                  onPressed: () => ref.invalidate(ledgerProvider((section, id))),
                  child: const Text(AppStrings.loadOlder),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _movement(BuildContext context, WidgetRef ref, {required String type}) async {
    final amount = TextEditingController();
    final factor = TextEditingController();
    final note = TextEditingController();
    final date = TextEditingController(text: formatIsoDate(DateTime.now()));
    var mode = CalculationMode.direct;
    final saved = await showAppForm<bool>(
      context,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              type == 'payment' ? AppStrings.paymentMovement : AppStrings.debtMovement,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(AppStrings.noPreview),
            const SizedBox(height: AppSpacing.md),
            UnitsField(controller: amount, label: AppStrings.amount),
            const SizedBox(height: AppSpacing.md),
            DropdownButton<CalculationMode>(
              value: mode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: CalculationMode.direct, child: Text(AppStrings.direct)),
                DropdownMenuItem(value: CalculationMode.divide, child: Text(AppStrings.divide)),
                DropdownMenuItem(value: CalculationMode.multiply, child: Text(AppStrings.multiply)),
              ],
              onChanged: (value) => setLocal(() => mode = value ?? CalculationMode.direct),
            ),
            if (mode != CalculationMode.direct)
              TextField(
                controller: factor,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: AppStrings.factor),
              ),
            TextField(
              controller: date,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.date),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: AppStrings.note),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () async {
                final units = parseUnits(amount.text);
                if (units == null) return;
                final parsedDate = DateTime.tryParse(date.text);
                if (parsedDate == null) return;
                DecimalString? factorValue;
                if (mode != CalculationMode.direct) {
                  factorValue = DecimalString.tryParse(factor.text);
                  if (factorValue == null) return;
                }
                final cardVersion = ref.read(accountCardProvider((section, id))).asData?.value.version;
                final request = type == 'payment'
                    ? AccountTransactionRequest.partialPayment(
                        inputValue: units,
                        mode: mode,
                        factor: factorValue,
                        date: parsedDate,
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
                      )
                    : AccountTransactionRequest.debt(
                        inputValue: units,
                        mode: mode,
                        factor: factorValue,
                        date: parsedDate,
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
                      );
                try {
                  final ack = await ref.read(apiLayerProvider).accounts.addTransaction(
                    section,
                    id,
                    request,
                    MutationMeta(expectedVersion: cardVersion),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
                  );
                  Navigator.of(context).pop(true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
                  );
                }
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountCardProvider((section, id)));
      ref.invalidate(accountsProvider(section));
    }
  }

  Future<void> _full(BuildContext context, WidgetRef ref, int? version) async {
    try {
      final ack = await ref.read(apiLayerProvider).accounts.addTransaction(
        section,
        id,
        AccountTransactionRequest.fullPayment(date: DateTime.now()),
        MutationMeta(expectedVersion: version),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountsProvider(section));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, LedgerEntryDto entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(AppStrings.confirmCancel),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.confirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final ack = await ref.read(apiLayerProvider).accounts.cancelTransaction(
        section,
        id,
        entry.id,
        MutationMeta(expectedVersion: entry.version),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(ledgerProvider((section, id)));
    } catch (error) {
      if (!context.mounted) return;
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      if (failure.code == 'VERSION_CONFLICT') {
        ref.invalidate(ledgerProvider((section, id)));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.section, required this.card, required this.money});

  final AccountSection section;
  final AsyncValue<AccountCardDto> card;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return card.when(
      loading: () => const SkeletonBox(height: 48),
      error: (_, _) => const SizedBox.shrink(),
      data: (value) {
        final visual = ageVisual(
          colors: context.statusColors,
          ageStatus: value.ageStatus,
          section: section,
          serverLabel: value.ageStatusLabel,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value.name, style: Theme.of(context).textTheme.titleLarge),
            if (value.phone != null) LtrText(value.phone!),
            MoneyText(
              money.formatOrDash(value.balanceUnits, value.currency),
              style: context.textExtras.amountLarge.copyWith(
                color: visual.colored ? null : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (visual.label != null) Text(visual.label!),
            if (value.systemManaged) const Text(AppStrings.systemCard),
          ],
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.section,
    required this.entry,
    required this.money,
    required this.showBalance,
    required this.canWrite,
    required this.online,
    required this.onCancel,
  });

  final AccountSection section;
  final LedgerEntryDto entry;
  final MoneyFormatter money;
  final bool showBalance;
  final bool canWrite;
  final bool online;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final reversed = entry.status == 'reversed';
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: reversed ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      decoration: reversed ? TextDecoration.lineThrough : null,
    );
    return Card(
      color: reversed ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.sequence}', style: style),
            Text(formatIsoDate(entry.date), style: style),
            Text(
              movementLabel(section: section, type: entry.type, paymentMode: entry.paymentMode),
              style: style,
            ),
            MoneyText(
              money.formatOrDash(entry.amountUnits, section.currency),
              style: context.textExtras.amount.copyWith(
                decoration: reversed ? TextDecoration.lineThrough : null,
              ),
            ),
            Text(
              '${calculationLabel(entry.calculationMode)} · ${AppStrings.inputValue} ${entry.inputValue ?? AppStrings.dash}'
              '${entry.factorMicros == null ? '' : ' · ${money.formatScaled(entry.factorMicros!, 6)}'}',
              style: style,
            ),
            LtrText(entry.id, style: style),
            if (entry.note != null) Text(entry.note!, style: style),
            if (entry.createdByName != null)
              Text('${AppStrings.actor}: ${entry.createdByName}', style: style),
            if (reversed) Text(AppStrings.reversed, style: Theme.of(context).textTheme.labelLarge),
            if (entry.corrected) const Text(AppStrings.corrected),
            if (showBalance && entry.balanceAfterUnits != null)
              Text(
                '${AppStrings.balanceAfter} ${money.format(entry.balanceAfterUnits!, section.currency)}',
              ),
            if (canWrite && !reversed)
              GatedButton(
                buttonKey: Key('cancel-${entry.id}'),
                allowed: true,
                online: online,
                filled: false,
                label: AppStrings.cancelMovement,
                onPressed: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}
