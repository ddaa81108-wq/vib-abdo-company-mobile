import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../error_handling/app_failure.dart';
import '../error_handling/error_handler.dart';
import '../performance/history_window.dart';
import '../ui/strings.dart';
import 'notification_merge.dart';
import 'session_providers.dart';

export 'notification_merge.dart' show NotificationSource, mergeAppNotifications;

/// Unread badge. The integer is the server's `unreadCount` from the list
/// page, or null while that request has not completed or the server omits it.
/// The app never increments it locally.
final unreadCountProvider = FutureProvider<int?>((ref) async {
  final session = ref.watch(sessionStateProvider);
  if (session is! SessionAuthenticated) return null;
  return ref.watch(apiLayerProvider).notifications.fetchUnreadCount();
});

/// Server unread count from 🔶 GET /api/notifications/unread-count.
///
/// Signed out, the value is 0 so the previous account's count is gone.
/// 0 is also a real server count. Watch this for [AsyncValue<int>].
class UnreadNotificationsCountController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final session = ref.watch(sessionStateProvider);
    if (session is! SessionAuthenticated) return 0;
    return ref.read(apiLayerProvider).notifications.serverUnreadCount();
  }

  /// Applies a count that arrived on a write or unread-count response.
  void applyServerCount(int count) {
    state = AsyncData(count);
  }
}

final unreadNotificationsCountProvider =
    AsyncNotifierProvider<UnreadNotificationsCountController, int>(
      UnreadNotificationsCountController.new,
      retry: (_, _) => null,
    );

final _foregroundBusProvider = Provider<StreamController<AppNotification>>((
  ref,
) {
  final bus = StreamController<AppNotification>.broadcast();
  ref.onDispose(bus.close);
  ref.watch(sessionStateProvider);
  return bus;
});

/// Newly seen unread rows from a push, or from a refresh that passes
/// `announce: true`. The initial list does not emit.
final foregroundNotificationsProvider = StreamProvider<AppNotification>((ref) {
  final session = ref.watch(sessionStateProvider);
  if (session is! SessionAuthenticated) return const Stream.empty();
  return ref.watch(_foregroundBusProvider).stream;
});

/// List, ingest, and mark-read. The current screen watches this as
/// [AsyncValue<NotificationsPage>]. Retry with
/// `ref.invalidate(notificationsProvider)`.
class NotificationsController extends AsyncNotifier<NotificationsPage> {
  final Map<String, NotificationWriteResult> _writes = {};
  final Map<String, String> _oneReadIds = {};
  final Map<String, Future<void>> _oneReadFlights = {};
  String? _allReadId;
  Future<void>? _allReadFlight;

  @override
  Future<NotificationsPage> build() async {
    final session = ref.watch(sessionStateProvider);
    _writes.clear();
    _oneReadIds.clear();
    _oneReadFlights.clear();
    _allReadId = null;
    _allReadFlight = null;
    ref.read(apiLayerProvider).notifications.clearWriteCache();
    if (session is! SessionAuthenticated) {
      return const NotificationsPage(items: [], unreadCount: null);
    }
    final page = await ref.read(apiLayerProvider).notifications.list();
    final visible = mergeAppNotifications(
      current: const [],
      incoming: page.appNotifications,
      currentUserId: session.profile.id,
      source: NotificationSource.fetch,
    );
    return _page(visible, unreadCount: page.unreadCount, base: page);
  }

  /// Follows `nextBefore` one page.
  ///
  /// The cap is pending Ali. With [HistoryWindow.trimEnabled] off, every
  /// fetched row stays. With it on, the newest
  /// [HistoryWindow.notificationRetain] rows stay and the walk stops.
  Future<void> loadOlder() async {
    final current = state.asData?.value;
    final before = current?.nextBefore;
    if (current == null || before == null || before.isEmpty) return;
    final cap = HistoryWindow.trimEnabled
        ? HistoryWindow.notificationRetain
        : null;
    if (cap != null && current.appNotifications.length >= cap) return;
    final page = await ref
        .read(apiLayerProvider)
        .notifications
        .list(before: before);
    final session = ref.read(sessionStateProvider);
    if (session is! SessionAuthenticated) return;
    final merged = mergeAppNotifications(
      current: current.appNotifications,
      incoming: page.appNotifications,
      currentUserId: session.profile.id,
      source: NotificationSource.fetch,
    );
    final capped = cap != null && merged.length > cap
        ? merged.sublist(0, cap)
        : merged;
    final nextBefore = cap != null && capped.length >= cap
        ? null
        : page.nextBefore;
    state = AsyncData(
      _page(
        capped,
        unreadCount: page.unreadCount,
        base: NotificationsPage(
          items: page.items,
          appNotifications: page.appNotifications,
          unreadCount: page.unreadCount,
          nextBefore: nextBefore,
        ),
      ),
    );
  }

  /// GET /api/notifications and ingest first, then GET the unread-count route.
  ///
  /// A 404 or any other non-auth failure of the count route falls back to the
  /// list response's `unreadCount`. If that field is absent too, the previous
  /// count stays. The count is never computed from the rows. A count failure
  /// does not roll back the list. 401 still throws [SessionExpiredException]
  /// after the interceptor has called forceLogout.
  ///
  /// Realtime (SSE `/api/events` or polling `/api/event-changes`) should call
  /// `refresh(announce: true)` so a newly seen unread row can raise a banner.
  /// The initial load uses the default and stays quiet.
  Future<void> refresh({bool announce = false}) async {
    final page = await ref.read(apiLayerProvider).notifications.list();
    await ingest(
      page.appNotifications,
      source: NotificationSource.fetch,
      announce: announce,
    );
    final count = await _resolveUnread(listUnread: page.unreadCount);
    if (count != null) _applyCount(count, pageUnread: page.unreadCount);
  }

  Future<void> ingest(
    List<AppNotification> items, {
    required NotificationSource source,
    bool announce = false,
  }) async {
    final session = ref.read(sessionStateProvider);
    final userId = session is SessionAuthenticated ? session.profile.id : null;
    if (userId == null) {
      state = const AsyncData(NotificationsPage(items: [], unreadCount: null));
      return;
    }
    final current = _records(state.value);
    final merged = mergeAppNotifications(
      current: current,
      incoming: items,
      currentUserId: userId,
      source: source,
    );
    state = AsyncData(_page(merged, base: state.value));
    final shouldAnnounce = announce || source == NotificationSource.push;
    if (shouldAnnounce) {
      final bus = ref.read(_foregroundBusProvider);
      if (!bus.isClosed) {
        for (final item in newlySeenUnread(before: current, after: merged)) {
          bus.add(item);
        }
      }
    }
    if (source == NotificationSource.push) {
      final count = await _resolveUnread();
      if (count != null) _applyCount(count);
    }
  }

  /// [explicit] is a write response's `unreadCount`. Otherwise the unread-count
  /// route is tried on its own. A non-auth failure returns [listUnread], which
  /// is null when the list omitted the field so the caller keeps the previous
  /// count. [SessionExpiredException] is rethrown; forceLogout already ran.
  Future<int?> _resolveUnread({int? explicit, int? listUnread}) async {
    if (explicit != null) return explicit;
    try {
      return await ref.read(apiLayerProvider).notifications.serverUnreadCount();
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return listUnread;
    }
  }

  Future<void> ingestOne(
    AppNotification item, {
    required NotificationSource source,
    bool announce = false,
  }) => ingest([item], source: source, announce: announce);

  /// Marks one row read. The in-flight attempt keeps one [requestId].
  /// A second call for the same id before that attempt finishes waits on the
  /// same future and does not send again. A network failure keeps the id.
  /// A finished attempt drops it. The count is the server's number, never a
  /// local decrement.
  Future<void> markRead(String notificationId) {
    final inFlight = _oneReadFlights[notificationId];
    if (inFlight != null) return inFlight;
    final flight = _markOne(notificationId);
    _oneReadFlights[notificationId] = flight;
    flight.whenComplete(() {
      if (identical(_oneReadFlights[notificationId], flight)) {
        _oneReadFlights.remove(notificationId);
      }
    }).ignore();
    return flight;
  }

  Future<void> _markOne(String notificationId) async {
    final requestId = _oneReadIds.putIfAbsent(
      notificationId,
      RequestIds.newRequestId,
    );
    final result = await _send(
      requestId,
      () => ref
          .read(apiLayerProvider)
          .notifications
          .markRead(notificationId, requestId: requestId),
    );
    _oneReadIds.remove(notificationId);
    await _applyWrite(result, onlyId: notificationId);
  }

  /// Marks every cached row read. A second call while the first is in flight
  /// waits on the same future and does not send again.
  Future<void> markAllRead() {
    final inFlight = _allReadFlight;
    if (inFlight != null) return inFlight;
    final flight = _markAll();
    _allReadFlight = flight;
    flight.whenComplete(() {
      if (identical(_allReadFlight, flight)) _allReadFlight = null;
    }).ignore();
    return flight;
  }

  Future<void> _markAll() async {
    final requestId = _allReadId ??= RequestIds.newRequestId();
    final result = await _send(
      requestId,
      () => ref
          .read(apiLayerProvider)
          .notifications
          .markAllRead(requestId: requestId),
    );
    _allReadId = null;
    await _applyWrite(result);
  }

  Future<NotificationWriteResult> _send(
    String requestId,
    Future<NotificationWriteResult> Function() send,
  ) async {
    final cached = _writes[requestId];
    if (cached != null) return cached;
    try {
      final result = await send();
      _writes[requestId] = result;
      return result;
    } on NetworkException {
      rethrow;
    } on TimeoutApiException {
      rethrow;
    } catch (error) {
      _oneReadIds.removeWhere((_, id) => id == requestId);
      if (_allReadId == requestId) _allReadId = null;
      rethrow;
    }
  }

  Future<void> _applyWrite(
    NotificationWriteResult result, {
    String? onlyId,
  }) async {
    final notification = result.notification;
    if (notification != null) {
      await ingest(
        [notification],
        source: NotificationSource.fetch,
        announce: false,
      );
    } else {
      final readAt = result.readAt;
      if (readAt == null) {
        await refresh();
        if (result.unreadCount != null) _applyCount(result.unreadCount!);
        return;
      }
      final next = [
        for (final item in _records(state.value))
          if ((onlyId == null || item.notificationId == onlyId) && !item.isRead)
            item.withReadAt(readAt)
          else
            item,
      ];
      state = AsyncData(_page(next, base: state.value));
    }
    final count = await _resolveUnread(
      explicit: result.unreadCount,
      listUnread: state.value?.unreadCount,
    );
    if (count != null) _applyCount(count, pageUnread: count);
  }

  void _applyCount(int count, {int? pageUnread}) {
    ref.read(unreadNotificationsCountProvider.notifier).applyServerCount(count);
    final current = state.value;
    if (current != null &&
        pageUnread != null &&
        current.unreadCount != pageUnread) {
      state = AsyncData(
        NotificationsPage(
          items: current.items,
          appNotifications: current.appNotifications,
          unreadCount: pageUnread,
          nextBefore: current.nextBefore,
        ),
      );
    }
    ref.invalidate(unreadCountProvider);
  }

  List<AppNotification> _records(NotificationsPage? page) {
    if (page == null) return const [];
    if (page.appNotifications.isNotEmpty || page.items.isEmpty) {
      return page.appNotifications;
    }
    return [for (final item in page.items) AppNotification.fromDto(item)];
  }

  NotificationsPage _page(
    List<AppNotification> records, {
    int? unreadCount,
    NotificationsPage? base,
  }) {
    final sorted = [...records]
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) return byTime;
        return a.notificationId.compareTo(b.notificationId);
      });
    return NotificationsPage(
      items: [for (final item in sorted) item.toDto()],
      appNotifications: sorted,
      unreadCount: unreadCount ?? base?.unreadCount,
      nextBefore: base?.nextBefore,
    );
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsPage>(
      NotificationsController.new,
      retry: (_, _) => null,
    );

/// What a notifications screen switches on. Built only from
/// [notificationsProvider]. Retry with `ref.invalidate(notificationsProvider)`.
sealed class NotificationsState {
  const NotificationsState();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsEmpty extends NotificationsState {
  const NotificationsEmpty();
}

class NotificationsReady extends NotificationsState {
  const NotificationsReady(this.items);

  final List<AppNotification> items;
}

class NotificationsFailure extends NotificationsState {
  const NotificationsFailure(this.failure);

  final AppFailure failure;
}

/// HTTP 403. [message] is [AppStrings.forbidden]. The server sentence is not stored.
class NotificationsForbidden extends NotificationsState {
  const NotificationsForbidden();

  String get message => AppStrings.forbidden;
}

NotificationsState notificationsStateOf(
  AsyncValue<NotificationsPage> value,
  ErrorHandler errors,
) {
  return value.when(
    loading: () => const NotificationsLoading(),
    data: (page) {
      final items = page.appNotifications.isNotEmpty || page.items.isEmpty
          ? page.appNotifications
          : [for (final item in page.items) AppNotification.fromDto(item)];
      if (items.isEmpty) return const NotificationsEmpty();
      return NotificationsReady(items);
    },
    error: (error, _) => error is ForbiddenException
        ? const NotificationsForbidden()
        : NotificationsFailure(errors.toFailure(error)),
  );
}

final notificationsStateProvider = Provider<NotificationsState>(
  (ref) => notificationsStateOf(
    ref.watch(notificationsProvider),
    ref.read(errorHandlerProvider),
  ),
);
