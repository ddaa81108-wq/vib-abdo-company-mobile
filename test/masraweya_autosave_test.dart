import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_autosave.dart';

void main() {
  MasraweyaDraft draft({
    int previous = 10000,
    int purchases = 2000,
    List<(int, int)> rows = const [(3000, 50)],
    bool summaryLeave = false,
    bool previousEditable = true,
  }) {
    return MasraweyaDraft(
      businessDate: '2026-10-19',
      previousText: '$previous',
      previousEditable: previousEditable,
      lockedPreviousUnits: previous,
      purchasesText: '$purchases',
      rows: [
        for (final row in rows)
          MasraweyaRowDraft(
            valueText: '${row.$1}',
            commissionText: '${row.$2}',
          ),
      ],
      summaryLeave: summaryLeave,
    );
  }

  MasraweyaDayDto day(int version) => MasraweyaDayDto(
    businessDate: '2026-10-19',
    version: version,
    previousValueUnits: const MoneyValue.known(10000),
    purchasesUnits: const MoneyValue.known(2000),
    workTotalUnits: const MoneyValue.known(3050),
    remainingUnits: const MoneyValue.known(8950),
  );

  test('two leaves serialize and the newer draft waits', () async {
    final calls = <int>[];
    final versions = <int?>[];
    final gates = <Completer<void>>[];
    var version = 2;
    final autosave = MasraweyaAutosave(
      send: (request, meta) async {
        calls.add(request.purchasesUnits!);
        versions.add(meta.expectedVersion);
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        version += 1;
        return day(version);
      },
    );
    autosave.bindLoaded(day(2), draft());
    autosave.noteLeave(draft(purchases: 9), leftRowIndex: 0, online: true);
    final first = autosave.pump();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [9]);
    expect(autosave.phase, MasraweyaSavePhase.saving);

    autosave.noteLeave(draft(purchases: 11), leftRowIndex: 0, online: true);
    final second = autosave.pump();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [9]);

    gates.single.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [9, 11]);
    gates[1].complete();
    await first;
    await second;
    expect(calls, [9, 11]);
    expect(versions, [2, 3]);
    expect(autosave.serverVersion, 4);
    expect(autosave.authoritative?.workTotalUnits?.units, 3050);
    expect(autosave.phase, MasraweyaSavePhase.saved);
    expect(autosave.sentRequestIds, hasLength(2));
    expect(autosave.sentRequestIds[0], isNot(autosave.sentRequestIds[1]));
  });

  test('an error keeps the request id and a conflict does not auto-send', () async {
    final autosave = MasraweyaAutosave(
      send: (request, meta) async {
        throw const ConflictException(
          code: 'VERSION_CONFLICT',
          message: 'conflict',
        );
      },
    );
    autosave.bindLoaded(day(2), draft());
    autosave.noteLeave(draft(previous: 1), leftRowIndex: 0, online: true);
    await autosave.pump();
    expect(autosave.phase, MasraweyaSavePhase.conflict);
    expect(autosave.blocksNavigation, isTrue);
    final sent = autosave.sentRequestIds.length;

    autosave.noteLeave(draft(previous: 8), leftRowIndex: 0, online: true);
    await autosave.pump();
    await autosave.retry();
    expect(autosave.sentRequestIds, hasLength(sent));

    autosave.adoptFreshVersion(3);
    autosave.noteLeave(draft(previous: 8), leftRowIndex: 0, online: true);
    // The sender still conflicts; the point is a new id and the new version.
    await autosave.pump();
    expect(autosave.sentVersions.last, 3);
    expect(autosave.sentRequestIds.last, isNot(autosave.sentRequestIds.first));
  });

  test('a failed send reuses the request id until the draft changes', () async {
    var fail = true;
    final autosave = MasraweyaAutosave(
      send: (request, meta) async {
        if (fail) {
          throw Exception('network');
        }
        return day(3);
      },
    );
    autosave.bindLoaded(day(2), draft());
    autosave.noteLeave(draft(purchases: 9), leftRowIndex: 0, online: true);
    await autosave.pump();
    expect(autosave.phase, MasraweyaSavePhase.error);
    final id = autosave.sentRequestIds.single;

    fail = false;
    await autosave.retry();
    expect(autosave.sentRequestIds, [id, id]);
    expect(autosave.phase, MasraweyaSavePhase.saved);

    autosave.noteLeave(draft(purchases: 4), leftRowIndex: 0, online: true);
    await autosave.pump();
    expect(autosave.sentRequestIds, hasLength(3));
    expect(autosave.sentRequestIds.last, isNot(id));
  });

  test('a partial row and an offline leave do not send', () async {
    final autosave = MasraweyaAutosave(
      send: (request, meta) async => day(3),
    );
    final initial = draft();
    autosave.bindLoaded(day(2), initial);
    final partial = MasraweyaDraft(
      businessDate: '2026-10-19',
      previousText: '10000',
      previousEditable: true,
      lockedPreviousUnits: 10000,
      purchasesText: '2000',
      rows: const [
        MasraweyaRowDraft(valueText: '3000', commissionText: '50'),
        MasraweyaRowDraft(valueText: '5', commissionText: ''),
      ],
      summaryLeave: false,
    );
    autosave.noteLeave(partial, leftRowIndex: 0, online: true);
    await autosave.pump();
    expect(autosave.sentRequestIds, isEmpty);
    expect(autosave.issue, MasraweyaDraftIssue.partialRow);
    expect(autosave.blocksNavigation, isTrue);

    autosave.noteLeave(draft(purchases: 3), leftRowIndex: 0, online: false);
    await autosave.pump();
    expect(autosave.sentRequestIds, isEmpty);
    expect(autosave.issue, MasraweyaDraftIssue.offline);
  });

  test('shiftIsoDate is a calendar step and editability is the server flag', () {
    expect(shiftIsoDate('2026-10-01', -1), '2026-09-30');
    expect(shiftIsoDate('2026-10-19', -8), '2026-10-11');
    expect(
      masraweyaFieldsEditable(canWrite: true, serverEditable: false),
      isFalse,
    );
    expect(
      masraweyaFieldsEditable(canWrite: true, serverEditable: null),
      isTrue,
    );
    expect(
      masraweyaFieldsEditable(canWrite: false, serverEditable: true),
      isFalse,
    );
  });
}
