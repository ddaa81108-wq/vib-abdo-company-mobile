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
    if (!_belongsToUser(n, userId, origin)) {
      // A different recipient is not this user's row. Every other result,
      // including a missing recipient on a tray tap, is marked read.
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
    if (!permissions.canRead(target.section)) {
      await _markRead(n.notificationId);
      _go(forbiddenLocation);
      return NotificationOpenResult.forbidden;
    }

    if (target.account != null) {
      try {
        await _ref
            .read(apiLayerProvider)
            .accounts
            .get(target.account!, target.accountId!);
      } on NotFoundException {
        await _markRead(n.notificationId);
        _go('/notifications');
        return NotificationOpenResult.notFound;
      }
    }

    await _markRead(n.notificationId);
    _go(target.location);
    return NotificationOpenResult.opened;
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

  bool _belongsToUser(
    AppNotification notification,
    String userId,
    NotificationOpenOrigin origin,
  ) {
    final owner = notification.recipientUserId;
    if (origin == NotificationOpenOrigin.list) {
      return owner == null || owner.isEmpty || owner == userId;
    }
    return owner != null && owner.isNotEmpty && owner == userId;
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
  final SectionKey section;
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
  if (type.isEmpty || id.isEmpty) return null;
  switch (type) {
    case 'collection':
    case 'collections':
    case 'receipt':
    case 'receipts':
      return NotificationTarget._(
        location: '/collections',
        section: SectionKey.collections,
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
  if (account == null) {
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

AccountSection? _accountFor(SectionKey section) {
  for (final account in AccountSection.values) {
    if (account.sectionKey == section) return account;
  }
  return null;
}

/// Router location helper for tests. Null when the router has no match yet.
String routerPath(GoRouter router) => router.state.uri.path;
