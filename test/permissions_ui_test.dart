import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('unknown role with empty permissions opens nothing', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'unknown.demo', password: 'demo-only');

    expect(find.text(AppStrings.noSections), findsOneWidget);
    expect(find.text(AppStrings.roleUnknown), findsOneWidget);
    for (final section in SectionKey.values) {
      expect(find.byKey(HomeShell.sectionKey(section)), findsNothing);
      expect(find.byKey(HomeShell.writeKey(section)), findsNothing);
    }
  });

  testWidgets('employee with a read-only permission sees no write buttons', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'readonly.demo', password: 'demo-only');

    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.customers)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.writeAction), findsNothing);
    for (final section in SectionKey.values) {
      expect(find.byKey(HomeShell.writeKey(section)), findsNothing);
    }
  });

  testWidgets('employee without sectionAccess for a section does not see it', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'nosection.demo', password: 'demo-only');

    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.customers)),
      findsOneWidget,
    );
    expect(find.byKey(HomeShell.sectionKey(SectionKey.treasury)), findsNothing);
    expect(find.text(AppStrings.writeAction), findsNothing);
  });

  testWidgets(
    'admin with an explicit permission list is limited to that list',
    (tester) async {
      await pumpFakeApp(tester);
      await signIn(
        tester,
        username: 'limited.admin.demo',
        password: 'demo-only',
      );

      expect(find.text('مدير مقيّد تجريبي'), findsOneWidget);
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.collections)),
        findsOneWidget,
      );
      expect(
        find.byKey(HomeShell.writeKey(SectionKey.collections)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
        findsNothing,
      );
      expect(
        find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        findsNothing,
      );
      expect(find.text(AppStrings.writeAction), findsNothing);
    },
  );
}
