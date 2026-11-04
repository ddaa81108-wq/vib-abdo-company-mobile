import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_export.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_pdf.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// Set to a folder to also save the sample PDFs (fake data only).
final _sampleDir = Platform.environment['COLLECTIONS_PDF_SAMPLE_DIR'];

void main() {
  for (final role in ['admin', 'employee']) {
    testWidgets('$role export builds the PDF on the device, no new request', (
      tester,
    ) async {
      final shared = <(Uint8List, String)>[];
      final layer = await pumpFakeApp(
        tester,
        size: const Size(430, 2400),
        overrides: [
          collectionsPdfSharerProvider.overrideWithValue((bytes, name) async {
            shared.add((bytes, name));
          }),
          collectionsExportClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 3, 20, 15),
          ),
        ],
      );
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: '$role.demo', password: 'demo-only');
      await go(tester, '/collections');

      final button = find.byKey(CollectionsExportButton.buttonKey);
      expect(button, findsOneWidget);
      expect(
        find.descendant(
          of: button,
          matching: find.text(
            role == 'admin'
                ? CollectionsText.exportBatch
                : CollectionsText.exportDay,
          ),
        ),
        findsOneWidget,
      );
      final reads = fake.collectionOverviewReads;
      final writes = fake.mutationPaths.length;

      await tester.runAsync(() async {
        await tester.tap(button);
        for (var i = 0; i < 200 && shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await settle(tester);

      expect(shared, hasLength(1));
      final (bytes, name) = shared.single;
      expect(name, 'collections-2026-11-03-2015.pdf');
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(20000)); // fonts are embedded
      expect(fake.collectionOverviewReads, reads);
      expect(fake.mutationPaths, hasLength(writes));
      expect(find.text(CollectionsPdfText.failed), findsNothing);
      expect(tester.takeException(), isNull);

      final dir = _sampleDir;
      if (dir != null) {
        Directory(dir).createSync(recursive: true);
        File('$dir/collections-$role-sample.pdf').writeAsBytesSync(bytes);
      }
    });
  }

  testWidgets('a failed export says so and keeps the button', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 2400),
      overrides: [
        collectionsPdfSharerProvider.overrideWithValue(
          (bytes, name) async => throw StateError('share sheet unavailable'),
        ),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(CollectionsExportButton.buttonKey));
      for (
        var i = 0;
        i < 200 && find.text(CollectionsPdfText.failed).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    expect(find.text(CollectionsPdfText.failed), findsOneWidget);
    await settle(tester);
    expect(find.byKey(CollectionsExportButton.buttonKey), findsOneWidget);
    expect(find.byKey(CollectionsExportButton.busyKey), findsNothing);
  });

  test('file name carries the export minute', () {
    expect(
      collectionsPdfFileName(DateTime(2026, 1, 5, 7, 9)),
      'collections-2026-01-05-0709.pdf',
    );
  });
}
