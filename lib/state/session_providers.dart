import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../features/home/home_fallback.dart';
import '../models/home_summary.dart';
import 'theme_controller.dart';

/// Mirrors [SessionManager.listenable] so widgets rebuild when the session changes.
class SessionStateNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    final session = ref.watch(apiLayerProvider).session;
    void listener() {
      state = session.state;
    }

    session.listenable.addListener(listener);
    ref.onDispose(() => session.listenable.removeListener(listener));
    return session.state;
  }

  Future<void> logout() => ref.read(apiLayerProvider).session.logout();
}

final sessionStateProvider =
    NotifierProvider<SessionStateNotifier, SessionState>(
      SessionStateNotifier.new,
    );

/// Runs once at startup. Restores a persisted session, or settles on signed out.
final startupProvider = FutureProvider<void>((ref) async {
  final session = ref.read(apiLayerProvider).session;
  if (session.state is SessionUnknown) {
    await session.restore();
  }
});

final homeSummaryProvider = Provider<HomeSummary?>((ref) {
  ref.watch(permissionRevisionProvider);
  final session = ref.watch(sessionStateProvider);
  if (session is! SessionAuthenticated) return null;
  final permissions = ref.watch(apiLayerProvider).permissions;
  return HomeSummary.fromServer(
    profile: session.profile,
    permissions: permissions,
  );
});

/// Whether the latest home read used per-section data instead of `GET /api/home`.
///
/// The flag is written by [homeDashboardProvider] before that future completes.
/// Widgets read it on the rebuild the future causes. [HomeDto] itself is unchanged.
class HomeLoadMeta {
  bool fromFallback = false;
}

final homeLoadMetaProvider = Provider<HomeLoadMeta>((ref) => HomeLoadMeta());

/// Proposed `GET /api/home`. When that call fails, per-section fields are shown
/// as returned, with no totals combined across sections.
final homeDashboardProvider = FutureProvider<HomeDto?>((ref) async {
  final session = ref.watch(sessionStateProvider);
  final meta = ref.read(homeLoadMetaProvider);
  if (session is! SessionAuthenticated) {
    meta.fromFallback = false;
    return null;
  }
  meta.fromFallback = false;
  final result = await loadHomeDetailed(ref.read(apiLayerProvider));
  meta.fromFallback = result.fromFallback;
  return result.home;
});
