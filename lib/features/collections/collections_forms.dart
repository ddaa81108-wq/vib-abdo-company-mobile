import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../state/collection_request_journal.dart';
import '../../state/section_providers.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
import 'collection_send.dart';
import 'collections_strings.dart';
import 'egyptian_link_pause.dart';

/// استلام جزئي on one assigned card (website `PartialReceiptForm`).
class PartialReceiptForm extends ConsumerStatefulWidget {
  const PartialReceiptForm({required this.assignment, super.key});

  final CollectionAssignmentDto assignment;

  @override
  ConsumerState<PartialReceiptForm> createState() => _PartialReceiptFormState();
}

class _PartialReceiptFormState extends ConsumerState<PartialReceiptForm> {
  final _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _amount.removeListener(_changed);
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Column(
      key: const Key('partial-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CollectionsText.partialReceipt,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          widget.assignment.customerName,
          style: cairo(13, 600, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('assignment-amount'),
          controller: _amount,
          label: CollectionsText.amount,
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-assignment'),
          inputs: 'partial:${widget.assignment.id}:${_amount.text}',
          label: CollectionsText.save,
          onVersionConflict: () => ref.invalidate(collectionsProvider),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta _) async {
    final units = parseUnits(_amount.text);
    if (units == null || units <= 0) return CollectionsText.amountRequired;
    final outcome = await sendAssignmentReceipt(
      ref,
      assignmentId: widget.assignment.id,
      mode: 'partial',
      amountUnits: units,
    );
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == CollectionSendOutcome.alreadyRecorded
              ? CollectionsText.alreadyRecorded
              : CollectionsText.sent,
        ),
      ),
    );
    Navigator.of(context).pop();
    return null;
  }
}

/// إنشاء عميل مستقل: name and amount only. An unconfirmed earlier send
/// reopens with its saved inputs locked, so the retry is the same request.
class UnlinkedReceiptForm extends ConsumerStatefulWidget {
  const UnlinkedReceiptForm({super.key});

  @override
  ConsumerState<UnlinkedReceiptForm> createState() =>
      _UnlinkedReceiptFormState();
}

class _UnlinkedReceiptFormState extends ConsumerState<UnlinkedReceiptForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  CollectionAttempt? _open;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _amount.addListener(_changed);
    _open = ref
        .read(collectionRequestJournalProvider.notifier)
        .pending(collectionsUserId(ref), unlinkedSlot);
    final open = _open;
    if (open != null) {
      final cut = open.fingerprint.lastIndexOf('|');
      _name.text = open.fingerprint.substring(0, cut);
      _amount.text = open.fingerprint.substring(cut + 1);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_changed);
    _amount.removeListener(_changed);
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final locked = _open != null;
    return Column(
      key: const Key('unlinked-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CollectionsText.createStandalone,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          CollectionsText.createNote,
          style: cairo(12, 500, color: look.muted),
        ),
        if (locked) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            CollectionsText.unconfirmed,
            key: const Key('unlinked-unconfirmed'),
            style: cairo(12, 700, color: look.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('unlinked-name'),
          controller: _name,
          readOnly: locked,
          maxLength: 160,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: CollectionsText.customerName,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IgnorePointer(
          ignoring: locked,
          child: UnitsField(
            key: const Key('unlinked-amount'),
            controller: _amount,
            label: CollectionsText.receivedAmount,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-unlinked'),
          inputs: '${_name.text}|${_amount.text}',
          label: locked
              ? CollectionsText.retrySend
              : CollectionsText.registerPending,
          onVersionConflict: () => ref.invalidate(collectionsProvider),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta _) async {
    final name = _name.text.trim();
    final units = parseUnits(_amount.text);
    if (name.length < 2) return CollectionsText.nameRequired;
    if (units == null || units <= 0) return CollectionsText.amountRequired;
    await sendUnlinkedReceipt(ref, customerName: name, amountUnits: units);
    if (!mounted) return null;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(CollectionsText.sent)));
    Navigator.of(context).pop();
    return null;
  }
}

/// ربط استلام بكارت أصلي. Linking to an existing card only ever uses a
/// row the server offered (`link-candidates`); there is no free id entry.
/// Egyptian-deposit rows stay hidden (DEF-035). [createNew] opens on
/// «عميل جديد» (the server creates the card on approval).
class LinkReceiptForm extends ConsumerStatefulWidget {
  const LinkReceiptForm({
    required this.receipt,
    required this.createNew,
    super.key,
  });

  final UnlinkedReceiptDto receipt;
  final bool createNew;

  @override
  ConsumerState<LinkReceiptForm> createState() => _LinkReceiptFormState();
}

class _LinkReceiptFormState extends ConsumerState<LinkReceiptForm> {
  late final _query = TextEditingController(text: widget.receipt.customerName);
  late bool _createNew = widget.createNew;
  List<CollectionLinkCandidateDto> _offered = const [];
  String? _selected;
  var _entryType = 'payment';
  var _newKind = 'customer';
  var _searching = false;
  var _searched = false;
  String? _searchError;
  var _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _searchError = CollectionsText.minTwo);
      return;
    }
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final rows = await ref
          .read(apiLayerProvider)
          .collections
          .linkCandidateRows(q);
      if (!mounted || generation != _generation) return;
      // Card ids are unique on the server; keep the first row per id so a
      // repeated row cannot break the list.
      final seen = <String>{};
      setState(() {
        _offered = [
          for (final row in rows)
            if (!isEgyptianDepositSection(row.sectionKey) && seen.add(row.id))
              row,
        ];
        if (!_offered.any((row) => row.id == _selected)) _selected = null;
        _searched = true;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _searchError = CollectionsText.searchFailed);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final money = ref.watch(apiLayerProvider).money;
    final receipt = widget.receipt;
    return Column(
      key: const Key('link-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CollectionsText.linkTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          '${receipt.customerName} — ${money.formatOrDash(receipt.amountUnits, Currency.lyd)}',
          style: cairo(13, 600, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          key: const Key('link-mode'),
          segments: const [
            ButtonSegment(
              value: false,
              label: Text(CollectionsText.existingCustomer),
            ),
            ButtonSegment(
              value: true,
              label: Text(CollectionsText.newCustomer),
            ),
          ],
          selected: {_createNew},
          onSelectionChanged: (value) =>
              setState(() => _createNew = value.single),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_createNew) ...[
          Text(
            AppStrings.egyptianLinkPaused,
            key: const Key('egyptian-link-paused'),
            style: cairo(12, 500, color: look.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('link-customer'),
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: CollectionsText.searchAll,
                    errorText: _searchError,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                key: const Key('link-search'),
                tooltip: CollectionsText.search,
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_offered.isEmpty)
            Text(
              CollectionsText.searchHint,
              key: Key(_searched ? 'link-no-candidates' : 'link-search-hint'),
              style: cairo(12, 500, color: look.muted),
            ),
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
            child: Column(
              children: [
                for (final row in _offered)
                  RadioListTile<String>(
                    key: Key('link-candidate-${row.id}'),
                    value: row.id,
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.name),
                    subtitle: Text(
                      CollectionsText.candidateSection(row.sectionKey),
                    ),
                    secondary: MoneyText(
                      money.formatOrDash(row.balanceUnits, Currency.lyd),
                      style: cairo(13, 700, color: look.ink),
                    ),
                  ),
              ],
            ),
          ),
        ] else ...[
          Text(
            CollectionsText.newPlace,
            style: cairo(13, 700, color: look.ink),
          ),
          RadioGroup<String>(
            groupValue: _newKind,
            onChanged: (value) =>
                setState(() => _newKind = value ?? 'customer'),
            child: const Column(
              children: [
                RadioListTile<String>(
                  key: Key('link-new-customer'),
                  value: 'customer',
                  contentPadding: EdgeInsets.zero,
                  title: Text(CollectionsText.newCustomers),
                ),
                RadioListTile<String>(
                  key: Key('link-new-company'),
                  value: 'company',
                  contentPadding: EdgeInsets.zero,
                  title: Text(CollectionsText.newCompanies),
                ),
              ],
            ),
          ),
          Text(
            CollectionsText.newNote(receipt.customerName),
            style: cairo(12, 500, color: look.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(CollectionsText.entryType, style: cairo(13, 700, color: look.ink)),
        RadioGroup<String>(
          groupValue: _entryType,
          onChanged: (value) => setState(() => _entryType = value ?? 'payment'),
          child: const Column(
            children: [
              RadioListTile<String>(
                key: Key('link-entry-payment'),
                value: 'payment',
                contentPadding: EdgeInsets.zero,
                title: Text(CollectionsText.entryPayment),
              ),
              RadioListTile<String>(
                key: Key('link-entry-debt'),
                value: 'debt',
                contentPadding: EdgeInsets.zero,
                title: Text(CollectionsText.entryDebt),
              ),
            ],
          ),
        ),
        Text(
          CollectionsText.noEffectUntil,
          style: cairo(12, 500, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-link'),
          inputs:
              'link:${receipt.id}:$_createNew:${_selected ?? ''}:$_newKind:$_entryType',
          label: _createNew
              ? CollectionsText.newApprove
              : CollectionsText.linkApprove,
          onVersionConflict: () => ref.invalidate(collectionsProvider),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    if (!_createNew) {
      final chosen = _offered.where((row) => row.id == _selected);
      if (chosen.isEmpty) return CollectionsText.chooseCard;
      if (isEgyptianDepositSection(chosen.single.sectionKey)) {
        return AppStrings.egyptianLinkPaused;
      }
    }
    await ref
        .read(apiLayerProvider)
        .collections
        .decideUnlinked(
          widget.receipt.id,
          decision: CollectionDecision.approve,
          customerId: _createNew ? null : _selected,
          entryType: _entryType,
          newAccountKind: _createNew ? _newKind : null,
          meta: meta,
        );
    if (!mounted) return null;
    ref.invalidate(collectionsProvider);
    Navigator.of(context).pop();
    return null;
  }
}
