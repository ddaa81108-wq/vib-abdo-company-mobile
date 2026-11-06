import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';

const loginAccountSections = <String, String>{
  'customerDebts': 'ديون العملاء',
  'companyDebts': 'ديون الشركات',
  'libyanDeposits': 'أمانات ليبية',
  'egyptianDeposits': 'أمانات مصرية',
  'masraweya': 'المصراوية',
  'purchases': 'المشتريات',
  'treasury': 'الخزينة',
  'reports': 'التقارير',
};

final loginAccountsProvider = FutureProvider<LoginAccountsPage>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).directory.loginAccounts();
});

final accountRequestsProvider = FutureProvider<List<AccountRequest>>((
  ref,
) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).directory.accountRequests();
});

class LoginAccountsScreen extends ConsumerWidget {
  const LoginAccountsScreen({super.key});

  static const screenKey = Key('screen-settings-employees');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canDo(ManagementAction.settingsManage)) {
      return const ForbiddenPane();
    }
    final owner = _primaryOwner(ref);
    final accounts = ref.watch(loginAccountsProvider);
    final requests = ref.watch(accountRequestsProvider);
    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          Text(
            'حسابات الدخول للإدارة والموظفين وصلاحيات الأقسام. ليست حسابات التحصيل أو المرتبات.',
            key: const Key('login-accounts-scope'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (owner)
            FilledButton.icon(
              key: const Key('login-account-create'),
              onPressed: () => context.go('/settings/users/new'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إنشاء حساب'),
            )
          else
            const Text(
              'إنشاء الحسابات للمدير الأساسي فقط. هذا الحساب إدارة وليس المدير الأساسي.',
              key: Key('login-account-create-closed'),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('طلبات بوابة الدخول', style: cairo(16, 800)),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'الموافقة لا تتم من بوابة الدخول نفسها. الطلب يبقى معلّقًا حتى قرار الإدارة، ولا ينشئ جلسة.',
          ),
          requests.when(
            loading: () => const SkeletonBox(height: 48),
            error: (error, _) => presentFailure(
              ref.read(errorHandlerProvider).toFailure(error),
              onRetry: () => ref.invalidate(accountRequestsProvider),
            ),
            data: (items) => items.isEmpty
                ? const Text('لا طلبات معلّقة.')
                : Column(
                    children: [
                      for (final item in items) _RequestTile(request: item),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('الحسابات', style: cairo(16, 800)),
          accounts.when(
            loading: () => const SkeletonBox(height: 72),
            error: (error, _) => presentFailure(
              ref.read(errorHandlerProvider).toFailure(error),
              onRetry: () => ref.invalidate(loginAccountsProvider),
              retryKey: const Key('login-accounts-retry'),
            ),
            data: (page) => page.items.isEmpty
                ? const EmptyPane(message: 'لا حسابات من الخادم.')
                : Column(
                    children: [
                      for (final account in page.items)
                        ListTile(
                          key: Key('login-account-${account.id}'),
                          title: Text(account.displayName ?? account.username),
                          subtitle: Text(
                            '${account.username} · ${account.role ?? '—'}'
                            '${account.isOwner ? ' · المدير الأساسي' : ''}'
                            '${account.isActive ? '' : ' · موقوف'}',
                          ),
                          onTap: () =>
                              context.go('/settings/users/${account.id}'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request});

  final AccountRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('account-request-${request.id}'),
      title: Text(request.displayName ?? request.email ?? request.id),
      subtitle: Text('${request.email ?? '—'} · ${request.status ?? '—'}'),
      trailing: request.pending
          ? Wrap(
              spacing: 4,
              children: [
                TextButton(
                  key: Key('account-request-approve-${request.id}'),
                  onPressed: () => _decide(ref, 'approve'),
                  child: const Text('موافقة'),
                ),
                TextButton(
                  key: Key('account-request-reject-${request.id}'),
                  onPressed: () => _decide(ref, 'reject'),
                  child: const Text('رفض'),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _decide(WidgetRef ref, String decision) async {
    await ref.read(apiLayerProvider).directory.decideAccountRequest(
      request.id,
      {'expectedVersion': request.version ?? 1, 'decision': decision},
    );
    ref.invalidate(accountRequestsProvider);
  }
}

bool _primaryOwner(WidgetRef ref) {
  final session = ref.watch(sessionStateProvider);
  return session is SessionAuthenticated && session.profile.isOwner;
}

class LoginAccountEditorScreen extends ConsumerStatefulWidget {
  const LoginAccountEditorScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<LoginAccountEditorScreen> createState() =>
      _LoginAccountEditorScreenState();
}

class _LoginAccountEditorScreenState
    extends ConsumerState<LoginAccountEditorScreen> {
  String? _error;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    if (!permissionsOf(ref).canDo(ManagementAction.settingsManage)) {
      return const ForbiddenPane();
    }
    final accounts = ref.watch(loginAccountsProvider);
    return accounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => presentFailure(
        ref.read(errorHandlerProvider).toFailure(error),
        onRetry: () => ref.invalidate(loginAccountsProvider),
      ),
      data: (page) {
        final account = page.items.cast<LoginAccount?>().firstWhere(
          (item) => item?.id == widget.id,
          orElse: () => null,
        );
        if (account == null) {
          return const EmptyPane(message: 'الحساب غير موجود في آخر رد.');
        }
        final owner = _primaryOwner(ref);
        final locked = account.isOwner || account.role == 'admin';
        return ListView(
          key: const Key('screen-login-account-edit'),
          padding: pagePadding(MediaQuery.sizeOf(context).width),
          children: [
            Text(
              account.displayName ?? account.username,
              style: cairo(18, 800),
            ),
            Text(account.username),
            if (locked && !owner)
              const Text(
                'تعديل حساب الإدارة للمدير الأساسي. الخادم يرفض غيره.',
                key: Key('login-account-edit-closed'),
              )
            else
              _PermissionEditor(
                account: account,
                assignable: page.assignablePermissions,
                saving: _saving,
                error: _error,
                onSave: (body) => _save(account, body),
              ),
          ],
        );
      },
    );
  }

  Future<void> _save(LoginAccount account, Map<String, Object?> body) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiLayerProvider).directory.updateLoginAccount(
        account.id,
        {'expectedVersion': account.version ?? 1, ...body},
      );
      ref.invalidate(loginAccountsProvider);
      if (mounted) context.go('/settings/users');
    } catch (error) {
      setState(
        () => _error = ref.read(errorHandlerProvider).toFailure(error).message,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class LoginAccountCreateScreen extends ConsumerStatefulWidget {
  const LoginAccountCreateScreen({super.key});

  static const screenKey = Key('screen-login-account-create');

  @override
  ConsumerState<LoginAccountCreateScreen> createState() =>
      _LoginAccountCreateScreenState();
}

class _LoginAccountCreateScreenState
    extends ConsumerState<LoginAccountCreateScreen> {
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _role = 'employee';
  final _permissions = <String>{};
  final _access = {for (final key in loginAccountSections.keys) key: 'none'};
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_primaryOwner(ref) ||
        !permissionsOf(ref).canDo(ManagementAction.settingsManage)) {
      return const ForbiddenPane(key: Key('login-account-create-forbidden'));
    }
    final accounts = ref.watch(loginAccountsProvider);
    return accounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => presentFailure(
        ref.read(errorHandlerProvider).toFailure(error),
        onRetry: () => ref.invalidate(loginAccountsProvider),
      ),
      data: (page) => SingleChildScrollView(
        key: LoginAccountCreateScreen.screenKey,
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إنشاء حساب دخول', style: cairo(18, 800)),
            const Text(
              'يظهر للمدير الأساسي فقط. الحساب الجديد لا يصبح مديرًا أساسيًا.',
            ),
            TextField(
              key: const Key('create-username'),
              controller: _username,
              decoration: const InputDecoration(labelText: 'اسم الدخول'),
            ),
            TextField(
              key: const Key('create-display-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم الظاهر'),
            ),
            DropdownButtonFormField<String>(
              key: const Key('create-role'),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'الدور'),
              items: const [
                DropdownMenuItem(value: 'employee', child: Text('موظف')),
                DropdownMenuItem(value: 'admin', child: Text('إدارة')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'employee'),
            ),
            TextField(
              key: const Key('create-email'),
              controller: _email,
              decoration: InputDecoration(
                labelText: _role == 'admin'
                    ? 'البريد (مطلوب للإدارة)'
                    : 'البريد',
              ),
            ),
            TextField(
              key: const Key('create-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة مرور مؤقتة'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('الصلاحيات', style: cairo(14, 800)),
          for (final code in page.assignablePermissions)
            Row(
              children: [
                Checkbox(
                  key: Key('create-permission-$code'),
                  value: _permissions.contains(code),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      _permissions.add(code);
                    } else {
                      _permissions.remove(code);
                    }
                  }),
                ),
                Expanded(child: Text(code)),
              ],
            ),
            Text('أقسام', style: cairo(14, 800)),
            for (final entry in loginAccountSections.entries)
              DropdownButtonFormField<String>(
                key: Key('create-access-${entry.key}'),
                initialValue: _access[entry.key],
                decoration: InputDecoration(labelText: entry.value),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('لا شيء')),
                  DropdownMenuItem(value: 'read', child: Text('قراءة')),
                  DropdownMenuItem(value: 'manage', child: Text('إدارة')),
                ],
                onChanged: (value) =>
                    setState(() => _access[entry.key] = value ?? 'none'),
              ),
            if (_error != null)
              Text(_error!, key: const Key('create-account-error')),
            FilledButton(
              key: const Key('create-account-submit'),
              onPressed: _saving ? null : () => _submit(),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiLayerProvider).directory.createLoginAccount({
        'username': _username.text.trim(),
        'displayName': _name.text.trim(),
        'role': _role,
        'email': _email.text.trim(),
        'password': _password.text,
        'permissions': _permissions.toList(),
        for (final entry in _access.entries) '${entry.key}Access': entry.value,
      });
      _password.clear();
      ref.invalidate(loginAccountsProvider);
      if (mounted) context.go('/settings/users');
    } catch (error) {
      setState(
        () => _error = ref.read(errorHandlerProvider).toFailure(error).message,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PermissionEditor extends StatefulWidget {
  const _PermissionEditor({
    required this.account,
    required this.assignable,
    required this.saving,
    required this.error,
    required this.onSave,
  });

  final LoginAccount account;
  final List<String> assignable;
  final bool saving;
  final String? error;
  final Future<void> Function(Map<String, Object?> body) onSave;

  @override
  State<_PermissionEditor> createState() => _PermissionEditorState();
}

class _PermissionEditorState extends State<_PermissionEditor> {
  late final Set<String> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = {...widget.account.permissions};
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final code in widget.assignable)
          Row(
            children: [
              Checkbox(
                value: _permissions.contains(code),
                onChanged: (value) => setState(() {
                  if (value ?? false) {
                    _permissions.add(code);
                  } else {
                    _permissions.remove(code);
                  }
                }),
              ),
              Expanded(child: Text(code)),
            ],
          ),
        if (widget.error != null) Text(widget.error!),
        FilledButton(
          key: const Key('login-account-save-permissions'),
          onPressed: widget.saving
              ? null
              : () => widget.onSave({'permissions': _permissions.toList()}),
          child: const Text('حفظ الصلاحيات'),
        ),
      ],
    );
  }
}
