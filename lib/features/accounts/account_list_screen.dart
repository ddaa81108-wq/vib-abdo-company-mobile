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
import '../../ui/widgets/mutation_form.dart';

/// Customers, companies, Libyan deposits, and Egyptian deposits share this
/// screen. [section] selects the repository path, currency, and labels.
/// The ledger for a card is [LedgerScreen] with the same section.
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
  var _showAllDebts = false;
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
    final canWrite = permissions.canWrite(section.sectionKey);
    final home = ref.watch(homeDashboardProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = accountListColumns(
      width,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );

    return KeptData<AccountsPage>(
      value: page,
      resetKey: section,
      expand: true,
      onRetry: () => ref.invalidate(accountsProvider(section)),
      messageOf: _message,
      loading: const Padding(
        key: Key('accounts-loading'),
        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 28, width: 180),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 96),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 148),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 148),
          ],
        ),
      ),
      builder: (data) {
        final cards = [...data.page.items, ..._extra];
        return ListView(
          key: Key('screen-${section.path}'),
          padding: pagePadding(width),
          children: [
            ScreenTitle(sectionLabel(section.sectionKey)),
            const SizedBox(height: AppSpacing.md),
            if (_showTicker) _ticker(home, money, width, cards),
            _SummaryStrip(
              summary: data.summary,
              currency: section.currency,
              money: money,
            ),
            if (section == AccountSection.egyptianDeposits) const _RateCard(),
            const SizedBox(height: AppSpacing.md),
            _Tabs(section: section, summary: data.summary),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('account-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: AppStrings.filterSearch,
                isDense: false,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _search,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      key: const Key('clear-account-search'),
                      tooltip: AppStrings.clearSearch,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(_extra.clear);
                        ref.read(accountQueryProvider(section).notifier).state =
                            '';
                      },
                    );
                  },
                ),
              ),
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
            if (_assigning)
              _AssignSubmit(
                section: section,
                customerIds: _selected.toList(growable: false),
                online: online,
              ),
            if (_reply != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _reply!,
                key: const Key('server-reply'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (cards.isEmpty)
              EmptyPane(message: AppStrings.emptyAccounts)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = _cardWidth(constraints.maxWidth, columns);
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
                            onOpen: () =>
                                context.go('/${section.path}/${card.id}'),
                            onToggle: () => setState(() {
                              _selected.contains(card.id)
                                  ? _selected.remove(card.id)
                                  : _selected.add(card.id);
                            }),
                            onPin: (meta) => _pin(card, meta),
                            onZero:
                                permissions.canDo(
                                      ManagementAction.customerZeroReview,
                                    ) &&
                                    section == AccountSection.customers
                                ? (meta) => _zero(card, meta)
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (data.page.nextCursor != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: online ? () => _more(data.page.nextCursor!) : null,
                  child: const Text(AppStrings.loadMore),
                ),
              ),
          ],
        );
      },
    );
  }

  double _cardWidth(double maxWidth, int columns) {
    if (columns <= 1 || maxWidth <= 0) return maxWidth;
    final raw = (maxWidth - AppSpacing.md * (columns - 1)) / columns;
    if (raw < 160) return maxWidth;
    return raw.clamp(160.0, maxWidth);
  }

  bool get _showTicker =>
      section == AccountSection.customers ||
      section == AccountSection.companies;

  bool _canAssign(PermissionService permissions) =>
      (section == AccountSection.customers ||
          section == AccountSection.companies) &&
      permissions.canDo(ManagementAction.collectionsAssign);

  String get _addLabel => switch (section) {
    AccountSection.customers => AppStrings.addCustomer,
    AccountSection.companies => AppStrings.addCompany,
    _ => AppStrings.addDeposit,
  };

  Widget _ticker(
    AsyncValue<HomeDto?> home,
    MoneyFormatter money,
    double width,
    List<AccountCardDto> cards,
  ) {
    final debts = home.asData?.value?.oldDebts;
    if (debts == null) return const SizedBox.shrink();
    final rows = [
      for (final debt in debts)
        if (debt.section == section.sectionKey.key) debt,
    ];
    final body = rows.isEmpty
        ? const Text(AppStrings.emptyTicker)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _TickerLine(
                  debt: rows[i],
                  card: _cardFor(cards, rows[i].id),
                  money: money,
                ),
              ],
            ],
          );
    if (width <= AppBreakpoints.phone && !_showAllDebts) {
      return ExpansionTile(
        tilePadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
        ),
        childrenPadding: const EdgeInsetsDirectional.only(
          bottom: AppSpacing.sm,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: const Text(AppStrings.oldDebtsTitle),
        children: [
          body,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('show-all-debts'),
              onPressed: () => setState(() => _showAllDebts = true),
              child: const Text(AppStrings.showAll),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.oldDebtsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        body,
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  AccountCardDto? _cardFor(List<AccountCardDto> cards, String id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  String _message(Object error) {
    final failure = ref.read(errorHandlerProvider).toFailure(error);
    if (failure.code == 'FORBIDDEN') return AppStrings.forbidden;
    return failure.message;
  }

  Future<void> _more(String cursor) async {
    final query = ref.read(accountQueryProvider(section)).trim();
    final filter = ref.read(accountFilterProvider(section));
    final next = await ref
        .read(apiLayerProvider)
        .accounts
        .list(
          section,
          cursor: cursor,
          q: query.isEmpty ? null : query,
          filter: filter,
        );
    if (!mounted) return;
    setState(() => _extra.addAll(next.page.items));
  }

  Future<void> _create(BuildContext context) async {
    final saved = await showAppForm<bool>(
      context,
      _CreateForm(section: section),
    );
    if (saved == true) {
      ref.invalidate(accountsProvider(section));
    }
  }

  Future<String?> _pin(AccountCardDto card, MutationMeta meta) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .setPinned(section, card.id, !card.pinned, meta);
      if (!mounted) return null;
      setState(() => _reply = _ack(ack));
      ref.invalidate(accountsProvider(section));
      return null;
    } catch (error) {
      if (!mounted) {
        return ref.read(errorHandlerProvider).toFailure(error).message;
      }
      final message = ref.read(errorHandlerProvider).toFailure(error).message;
      setState(() => _reply = message);
      return message;
    }
  }

  Future<String?> _zero(AccountCardDto card, MutationMeta meta) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .confirmZeroReview(card.id, meta);
      if (!mounted) return null;
      setState(() => _reply = _ack(ack));
      ref.invalidate(accountsProvider(section));
      return null;
    } catch (error) {
      if (!mounted) {
        return ref.read(errorHandlerProvider).toFailure(error).message;
      }
      final message = ref.read(errorHandlerProvider).toFailure(error).message;
      setState(() => _reply = message);
      ref.invalidate(accountsProvider(section));
      return message;
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
  const _SummaryStrip({
    required this.summary,
    required this.currency,
    required this.money,
  });

  final AccountsSummaryDto summary;
  final Currency currency;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: [
            _Metric(
              label: AppStrings.netDebt,
              value: money.formatOrDash(summary.netBalanceUnits, currency),
              valueStyle: theme.textTheme.titleSmall,
              amountStyle: context.textExtras.amountLarge,
            ),
            _Metric(
              label: AppStrings.totalDebt,
              value: money.formatOrDash(summary.totalDebtUnits, currency),
              valueStyle: theme.textTheme.bodySmall,
              amountStyle: context.textExtras.amount,
            ),
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
      (
        null,
        section == AccountSection.libyanDeposits
            ? AppStrings.smartTab
            : AppStrings.activeTab,
        summary.activeCards,
      ),
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
                  ref.read(accountFilterProvider(section).notifier).state =
                      tab.$1;
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
  final Future<String?> Function(MutationMeta meta) onPin;
  final Future<String?> Function(MutationMeta meta)? onZero;

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
    final scheme = Theme.of(context).colorScheme;
    final fg = colored ? colors.onStatus : scheme.onSurface;
    final accent = colored
        ? (visual.accent ?? colors.onStatus)
        : scheme.onSurfaceVariant;
    final age = singleAgeText(
      serverLabel: card.ageStatusLabel,
      ageStatus: card.ageStatus,
      section: section,
      debtAgeDays: card.debtAgeDays,
    );
    final showPin = canWrite;
    final showZero = onZero != null && !card.systemManaged;
    final showActions = assigning || showPin || showZero;
    return Material(
      key: Key('account-card-${card.id}'),
      color: colored
          ? (flat ? visual.flat : colors.neutralCard)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: colored && !flat ? visual.gradient : null,
          color: colored && flat ? visual.flat : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: card.ageStatus == 'zero'
                ? colors.zeroCardBorder
                : colored
                ? colors.onStatus.withValues(alpha: 0.2)
                : scheme.outline,
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
                  if (age != null)
                    Text(
                      age,
                      key: Key('account-age-${card.id}'),
                      style: cairo(11, 800, color: accent),
                    ),
                  Text(card.name, style: cairo(16, 800, color: fg)),
                  if (card.phone != null)
                    _StartAlignedText(
                      card.phone!,
                      style: cairo(12, 500, color: accent),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _StartAlignedText(
                    money.formatOrDash(card.balanceUnits, card.currency),
                    style: context.textExtras.amountLarge.copyWith(
                      color: fg,
                      fontFamily: 'JetBrainsMono',
                    ),
                    mono: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${AppStrings.lastActivity}: ${formatIsoDate(card.lastActivityAt)}',
                    style: cairo(11, 500, color: accent),
                  ),
                  if (card.activeAssigneeName != null)
                    Text(
                      '${AppStrings.withEmployee}: ${card.activeAssigneeName}',
                      style: cairo(11, 600, color: accent),
                    ),
                  if (card.systemManaged)
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: fg),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            AppStrings.systemCard,
                            style: cairo(11, 800, color: fg),
                          ),
                        ),
                      ],
                    ),
                  if (showActions) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Divider(
                      height: 1,
                      color: colored
                          ? colors.onStatus.withValues(alpha: 0.24)
                          : scheme.outlineVariant,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (assigning)
                          Checkbox(
                            value: selected,
                            onChanged: (_) => onToggle(),
                          ),
                        if (showPin)
                          GuardedMutation(
                            buttonKey: Key('pin-${card.id}'),
                            inputs:
                                'pin:${card.id}:${card.pinned}:${card.version}',
                            expectedVersion: card.version,
                            label: card.pinned
                                ? AppStrings.unpin
                                : AppStrings.pin,
                            tooltip: card.pinned
                                ? AppStrings.unpin
                                : AppStrings.pin,
                            icon: card.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            onSubmit: (meta) => onPin(meta),
                          ),
                        if (showZero)
                          GuardedMutation(
                            buttonKey: const Key('zero-review'),
                            inputs: 'zero:${card.id}:${card.version}',
                            expectedVersion: card.version,
                            label: AppStrings.zeroReview,
                            filled: false,
                            onSubmit: (meta) => onZero!(meta),
                          ),
                      ],
                    ),
                  ],
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

  @override
  void initState() {
    super.initState();
    _rate.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _rate.removeListener(_changed);
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rate = ref.watch(exchangeRateProvider);
    final permissions = permissionsOf(ref);
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
          data: (data) {
            final canEdit = permissions.canWrite(SectionKey.egyptianDeposits);
            final theme = Theme.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.rateTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                _StartAlignedText(
                  money.formatDecimalOrDash(data.egpPerLyd),
                  style: context.textExtras.amountLarge.copyWith(
                    fontFamily: 'JetBrainsMono',
                  ),
                  mono: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${AppStrings.date}: ${formatIsoDate(data.updatedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (canEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('rate-field'),
                    controller: _rate,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    decoration: const InputDecoration(
                      labelText: AppStrings.rate,
                      isDense: false,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GuardedMutation(
                    buttonKey: const Key('save-rate'),
                    inputs: _rate.text,
                    expectedVersion: data.version,
                    label: AppStrings.save,
                    confirmText: AppStrings.confirm,
                    normalizedValue: DecimalString.tryParse(_rate.text)?.value,
                    onSubmit: _save,
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_message!, style: theme.textTheme.bodyMedium),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<String?> _save(MutationMeta meta) async {
    final parsed = DecimalString.tryParse(_rate.text);
    if (parsed == null) return AppStrings.rateInvalid;
    try {
      final next = await ref
          .read(apiLayerProvider)
          .accounts
          .updateExchangeRate(parsed, meta);
      ref.invalidate(exchangeRateProvider);
      ref.invalidate(treasuryProvider);
      if (!mounted) return null;
      setState(
        () => _message =
            '${AppStrings.serverReply} ${next.egpPerLyd?.value ?? AppStrings.dash}',
      );
      return null;
    } catch (error) {
      final message = ref.read(errorHandlerProvider).toFailure(error).message;
      if (mounted) setState(() => _message = message);
      return message;
    }
  }
}

class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm({required this.section});

  final AccountSection section;

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _opening = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _phone, _opening]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_name, _phone, _opening]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('create-name'),
          controller: _name,
          decoration: const InputDecoration(
            labelText: AppStrings.name,
            isDense: false,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          decoration: const InputDecoration(
            labelText: AppStrings.phone,
            isDense: false,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          controller: _opening,
          label: AppStrings.openingBalance,
          dense: false,
        ),
        const SizedBox(height: AppSpacing.lg),
        GuardedMutation(
          buttonKey: const Key('save-account'),
          inputs: '${_name.text}|${_phone.text}|${_opening.text}',
          label: AppStrings.save,
          onSubmit: _submit,
        ),
      ],
    );
  }

  String get _title => switch (widget.section) {
    AccountSection.customers => AppStrings.addCustomer,
    AccountSection.companies => AppStrings.addCompany,
    _ => AppStrings.addDeposit,
  };

  Future<String?> _submit(MutationMeta meta) async {
    final opening = _opening.text.trim().isEmpty
        ? null
        : parseUnits(_opening.text);
    if (_name.text.trim().isEmpty) return AppStrings.integerOnly;
    if (_opening.text.trim().isNotEmpty && opening == null) {
      return AppStrings.integerOnly;
    }
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .create(
            widget.section,
            CreateAccountRequest(
              name: _name.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              openingBalance: opening,
            ),
            meta,
          );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      Navigator.of(context).pop(true);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _AssignSubmit extends ConsumerStatefulWidget {
  const _AssignSubmit({
    required this.section,
    required this.customerIds,
    required this.online,
  });

  final AccountSection section;
  final List<String> customerIds;
  final bool online;

  @override
  ConsumerState<_AssignSubmit> createState() => _AssignSubmitState();
}

class _AssignSubmitState extends ConsumerState<_AssignSubmit> {
  String? _assignee;

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(assigneesProvider);
    return people.when(
      loading: () => const SkeletonBox(height: 48),
      error: (error, _) => ErrorPane(
        message: ref.read(errorHandlerProvider).toFailure(error).message,
        onRetry: () => ref.invalidate(assigneesProvider),
      ),
      data: (rows) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Column(
          key: const Key('assignee-field'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.assignee, style: theme.textTheme.titleSmall),
            if (!widget.online) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.offline,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty)
              Text(AppStrings.noAssignees, style: theme.textTheme.bodyMedium)
            else
              for (final row in rows)
                _AssigneeChoice(
                  id: '${row['id']}',
                  label: '${row['displayName'] ?? row['id']}',
                  selected: _assignee == '${row['id']}',
                  onSelected: (id) => setState(() => _assignee = id),
                ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GuardedMutation(
                buttonKey: const Key('save-assignment'),
                inputs: '${widget.customerIds.join(",")}|$_assignee',
                label: AppStrings.assign,
                onSubmit: _submit,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final assignee = _assignee;
    if (assignee == null || widget.customerIds.isEmpty) {
      return AppStrings.chooseAssignee;
    }
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .assign(
            customerIds: widget.customerIds,
            assigneeUserId: assignee,
            section: widget.section.path,
            meta: meta,
          );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(accountsProvider(widget.section));
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

/// One column when text is large enough that two cards would be unreadably
/// narrow. [width] is the screen width in logical pixels.
int accountListColumns(double width, {double textScale = 1}) {
  final scale = textScale <= 0 ? 1.0 : textScale;
  return AppBreakpoints.cardColumns(width / scale);
}

/// Amounts and phone numbers stay left-to-right and sit on the RTL start edge.
class _StartAlignedText extends StatelessWidget {
  const _StartAlignedText(this.text, {required this.style, this.mono = false});

  final String text;
  final TextStyle style;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.end,
        softWrap: true,
        style: mono
            ? style.copyWith(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: const ['Cairo'],
              )
            : style,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.amountStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final TextStyle amountStyle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: valueStyle),
          const SizedBox(height: AppSpacing.xs),
          _StartAlignedText(value, style: amountStyle, mono: true),
        ],
      ),
    );
  }
}

class _TickerLine extends StatelessWidget {
  const _TickerLine({
    required this.debt,
    required this.card,
    required this.money,
  });

  final OldDebtDto debt;
  final AccountCardDto? card;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final age = singleAgeText(
      serverLabel: debt.ageStatusLabel,
      ageStatus: debt.ageStatus,
      debtAgeDays: debt.debtAgeDays,
    );
    final currency = card?.currency ?? debt.currency;
    final units = card?.balanceUnits ?? debt.balanceUnits;
    final amount = currency == null
        ? AppStrings.dash
        : money.formatOrDash(units, currency);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(debt.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            _StartAlignedText(
              amount,
              style: context.textExtras.amount,
              mono: true,
            ),
            if (age != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(age, key: Key('ticker-age-${debt.id}')),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssigneeChoice extends StatelessWidget {
  const _AssigneeChoice({
    required this.id,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String id;
  final String label;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: () => onSelected(id),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
