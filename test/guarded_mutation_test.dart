import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/mutation_form.dart';

void main() {
  testWidgets(
    'a non-null failure reuses the request id only while the request is unchanged',
    (tester) async {
      final host = await _pump(tester);

      await _send(tester, host, 'no');
      await _send(tester, host, 'no');

      expect(host.ids, hasLength(2));
      expect(host.ids[1], host.ids[0]);
      expect(host.versions, [1, 1]);

      host.bumpVersion();
      await tester.pump();
      await _send(tester, host, 'no');

      expect(host.ids, hasLength(3));
      expect(host.ids[2], isNot(host.ids[0]));
      expect(host.versions, [1, 1, 2]);

      host.bumpPayload();
      await tester.pump();
      await _send(tester, host, 'no');

      expect(host.ids, hasLength(4));
      expect(host.ids[3], isNot(host.ids[2]));
      expect(host.versions, [1, 1, 2, 2]);
    },
  );

  testWidgets(
    'returning a conflict message still starts a new id once the version changes',
    (tester) async {
      final host = await _pump(tester, bumpOnFailure: true);

      await _send(tester, host, 'conflict');
      await _send(tester, host, 'conflict');

      expect(host.ids, hasLength(2));
      expect(host.ids[1], isNot(host.ids[0]));
      expect(host.versions, [1, 2]);
    },
  );

  testWidgets(
    'VERSION_CONFLICT refetches, shows the conflict message, and rotates the id when the version changes',
    (tester) async {
      final host = await _pump(tester, bumpOnConflict: true);

      await _fail(
        tester,
        host,
        const ConflictException(
          code: 'VERSION_CONFLICT',
          message: 'تم تعديل البيانات من مستخدم آخر',
          statusCode: 409,
        ),
      );

      expect(host.conflicts, 1);
      expect(find.text(AppStrings.versionConflict), findsWidgets);
      expect(find.text('تم تعديل البيانات من مستخدم آخر'), findsNothing);

      await _send(tester, host, 'no');

      expect(host.ids, hasLength(2));
      expect(host.ids[1], isNot(host.ids[0]));
      expect(host.versions, [1, 2]);
      await _drainSnackBar(tester);
    },
  );

  testWidgets('a version conflict keeps the request id when nothing changed', (
    tester,
  ) async {
    final host = await _pump(tester);

    await _fail(
      tester,
      host,
      const ConflictException(
        code: 'VERSION_CONFLICT',
        message: 'تم تعديل البيانات من مستخدم آخر',
        statusCode: 409,
      ),
    );
    await _fail(
      tester,
      host,
      const ConflictException(
        code: 'VERSION_CONFLICT',
        message: 'تم تعديل البيانات من مستخدم آخر',
        statusCode: 409,
      ),
    );

    expect(host.conflicts, 2);
    expect(host.ids, hasLength(2));
    expect(host.ids[1], host.ids[0]);
    expect(host.versions, [1, 1]);
    await _drainSnackBar(tester);
  });

  testWidgets(
    'session expiry says the write was not saved and a manual retry reuses the request id',
    (tester) async {
      final host = await _pump(tester);

      await _fail(
        tester,
        host,
        const SessionExpiredException(
          code: 'AUTH_REQUIRED',
          message: 'انتهت الجلسة، يرجى تسجيل الدخول',
          statusCode: 401,
        ),
      );

      expect(find.text(AppStrings.writeNotSaved), findsOneWidget);
      expect(find.text('انتهت الجلسة، يرجى تسجيل الدخول'), findsNothing);
      expect(host.conflicts, 0);

      await _fail(
        tester,
        host,
        const SessionExpiredException(statusCode: 419, code: 'PAGE_EXPIRED'),
      );

      expect(host.ids, hasLength(2));
      expect(host.ids[1], host.ids[0]);
      expect(host.versions, [1, 1]);
    },
  );

  testWidgets('a non-conflict error does not refetch', (tester) async {
    final host = await _pump(tester);

    await _fail(
      tester,
      host,
      const ForbiddenException(
        code: 'FORBIDDEN',
        message: 'هذا الإجراء للإدارة فقط',
        statusCode: 403,
      ),
    );

    expect(host.conflicts, 0);
    expect(find.text('هذا الإجراء للإدارة فقط'), findsOneWidget);
    expect(find.text(AppStrings.versionConflict), findsNothing);
  });

  testWidgets('a confirmed send uses the same conflict handling', (
    tester,
  ) async {
    final host = await _pump(tester, confirm: true, bumpOnConflict: true);

    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await tester.pump();
    host.gate.completeError(
      const ConflictException(
        code: 'VERSION_CONFLICT',
        message: 'تم تعديل البيانات من مستخدم آخر',
        statusCode: 409,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(host.conflicts, 1);
    expect(find.text(AppStrings.versionConflict), findsWidgets);
    expect(host.versions, [1]);

    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await tester.pump();
    host.gate.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(host.ids, hasLength(2));
    expect(host.ids[1], isNot(host.ids[0]));
    expect(host.versions, [1, 2]);
    await _drainSnackBar(tester);
  });
}

Future<_HostState> _pump(
  WidgetTester tester, {
  bool bumpOnFailure = false,
  bool bumpOnConflict = false,
  bool confirm = false,
}) async {
  final key = GlobalKey<_HostState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityPortProvider.overrideWithValue(
          const FixedConnectivity(true),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: _Host(
            key: key,
            confirm: confirm,
            bumpOnFailure: bumpOnFailure,
            bumpOnConflict: bumpOnConflict,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return key.currentState!;
}

Future<void> _send(
  WidgetTester tester,
  _HostState host,
  String? message,
) async {
  await tester.tap(find.byKey(const Key('send')));
  await tester.pump();
  host.gate.complete(message);
  await tester.pump();
}

Future<void> _fail(WidgetTester tester, _HostState host, Object error) async {
  await tester.tap(find.byKey(const Key('send')));
  await tester.pump();
  host.gate.completeError(error);
  await tester.pump();
}

Future<void> _drainSnackBar(WidgetTester tester) {
  return tester.pump(const Duration(seconds: 5));
}

class _Host extends StatefulWidget {
  const _Host({
    required this.bumpOnFailure,
    required this.bumpOnConflict,
    required this.confirm,
    super.key,
  });

  final bool bumpOnFailure;
  final bool bumpOnConflict;
  final bool confirm;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int version = 1;
  String payload = 'same';
  int conflicts = 0;
  final ids = <String>[];
  final versions = <int?>[];
  var gate = Completer<String?>();

  void bumpVersion() => setState(() => version += 1);

  void bumpPayload() => setState(() => payload = '$payload-next');

  @override
  Widget build(BuildContext context) {
    return GuardedMutation(
      buttonKey: const Key('send'),
      inputs: payload,
      expectedVersion: version,
      label: 'Send',
      confirmText: widget.confirm ? 'confirm this' : null,
      onVersionConflict: () {
        conflicts += 1;
        if (widget.bumpOnConflict) bumpVersion();
      },
      onSubmit: (meta) {
        ids.add(meta.requestId);
        versions.add(meta.expectedVersion);
        gate = Completer<String?>();
        return gate.future.then((message) {
          if (widget.bumpOnFailure && message != null) bumpVersion();
          return message;
        });
      },
    );
  }
}
