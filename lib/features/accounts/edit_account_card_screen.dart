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
import '../../ui/widgets/mutation_form.dart';

/// Record action passed to [PermissionService.canOnRecord] when the server
/// sends `allowedActions`. The permission tests use this token.
const accountCardEditAction = 'edit';

/// Whether the edit control may be shown.
///
/// A system-managed card never shows a write control. Otherwise the server
/// record list wins when it is present, and section write
/// (`read` + `write` + `sectionAccess == manage`) is the fallback.
bool canEditAccountCard({
  required PermissionService permissions,
  required SectionKey section,
  required AccountCardDto card,
}) {
  if (card.systemManaged) return false;
  return permissions.canOnRecord(
    action: accountCardEditAction,
    allowedActions: card.allowedActions,
    section: section,
  );
}

/// Empty name is the only client-side rejection. The phone is free text.
String? validateAccountCardEdit({required String name}) {
  if (name.trim().isEmpty) return AppStrings.nameRequired;
  return null;
}

/// Body for [AccountsRepository.update]. Name and phone only.
///
/// An empty phone is sent as `''` so a cleared field is explicit. No balance,
/// opening balance, age, or other server value is included.
UpdateAccountRequest accountCardEditRequest({
  required String name,
  required String phone,
}) {
  return UpdateAccountRequest(name: name.trim(), phone: phone.trim());
}

/// Opens [EditAccountCardScreen]. Hidden unless [canEditAccountCard] is true.
class EditAccountCardButton extends ConsumerWidget {
  const EditAccountCardButton({
    required this.section,
    required this.card,
    super.key,
  });

  final AccountSection section;
  final AccountCardDto card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = canEditAccountCard(
      permissions: permissionsOf(ref),
      section: section.sectionKey,
      card: card,
    );
    if (!allowed) return const SizedBox.shrink();
    final online = ref.watch(onlineProvider);
    final button = GatedButton(
      buttonKey: const Key('edit-account-card'),
      allowed: true,
      online: online,
      filled: false,
      label: AppStrings.editCard,
      onPressed: () => context.push('/${section.path}/${card.id}/edit'),
    );
    final tight = layoutIsTight(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: tight
          ? SizedBox(
              width: double.infinity,
              child: Theme(data: _editStretchButtons(context), child: button),
            )
          : Align(alignment: AlignmentDirectional.centerStart, child: button),
    );
  }
}

/// Edits one account card. Reachable from the ledger.
///
/// Customers, companies, and both deposit sections share this screen.
class EditAccountCardScreen extends ConsumerWidget {
  const EditAccountCardScreen({
    required this.section,
    required this.id,
    super.key,
  });

  final AccountSection section;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(section.sectionKey)) return const ForbiddenPane();
    final card = ref.watch(accountCardProvider((section, id)));
    String messageOf(Object error) =>
        failureText(ref.read(errorHandlerProvider).toFailure(error));
    failureOf(Object error) => ref.read(errorHandlerProvider).toFailure(error);

    return Scaffold(
      key: Key('screen-edit-card-${section.path}'),
      body: KeptData<AccountCardDto>(
        value: card,
        resetKey: '${section.path}/$id/edit',
        expand: true,
        onRetry: () => ref.invalidate(accountCardProvider((section, id))),
        messageOf: messageOf,
        failureOf: failureOf,
        loading: const SkeletonBox(key: Key('edit-card-loading'), height: 240),
        builder: (loaded) {
          final allowed = canEditAccountCard(
            permissions: permissions,
            section: section.sectionKey,
            card: loaded,
          );
          if (!allowed) {
            return _EditUnavailable(section: section, card: loaded);
          }
          return _EditAccountCardForm(section: section, card: loaded);
        },
      ),
    );
  }
}

class _EditUnavailable extends StatelessWidget {
  const _EditUnavailable({required this.section, required this.card});

  final AccountSection section;
  final AccountCardDto card;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        _EditHeader(
          onBack: () => _leave(context, section: section, id: card.id),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.editCardUnavailable,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditAccountCardForm extends ConsumerStatefulWidget {
  const _EditAccountCardForm({required this.section, required this.card});

  final AccountSection section;
  final AccountCardDto card;

  @override
  ConsumerState<_EditAccountCardForm> createState() =>
      _EditAccountCardFormState();
}

class _EditAccountCardFormState extends ConsumerState<_EditAccountCardForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.card.name);
    _phone = TextEditingController(text: widget.card.phone ?? '');
    _name.addListener(_changed);
    _phone.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void didUpdateWidget(covariant _EditAccountCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.version != widget.card.version) {
      _replace(_name, widget.card.name);
      _replace(_phone, widget.card.phone ?? '');
    }
  }

  void _replace(TextEditingController controller, String value) {
    controller.removeListener(_changed);
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    controller.addListener(_changed);
  }

  @override
  void dispose() {
    _name.removeListener(_changed);
    _phone.removeListener(_changed);
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = pagePadding(width);
    final colors = context.appColors;
    final tight = layoutIsTight(context);
    final save = GuardedMutation(
      buttonKey: const Key('save-account-card'),
      inputs: '${_name.text}|${_phone.text}',
      expectedVersion: widget.card.version,
      label: AppStrings.save,
      onSubmit: _submit,
    );
    return ListView(
      padding: padding.copyWith(
        bottom: padding.bottom + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        _EditHeader(
          onBack: () =>
              _leave(context, section: widget.section, id: widget.card.id),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.noteBg,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: colors.noteLine),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: Text(
                      AppStrings.editCardScope,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.noteText),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const Key('edit-card-name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: AppStrings.name),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('edit-card-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: AppStrings.phone,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (tight)
                  Theme(data: _editStretchButtons(context), child: save)
                else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: save,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final validation = validateAccountCardEdit(name: _name.text);
    if (validation != null) return validation;
    if (widget.card.version == null) {
      _refresh();
      return AppStrings.cardVersionMissing;
    }
    final request = accountCardEditRequest(
      name: _name.text,
      phone: _phone.text,
    );
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .update(widget.section, widget.card.id, request, meta);
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      _refresh();
      context.go('/${widget.section.path}/${widget.card.id}');
      return null;
    } catch (error) {
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (failure.code == 'VERSION_CONFLICT') {
        _refresh();
        return AppStrings.versionConflict;
      }
      return failureText(failure);
    }
  }

  void _refresh() {
    final key = (widget.section, widget.card.id);
    ref.invalidate(accountCardProvider(key));
    ref.invalidate(ledgerProvider(key));
    ref.invalidate(accountsProvider(widget.section));
  }
}

class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: AppStrings.back,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            AppStrings.editCardTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

ThemeData _editStretchButtons(BuildContext context) {
  final theme = Theme.of(context);
  const min = WidgetStatePropertyAll(Size(double.infinity, 48));
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: (theme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: min,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: min,
      ),
    ),
  );
}

void _leave(
  BuildContext context, {
  required AccountSection section,
  required String id,
}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/${section.path}/$id');
}
