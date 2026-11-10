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
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InkWell(
                            key: Key('login-account-${account.id}'),
                            onTap: () =>
                                context.go('/settings/users/${account.id}'),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(
                                AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          account.displayName ??
                                              account.username,
                                          style: cairo(16, 800),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_left),
                                    ],
                                  ),
                                  Text(
                                    account.username,
                                    style: cairo(
                                      12,
                                      600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _Tag(_roleLabel(account.role)),
                                      if (account.isOwner)
                                        const _Tag('المدير الأساسي'),
                                      _Tag(account.isActive ? 'نشط' : 'موقوف'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.displayName ?? request.email ?? request.id,
              key: Key('account-request-${request.id}'),
              style: cairo(14, 800),
            ),
            if (request.email != null) Text(request.email!),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _Tag(_requestStatus(request.status)),
            ),
            if (request.pending)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: Key('account-request-approve-${request.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => _decide(ref, 'approve'),
                    child: const Text('موافقة'),
                  ),
                  TextButton(
                    key: Key('account-request-reject-${request.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => _decide(ref, 'reject'),
                    child: const Text('رفض'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(WidgetRef ref, String decision) async {
    final messenger = ScaffoldMessenger.maybeOf(ref.context);
    try {
      await ref.read(apiLayerProvider).directory.decideAccountRequest(
        request.id,
        {'expectedVersion': request.version ?? 1, 'decision': decision},
      );
      ref.invalidate(accountRequestsProvider);
    } catch (error) {
      final message = ref.read(errorHandlerProvider).toFailure(error).message;
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: cairo(11, 700, color: gold)),
    );
  }
}

String _requestStatus(String? status) => switch (status) {
  'pending' => AppStrings.pendingApproval,
  'approved' => AppStrings.approved,
  'rejected' => AppStrings.rejected,
  null || '' => '—',
  _ => status,
};

String _roleLabel(String? role) => switch (role) {
  'admin' => 'إدارة',
  'employee' => 'موظف',
  null || '' => '—',
  _ => role,
};

String permissionLabel(String code) => switch (code) {
  'debts.read' => 'قراءة ديون العملاء',
  'debts.write' => 'تسجيل ديون العملاء',
  'companies.read' => 'قراءة ديون الشركات',
  'companies.write' => 'تسجيل ديون الشركات',
  'libyan_deposits.read' => 'قراءة الأمانات الليبية',
  'libyan_deposits.write' => 'تسجيل الأمانات الليبية',
  'egyptian_deposits.read' => 'قراءة الأمانات المصرية',
  'egyptian_deposits.write' => 'تسجيل الأمانات المصرية',
  'collections.read' => 'قراءة الاستلامات',
  'collections.write' => 'تسجيل الاستلامات',
  'masraweya.read' => 'قراءة المصراوية',
  'masraweya.write' => 'تسجيل المصراوية',
  'purchases.read' => 'قراءة المشتريات',
  'purchases.write' => 'تسجيل المشتريات',
  'purchases.finalize' => 'إقفال يوم المشتريات',
  'treasury.read' => 'قراءة الخزينة',
  'treasury.write' => 'تسجيل الخزينة',
  'reports.read' => 'قراءة التقارير',
  _ => code,
};

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
        if (locked && !owner) {
          return ListView(
            key: const Key('screen-login-account-edit'),
            padding: pagePadding(MediaQuery.sizeOf(context).width),
            children: [
              _AccountHeading(account: account),
              const Text(
                'تعديل حساب الإدارة للمدير الأساسي. الخادم يرفض غيره.',
                key: Key('login-account-edit-closed'),
              ),
            ],
          );
        }
        return _PermissionEditor(
          account: account,
          assignable: page.assignablePermissions,
          saving: _saving,
          error: _error,
          onSave: (body) => _save(account, body),
          onCancel: _saving ? null : () => context.go('/settings/users'),
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
      data: (page) => Column(
        key: LoginAccountCreateScreen.screenKey,
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                    decoration: const InputDecoration(
                      labelText: 'الاسم الظاهر',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: const Key('create-role'),
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'الدور'),
                    items: const [
                      DropdownMenuItem(value: 'employee', child: Text('موظف')),
                      DropdownMenuItem(value: 'admin', child: Text('إدارة')),
                    ],
                    onChanged: (value) =>
                        setState(() => _role = value ?? 'employee'),
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
                    decoration: const InputDecoration(
                      labelText: 'كلمة مرور مؤقتة',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('صلاحيات عامة', style: cairo(14, 800)),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final code in page.assignablePermissions)
                        FilterChip(
                          key: Key('create-permission-$code'),
                          label: Text(permissionLabel(code)),
                          selected: _permissions.contains(code),
                          onSelected: (value) => setState(() {
                            if (value) {
                              _permissions.add(code);
                            } else {
                              _permissions.remove(code);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('أقسام العمل', style: cairo(14, 800)),
                  const Text(
                    'القسم إما ممنوع أو دخول كامل: قراءة وإضافة وكتابة وتعديل ذلك القسم. لا خيار وصول محدود.',
                  ),
                  for (final entry in loginAccountSections.entries)
                    _SectionGrant(
                      cardKey: Key('create-access-${entry.key}'),
                      denyKey: Key('create-deny-${entry.key}'),
                      grantKey: Key('create-grant-${entry.key}'),
                      title: entry.value,
                      value: _access[entry.key] ?? 'none',
                      note: entry.key == 'reports'
                          ? 'لا مسار كتابة للتقارير في العقد. الدخول الكامل يرسل reports.read ولا يفتح تعديلًا.'
                          : null,
                      enabled: !_saving,
                      onChanged: (level) => setState(() {
                        _access[entry.key] = level;
                        _applySectionCodes(
                          _permissions,
                          entry.key,
                          level,
                          page.assignablePermissions,
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: pagePadding(MediaQuery.sizeOf(context).width),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.sm,
                      ),
                      child: Text(
                        _error!,
                        key: const Key('create-account-error'),
                        style: cairo(
                          13,
                          700,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('create-account-cancel'),
                          onPressed: _saving
                              ? null
                              : () => context.go('/settings/users'),
                          child: const Text(AppStrings.cancel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const Key('create-account-submit'),
                          onPressed: _saving ? null : () => _submit(),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(AppStrings.save),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final assignable =
          ref.read(loginAccountsProvider).asData?.value.assignablePermissions ??
          const <String>[];
      await ref.read(apiLayerProvider).directory.createLoginAccount({
        'username': _username.text.trim(),
        'displayName': _name.text.trim(),
        'role': _role,
        'email': _email.text.trim(),
        'password': _password.text,
        'permissions': _codesForSave(
          _permissions,
          _access,
          assignable,
        ).toList(),
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

  String? _problem() {
    if (_username.text.trim().isEmpty) return 'أدخل اسم الدخول';
    if (_name.text.trim().isEmpty) return 'أدخل الاسم الظاهر';
    if (_role == 'admin' && !_email.text.contains('@')) {
      return 'البريد مطلوب لحساب الإدارة';
    }
    if (_password.text.length < 10) {
      return 'كلمة المرور المؤقتة عشرة أحرف على الأقل';
    }
    return null;
  }
}

class _PermissionEditor extends StatefulWidget {
  const _PermissionEditor({
    required this.account,
    required this.assignable,
    required this.saving,
    required this.error,
    required this.onSave,
    required this.onCancel,
  });

  final LoginAccount account;
  final List<String> assignable;
  final bool saving;
  final String? error;
  final Future<void> Function(Map<String, Object?> body) onSave;
  final VoidCallback? onCancel;

  @override
  State<_PermissionEditor> createState() => _PermissionEditorState();
}

class _PermissionEditorState extends State<_PermissionEditor> {
  late final Set<String> _permissions;
  late final Map<String, String> _access;

  @override
  void initState() {
    super.initState();
    _permissions = {...widget.account.permissions};
    _access = {
      for (final key in loginAccountSections.keys)
        key: _knownAccess(widget.account.sectionAccess[key]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('screen-login-account-edit'),
      children: [
        Expanded(
          child: ListView(
            padding: pagePadding(MediaQuery.sizeOf(context).width),
            children: [
              _AccountHeading(account: widget.account),
              Text('صلاحيات عامة', style: cairo(16, 800)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'المحدد الآن ظاهر بلون مختلف. الحفظ يرسل هذه القائمة ومستوى كل قسم.',
                style: cairo(12, 600, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final code in widget.assignable)
                    FilterChip(
                      key: Key('edit-permission-$code'),
                      label: Text(permissionLabel(code)),
                      selected: _permissions.contains(code),
                      onSelected: widget.saving
                          ? null
                          : (value) => setState(() {
                              if (value) {
                                _permissions.add(code);
                              } else {
                                _permissions.remove(code);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('أقسام العمل', style: cairo(16, 800)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'ممنوع أو دخول كامل لهذا القسم. الحفظ يرسل manage مع صلاحيات القراءة والكتابة المنشورة.',
                style: cairo(12, 600, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final entry in loginAccountSections.entries)
                _SectionGrant(
                  cardKey: Key('edit-access-${entry.key}'),
                  denyKey: Key('edit-deny-${entry.key}'),
                  grantKey: Key('edit-grant-${entry.key}'),
                  legacyKey: Key('edit-legacy-${entry.key}'),
                  title: entry.value,
                  value: _access[entry.key] ?? 'none',
                  note: entry.key == 'reports'
                      ? 'لا مسار كتابة للتقارير في العقد. الدخول الكامل يرسل reports.read ولا يفتح تعديلًا.'
                      : null,
                  enabled: !widget.saving,
                  onChanged: (level) => setState(() {
                    _access[entry.key] = level;
                    _applySectionCodes(
                      _permissions,
                      entry.key,
                      level,
                      widget.assignable,
                    );
                  }),
                ),
            ],
          ),
        ),
        Material(
          color: scheme.surface,
          child: Padding(
            padding: pagePadding(MediaQuery.sizeOf(context).width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.error != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      widget.error!,
                      key: const Key('login-account-save-error'),
                      style: cairo(13, 700, color: scheme.error),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('login-account-cancel'),
                        onPressed: widget.saving ? null : widget.onCancel,
                        child: const Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const Key('login-account-save-permissions'),
                        onPressed: widget.saving
                            ? null
                            : () => widget.onSave({
                                'permissions': _codesForSave(
                                  _permissions,
                                  _access,
                                  widget.assignable,
                                ).toList(),
                                for (final entry in _access.entries)
                                  '${entry.key}Access': entry.value,
                              }),
                        child: widget.saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('حفظ الصلاحيات'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountHeading extends StatelessWidget {
  const _AccountHeading({required this.account});

  final LoginAccount account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حساب الدخول', style: cairo(13, 700)),
          Text(account.displayName ?? account.username, style: cairo(22, 800)),
          Text(account.username, style: cairo(14, 600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(_roleLabel(account.role)),
              if (account.isOwner) const _Tag('المدير الأساسي'),
              _Tag(account.isActive ? 'نشط' : 'موقوف'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Codes the published contract uses for one section grant.
/// `manage` plus these codes is full read/add/write/edit for that section.
/// Reports have no write code. Purchases finalize stays outside this group.
const sectionCapabilityCodes = <String, List<String>>{
  'customerDebts': ['debts.read', 'debts.write'],
  'companyDebts': ['companies.read', 'companies.write'],
  'libyanDeposits': ['libyan_deposits.read', 'libyan_deposits.write'],
  'egyptianDeposits': ['egyptian_deposits.read', 'egyptian_deposits.write'],
  'masraweya': ['masraweya.read', 'masraweya.write'],
  'purchases': ['purchases.read', 'purchases.write'],
  'treasury': ['treasury.read', 'treasury.write'],
  'reports': ['reports.read'],
};

String _knownAccess(String? raw) =>
    raw == 'read' || raw == 'manage' || raw == 'none' ? raw! : 'none';

void _applySectionCodes(
  Set<String> permissions,
  String key,
  String level,
  List<String> assignable,
) {
  final group = [
    for (final code in sectionCapabilityCodes[key] ?? const <String>[])
      if (assignable.contains(code)) code,
  ];
  if (level == 'manage') {
    permissions.addAll(group);
  } else if (level == 'none') {
    permissions.removeAll(group);
  }
}

Set<String> _codesForSave(
  Set<String> permissions,
  Map<String, String> access,
  List<String> assignable,
) {
  final codes = {...permissions};
  for (final entry in access.entries) {
    _applySectionCodes(codes, entry.key, entry.value, assignable);
  }
  return codes;
}

class _SectionGrant extends StatelessWidget {
  const _SectionGrant({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.note,
    this.cardKey,
    this.denyKey,
    this.grantKey,
    this.legacyKey,
  });

  final String title;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? note;
  final Key? cardKey;
  final Key? denyKey;
  final Key? grantKey;
  final Key? legacyKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final legacy = value == 'read';
    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: cairo(14, 800)),
            if (note != null)
              Text(
                note!,
                style: cairo(12, 600, color: scheme.onSurfaceVariant),
              ),
            if (legacy)
              Text(
                'محفوظ سابقاً بحالة ليست دخولاً كاملاً. لن يتغير إلا إذا اخترت الدخول الكامل أو المنع ثم حفظت.',
                key: legacyKey,
                style: cairo(12, 700, color: scheme.error),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: denyKey,
                  label: const Text('ممنوع'),
                  selected: value == 'none',
                  onSelected: enabled ? (_) => onChanged('none') : null,
                ),
                ChoiceChip(
                  key: grantKey,
                  label: const Text('دخول كامل'),
                  selected: value == 'manage',
                  onSelected: enabled ? (_) => onChanged('manage') : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
