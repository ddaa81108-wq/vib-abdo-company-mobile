import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import 'session_providers.dart';

/// Unread badge. The integer is the server's `unreadCount`, or null while
/// that request has not completed. The app never increments it locally.
final unreadCountProvider = FutureProvider<int?>((ref) async {
  final session = ref.watch(sessionStateProvider);
  if (session is! SessionAuthenticated) return null;
  return ref.watch(apiLayerProvider).notifications.fetchUnreadCount();
});
