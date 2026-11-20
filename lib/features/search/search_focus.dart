import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app-bar shortcut also focuses an already-open search route.
final searchInputFocusProvider = Provider.autoDispose<FocusNode>((ref) {
  final focus = FocusNode(debugLabel: 'unified-account-search');
  ref.onDispose(focus.dispose);
  return focus;
});
