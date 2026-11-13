import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../authentication/auth_gate.dart';
import '../../state/notification_providers.dart';
import '../../state/router_provider.dart';
import '../../state/session_providers.dart';

enum NotificationOpenOrigin { list, banner, systemTray }

enum NotificationOpenResult {
  opened,
  needsLogin,
  forbidden,
  notFound,
  noTarget,
}

/// In-memory destination kept across the login redirect and a cold start.
///
/// The path is not written into the login URL.
class PendingNotificationOpen {
  AppNotification? notification;
  NotificationOpenOrigin? origin;

  bool get hasPending => notification != null && origin != null;

  void save(AppNotification notification, NotificationOpenOrigin origin) {
    this.notification = notification;
    this.origin = origin;
  }

  void clear() {
    notification = null;
    origin = null;
  }
}

final pendingNotificationOpenProvider = Provider<PendingNotificationOpen>(
  (ref) => PendingNotificationOpen(),
);

/// Agreed with the UI dev. The signature of [open] stays as declared.
///
/// [open] marks the row read for every result except
/// [NotificationOpenResult.needsLogin]. The one other exception is a
/// `recipientUserId` that is present and is not the signed-in user: that
/// row is not marked read, and the route is `/forbidden`. A permission
/// failure for the current user's own row is marked read, then `/forbidden`.
class NotificationOpener {
  NotificationOpener(this._ref);

  final Ref _ref;

  Future<NotificationOpenResult> open(
    AppNotification n, {
    required NotificationOpenOrigin origin,
  }) async {
    final session = _ref.read(sessionStateProvider);
    if (session is! SessionAuthenticated) {
      _ref.read(pendingNotificationOpenProvider).save(n, origin);
      if (session is! SessionUnknown) {
        _go('/login');
      }
      return NotificationOpenResult.needsLogin;
    }

    final userId = session.profile.id;
    if (!_belongsToUser(n, userId)) {
      // A named recipient who is not this user is not this row.
      if (!_foreignRecipient(n, userId)) {
        await _markRead(n.notificationId);
      }
      _go(forbiddenLocation);
      return NotificationOpenResult.forbidden;
    }

    final target = resolveNotificationTarget(n.relatedRef);
    if (target == null) {
      await _markRead(n.notificationId);
      _go('/notifications');
      return NotificationOpenResult.noTarget;
    }

    final permissions = _ref.read(apiLayerProvider).permissions;
    final owner = session.profile.isOwner;
    if (target.section == null) {
      final settings =
          permissions.canDo(ManagementAction.settingsManage) ||
          permissions.canViewFinancialLedger ||
          owner;
      if (!settings) {
        await _markRead(n.notificationId);
        _go(forbiddenLocation);
        return NotificationOpenResult.forbidden;
      }
    } else if (!owner && !permissions.canRead(target.section!)) {
      await _markRead(n.notificationId);
      _go(forbiddenLocation);
      return NotificationOpenResult.forbidden;
    }

    var location = target.location;
    if (target.account != null) {
      try {
        await _ref
            .read(apiLayerProvider)
            .accounts
            .get(target.account!, target.accountId!);
      } on NotFoundException {
        // The row still names a section. Open that list, then mark it read.
        location = '/${target.account!.path}';
      }
    }

    _go(location);
    await _markRead(n.notificationId);
    return location == target.location
        ? NotificationOpenResult.opened
        : NotificationOpenResult.notFound;
  }

  Future<void> _markRead(String notificationId) async {
    try {
      await _ref.read(notificationsProvider.notifier).markRead(notificationId);
    } catch (_) {
      // A failed read must not block navigation.
    }
  }

  /// After auth bootstrap or a successful login. No-op when nothing is pending.
  Future<NotificationOpenResult?> resumePending() async {
    final pending = _ref.read(pendingNotificationOpenProvider);
    final notification = pending.notification;
    final origin = pending.origin;
    if (notification == null || origin == null) return null;
    pending.clear();
    return open(notification, origin: origin);
  }

  void _go(String location) {
    final router = _ref.read(routerProvider);
    final path = router.state.uri.path;
    if (path == location) return;
    router.go(location);
  }

  bool _belongsToUser(AppNotification notification, String userId) {
    // GET /api/notifications is already filtered to the signed-in user and
    // does not send recipientUserId. A named other recipient is refused.
    final owner = notification.recipientUserId?.trim();
    if (owner == null || owner.isEmpty) return true;
    return owner == userId;
  }

  /// True only when the server named a recipient and it is not [userId].
  bool _foreignRecipient(AppNotification notification, String userId) {
    final owner = notification.recipientUserId?.trim();
    return owner != null && owner.isNotEmpty && owner != userId;
  }
}

final notificationOpenerProvider = Provider<NotificationOpener>(
  NotificationOpener.new,
);

/// Where a related ref goes, when it goes anywhere.
class NotificationTarget {
  const NotificationTarget._({
    required this.location,
    required this.section,
    this.account,
    this.accountId,
  });

  final String location;

  /// Null is the settings screen, which is not a [SectionKey].
  final SectionKey? section;
  final AccountSection? account;
  final String? accountId;
}

/// `collection` and `receipt` open the collections screen.
///
/// `account` with no book is null. A section key (`customers`, and the other
/// card books) opens that card when the id is present.
NotificationTarget? resolveNotificationTarget(NotificationRelatedRef? ref) {
  if (ref == null) return null;
  final type = ref.type.trim().toLowerCase();
  final id = ref.id.trim();
  if (type.isEmpty) return null;
  if (type == 'settings') {
    return const NotificationTarget._(location: '/settings', section: null);
  }
  switch (type) {
    case 'collection':
    case 'collections':
    case 'receipt':
    case 'receipts':
    case 'collection_submission':
      return NotificationTarget._(
        location: '/collections',
        section: SectionKey.collections,
      );
    case 'customer':
      return _accountTarget(AccountSection.customers, id);
    case 'company':
      return _accountTarget(AccountSection.companies, id);
    case 'libyan_deposit':
    case 'libyan-deposit':
      return _accountTarget(AccountSection.libyanDeposits, id);
    case 'egyptian_deposit':
    case 'egyptian-deposit':
      return _accountTarget(AccountSection.egyptianDeposits, id);
    case 'purchase':
    case 'purchase_entry':
    case 'purchases':
      return NotificationTarget._(
        location: '/purchases',
        section: SectionKey.purchases,
      );
    case 'treasury':
    case 'cash_entry':
      return NotificationTarget._(
        location: '/treasury',
        section: SectionKey.treasury,
      );
    case 'masraweya':
      return NotificationTarget._(
        location: '/masraweya',
        section: SectionKey.masraweya,
      );
    case 'reports':
      return NotificationTarget._(
        location: '/reports',
        section: SectionKey.reports,
      );
    case 'account':
    case 'accounts':
      return null;
    default:
      break;
  }
  final section = _sectionFor(type);
  if (section == null) return null;
  if (section == SectionKey.collections) {
    return NotificationTarget._(location: '/collections', section: section);
  }
  final account = _accountFor(section);
  if (account == null || id.isEmpty) {
    return NotificationTarget._(location: '/${section.key}', section: section);
  }
  return NotificationTarget._(
    location: '/${account.path}/$id',
    section: section,
    account: account,
    accountId: id,
  );
}

SectionKey? _sectionFor(String type) {
  for (final section in SectionKey.values) {
    if (section.key == type || section.name.toLowerCase() == type) {
      return section;
    }
  }
  return null;
}

NotificationTarget _accountTarget(AccountSection account, String id) {
  if (id.isEmpty) {
    return NotificationTarget._(
      location: '/${account.path}',
      section: account.sectionKey,
    );
  }
  return NotificationTarget._(
    location: '/${account.path}/$id',
    section: account.sectionKey,
    account: account,
    accountId: id,
  );
}

AccountSection? _accountFor(SectionKey section) {
  for (final account in AccountSection.values) {
    if (account.sectionKey == section) return account;
  }
  return null;
}

/// Router location helper for tests. Null when the router has no match yet.
String routerPath(GoRouter router) => router.state.uri.path;
