import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../models/home_summary.dart';
import '../../notifications/unread_badge.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const shellKey = Key('home-shell');
  static const logoutKey = Key('logout-button');
  static const roleKey = Key('role-label');
  static const homeLoadingKey = Key('home-loading');

  static Key sectionKey(SectionKey section) => Key('section-${section.key}');
  static Key writeKey(SectionKey section) => Key('write-${section.key}');
  static Key actionKey(ManagementAction action) =>
      Key('action-${action.proposedCode}');
  static Key summaryKey(String cardKey) => Key('summary-$cardKey');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final unread = ref.watch(unreadCountProvider);
    final dashboard = ref.watch(homeDashboardProvider);
    final theme = Theme.of(context);

    if (summary == null) {
      return const Scaffold(body: Center(child: Text(AppStrings.loading)));
    }

    final permissions = ref.watch(apiLayerProvider).permissions;
    final money = ref.watch(apiLayerProvider).money;

    return Scaffold(
      key: shellKey,
      appBar: AppBar(
        title: const Text(AppStrings.homeTitle),
        actions: [
          UnreadBadge(count: unread.asData?.value),
          IconButton(
            key: logoutKey,
            tooltip: AppStrings.logout,
            onPressed: () => ref.read(sessionStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.signedInAs, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              summary.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(roleLabel(summary.role), key: roleKey),
            if (summary.mustChangePassword) ...[
              const SizedBox(height: 16),
              const _PasswordChangeBanner(),
            ],
            const SizedBox(height: 28),
            if (dashboard.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Center(
                  child: CircularProgressIndicator(key: homeLoadingKey),
                ),
              )
            else if (dashboard.asData?.value case final home?) ...[
              ..._serverCards(home, permissions, money, theme),
            ],
            if (summary.actions.isNotEmpty) ...[
              Text(AppStrings.actionsTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in summary.actions)
                    TextButton(
                      key: actionKey(action),
                      onPressed: () {},
                      child: Text(actionLabel(action)),
                    ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            Text(AppStrings.sectionsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              AppStrings.sectionsHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (summary.sections.isEmpty)
              const Text(AppStrings.noSections)
            else
              for (final section in summary.sections)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: sectionKey(section),
                    title: Text(sectionLabel(section)),
                    subtitle: const Text(AppStrings.comingSoon),
                    trailing: summary.writableSections.contains(section)
                        ? TextButton(
                            key: writeKey(section),
                            onPressed: () {},
                            child: const Text(AppStrings.writeAction),
                          )
                        : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  List<Widget> _serverCards(
    HomeDto home,
    PermissionService permissions,
    MoneyFormatter money,
    ThemeData theme,
  ) {
    final cards = [
      for (final card in home.summaries)
        if (sectionIsReadable(card.section, permissions)) card,
    ];
    final debts = [
      for (final debt in home.oldDebts ?? const <OldDebtDto>[])
        if (sectionIsReadable(debt.section, permissions)) debt,
    ];
    if (cards.isEmpty && debts.isEmpty && home.businessDate == null) {
      return const [];
    }
    return [
      Text(AppStrings.homeCardsTitle, style: theme.textTheme.titleMedium),
      if (home.businessDate != null) ...[
        const SizedBox(height: 4),
        Text(home.businessDate!, key: const Key('home-business-date')),
      ],
      const SizedBox(height: 8),
      for (final card in cards)
        Card(
          key: summaryKey(card.key),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(card.title),
            subtitle: Text(_cardDetail(card, money)),
          ),
        ),
      if (debts.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(AppStrings.oldDebtsTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final debt in debts)
          Card(
            key: Key('old-debt-${debt.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(debt.name),
              subtitle: Text(_debtDetail(debt, money)),
            ),
          ),
      ],
      const SizedBox(height: 20),
    ];
  }

  String _cardDetail(HomeSummaryDto card, MoneyFormatter money) {
    final lines = <String>[
      if (card.currency != null)
        money.formatOrDash(card.valueUnits, card.currency!),
      if (card.status != null) card.status!,
      if (card.note != null) card.note!,
    ];
    return lines.isEmpty ? '—' : lines.join('\n');
  }

  String _debtDetail(OldDebtDto debt, MoneyFormatter money) {
    final lines = <String>[
      if (debt.currency != null)
        money.formatOrDash(debt.balanceUnits, debt.currency!),
      if (debt.ageStatusLabel != null) debt.ageStatusLabel!,
    ];
    return lines.isEmpty ? '—' : lines.join('\n');
  }
}

class _PasswordChangeBanner extends StatelessWidget {
  const _PasswordChangeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(AppStrings.passwordChangeRequired),
      ),
    );
  }
}
