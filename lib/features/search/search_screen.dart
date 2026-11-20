import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../state/session_providers.dart';
import '../../state/section_providers.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import 'account_search_controller.dart';
import 'search_focus.dart';
import 'search_results.dart';

/// One paginated server search per permitted section, in either scope.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.originSection, super.key});

  final AccountSection? originSection;
  static const screenKey = Key('screen-search');
  static const debounce = AccountSearchController.debounce;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  late final AccountSearchController _search;

  @override
  void initState() {
    super.initState();
    _search = AccountSearchController(
      repository: () => ref.read(apiLayerProvider).accounts,
      canRead: (section) =>
          ref.read(apiLayerProvider).permissions.canRead(section.sectionKey),
      currentUserId: _signedInUserId,
    )..addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_changed);
    _search.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text;
    final permissions = ref.watch(apiLayerProvider).permissions;
    final sections = AccountSection.values.where(
      (section) => permissions.canRead(section.sectionKey),
    );
    return ListView(
      key: SearchScreen.screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const ScreenTitle(AppStrings.search),
        TextField(
          key: const Key('unified-search'),
          controller: _query,
          focusNode: ref.watch(searchInputFocusProvider),
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    key: const Key('search-clear'),
                    tooltip: AppStrings.searchClear,
                    onPressed: () {
                      _onChanged('');
                      ref.read(searchInputFocusProvider).requestFocus();
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: (_) => _openFirst(),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: const Key('search-scope'),
          initialValue: _search.scope?.path ?? 'all',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'نطاق البحث'),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('كل الحسابات')),
            for (final section in sections)
              DropdownMenuItem(
                value: section.path,
                child: Text(
                  section == widget.originSection
                      ? 'القسم الحالي: ${searchSectionTitle(section)}'
                      : searchSectionTitle(section),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (path) {
            _search.setScope(
              AccountSection.values
                  .where((section) => section.path == path)
                  .firstOrNull,
            );
            ref.read(searchInputFocusProvider).requestFocus();
          },
        ),
        if (_search.error.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_search.error, key: const Key('search-open-error')),
                TextButton(
                  key: const Key('search-retry'),
                  onPressed: _search.retry,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        if (query.trim().length >= 2)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: SearchResults(
              busy: _search.busy,
              failed: _search.error.isNotEmpty,
              items: _search.items,
              onLedger: (hit) => _open(hit, card: false),
              onCard: (hit) => _open(hit, card: true),
            ),
          ),
        if (_search.hasMore && !_search.busy)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: OutlinedButton(
              key: const Key('search-load-more'),
              onPressed: _search.paging
                  ? null
                  : () => unawaited(_search.loadMore()),
              child: Text(
                _search.paging ? AppStrings.searchBusy : AppStrings.loadMore,
              ),
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
    _search.search(value);
  }

  void _openFirst() {
    if (_search.busy || _search.items.isEmpty) return;
    _open(_search.items.first, card: false);
  }

  void _open(GlobalAccountHit hit, {required bool card}) {
    if (!ref
        .read(apiLayerProvider)
        .permissions
        .canRead(hit.section.sectionKey)) {
      return;
    }
    ref.read(searchInputFocusProvider).unfocus();
    if (card) {
      ref.read(accountQueryProvider(hit.section).notifier).state = '';
      ref.read(accountFilterProvider(hit.section).notifier).state = null;
      ref.read(accountExtraCardsProvider(hit.section).notifier).clear();
    }
    context.go(
      card
          ? Uri(
              path: '/${hit.section.path}',
              queryParameters: {'card': hit.id},
            ).toString()
          : '/${hit.section.path}/${Uri.encodeComponent(hit.id)}',
    );
  }

  String? _signedInUserId() {
    final session = ref.read(sessionStateProvider);
    return session is SessionAuthenticated ? session.profile.id : null;
  }
}
