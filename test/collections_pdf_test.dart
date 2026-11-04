import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
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

  group('daily statement rows (537 website exportPdf rule)', () {
    const batch = CollectionBatchDto(id: 'b1', businessDate: '2026-11-03');
    CollectionSubmissionDto sub(
      String id,
      String status,
      int units, {
      String batchId = 'b1',
      String collector = 'u1',
    }) => CollectionSubmissionDto(
      id: id,
      mode: 'full',
      status: status,
      amountUnits: MoneyValue.known(units),
      customerName: 'عميل $id',
      batchId: batchId,
      collectorUserId: collector,
    );
    final data = CollectionsOverviewDto(
      assignments: const [],
      employeeTotals: const [],
      openBatches: const [batch],
      submissions: [
        sub('a', 'approved', 100),
        sub('b', 'pending', 50),
        sub('c', 'rejected', 70),
        sub('d', 'approved', 30, batchId: 'b0'),
        sub('e', 'approved', 25, collector: 'u2'),
      ],
      unlinkedReceipts: const [
        UnlinkedReceiptDto(
          id: 'r1',
          customerName: 'اسم حر',
          status: 'approved',
          amountUnits: MoneyValue.known(40),
          batchId: 'b1',
        ),
        UnlinkedReceiptDto(
          id: 'r2',
          customerName: 'اسم معلق',
          status: 'pending',
          amountUnits: MoneyValue.known(9),
          batchId: 'b1',
        ),
      ],
    );
    final now = DateTime(2026, 11, 3, 20);

    test('admin: approved rows of the batch, linked then standalone', () {
      final s = DailyStatement.of(data, batchId: 'b1', now: now);
      expect(s.businessDate, '2026-11-03');
      expect([for (final r in s.rows) r.name], ['عميل a', 'عميل e', 'اسم حر']);
      expect(s.totalUnits, 165);
    });

    test('employee: only their own submissions', () {
      final s = DailyStatement.of(
        data,
        batchId: 'b1',
        now: now,
        collectorUserId: 'u1',
        employeeName: 'موظف',
      );
      expect([for (final r in s.rows) r.name], ['عميل a', 'اسم حر']);
      expect(s.totalUnits, 140);
    });

    test('no batch: empty statement dated today', () {
      final s = DailyStatement.of(data, batchId: null, now: now);
      expect(s.rows, isEmpty);
      expect(s.businessDate, '2026-11-03');
    });
  });

  testWidgets('statement renders with the app font and paginates', (
    tester,
  ) async {
    const names = [
      'محمد عبد الله الشريف',
      'فاطمة علي المصراتي',
      'أحمد سالم بن عمران',
      'خديجة يوسف الزاوي',
      'عبد الرحمن مفتاح القماطي',
      'سارة إبراهيم الورفلي',
      'شركة النور للمقاولات',
      'مصطفى خليفة الترهوني',
    ];
    const units = [1250, 400, 75, 3200, 980, 150, 12500, 640];
    final statement = DailyStatement(
      businessDate: '2026-11-03',
      rows: [
        for (var i = 0; i < names.length; i++)
          DailyStatementRow(names[i], units[i]),
      ],
    );
    final long = DailyStatement(
      businessDate: '2026-11-03',
      rows: [
        for (var i = 0; i < 40; i++)
          DailyStatementRow(names[i % names.length], units[i % units.length]),
      ],
    );
    const money = MoneyFormatter();
    await tester.runAsync(() async {
      final loader = FontLoader('IBMPlexSansArabic');
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(
          rootBundle.load('assets/fonts/IBMPlexSansArabic-$w.ttf'),
        );
      }
      await loader.load();

      final pages = await renderDailyStatementPages(statement, money: money);
      expect(pages, hasLength(1));
      expect(await renderDailyStatementPages(long, money: money), hasLength(2));
      final pdf = await buildCollectionsPdf(statement: statement, money: money);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

      final dir = _sampleDir;
      if (dir != null) {
        Directory(dir).createSync(recursive: true);
        File('$dir/collections-daily-sample.pdf').writeAsBytesSync(pdf);
        File('$dir/collections-daily-sample.png').writeAsBytesSync(pages[0]);
        final employee = DailyStatement(
          businessDate: '2026-11-03',
          employeeName: 'موظف تجريبي',
          rows: statement.rows.take(3).toList(),
        );
        File('$dir/collections-daily-employee-sample.pdf').writeAsBytesSync(
          await buildCollectionsPdf(statement: employee, money: money),
        );
      }
    });
  });

  test('file name carries the export minute', () {
    expect(
      collectionsPdfFileName(DateTime(2026, 1, 5, 7, 9)),
      'collections-2026-01-05-0709.pdf',
    );
  });
}
