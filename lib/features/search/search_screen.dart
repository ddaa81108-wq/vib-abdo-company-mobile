import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

/// Website `GlobalAccountSearch`: live suggestions from `GET /api/account-search`.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const screenKey = Key('screen-search');

  /// Same delay as the website (`window.setTimeout(..., 250)`).
  static const debounce = Duration(milliseconds: 250);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Timer? _timer;
  var _items = <GlobalAccountHit>[];
  var _busy = false;
  var _openError = '';
  var _ticket = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text;
    final trimmed = query.trim();
    final showResults = trimmed.length >= 2;
    return ListView(
      key: SearchScreen.screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.search),
        TextField(
          key: const Key('unified-search'),
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    key: const Key('search-clear'),
                    tooltip: AppStrings.searchClear,
                    onPressed: () => _onChanged(''),
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: (_) => _openFirst(),
        ),
        if (_openError.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: Text(_openError, key: const Key('search-open-error')),
          ),
        if (showResults)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: _Results(
              busy: _busy,
              items: _items,
              onLedger: (hit) => _open(hit, card: false),
              onCard: (hit) => _open(hit, card: true),
            ),
          ),
      ],
    );
  }

  void _onChanged(String value) {
    if (value != _query.text) {
      _query.text = value;
      _query.selection = TextSelection.collapsed(offset: value.length);
    }
    _timer?.cancel();
    final ticket = ++_ticket;
    final trimmed = value.trim();
    setState(() {
      _items = [];
      _openError = '';
      _busy = trimmed.length >= 2;
    });
    if (trimmed.length < 2) return;
    _timer = Timer(SearchScreen.debounce, () {
      unawaited(_fetch(ticket, trimmed));
    });
  }

  Future<void> _fetch(int ticket, String query) async {
    final userId = _signedInUserId();
    try {
      final items = await ref.read(apiLayerProvider).accounts.search(query);
      if (!_current(ticket, query, userId)) return;
      setState(() {
        _items = items;
        _busy = false;
      });
    } catch (_) {
      if (!_current(ticket, query, userId)) return;
      setState(() {
        _items = [];
        _busy = false;
      });
    }
  }

  void _openFirst() {
    if (_busy || _items.isEmpty) return;
    unawaited(_open(_items.first, card: false));
  }

  Future<void> _open(GlobalAccountHit hit, {required bool card}) async {
    setState(() => _openError = '');
    try {
      final path = card
          ? '/${hit.section.path}?card=${hit.id}'
          : '/${hit.section.path}/${hit.id}';
      if (!mounted) return;
      context.go(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _openError = AppStrings.searchOpenFailed);
    }
  }

  bool _current(int ticket, String query, String? userId) {
    if (!mounted || ticket != _ticket || _query.text.trim() != query) {
      return false;
    }
    final session = ref.read(sessionStateProvider);
    return session is SessionAuthenticated && session.profile.id == userId;
  }

  String? _signedInUserId() {
    final session = ref.read(sessionStateProvider);
    return session is SessionAuthenticated ? session.profile.id : null;
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.busy,
    required this.items,
    required this.onLedger,
    required this.onCard,
  });

  final bool busy;
  final List<GlobalAccountHit> items;
  final ValueChanged<GlobalAccountHit> onLedger;
  final ValueChanged<GlobalAccountHit> onCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('search-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy)
          const Padding(
            padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(AppStrings.searchBusy, key: Key('search-loading')),
          ),
        if (!busy && items.isEmpty)
          const Text(AppStrings.searchNoAccounts, key: Key('search-empty')),
        for (final item in items)
          _Hit(item: item, onLedger: onLedger, onCard: onCard),
      ],
    );
  }
}

class _Hit extends StatelessWidget {
  const _Hit({
    required this.item,
    required this.onLedger,
    required this.onCard,
  });

  final GlobalAccountHit item;
  final ValueChanged<GlobalAccountHit> onLedger;
  final ValueChanged<GlobalAccountHit> onCard;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final debt =
        item.section == AccountSection.customers ||
        item.section == AccountSection.companies;
    final assigned = item.activeAssignmentId != null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: look.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: Key('search-hit-${item.section.path}-${item.id}'),
              onTap: () => onLedger(item),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: cairo(15, 800, color: look.ink),
                          ),
                          Text(
                            _sectionTitle(item.section),
                            style: cairo(12, 600, color: look.muted),
                          ),
                          if (debt)
                            Text(
                              assigned
                                  ? 'موجّه إلى: ${item.activeAssigneeName ?? AppStrings.searchAssigneeFallback}'
                                  : AppStrings.searchUnassigned,
                              style: cairo(12, 600, color: look.muted),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _amount(item),
                          textDirection: TextDirection.ltr,
                          style: cairo(16, 800, color: look.ink),
                        ),
                        Text(
                          item.currency.symbol,
                          style: cairo(11, 700, color: look.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (debt)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: Key('search-card-${item.section.path}-${item.id}'),
                  onPressed: () => onCard(item),
                  child: const Text(AppStrings.searchShowCard),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _sectionTitle(AccountSection section) => switch (section) {
  AccountSection.customers => 'قسم ديون العملاء',
  AccountSection.companies => 'قسم ديون الشركات',
  AccountSection.libyanDeposits => 'أمانات ليبية',
  AccountSection.egyptianDeposits => 'أمانات مصرية',
};

String _amount(GlobalAccountHit hit) {
  final balance = hit.balanceUnits;
  if (balance == null) return AppStrings.dash;
  if (balance.isInvalid) return MoneyValue.invalidLabel;
  final units = balance.asInt;
  if (units == null) return AppStrings.dash;
  final raw = units.toString();
  final digits = raw.startsWith('-') ? raw.substring(1) : raw;
  return const MoneyFormatter().formatNumber(int.parse(digits));
}
