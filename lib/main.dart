import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'error_handling/error_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const errors = ErrorHandler();
  FlutterError.onError = (details) {
    errors.report(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errors.report(error, stack);
    return true;
  };
  runApp(const ProviderScope(child: CompanyApp()));
}
