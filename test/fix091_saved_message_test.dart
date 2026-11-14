import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/error_handling/app_failure.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  test('a raw error code becomes Arabic and never stays a code', () {
    expect(
      failureText(
        const AppFailure(message: 'VERSION_CONFLICT', code: 'VERSION_CONFLICT'),
      ),
      AppStrings.versionConflict,
    );
    expect(
      failureText(const AppFailure(message: 'pe_new', code: 'REQUEST_FAILED')),
      isNot(contains('pe_new')),
    );
    expect(
      failureText(
        const AppFailure(
          message: 'اليوم مرحّل. لا يمكن إضافة أو تعديل أو حذف بند.',
          code: 'DAY_FINALIZED',
        ),
      ),
      'اليوم مرحّل. لا يمكن إضافة أو تعديل أو حذف بند.',
    );
    expect(
      failureText(const AppFailure(message: 'FORBIDDEN', code: 'FORBIDDEN')),
      AppStrings.forbidden,
    );
    expect(friendlyErrorCode('NOT_A_REAL_CODE'), AppStrings.genericError);
    expect(friendlyErrorCode('NOT_A_REAL_CODE').contains('_'), isFalse);
  });

  testWidgets('saving a purchase says تم الحفظ and not the server id', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1100, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.ensureVisible(find.byKey(const Key('purchase-kind-fawry')));
    await tester.tap(find.byKey(const Key('purchase-kind-fawry')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('purchase-field-value')),
      '100',
    );
    await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
    await tester.enterText(find.byKey(const Key('purchase-field-paid')), '10');
    await tester.ensureVisible(find.byKey(const Key('save-purchase')));
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.saved), findsOneWidget);
    expect(find.textContaining('رد الخادم'), findsNothing);
    expect(find.textContaining('pe_new'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
