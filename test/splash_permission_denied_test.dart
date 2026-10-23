import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/splash/splash_screen.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

void main() {
  testWidgets('splash shows the forbidden pane for PERMISSION_DENIED', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith((ref) async {
            throw const ForbiddenException(
              code: 'PERMISSION_DENIED',
              message: 'سر الخادم',
              statusCode: 403,
            );
          }),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(SplashScreen.screenKey), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text('سر الخادم'), findsNothing);
    expect(find.byKey(SplashScreen.retryKey), findsNothing);
  });

  testWidgets('splash still shows the forbidden pane for FORBIDDEN', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProvider.overrideWith((ref) async {
            throw const ForbiddenException(
              code: 'FORBIDDEN',
              message: 'سر الخادم',
              statusCode: 403,
            );
          }),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text('سر الخادم'), findsNothing);
  });
}
