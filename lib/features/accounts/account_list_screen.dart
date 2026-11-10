import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../performance/history_window.dart';
import '../../error_handling/app_failure.dart';
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
import '../../ui/widgets/section_kit.dart';
import '../../ui/widgets/mutation_form.dart';
import 'account_list_logic.dart';
import 'zero_review_preview.dart';
import 'account_name_suggestions.dart';
import 'company_card_tone.dart';
import 'customer_card_tone.dart';

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
  var _assigning = false;
  var _showAllDebts = false;
  var _paging = false;
  String? _moreError;
  var _scrollArmed = true;
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
    ref.listen(accountsProvider(section), (previous, next) {
      if (!next.isRefreshing && !next.isReloading) return;
      ref.read(accountExtraCardsProvider(section).notifier).clear();
    });
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(section.sectionKey)) {
      return const ForbiddenPane();
    }
    final page = ref.watch(accountsProvider(section));
    final extra = ref.watch(accountExtraCardsProvider(section));
    final online = ref.watch(onlineProvider);
    final money = ref.watch(apiLayerProvider).money;
    final canWrite = permissions.canWrite(section.sectionKey);
    final home = ref.watch(homeDashboardProvider);
    final width = MediaQuery.sizeOf(context).width;
    final gridColumns = accountListColumns(
      width,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    // Customers and companies share the debt-card design (the website's
    // `customers || companies` layout): two equal cards per row on every
    // phone (Ali, 2026-11-02; companies 2026-11-03). Each keeps its own data.
    final isCustomers = section == AccountSection.customers;
    final debtLook = isDebtLookSection(section);
    final columns = debtLook && gridColumns < 2 ? 2 : gridColumns;

    final Widget searchField = TextField(
      key: const Key('account-search'),
      controller: _search,
      textInputAction: TextInputAction.search,
      // Fills the toolbar height like the two buttons.
      expands: debtLook,
      maxLines: debtLook ? null : 1,
      textAlignVertical: debtLook ? TextAlignVertical.center : null,
      decoration: InputDecoration(
        labelText: debtLook ? null : AppStrings.filterSearch,
        hintText: debtLook ? AppStrings.filterSearch : null,
        hintMaxLines: 1,
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
                ref.read(accountExtraCardsProvider(section).notifier).clear();
                ref.read(accountQueryProvider(section).notifier).state = '';
              },
            );
          },
        ),
      ),
      onSubmitted: (value) {
        ref.read(accountExtraCardsProvider(section).notifier).clear();
        ref.read(accountQueryProvider(section).notifier).state = value;
      },
    );
    final Widget addButton = GatedButton(
      buttonKey: const Key('add-account'),
      allowed: permissions.canWrite(section.sectionKey),
      online: online,
      label: _addLabel,
      onPressed: () => _create(context),
    );
    final Widget assignButton = GatedButton(
      buttonKey: const Key('assign-mode'),
      allowed: _canAssign(permissions),
      online: online,
      filled: false,
      label: AppStrings.assign,
      onPressed: () => setState(() {
        _assigning = !_assigning;
        _selected.clear();
      }),
    );

    final deposits =
        section == AccountSection.libyanDeposits ||
        section == AccountSection.egyptianDeposits;
    final Widget body = KeptData<AccountsPage>(
      value: page,
      resetKey: section,
      expand: true,
      onRetry: () => ref.invalidate(accountsProvider(section)),
      messageOf: _message,
      failureOf: _failure,
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
        final session = ref.watch(sessionStateProvider);
        final userId = session is SessionAuthenticated
            ? session.profile.id
            : null;
        final ack = ref.watch(zeroReviewAckProvider(section));
        final loaded = [
          for (final card in [...data.page.items, ...extra])
            _reviewFromServer(card, ack, userId),
        ];
        final cards = settledZeroReviewsLast(loaded);
        HistoryWindowTrace.accountWindow = [for (final card in cards) card.id];
        return RefreshIndicator(
          key: const Key('accounts-refresh'),
          onRefresh: () async {
            ref.read(accountExtraCardsProvider(section).notifier).clear();
            ref.invalidate(accountsProvider(section));
            await ref.read(accountsProvider(section).future);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) =>
                _onCardsScroll(notification, data.page.nextCursor),
            child: ListView(
              key: Key('screen-${section.path}'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(width)
                  .copyWith(bottom: pagePadding(width).bottom + 32),
              children: [
                // Customers and companies: no page title (Ali, 2026-11-02).
                // Deposits: the toolbar already names the section (Ali, t348).
                if (!debtLook && !deposits) ...[
                  ScreenTitle(sectionLabel(section.sectionKey)),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_showTicker)
                  _ticker(
                    home,
                    money,
                    width,
                    cards,
                    data.page.nextCursor,
                    HistoryWindow.trimEnabled &&
                            data.page.items.length > HistoryWindow.eagerLimit
                        ? HistoryWindow.retainLimit
                        : null,
                  ),
                // Deposits: الإجمالي, النشط, إضافة أمانة on one row, then a
                // full-width search. The Egyptian rate stays under that search.
                if (deposits)
                  _DepositTopRow(
                    summary: data.summary,
                    currency: section.currency,
                    money: money,
                    add: addButton,
                  )
                else
                  _SummaryStrip(
                    section: section,
                    summary: data.summary,
                    currency: section.currency,
                    money: money,
                  ),
                const SizedBox(height: AppSpacing.md),
                // Customers and companies: no filter chips (Ali, 2026-11-02).
                // Deposits: no filter chips (Ali, 2026-11-04).
                if (!debtLook && !deposits) ...[
                  _Tabs(section: section, summary: data.summary),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (debtLook)
                  _CustomersToolbar(
                    toolbarKey: Key(
                      isCustomers ? 'customers-toolbar' : 'companies-toolbar',
                    ),
                    add: addButton,
                    search: searchField,
                    assign: assignButton,
                  )
                else ...[
                  searchField,
                  if (section == AccountSection.egyptianDeposits)
                    const _RateCard(),
                  // Deposits: add sits in the top row.
                  if (!deposits) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [addButton, assignButton],
                    ),
                  ],
                ],
                if (_assigning)
                  _AssignSubmit(
                    section: section,
                    customerIds: assignmentTargetIds(_selected, cards),
                    online: online,
                    onCancel: () => setState(() {
                      _assigning = false;
                      _selected.clear();
                    }),
                    onAssigned: (message) => setState(() {
                      _assigning = false;
                      _selected.clear();
                      _reply = message;
                    }),
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
                else if (cards.length <= HistoryWindow.eagerLimit)
                  _cardWrap(
                    cards: cards,
                    columns: columns,
                    canWrite: canWrite,
                    permissions: permissions,
                  )
                else
                  debtLook
                      ? ListView.builder(
                          key: const Key('account-cards-list'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (cards.length + 1) ~/ 2,
                          itemBuilder: (context, row) => Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SizedBox(
                              height: customerCardHeight(context),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final i in [row * 2, row * 2 + 1]) ...[
                                    if (i == row * 2 + 1)
                                      const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: i < cards.length
                                          ? _accountCard(
                                              card: cards[i],
                                              canWrite: canWrite,
                                              permissions: permissions,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: const Key('account-cards-list'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cards.length,
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _accountCard(
                                card: card,
                                canWrite: canWrite,
                                permissions: permissions,
                              ),
                            );
                          },
                        ),
                if (_moreError != null)
                  Text(
                    _moreError!,
                    key: const Key('load-more-accounts-error'),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                if (_loadMoreCursor(data.page.nextCursor) != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const Key('load-more-accounts'),
                      onPressed: online && !_paging
                          ? () => _more(
                              _loadMoreCursor(data.page.nextCursor)!,
                              retainLimit: _accountRetainLimit(data.page.items),
                            )
                          : null,
                      child: const Text(AppStrings.loadMore),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    // Deposits use the app's gold buttons (Ali's device shots).
    return deposits ? SectionTheme(child: body) : body;
  }

  /// Approved by Ali on 2026-10-22, enabled by default.
  /// Off, the button keeps the previous cursor behaviour.
  /// On, it follows the newest prefix and keeps [HistoryWindow.retainLimit]
  /// extra rows. A later press reloads the oldest page that was dropped.
  String? _loadMoreCursor(String? firstPageCursor) {
    if (!HistoryWindow.trimEnabled) return firstPageCursor;
    return ref
        .read(accountExtraCardsProvider(section).notifier)
        .cursorAfter(firstPageCursor);
  }

  int? _accountRetainLimit(List<AccountCardDto> firstPage) {
    if (!HistoryWindow.trimEnabled) return null;
    if (firstPage.length <= HistoryWindow.eagerLimit) return null;
    return HistoryWindow.retainLimit;
  }

  Widget _cardWrap({
    required List<AccountCardDto> cards,
    required int columns,
    required bool canWrite,
    required PermissionService permissions,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _cardWidth(constraints.maxWidth, columns);
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                height: isDebtLookSection(section)
                    ? customerCardHeight(context)
                    : null,
                child: _accountCard(
                  card: card,
                  canWrite: canWrite,
                  permissions: permissions,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _accountCard({
    required AccountCardDto card,
    required bool canWrite,
    required PermissionService permissions,
  }) {
    return _AccountCard(
      section: section,
      card: card,
      money: ref.watch(apiLayerProvider).money,
      canWrite: canWrite && !card.systemManaged,
      assigning: _assigning,
      selected: _selected.contains(card.id),
      onOpen: () => context.go('/${section.path}/${card.id}'),
      onToggle: () => setState(() {
        if (!canSelectAccountForAssignment(card)) return;
        _selected.contains(card.id)
            ? _selected.remove(card.id)
            : _selected.add(card.id);
      }),
      onPin: (meta) => _pin(card, meta),
      zeroOnline: ref.watch(onlineProvider),
      onZeroPreview:
          showCustomerZeroReview(
            permissions: permissions,
            section: section,
            card: card,
          )
          ? () => _openZeroPreview(card)
          : null,
    );
  }

  double _cardWidth(double maxWidth, int columns) {
    if (columns <= 1 || maxWidth <= 0) return maxWidth;
    final raw = (maxWidth - AppSpacing.md * (columns - 1)) / columns;
    final min = isDebtLookSection(section) ? 120.0 : 160.0;
    if (raw < min) return maxWidth;
    return raw.clamp(min, maxWidth);
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
    String? nextCursor,
    int? retainLimit,
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
      // Its own Material, so its ink stays visible under page transitions.
      return Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
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
                onPressed: () => _showAll(nextCursor, retainLimit: retainLimit),
                child: const Text(AppStrings.showAll),
              ),
            ),
          ],
        ),
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

  AppFailure _failure(Object error) =>
      ref.read(errorHandlerProvider).toFailure(error);

  String _message(Object error) => failureText(_failure(error));

  bool _onCardsScroll(ScrollNotification notification, String? firstCursor) {
    if (notification is! ScrollUpdateNotification) return false;
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent > 0 &&
        metrics.pixels < metrics.maxScrollExtent - 24) {
      _scrollArmed = true;
      return false;
    }
    if (!historyDraggedToEnd(notification)) return false;
    final cursor = _loadMoreCursor(firstCursor);
    if (!_scrollArmed || cursor == null || _paging) return false;
    _scrollArmed = false;
    _more(cursor, retainLimit: _accountRetainLimit(_firstPageItems()));
    return false;
  }

  List<AccountCardDto> _firstPageItems() {
    final page = ref.read(accountsProvider(section)).asData?.value;
    return page?.page.items ?? const [];
  }

  Future<void> _more(String cursor, {int? retainLimit}) async {
    if (_paging || !ref.read(onlineProvider)) return;
    _paging = true;
    if (mounted) setState(() => _moreError = null);
    try {
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
      if (ref.read(accountQueryProvider(section)).trim() != query) return;
      if (ref.read(accountFilterProvider(section)) != filter) return;
      ref
          .read(accountExtraCardsProvider(section).notifier)
          .append(
            next.page.items,
            nextCursor: next.page.nextCursor,
            retainLimit: retainLimit,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => _moreError = _message(error));
    } finally {
      _paging = false;
    }
  }

  /// Phone «عرض الكل»: keep the bulletin's existing flag, and load every
  /// remaining account page for the filter and search that are active now.
  void _showAll(String? firstPageCursor, {int? retainLimit}) {
    setState(() => _showAllDebts = true);
    if (!ref.read(onlineProvider)) return;
    final query = ref.read(accountQueryProvider(section)).trim();
    final filter = ref.read(accountFilterProvider(section));
    ref
        .read(accountExtraCardsProvider(section).notifier)
        .loadRemaining(
          firstPageCursor: firstPageCursor,
          retainLimit: retainLimit,
          fetch: (cursor) => ref
              .read(apiLayerProvider)
              .accounts
              .list(
                section,
                cursor: cursor,
                q: query.isEmpty ? null : query,
                filter: filter,
              ),
          stillCurrent: () =>
              mounted &&
              ref.read(accountQueryProvider(section)).trim() == query &&
              ref.read(accountFilterProvider(section)) == filter,
        );
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
        return failureText(ref.read(errorHandlerProvider).toFailure(error));
      }
      final message = failureText(
        ref.read(errorHandlerProvider).toFailure(error),
      );
      setState(() => _reply = message);
      return message;
    }
  }

  Future<void> _openZeroPreview(AccountCardDto card) async {
    final financial = zeroReviewFinancialVersion(card);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ZeroReviewPreview(
        name: card.name,
        balance: ref
            .read(apiLayerProvider)
            .money
            .formatOrDash(card.balanceUnits, card.currency),
        financialVersion: financial,
        onConfirm: financial == null
            ? null
            : () => _confirmZeroPreview(card.id, financial),
      ),
    );
  }

  Future<String?> _confirmZeroPreview(String id, int financial) async {
    final latest = _financialVersionNow(id);
    if (latest != financial) {
      return 'تغيرت بيانات الكارت. أعد فتح المعاينة.';
    }
    final current = _cardNow(id);
    if (current == null) return 'الكارت لم يعد في القائمة.';
    final message = await _zero(
      current,
      MutationMeta(expectedVersion: financial),
    );
    // The open preview owns the error. The list banner stays clear so the
    // same sentence is not painted twice behind the dialog.
    if (message != null && mounted) setState(() => _reply = null);
    return message;
  }

  AccountCardDto? _cardNow(String id) {
    final page = ref.read(accountsProvider(section)).asData?.value;
    final extra = ref.read(accountExtraCardsProvider(section));
    for (final card in [...?page?.page.items, ...extra]) {
      if (card.id == id) return card;
    }
    return null;
  }

  int? _financialVersionNow(String id) {
    final card = _cardNow(id);
    return card == null ? null : zeroReviewFinancialVersion(card);
  }

  Future<String?> _zero(AccountCardDto card, MutationMeta meta) async {
    if (meta.expectedVersion == null) {
      const message = 'لا يوجد إصدار مالي على الكارت. لم تُرسل مراجعة التصفير.';
      if (mounted) setState(() => _reply = message);
      return message;
    }
    final userId = _signedInId();
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .confirmZeroReview(section, card.id, meta);
      if (!mounted || _signedInId() != userId) return null;
      final review = ack.raw['zeroReview'];
      if (review is Map) {
        ref
            .read(zeroReviewAckProvider(section).notifier)
            .remember(
              userId: userId,
              cardId: card.id,
              review: Map<String, dynamic>.from(review),
            );
      }
      try {
        ref.invalidate(accountsProvider(section));
        await ref.read(accountsProvider(section).future);
        if (!mounted || _signedInId() != userId) return null;
        ref.read(zeroReviewAckProvider(section).notifier).forget(card.id);
      } catch (error) {
        if (!mounted || _signedInId() != userId) return null;
      }
      return null;
    } catch (error) {
      if (!mounted || _signedInId() != userId) return null;
      final message = failureText(
        ref.read(errorHandlerProvider).toFailure(error),
      );
      setState(() => _reply = message);
      ref.invalidate(accountsProvider(section));
      return message;
    }
  }

  String? _signedInId() {
    final session = ref.read(sessionStateProvider);
    return session is SessionAuthenticated ? session.profile.id : null;
  }

  AccountCardDto _reviewFromServer(
    AccountCardDto card,
    ZeroReviewAckState ack,
    String? userId,
  ) {
    if (userId == null || ack.userId != userId) return card;
    final review = ack.reviews[card.id];
    if (review == null) return card;
    return cardWithServerZeroReview(card, review);
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
    required this.section,
    required this.summary,
    required this.currency,
    required this.money,
  });

  final AccountSection section;
  final AccountsSummaryDto summary;
  final Currency currency;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Customers show only the server totalDebt, as the headline (Ali,
    // 2026-11-02). Other sections keep net and total.
    if (isDebtLookSection(section)) {
      final isCustomers = section == AccountSection.customers;
      final prefix = isCustomers ? 'customers' : 'companies';
      // Right: this section's own server netBalance (total debts minus credits). Left: server
      // activeCards. No client arithmetic (Ali, 2026-11-02).
      final count = summary.activeCards;
      // Glossy headline in both themes (Ali, 2026-11-03): vivid gradient,
      // white sheen, bright border, coloured glow, white text.
      final look = context.look;
      final gloss = look.glossHero;
      final label = theme.textTheme.titleSmall?.copyWith(
        color: look.onHeroMuted,
        fontWeight: FontWeight.w500,
      );
      final figure = context.textExtras.amountLarge.copyWith(
        color: look.heroFigure,
      );
      final radius = BorderRadius.circular(AppRadii.xxl);
      return DecoratedBox(
        key: Key('$prefix-summary'),
        decoration: gloss
            .decoration(radius)
            .copyWith(boxShadow: gloss.glowShadow),
        child: ClipRRect(
          borderRadius: radius,
          child: GlossSheen(
            gloss: gloss,
            radius: radius,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCustomers
                              ? AppStrings.customersTotalDebt
                              : AppStrings.netDebt,
                          style: label,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: MoneyText(
                            money.formatOrDash(
                              summary.netBalanceUnits,
                              currency,
                            ),
                            key: Key('$prefix-summary-amount'),
                            style: figure.copyWith(color: look.heroFigure),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    flex: 2,
                    // Scales down instead of breaking a word at large text.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.topEnd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isCustomers
                                ? AppStrings.activeCardsCount
                                : AppStrings.companiesActiveCards,
                            textAlign: TextAlign.end,
                            style: label,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            count == null ? AppStrings.dash : '$count',
                            key: Key('$prefix-summary-count'),
                            textDirection: TextDirection.ltr,
                            style: figure,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Deposits: the app's glossy gold headline (Ali's device shots).
    // Same two server figures; display only.
    const ink = Color(0xFF1A1300);
    const gold = Gloss(
      top: Color(0xFFFCD34D),
      bottom: Color(0xFFD97706),
      border: Color(0xFFFDE68A),
      glow: Color(0x40D97706),
      ink: ink,
      amount: ink,
      sheen: 0.22,
    );
    final radius = BorderRadius.circular(AppRadii.xxl);
    return DecoratedBox(
      decoration: gold.decoration(radius).copyWith(boxShadow: gold.glowShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: GlossSheen(
          gloss: gold,
          radius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                _Metric(
                  label: AppStrings.netDebt,
                  value: money.formatOrDash(summary.netBalanceUnits, currency),
                  valueStyle: theme.textTheme.titleSmall?.copyWith(color: ink),
                  amountStyle: context.textExtras.amountLarge.copyWith(
                    color: ink,
                  ),
                ),
                _Metric(
                  label: AppStrings.totalDebt,
                  value: money.formatOrDash(summary.totalDebtUnits, currency),
                  valueStyle: theme.textTheme.bodySmall?.copyWith(color: ink),
                  amountStyle: context.textExtras.amount.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row: الإجمالي (section net), النشط (active cards), إضافة أمانة.
/// Server figures only. The three stay side by side, including at text 1.3.
class _DepositTopRow extends StatelessWidget {
  const _DepositTopRow({
    required this.summary,
    required this.currency,
    required this.money,
    required this.add,
  });

  final AccountsSummaryDto summary;
  final Currency currency;
  final MoneyFormatter money;
  final Widget add;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gold = sectionGold(context);
    final on = onSectionGold(context);
    final count = summary.activeCards;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final total = DecoratedBox(
      key: const Key('deposit-total-pill'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(gold, Colors.white, 0.25)!, gold],
        ),
        border: Border.all(color: Color.lerp(gold, Colors.white, 0.4)!),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.depositTotalCompact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairo(11, 700, color: on),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: MoneyText(
                money.formatOrDash(summary.netBalanceUnits, currency),
                key: const Key('deposit-total'),
                style: context.textExtras.amount.copyWith(
                  color: on,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final active = DecoratedBox(
      key: const Key('deposit-active-pill'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: look.card,
        border: Border.all(color: gold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.depositActiveCompact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairo(11, 700, color: look.muted),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                count == null ? AppStrings.dash : '$count',
                key: const Key('deposit-active-count'),
                textDirection: TextDirection.ltr,
                style: cairo(15, 800, color: look.ink),
              ),
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      height: 58 * scale.clamp(1.0, 1.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: total),
          const SizedBox(width: 6),
          Expanded(child: active),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(fit: BoxFit.scaleDown, child: add),
          ),
        ],
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
    final tabs = accountListFilters(section);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                key: ValueKey('account-filter-${tab.id ?? 'all'}'),
                label: Text(_filterLabel(summary, tab)),
                selected: current == tab.id,
                onSelected: (_) {
                  ref.read(accountFilterProvider(section).notifier).state =
                      tab.id;
                },
              ),
            ),
        ],
      ),
    );
  }

  String _filterLabel(AccountsSummaryDto summary, AccountListFilter tab) {
    final count = accountFilterCount(summary, tab.count);
    if (count == null) return tab.label;
    return '${tab.label} $count';
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
    required this.onZeroPreview,
    required this.zeroOnline,
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
  final VoidCallback? onZeroPreview;
  final bool zeroOnline;

  /// Customers: name, value under it, the assigned employee if any, and the
  /// existing zero-review action as a check button (Ali, 2026-11-02).
  Widget _customerBody(
    BuildContext context, {
    required CustomerTone tone,
    required bool showAssign,
    required bool showZero,
  }) {
    final word = section == AccountSection.companies
        ? companyCardWord(companyCardKind(card.balanceUnits))
        : switch (customerBalanceKind(card.balanceUnits)) {
            CustomerBalanceKind.debt => AppStrings.customerDebtWord,
            CustomerBalanceKind.credit => AppStrings.customerCreditWord,
            _ => null,
          };
    final body = Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The facts clip instead of overflowing when text is large.
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          card.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: cairo(16, 800, color: tone.ink),
                        ),
                      ),
                      if (card.systemManaged)
                        Tooltip(
                          message: AppStrings.systemCard,
                          child: Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: tone.ink,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (word != null)
                    Text(
                      word,
                      key: Key('account-kind-${card.id}'),
                      style: cairo(12, 800, color: tone.amount),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: MoneyText(
                        money.formatOrDash(card.balanceUnits, card.currency),
                        style: context.textExtras.amountLarge.copyWith(
                          color: tone.amount,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  if (card.activeAssigneeName != null)
                    Text(
                      '${AppStrings.withEmployee}: ${card.activeAssigneeName}',
                      key: Key('account-assignee-${card.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairo(
                        12,
                        700,
                        color: tone.ink.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showAssign || showZero)
            Row(
              children: [
                if (showAssign)
                  SizedBox.square(
                    dimension: 32,
                    child: Checkbox(
                      key: ValueKey('assign-select-${card.id}'),
                      value: selected,
                      onChanged: (_) => onToggle(),
                    ),
                  ),
                const Spacer(),
                if (showZero)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: ValueKey('zero-review-${card.id}'),
                      tooltip: AppStrings.zeroReview,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: zeroOnline ? onZeroPreview : null,
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
    // Icons on the glossy card (lock, zero review) take the card ink.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        iconTheme: theme.iconTheme.copyWith(color: tone.ink),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: tone.ink,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: tone.ink),
        ),
      ),
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPin = canWrite;
    final showZero = onZeroPreview != null && !card.systemManaged;
    final showAssign = assigning && canSelectAccountForAssignment(card);
    final look0 = context.look;
    // Customers: debt / credit / zero tone from the balance sign (Ali,
    // 2026-11-02) instead of the age gradient.
    final CustomerTone tone = switch (section) {
      AccountSection.customers => customerTone(
        context,
        customerBalanceKind(card.balanceUnits),
      ),
      // Companies: the customers' colours from the company's own balance
      // sign (Ali, 2026-11-03).
      AccountSection.companies => _companyTone(
        companyCardGloss(context, companyCardKind(card.balanceUnits)),
      ),
      // Deposits (Ali's device shots): red for the server's overdue status
      // (دين على العميل / دين علينا للعميل), black for zero, green otherwise.
      _ => _companyTone(switch (card.ageStatus) {
        'overdue' => look0.glossDebt,
        'zero' => look0.glossZero,
        _ => look0.glossCredit,
      }),
    };
    // Every list card is glossy from its tone (customers, companies,
    // deposits).
    final Gloss gloss = tone.gloss ?? context.look.glossGrey;
    final radius = BorderRadius.circular(AppRadii.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: gloss.glowShadow,
      ),
      child: Material(
        key: Key('account-card-${card.id}'),
        color: tone.background,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gloss.fill,
            borderRadius: radius,
            border: Border.all(color: tone.border),
          ),
          child: InkWell(
            onTap: onOpen,
            child: GlossSheen(
              gloss: gloss,
              radius: radius,
              child: isDebtLookSection(section)
                  ? _customerBody(
                      context,
                      tone: tone,
                      showAssign: showAssign,
                      showZero: showZero,
                    )
                  : _depositBody(
                      context,
                      tone: tone,
                      // The status words (أمانة للعميل، دين على العميل،
                      // دين علينا للعميل، لصالح المنظومة) from the server.
                      age: ageVisual(
                        colors: context.statusColors,
                        ageStatus: card.ageStatus,
                        section: section,
                        // A day count (منذ N أيام) is not a status word.
                        serverLabel:
                            (card.ageStatusLabel ?? '').startsWith(
                              AppStrings.sinceDays,
                            )
                            ? null
                            : card.ageStatusLabel,
                      ).label,
                      showAssign: showAssign,
                      showPin: showPin,
                      showZero: showZero,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on _AccountCard {
  /// Deposit card (Ali's device shots): pin at the corner, status label,
  /// name, amount, then «آخر حركة» under a thin line. Server values only.
  Widget _depositBody(
    BuildContext context, {
    required CustomerTone tone,
    required String? age,
    required bool showAssign,
    required bool showPin,
    required bool showZero,
  }) {
    final ink = tone.ink;
    final gold = const Color(0xFFFBBF24);
    final last = card.lastActivityAt;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    age ?? '',
                    key: Key('account-age-${card.id}'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairo(11, 800, color: ink.withValues(alpha: 0.9)),
                  ),
                ),
                if (showPin)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1300).withValues(alpha: 0.7),
                      border: Border.all(color: gold.withValues(alpha: 0.8)),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(color: gold, size: 18),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: FittedBox(
                          child: GuardedMutation(
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
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              card.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: cairo(16, 800, color: ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MoneyText(
                  money.formatOrDash(card.balanceUnits, card.currency),
                  style: context.textExtras.amountLarge.copyWith(
                    color: tone.amount,
                  ),
                ),
              ),
            ),
            if (card.systemManaged)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: ink),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      AppStrings.systemCard,
                      style: cairo(10.5, 800, color: ink),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Divider(height: 1, color: ink.withValues(alpha: 0.25)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${AppStrings.lastActivity}: ${formatIsoDate(last)}'
              '${last == null ? '' : '، ${_clockText(last)}'}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairo(10.5, 700, color: ink.withValues(alpha: 0.9)),
            ),
            if (card.activeAssigneeName != null)
              Text(
                '${AppStrings.withEmployee}: ${card.activeAssigneeName}',
                textAlign: TextAlign.center,
                style: cairo(10.5, 600, color: ink.withValues(alpha: 0.85)),
              ),
            if (showAssign || showZero)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showAssign)
                    Checkbox(
                      key: ValueKey('assign-select-${card.id}'),
                      value: selected,
                      onChanged: (_) => onToggle(),
                    ),
                  if (showZero)
                    IconButton(
                      key: ValueKey('zero-review-${card.id}'),
                      tooltip: AppStrings.zeroReview,
                      onPressed: zeroOnline ? onZeroPreview : null,
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _clockText(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'ص' : 'م'}';
}

CustomerTone _companyTone(Gloss gloss) => CustomerTone(
  background: gloss.bottom,
  border: gloss.border,
  ink: gloss.ink,
  amount: gloss.amount,
  gloss: gloss,
);

/// One height for every customer card, grown with the text scale.
double customerCardHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
  return 128 * scale;
}

/// Customers: add on the right, search in the middle, assign on the left.
/// Very narrow or large-text screens put the buttons above the search.
class _CustomersToolbar extends StatelessWidget {
  const _CustomersToolbar({
    required this.toolbarKey,
    required this.add,
    required this.search,
    required this.assign,
  });

  final Key toolbarKey;
  final Widget add;
  final Widget search;
  final Widget assign;

  /// One height for all three controls, grown with the text scale.
  static double heightFor(double scale) => 24 + 28 * scale.clamp(1.0, 2.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = context.look;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = heightFor(scale);
    final radius = BorderRadius.circular(AppRadii.lg);
    final side = BorderSide(color: look.cardBorder);
    const padding = EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg);
    final outline = OutlineInputBorder(borderRadius: radius, borderSide: side);
    final themed = theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, height),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: radius),
          backgroundColor: look.button,
          foregroundColor: look.onButton,
          textStyle: cairo(15, 700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, height),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          foregroundColor: look.accent,
          backgroundColor: look.card,
          textStyle: cairo(15, 700),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        isDense: true,
        filled: true,
        fillColor: look.card,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: look.accent, width: 2),
        ),
      ),
    );
    Widget sized(Widget child) => SizedBox(height: height, child: child);
    return Theme(
      data: themed,
      child: LayoutBuilder(
        key: toolbarKey,
        builder: (context, constraints) {
          if (constraints.maxWidth / scale >= 330) {
            return Row(
              children: [
                sized(add),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: sized(search)),
                const SizedBox(width: AppSpacing.sm),
                sized(assign),
              ],
            );
          }
          // Narrow or large text: the two buttons share one row at equal
          // width, the search sits under them at the same height.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: sized(add)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: sized(assign)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              sized(search),
            ],
          );
        },
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
      color: context.look.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: sectionGold(context).withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: rate.when(
          loading: () => const SkeletonBox(height: 72),
          error: (error, _) => presentFailure(
            ref.read(errorHandlerProvider).toFailure(error),
            onRetry: () => ref.invalidate(exchangeRateProvider),
          ),
          data: (data) {
            final canEdit = permissions.canWrite(SectionKey.egyptianDeposits);
            final theme = Theme.of(context);
            final look = context.look;
            final current = money.formatDecimalOrDash(data.egpPerLyd);
            // One row (Ali's device shot): «سعر التحويل 1 د.ل =» [rate] ج.م
            // and a save symbol. The current server rate is the hint.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        AppStrings.rateRowLabel,
                        maxLines: 2,
                        style: cairo(13, 800, color: look.ink),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: canEdit
                          ? TextField(
                              key: const Key('rate-field'),
                              controller: _rate,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: cairo(15, 800, color: look.ink),
                              decoration: InputDecoration(
                                hintText: current,
                                isDense: true,
                                filled: true,
                                fillColor: look.page,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.lg,
                                  ),
                                ),
                              ),
                            )
                          : _StartAlignedText(
                              current,
                              style: context.textExtras.amount,
                              mono: true,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      Currency.egp.symbol,
                      style: cairo(13, 800, color: look.muted),
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: AppSpacing.xs),
                      GuardedMutation(
                        buttonKey: const Key('save-rate'),
                        inputs: _rate.text,
                        expectedVersion: data.version,
                        label: AppStrings.save,
                        glyph: Icons.save_outlined,
                        confirmText: AppStrings.confirm,
                        normalizedValue: DecimalString.tryParse(_rate.text)
                            ?.value,
                        onSubmit: _save,
                      ),
                    ],
                  ],
                ),
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
      final message = failureText(
        ref.read(errorHandlerProvider).toFailure(error),
      );
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
        AccountNameSuggestions(section: widget.section, query: _name.text),
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
    final message = createAccountValidationMessage(
      name: _name.text,
      opening: _opening.text,
    );
    if (message != null) return message;
    final opening = openingBalanceOrNull(_opening.text);
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
      return failureText(ref.read(errorHandlerProvider).toFailure(error));
    }
  }
}

class _AssignSubmit extends ConsumerStatefulWidget {
  const _AssignSubmit({
    required this.section,
    required this.customerIds,
    required this.online,
    required this.onCancel,
    required this.onAssigned,
  });

  final AccountSection section;
  final List<String> customerIds;
  final bool online;
  final VoidCallback onCancel;

  /// Called after a 201: the parent leaves assign mode and clears the ticks.
  final ValueChanged<String> onAssigned;

  @override
  ConsumerState<_AssignSubmit> createState() => _AssignSubmitState();
}

class _AssignSubmitState extends ConsumerState<_AssignSubmit> {
  String? _assignee;

  /// Ids and names of the assignees on screen. The first one is chosen by
  /// default, like the website (`items[0]?.id`).
  List<(String, String)> _people = const [];

  String? get _chosen =>
      _assignee ?? (_people.isEmpty ? null : _people.first.$1);

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(assigneesProvider);
    return people.when(
      loading: () => const SkeletonBox(height: 48),
      error: (error, _) => presentFailure(
        ref.read(errorHandlerProvider).toFailure(error),
        onRetry: () => ref.invalidate(assigneesProvider),
      ),
      data: (rows) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        _people = [
          for (final row in rows)
            ('${row['id']}', '${row['displayName'] ?? row['id']}'),
        ];
        final chosen = _chosen;
        return Column(
          key: const Key('assignee-field'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.assignSelected(widget.customerIds.length),
              key: const Key('assign-selected-count'),
              style: theme.textTheme.titleSmall,
            ),
            Text(AppStrings.assignHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
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
              for (final (id, label) in _people)
                _AssigneeChoice(
                  id: id,
                  label: label,
                  selected: chosen == id,
                  onSelected: (id) => setState(() => _assignee = id),
                ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                GuardedMutation(
                  buttonKey: const Key('save-assignment'),
                  inputs: '${widget.customerIds.join(",")}|$chosen',
                  label: AppStrings.assign,
                  onSubmit: _submit,
                ),
                TextButton(
                  key: const Key('assign-cancel'),
                  onPressed: widget.onCancel,
                  child: const Text(AppStrings.assignCancel),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final assignee = _chosen;
    if (assignee == null) return _tell(AppStrings.chooseAssignee);
    if (widget.customerIds.isEmpty) return _tell(AppStrings.chooseAssignCards);
    final name = [
      for (final (id, label) in _people)
        if (id == assignee) label,
    ].firstOrNull;
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
      // 537f073 answers 201 `{assignmentIds, eventSequences}`; there is no
      // single `id`, so the count comes from `assignmentIds`.
      final created = ack.raw['assignmentIds'];
      final count = created is List
          ? created.length
          : widget.customerIds.length;
      ref.invalidate(accountsProvider(widget.section));
      ref.invalidate(collectionsProvider);
      if (!mounted) return null;
      final message = AppStrings.assignDone(count, name ?? '');
      _tell(message);
      widget.onAssigned(message);
      return null;
    } catch (error) {
      final text = failureText(ref.read(errorHandlerProvider).toFailure(error));
      return _tell(text);
    }
  }

  /// Shows [message] in a snackbar as well as under the button, so a server
  /// refusal is never missed. Returns it for the inline error line.
  String _tell(String message) {
    final messenger = mounted ? ScaffoldMessenger.maybeOf(context) : null;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('assign-snackbar'),
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return message;
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
        style: mono ? style.copyWith(fontFamily: kAppFont) : style,
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
          MoneyText(value, style: amountStyle),
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
        ? (units != null && units.isInvalid
              ? MoneyValue.invalidLabel
              : AppStrings.dash)
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
            RichText(
              textDirection: Directionality.of(context),
              textAlign: TextAlign.start,
              text: TextSpan(
                text: debt.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            MoneyText(amount, style: context.textExtras.amount),
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
