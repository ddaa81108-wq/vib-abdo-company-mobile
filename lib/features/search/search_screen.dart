import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/app_failure.dart';
import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const screenKey = Key('screen-search');

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  final _results = <SectionKey, List<AccountSuggestionDto>>{};
  var _busy = false;
  AppFailure? _failure;

  static const _sections = [
    AccountSection.customers,
    AccountSection.companies,
    AccountSection.libyanDeposits,
    AccountSection.egyptianDeposits,
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: SearchScreen.screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.search),
        TextField(
          key: const Key('unified-search'),
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: AppStrings.searchHint),
          onSubmitted: (_) => _run(),
        ),
        if (_busy) const SkeletonBox(key: Key('search-loading'), height: 48),
        if (_failure != null)
          failurePane(
            _failure!,
            onRetry: _run,
            retryKey: const Key('search-retry'),
          ),
        if (!_busy &&
            _failure == null &&
            _query.text.isNotEmpty &&
            _results.values.every((items) => items.isEmpty))
          const EmptyPane(message: AppStrings.noResults),
        for (final entry in _results.entries)
          if (entry.value.isNotEmpty) ...[
            Text(sectionLabel(entry.key), style: Theme.of(context).textTheme.titleSmall),
            for (final item in entry.value)
              ListTile(
                title: Text(item.name),
                subtitle: item.phone == null ? null : LtrText(item.phone!),
                onTap: () => context.go('/${entry.key.key}/${item.id}'),
              ),
          ],
      ],
    );
  }

  Future<void> _run() async {
    final permissions = permissionsOf(ref);
    final query = _query.text.trim();
    setState(() {
      _busy = true;
      _failure = null;
      _results.clear();
    });
    try {
      for (final section in _sections) {
        if (!permissions.canRead(section.sectionKey)) continue;
        final items = await ref.read(apiLayerProvider).accounts.suggestions(section, query);
        _results[section.sectionKey] = items;
      }
    } catch (error) {
      if (!mounted) return;
      _failure = ref.read(errorHandlerProvider).toFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
