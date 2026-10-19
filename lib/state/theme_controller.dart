import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_providers.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'app-theme';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      if (prefs.getString(_key) == 'dark') state = ThemeMode.dark;
    } catch (_) {}
  }

  Future<void> setDark(bool dark) async {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> toggle() => setDark(state != ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class OnlineController extends Notifier<bool> {
  @override
  bool build() => true;

  void setOnline(bool value) => state = value;
}

final onlineProvider = NotifierProvider<OnlineController, bool>(
  OnlineController.new,
);

class PermissionRevision extends Notifier<int> {
  @override
  int build() {
    final service = ref.watch(apiLayerProvider).permissions;
    void listener() => state++;
    service.addListener(listener);
    ref.onDispose(() => service.removeListener(listener));
    return 0;
  }
}

final permissionRevisionProvider = NotifierProvider<PermissionRevision, int>(
  PermissionRevision.new,
);

PermissionService permissionsOf(WidgetRef ref) {
  ref.watch(permissionRevisionProvider);
  return ref.watch(apiLayerProvider).permissions;
}
