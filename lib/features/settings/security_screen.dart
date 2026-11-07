import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  static const screenKey = Key('screen-settings-audit');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canDo(ManagementAction.settingsManage)) {
      return const ForbiddenPane();
    }
    final session = ref.watch(sessionStateProvider);
    final profile = session is SessionAuthenticated ? session.profile : null;
    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          Text('الأمان', style: cairo(18, 800)),
          const SizedBox(height: AppSpacing.sm),
          Card(
            key: const Key('security-current-session'),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الجلسة الحالية على هذا الجهاز', style: cairo(14, 800)),
                  const Text('هذه ليست قائمة بكل جلسات الحساب على الخادم.'),
                  if (profile != null) ...[
                    Text(profile.displayName),
                    Text(profile.username),
                    Text('الدور: ${profile.role ?? '—'}'),
                    Text(
                      profile.isOwner
                          ? 'المدير الأساسي: نعم'
                          : 'المدير الأساسي: لا',
                      key: const Key('security-is-owner'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'إذا طلب الخادم رمزًا عند الدخول، التطبيق يرسل النص كما هو إلى POST /api/auth/mfa/verify. لا مفتاح هنا للتفعيل أو الإيقاف أو الاسترجاع، ولا تُفتح الجلسة قبل نجاح الرمز.',
            key: Key('security-mfa-note'),
          ),
          const Text(
            'هذا مسار العقد المكتوب. فحص القراءة على staging في 2026-10-23 لم يطلب MFA للحسابات الثلاثة، لذلك هذه الشاشة لا تثبت حسابًا حيًا يستخدم الرمز. التفعيل والإيقاف والاسترجاع ليست مسارات منشورة.',
            key: Key('security-mfa-evidence'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'لقطات الشاشة في الإصدار تُفتح فقط لدور الإدارة أو الموظف بعد التحقق من الجلسة، وتُقفل لغير ذلك. لا يفصل النظام اللقطة عن التسجيل. إذا ضاع طلب القفل بعد السماح، يعود القفل بعد مهلة قصيرة وليس فورًا. لا يوجد هنا تجاوز.',
            key: Key('security-capture-note'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('سجل الخادم', style: cairo(16, 800)),
          const Text(
            'لا مسار جلسات. الصفحة التالية تُطلب فقط بمعامل before عندما يعيد الخادم nextBefore. لا مرشح لنوع العملية. فحص staging للقراءة لم يستدع GET /api/audit-log. العينة المنشورة عمليات تحصيل لا دخول. الصفوف رد الخادم، وليست سجلاً محليًا.',
            key: Key('security-audit-scope'),
          ),
          const _ServerAuditLog(),
        ],
      ),
    );
  }
}

class _ServerAuditLog extends ConsumerStatefulWidget {
  const _ServerAuditLog();

  @override
  ConsumerState<_ServerAuditLog> createState() => _ServerAuditLogState();
}

class _ServerAuditLogState extends ConsumerState<_ServerAuditLog> {
  final _items = <AuditEvent>[];
  String? _before;
  Object? _error;
  var _loading = true;
  var _more = false;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted || _more || (_loading && _items.isNotEmpty)) return;
    final ticket = ++_ticket;
    final before = _before;
    setState(() {
      if (_items.isEmpty) {
        _loading = true;
      } else {
        _more = true;
      }
      _error = null;
    });
    try {
      final page = await ref
          .read(apiLayerProvider)
          .directory
          .auditLog(before: before);
      if (!mounted || ticket != _ticket) return;
      final seen = {for (final item in _items) item.id};
      setState(() {
        for (final item in page.items) {
          if (seen.add(item.id)) _items.add(item);
        }
        _before = page.nextBefore;
        _loading = false;
        _more = false;
      });
    } catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _error = error;
        _loading = false;
        _more = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const SkeletonBox(height: 72);
    if (_error != null && _items.isEmpty) {
      return presentFailure(
        ref.read(errorHandlerProvider).toFailure(_error!),
        onRetry: _load,
        retryKey: const Key('audit-retry'),
      );
    }
    final sessionRows = _items.where((item) => item.isSessionAction).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sessionRows == 0
              ? 'لا عملية دخول أو جلسة في الصفوف المحمّلة.'
              : 'عمليات دخول أو جلسة في الصفوف المحمّلة: $sessionRows',
          key: const Key('security-session-count'),
        ),
        if (_error != null)
          Text(
            ref.read(errorHandlerProvider).toFailure(_error!).message,
            key: const Key('audit-older-error'),
            style: cairo(13, 700, color: Theme.of(context).colorScheme.error),
          ),
        if (_items.isEmpty)
          const EmptyPane(message: AppStrings.auditEmpty)
        else
          for (final item in _items)
            ListTile(
              key: Key('audit-event-${item.id}'),
              title: Text(item.action),
              subtitle: Text(
                '${item.actorName ?? item.actorUsername ?? '—'} · ${item.outcome ?? '—'} · ${item.createdAt ?? '—'}',
              ),
            ),
        if (_before != null)
          TextButton(
            key: const Key('audit-older'),
            onPressed: _more ? null : _load,
            child: Text(_more ? '...' : 'أقدم'),
          ),
      ],
    );
  }
}
