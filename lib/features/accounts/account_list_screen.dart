import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({required this.section, super.key});

  final AccountSection section;

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  final _search = TextEditingController();
  final _extra = <AccountCardDto>[];
  var _assigning = false;
  final _selected = <String>{};
  String? _reply;

  AccountSection get section => widget.section;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(section.sectionKey)) {
      return const ForbiddenPane();
    }
    final page = ref.watch(accountsProvider(section));
    final online = ref.watch(onlineProvider);
    final money = ref.watch(apiLayerProvider).money;
    final canWrite = permissions.canWrite(section.sectionKey) && online;
    final home = ref.watch(homeDashboardProvider);
    final width = MediaQuery.sizeOf(context).width;

    return page.when(
      loading: () => const Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
        child: SkeletonBox(key: Key('accounts-loading')),
      ),
      error: (error, _) => ErrorPane(
        message: _message(error),
        onRetry: () => ref.invalidate(accountsProvider(section)),
      ),
      data: (data) {
        final cards = [...data.page.items, ..._extra];
        return ListView(
          key: Key('screen-${section.path}'),
          padding: pagePadding(width),
          children: [
            ScreenTitle(sectionLabel(section.sectionKey)),
            const SizedBox(height: AppSpacing.md),
            if (_showTicker) _ticker(home, money, width),
            _SummaryStrip(summary: data.summary, currency: section.currency, money: money),
            if (section == AccountSection.egyptianDeposits) const _RateCard(),
            const SizedBox(height: AppSpacing.md),
            _Tabs(section: section, summary: data.summary),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('account-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(labelText: AppStrings.filterSearch),
              onSubmitted: (value) {
                setState(_extra.clear);
                ref.read(accountQueryProvider(section).notifier).state = value;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                GatedButton(
                  buttonKey: const Key('add-account'),
                  allowed: permissions.canWrite(section.sectionKey),
                  online: online,
                  label: _addLabel,
                  onPressed: () => _create(context),
                ),
                GatedButton(
                  buttonKey: const Key('assign-mode'),
                  allowed: _canAssign(permissions),
                  online: online,
                  filled: false,
                  label: AppStrings.assign,
                  onPressed: () => setState(() => _assigning = !_assigning),
                ),
              ],
            ),
            if (_reply != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_reply!, key: const Key('server-reply')),
            ],
            const SizedBox(height: AppSpacing.md),
            if (cards.isEmpty)
              EmptyPane(message: AppStrings.emptyAccounts)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = AppBreakpoints.cardColumns(width);
                  final cardWidth = ((constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns)
                      .clamp(120.0, constraints.maxWidth);
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final card in cards)
                        SizedBox(
                          width: cardWidth,
                          child: _AccountCard(
                            section: section,
                            card: card,
                            money: money,
                            canWrite: canWrite && !card.systemManaged,
                            assigning: _assigning,
                            selected: _selected.contains(card.id),
                            onOpen: () => context.go('/${section.path}/${card.id}'),
                            onToggle: () => setState(() {
                              _selected.contains(card.id)
                                  ? _selected.remove(card.id)
                                  : _selected.add(card.id);
                            }),
                            onPin: () => _pin(card),
                            onZero: permissions.canDo(ManagementAction.customerZeroReview) &&
                                    section == AccountSection.customers
                                ? () => _zero(card)
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (data.page.nextCursor != null)
              TextButton(
                onPressed: online ? () => _more(data.page.nextCursor!) : null,
                child: const Text(AppStrings.loadMore),
              ),
          ],
        );
      },
    );
  }

  bool get _showTicker =>
      section == AccountSection.customers || section == AccountSection.companies;

  bool _canAssign(PermissionService permissions) =>
      (section == AccountSection.customers || section == AccountSection.companies) &&
      permissions.canDo(ManagementAction.collectionsAssign);

  String get _addLabel => switch (section) {
    AccountSection.customers => AppStrings.addCustomer,
    AccountSection.companies => AppStrings.addCompany,
    _ => AppStrings.addDeposit,
  };

  Widget _ticker(AsyncValue<HomeDto?> home, MoneyFormatter money, double width) {
    final debts = home.asData?.value?.oldDebts;
    if (debts == null) return const SizedBox.shrink();
    final rows = [
      for (final debt in debts)
        if (debt.section == section.sectionKey.key) debt,
    ];
    final body = rows.isEmpty
        ? const Text(AppStrings.emptyTicker)
        : Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final debt in rows)
                Chip(
                  label: Text(
                    '${debt.name} · ${debt.currency == null ? AppStrings.dash : money.formatOrDash(debt.balanceUnits, debt.currency!)} · ${sinceDays(debt.debtAgeDays)}',
                  ),
                ),
            ],
          );
    if (width <= AppBreakpoints.phone) {
      return ExpansionTile(
        title: const Text(AppStrings.oldDebtsTitle),
        children: [
          body,
          TextButton(
            onPressed: () {},
            child: const Text(AppStrings.showAll),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.oldDebtsTitle),
        const SizedBox(height: AppSpacing.sm),
        body,
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  String _message(Object error) {
    final failure = ref.read(errorHandlerProvider).toFailure(error);
    if (failure.code == 'FORBIDDEN') return AppStrings.forbidden;
    return failure.message;
  }

  Future<void> _more(String cursor) async {
    final query = ref.read(accountQueryProvider(section)).trim();
    final filter = ref.read(accountFilterProvider(section));
    final next = await ref.read(apiLayerProvider).accounts.list(
      section,
      cursor: cursor,
      q: query.isEmpty ? null : query,
      filter: filter,
    );
    if (!mounted) return;
    setState(() => _extra.addAll(next.page.items));
  }

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final opening = TextEditingController();
    final saved = await showAppForm<bool>(
      context,
      _CreateForm(name: name, phone: phone, opening: opening, section: section),
    );
    if (saved == true) {
      ref.invalidate(accountsProvider(section));
    }
  }

  Future<void> _pin(AccountCardDto card) async {
    final meta = MutationMeta(expectedVersion: card.version);
    try {
      final ack = await ref.read(apiLayerProvider).accounts.setPinned(
        section,
        card.id,
        !card.pinned,
        meta,
      );
      if (!mounted) return;
      setState(() => _reply = _ack(ack));
      ref.invalidate(accountsProvider(section));
    } catch (error) {
      if (!mounted) return;
      setState(() => _reply = ref.read(errorHandlerProvider).toFailure(error).message);
    }
  }

  Future<void> _zero(AccountCardDto card) async {
    final meta = MutationMeta(expectedVersion: card.version);
    try {
      final ack = await ref.read(apiLayerProvider).accounts.confirmZeroReview(card.id, meta);
      if (!mounted) return;
      setState(() => _reply = _ack(ack));
      ref.invalidate(accountsProvider(section));
    } catch (error) {
      if (!mounted) return;
      setState(() => _reply = ref.read(errorHandlerProvider).toFailure(error).message);
      ref.invalidate(accountsProvider(section));
    }
  }

  String _ack(MutationAck ack) {
    final bits = <String>[
      AppStrings.serverReply,
      if (ack.id != null) ack.id!,
      if (ack.version != null) '${ack.version}',
    ];
    return bits.join(' · ');
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary, required this.currency, required this.money});

  final AccountsSummaryDto summary;
  final Currency currency;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.netDebt, style: Theme.of(context).textTheme.titleSmall),
            MoneyText(money.formatOrDash(summary.netBalanceUnits, currency)),
            const SizedBox(height: AppSpacing.xs),
            Text(AppStrings.totalDebt, style: Theme.of(context).textTheme.bodySmall),
            MoneyText(money.formatOrDash(summary.totalDebtUnits, currency)),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs({required this.section, required this.summary});

  final AccountSection section;
  final AccountsSummaryDto summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(accountFilterProvider(section));
    final tabs = <(String?, String, int?)>[
      (null, section == AccountSection.libyanDeposits ? AppStrings.smartTab : AppStrings.activeTab, summary.activeCards),
      ('today', AppStrings.todayTab, null),
      ('debts', AppStrings.debtsTab, null),
      ('settled', AppStrings.settledTab, null),
      ('pinned', AppStrings.pinnedTab, null),
      if (section == AccountSection.customers)
        ('pendingReview', AppStrings.zeroTab, summary.pendingReviewCount),
    ];
    if (section == AccountSection.egyptianDeposits) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(tab.$3 == null ? tab.$2 : '${tab.$2} ${tab.$3}'),
                selected: current == tab.$1,
                onSelected: (_) {
                  ref.read(accountFilterProvider(section).notifier).state = tab.$1;
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.section,
    required this.card,
    required this.money,
    required this.canWrite,
    required this.assigning,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    required this.onPin,
    required this.onZero,
  });

  final AccountSection section;
  final AccountCardDto card;
  final MoneyFormatter money;
  final bool canWrite;
  final bool assigning;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onPin;
  final VoidCallback? onZero;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final colors = context.statusColors;
    final visual = ageVisual(
      colors: colors,
      ageStatus: card.ageStatus,
      section: section,
      serverLabel: card.ageStatusLabel,
    );
    final flat = useFlatAgeCard(width, Theme.of(context).brightness);
    final colored = visual.colored;
    final fg = colored ? colors.onStatus : Theme.of(context).colorScheme.onSurface;
    final accent = colored ? (visual.accent ?? colors.onStatus) : Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: colored
          ? (flat ? visual.flat : colors.neutralCard)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: colored && !flat ? visual.gradient : null,
          color: colored && flat ? visual.flat : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: colored ? colors.onStatus.withValues(alpha: 0.2) : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 118),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (visual.label != null)
                    Text(visual.label!, style: cairo(11, 800, color: accent)),
                  Text(card.name, style: cairo(16, 800, color: fg)),
                  if (card.phone != null) LtrText(card.phone!, style: cairo(12, 500, color: accent)),
                  MoneyText(
                    money.formatOrDash(card.balanceUnits, card.currency),
                    style: context.textExtras.amountLarge.copyWith(color: fg),
                  ),
                  Text(
                    '${AppStrings.lastActivity}: ${formatIsoDate(card.lastActivityAt)}',
                    style: cairo(11, 500, color: accent),
                  ),
                  if (card.activeAssigneeName != null)
                    Text(
                      '${AppStrings.withEmployee}: ${card.activeAssigneeName}',
                      style: cairo(11, 600, color: accent),
                    ),
                  if (card.debtAgeDays != null)
                    Text(sinceDays(card.debtAgeDays), style: cairo(11, 500, color: accent)),
                  if (card.systemManaged)
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: fg),
                        const SizedBox(width: AppSpacing.xs),
                        Text(AppStrings.systemCard, style: cairo(11, 800, color: fg)),
                      ],
                    ),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (assigning)
                        Checkbox(value: selected, onChanged: (_) => onToggle()),
                      if (canWrite)
                        IconButton(
                          key: Key('pin-${card.id}'),
                          tooltip: card.pinned ? AppStrings.unpin : AppStrings.pin,
                          onPressed: onPin,
                          icon: Icon(card.pinned ? Icons.push_pin : Icons.push_pin_outlined, color: fg),
                        ),
                      if (onZero != null && !card.systemManaged)
                        TextButton(
                          key: const Key('zero-review'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: onZero,
                          child: Text(AppStrings.zeroReview, style: cairo(12, 700, color: fg)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RateCard extends ConsumerStatefulWidget {
  const _RateCard();

  @override
  ConsumerState<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends ConsumerState<_RateCard> {
  final _rate = TextEditingController();
  String? _message;
  var _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rate = ref.watch(exchangeRateProvider);
    final permissions = permissionsOf(ref);
    final online = ref.watch(onlineProvider);
    final money = ref.watch(apiLayerProvider).money;
    return Card(
      key: const Key('exchange-rate-card'),
      margin: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: rate.when(
          loading: () => const SkeletonBox(height: 72),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(exchangeRateProvider),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.rateTitle, style: Theme.of(context).textTheme.titleSmall),
              LtrText(
                money.formatDecimalOrDash(data.egpPerLyd),
                style: context.textExtras.amountLarge,
              ),
              Text(formatIsoDate(data.updatedAt)),
              if (permissions.canWrite(SectionKey.egyptianDeposits)) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('rate-field'),
                  controller: _rate,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: AppStrings.rate),
                ),
                const SizedBox(height: AppSpacing.sm),
                GatedButton(
                  buttonKey: const Key('save-rate'),
                  allowed: true,
                  online: online,
                  busy: _busy,
                  label: AppStrings.save,
                  onPressed: () => _save(data.version),
                ),
              ],
              if (_message != null) Text(_message!),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(int? version) async {
    final parsed = DecimalString.tryParse(_rate.text);
    if (parsed == null) {
      setState(() => _message = AppStrings.rateInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      final next = await ref.read(apiLayerProvider).accounts.updateExchangeRate(
        parsed,
        MutationMeta(expectedVersion: version),
      );
      ref.invalidate(exchangeRateProvider);
      ref.invalidate(treasuryProvider);
      if (!mounted) return;
      setState(() => _message = '${AppStrings.serverReply} ${next.egpPerLyd?.value ?? AppStrings.dash}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = ref.read(errorHandlerProvider).toFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm({
    required this.name,
    required this.phone,
    required this.opening,
    required this.section,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController opening;
  final AccountSection section;

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: widget.name,
          decoration: const InputDecoration(labelText: AppStrings.name),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: widget.phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: AppStrings.phone),
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(controller: widget.opening, label: AppStrings.openingBalance),
        if (_error != null) Text(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }

  String get _title => switch (widget.section) {
    AccountSection.customers => AppStrings.addCustomer,
    AccountSection.companies => AppStrings.addCompany,
    _ => AppStrings.addDeposit,
  };

  Future<void> _submit() async {
    final opening = widget.opening.text.trim().isEmpty ? null : parseUnits(widget.opening.text);
    if (widget.opening.text.trim().isNotEmpty && opening == null) {
      setState(() => _error = AppStrings.integerOnly);
      return;
    }
    setState(() => _busy = true);
    try {
      final ack = await ref.read(apiLayerProvider).accounts.create(
        widget.section,
        CreateAccountRequest(
          name: widget.name.text.trim(),
          phone: widget.phone.text.trim().isEmpty ? null : widget.phone.text.trim(),
          openingBalance: opening,
        ),
        MutationMeta(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ref.read(errorHandlerProvider).toFailure(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
