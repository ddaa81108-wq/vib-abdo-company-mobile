import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';

import 'local_notification_poster.dart';
import 'notification_dedup.dart';
import 'shown_notification_store.dart';
import 'tray_notification.dart';

enum WorkerResult { loggedOut, posted, idle, sessionEnded, failed }

class PollSession {
  const PollSession({required this.userId, required this.cookieHeader});

  final String userId;
  final String cookieHeader;
}

class NotificationPollWorkerDeps {
  NotificationPollWorkerDeps({
    required this.session,
    required this.fetch,
    required this.poster,
    required this.shown,
    required this.cancelWork,
    NotificationIdDedup? dedup,
  }) : dedup = dedup ?? NotificationIdDedup();

  final Future<PollSession?> Function() session;
  final Future<NotificationsPage> Function(PollSession session) fetch;
  final LocalNotificationPoster poster;
  final ShownNotificationStore shown;
  final NotificationIdDedup dedup;

  /// Cancels the periodic work. Must not clear the foreground cookie jar.
  final Future<void> Function() cancelWork;
}

/// One WorkManager run. Restores a session, GETs the list, and posts.
///
/// A missing session posts nothing. A 401 or 419 cancels the work and clears
/// this store only. The foreground cookie wipe stays on the UI isolate.
class NotificationPollWorker {
  static Future<WorkerResult> run(NotificationPollWorkerDeps deps) async {
    final PollSession? current;
    try {
      current = await deps.session();
    } on _WorkerSessionExpired {
      await _endSession(deps);
      return WorkerResult.sessionEnded;
    }
    if (current == null || current.userId.isEmpty) {
      return WorkerResult.loggedOut;
    }
    final NotificationsPage page;
    try {
      page = await deps.fetch(current);
    } on _WorkerSessionExpired {
      await _endSession(deps);
      return WorkerResult.sessionEnded;
    } catch (_) {
      return WorkerResult.failed;
    }
    var posted = 0;
    for (final item in page.appNotifications) {
      final owner = item.recipientUserId;
      if (owner != null && owner.isNotEmpty && owner != current.userId) {
        continue;
      }
      if (item.isRead || item.notificationId.isEmpty) continue;
      if (deps.dedup.contains(item.notificationId)) continue;
      if (await deps.shown.contains(item.notificationId)) continue;
      deps.dedup.add(item.notificationId);
      await deps.shown.add(item.notificationId);
      await deps.poster.showTray(trayForServer(item));
      posted++;
    }
    await deps.shown.writeCursor(page.nextBefore);
    return posted == 0 ? WorkerResult.idle : WorkerResult.posted;
  }

  static Future<void> _endSession(NotificationPollWorkerDeps deps) async {
    try {
      await deps.cancelWork();
    } catch (_) {}
    try {
      await deps.shown.clear();
    } catch (_) {}
    deps.dedup.clear();
  }
}

class _WorkerSessionExpired implements Exception {
  const _WorkerSessionExpired();
}

/// Cookie GET used by the background isolate.
///
/// No `X-CSRF-Token` (this is a GET) and no call into [SessionManager], so a
/// 401 here cannot clear the foreground cookie while the UI is still using it.
class CookieNotificationPollFetcher {
  CookieNotificationPollFetcher({
    required this.baseUrl,
    required this.cookieHeader,
    this.client,
  });

  final String baseUrl;
  final String cookieHeader;
  final HttpClient? client;

  Future<String?> currentUserId() async {
    final data = await _get(ApiEndpoints.me);
    final me = MeResponse.fromData(data);
    final id = me.user.id.trim();
    if (id.isEmpty) return null;
    return id;
  }

  Future<NotificationsPage> fetchNotifications() async {
    final data = await _get(ApiEndpoints.notifications);
    return NotificationsPage.fromData(data);
  }

  Future<Object?> _get(String path) async {
    final http = client ?? HttpClient();
    final close = client == null;
    try {
      final request = await http.getUrl(Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Client-Api-Version', '1');
      request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response.transform(utf8.decoder).join();
      final status = response.statusCode;
      if (status == 401 || status == 419) {
        throw const _WorkerSessionExpired();
      }
      if (status == 404) {
        throw const NotFoundException(code: 'NOT_FOUND', message: 'غير موجود');
      }
      if (status >= 400) {
        throw const NetworkException();
      }
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (decoded is Map &&
          decoded['ok'] == true &&
          decoded.containsKey('data')) {
        return decoded['data'];
      }
      throw const NetworkException();
    } finally {
      if (close) http.close();
    }
  }
}
