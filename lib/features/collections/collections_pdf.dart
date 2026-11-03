import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'collection_card_tone.dart';
import 'collections_strings.dart';

/// Words used only in the exported report.
abstract final class CollectionsPdfText {
  static const title = 'تقرير استلامات الديون';
  static const adminScope = 'تقرير الإدارة';
  static String employeeScope(String name) => 'تقرير الموظف: $name';
  static const exportedAt = 'تاريخ التصدير';
  static const source = 'المصدر';
  static const batch = 'الدفعة';
  static const totals = 'الإجماليات';
  static const item = 'البند';
  static const value = 'القيمة';
  static const employee = 'الموظف';
  static const approvedCount = 'معتمد';
  static const pendingCount = 'ينتظر';
  static const collected = 'المحصل المعتمد';
  static const cards = 'الكروت الموجهة';
  static const myCards = 'الكروت الموجهة إليك';
  static const customer = 'العميل';
  static const balance = 'الرصيد الحالي';
  static const lastState = 'آخر حالة';
  static const receiptsCount = 'الاستلامات';
  static const receipts = 'سجل الاستلامات';
  static const kind = 'النوع';
  static const amount = 'المبلغ';
  static const state = 'الحالة';
  static const date = 'التاريخ';
  static const unlinked = 'استلامات بلا كارت موجه';
  static const myUnlinked = 'استلامات سجلتها بدون كارت موجه';
  static const name = 'الاسم';
  static const collector = 'المحصل';
  static const cash = 'النقدية';
  static const outstanding = 'نقدية دفعات سابقة لم تُستلم';
  static const none = 'لا يوجد.';
  static const noReceipt = 'بلا استلام';
  static const rejected = 'مرفوض';
  static const approved = 'معتمد';
  static const footer =
      'أُنشئ في التطبيق من بيانات الخادم المحمّلة وقت التصدير. للقراءة فقط.';
  static String page(int n, int of) => 'صفحة $n من $of';
  static const failed = 'تعذر إنشاء ملف PDF.';
}

/// The four IBM Plex Sans Arabic weights the app bundles.
class CollectionsPdfFonts {
  const CollectionsPdfFonts({
    required this.regular,
    required this.medium,
    required this.bold,
  });

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;

  static Future<CollectionsPdfFonts> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<pw.Font> font(String file) async =>
        pw.Font.ttf(await b.load('assets/fonts/$file'));
    return CollectionsPdfFonts(
      regular: await font('IBMPlexSansArabic-Regular.ttf'),
      medium: await font('IBMPlexSansArabic-Medium.ttf'),
      bold: await font('IBMPlexSansArabic-Bold.ttf'),
    );
  }
}

String collectionsPdfFileName(DateTime at) =>
    'collections-${_date(at)}-${_two(at.hour)}${_two(at.minute)}.pdf';

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
String _stamp(DateTime t) => '${_date(t)} ${_two(t.hour)}:${_two(t.minute)}';

final _ltrWord = RegExp(r'[0-9A-Za-z]');
final _arabicLetter = RegExp(r'[\u0600-\u06FF]');

/// Text for an RTL page that may hold numbers, dates or Latin words.
///
/// The pdf package reorders mixed Arabic / number text unreliably (a date
/// like 2026-11-03 comes out as 03-11-2026, an amount swaps with «د.ل»). So
/// words with digits or Latin letters are grouped and drawn as their own
/// left-to-right runs, and the runs are laid out right to left.
pw.Widget pdfBidiText(String text, {pw.TextStyle? style, bool fill = false}) {
  if (!_ltrWord.hasMatch(text)) return pw.Text(text, style: style);
  final runs = <(bool, String)>[];
  for (final word in text.split(' ')) {
    if (word.isEmpty) continue;
    final ltr = _ltrWord.hasMatch(word) && !_arabicLetter.hasMatch(word);
    if (runs.isNotEmpty && runs.last.$1 == ltr) {
      runs[runs.length - 1] = (ltr, '${runs.last.$2} $word');
    } else {
      runs.add((ltr, word));
    }
  }
  // pw.Row follows the page's RTL direction (pw.Wrap does not).
  return pw.Row(
    mainAxisSize: fill ? pw.MainAxisSize.max : pw.MainAxisSize.min,
    children: [
      for (var i = 0; i < runs.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 3.5),
        pw.Text(
          runs[i].$2,
          style: style,
          textDirection: runs[i].$1
              ? pw.TextDirection.ltr
              : pw.TextDirection.rtl,
        ),
      ],
    ],
  );
}

/// Builds the collections report from the overview the screen already has.
///
/// No request is made: 537f073 has no export route, so every figure here is
/// the server's own (`metrics`, `employeeTotals`, the card and receipt rows).
/// [admin] adds the per-employee totals and earlier outstanding cash; an
/// employee's overview is already scoped by the server to their own rows.
Future<Uint8List> buildCollectionsPdf({
  required CollectionsOverviewDto data,
  required bool admin,
  required String userName,
  required String environmentLabel,
  required DateTime exportedAt,
  required MoneyFormatter money,
  required CollectionsPdfFonts fonts,
}) async {
  String lyd(MoneyValue? v) => money.formatOrDash(v, Currency.lyd);
  String count(int? v) => v == null ? '—' : '$v';

  const ink = PdfColor.fromInt(0xFF1B1F3B);
  const muted = PdfColor.fromInt(0xFF5B6177);
  const line = PdfColor.fromInt(0xFFD5D9E6);
  const head = PdfColor.fromInt(0xFFEEF0FA);
  const accent = PdfColor.fromInt(0xFF2B3BD6);

  final theme = pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold)
      .copyWith(
        // The pdf package draws Arabic without the font's kerning, so the long
        // tails of ر / ت reach into the next word; a little word spacing keeps
        // the words apart as on screen.
        defaultTextStyle: pw.TextStyle(
          fontSize: 9.5,
          color: ink,
          wordSpacing: 2.4,
          font: fonts.regular,
          fontBold: fonts.bold,
        ),
      );

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: fonts.bold, fontSize: 12.5, color: accent),
    ),
  );

  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
    Set<int> numeric = const {},
  }) {
    if (rows.isEmpty) {
      return pw.Text(
        CollectionsPdfText.none,
        style: const pw.TextStyle(color: muted),
      );
    }
    pw.Widget cell(String text, {bool header = false, int col = 0}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
          child: pdfBidiText(
            text,
            // Fill the cell so the runs start at its right (start) edge.
            fill: true,
            style: header
                ? pw.TextStyle(font: fonts.medium, fontSize: 9, color: ink)
                : null,
          ),
        );
    // pw.Table always lays columns out left to right, so the first (start)
    // column is placed last to read right to left.
    final n = headers.length;
    List<T> rtl<T>(List<T> cells) => cells.reversed.toList();
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: line, width: .6),
        top: pw.BorderSide(color: line, width: .6),
        bottom: pw.BorderSide(color: line, width: .6),
      ),
      columnWidths: widths == null
          ? null
          : {for (final e in widths.entries) n - 1 - e.key: e.value},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: head),
          repeat: true,
          children: rtl([
            for (var i = 0; i < n; i++) cell(headers[i], header: true, col: i),
          ]),
        ),
        for (final row in rows)
          pw.TableRow(
            children: rtl([
              for (var i = 0; i < row.length; i++) cell(row[i], col: i),
            ]),
          ),
      ],
    );
  }

  String submissionState(CollectionSubmissionDto s) {
    if (s.status == 'pending') return CollectionsText.awaitingApproval;
    if (s.status == 'rejected') return CollectionsPdfText.rejected;
    if (s.awaitingCash) {
      return admin
          ? CollectionsText.awaitingCash
          : CollectionsText.waitingCashFromAdmin;
    }
    if (s.cashReceivedAt != null) return CollectionsText.cashReceived;
    return CollectionsPdfText.approved;
  }

  String cardState(CollectionAssignmentDto a) => switch (a.latestStatus) {
    'pending' => CollectionsText.awaitingApproval,
    'approved' => CollectionsPdfText.approved,
    'rejected' => CollectionsPdfText.rejected,
    _ => CollectionsPdfText.noReceipt,
  };

  String unlinkedState(UnlinkedReceiptDto r) => switch (r.status) {
    'pending' =>
      admin ? CollectionsText.unlinked : CollectionsText.myUnlinkedPending,
    'approved' => CollectionsText.unlinkedApproved,
    _ => CollectionsText.rejectedByAdmin,
  };

  String unlinkedCash(UnlinkedReceiptDto r) {
    if (r.status != 'approved') return '—';
    if (r.cashReceivedAt != null) return CollectionsText.cashReceived;
    return admin
        ? CollectionsText.awaitingCash
        : CollectionsText.waitingCashFromAdmin;
  }

  String day(DateTime? t) => t == null ? '—' : _date(t.toLocal());

  final batch = data.openBatches.isEmpty ? null : data.openBatches.first;

  final receiptRows = <List<String>>[];
  for (final a in data.assignments) {
    var partial = 0;
    for (final s in collectionCardHistory(data, a.id)) {
      receiptRows.add([
        a.customerName,
        if (admin) a.assigneeName ?? '—',
        s.mode == 'full'
            ? CollectionsText.fullReceipt
            : CollectionsText.partialReceiptN(++partial),
        lyd(s.amountUnits),
        submissionState(s),
        day(s.createdAt),
      ]);
    }
  }

  final doc = pw.Document(
    title: CollectionsPdfText.title,
    author: 'VIB',
    creator: 'VIB mobile',
  );
  doc.addPage(
    pw.MultiPage(
      theme: theme,
      textDirection: pw.TextDirection.rtl,
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 32,
        marginRight: 32,
        marginTop: 30,
        marginBottom: 30,
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pdfBidiText(
                '${CollectionsPdfText.title} — ${_stamp(exportedAt)}',
                style: const pw.TextStyle(fontSize: 8, color: muted),
              ),
            ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: line, width: .6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              CollectionsPdfText.footer,
              style: const pw.TextStyle(fontSize: 7.5, color: muted),
            ),
            pdfBidiText(
              CollectionsPdfText.page(context.pageNumber, context.pagesCount),
              style: const pw.TextStyle(fontSize: 7.5, color: muted),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: line, width: .8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                CollectionsPdfText.title,
                style: pw.TextStyle(font: fonts.bold, fontSize: 17),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                admin
                    ? CollectionsPdfText.adminScope
                    : CollectionsPdfText.employeeScope(userName),
                style: pw.TextStyle(font: fonts.medium, fontSize: 10.5),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  for (final part in [
                    '${CollectionsPdfText.exportedAt}: ${_stamp(exportedAt)}',
                    '${CollectionsPdfText.source}: $environmentLabel',
                    if (batch != null)
                      '${CollectionsPdfText.batch}: ${CollectionsText.batchLabel(batch.businessDate, batch.batchNumber)}',
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12),
                      child: pdfBidiText(
                        part,
                        style: const pw.TextStyle(fontSize: 9, color: muted),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        heading(CollectionsPdfText.totals),
        table(
          [CollectionsPdfText.item, CollectionsPdfText.value],
          [
            [CollectionsText.totalApproved, lyd(data.collectedUnits)],
            [CollectionsText.assigned, count(data.assignedCount)],
            [CollectionsText.executed, count(data.executedCount)],
            [CollectionsText.pending, count(data.pendingCount)],
            [CollectionsText.unlinked, count(data.unlinkedPendingCount)],
            [CollectionsText.cashOutstanding, lyd(data.cashOutstandingUnits)],
          ],
          widths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
          numeric: const {1},
        ),
        if (admin) ...[
          heading(CollectionsText.employeeTotals),
          table(
            [
              CollectionsPdfText.employee,
              CollectionsPdfText.approvedCount,
              CollectionsPdfText.pendingCount,
              CollectionsPdfText.collected,
            ],
            [
              for (final e in data.employeeTotals)
                [
                  e.employeeName,
                  count(e.approvedCount),
                  count(e.pendingCount),
                  lyd(e.collectedUnits),
                ],
            ],
            widths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2),
            },
            numeric: const {1, 2, 3},
          ),
          if (data.outstandingCash.isNotEmpty) ...[
            heading(CollectionsPdfText.outstanding),
            table(
              [
                CollectionsPdfText.customer,
                CollectionsPdfText.collector,
                CollectionsPdfText.amount,
              ],
              [
                for (final o in data.outstandingCash)
                  [o.customerName, o.collectorName ?? '—', lyd(o.amountUnits)],
              ],
              numeric: const {2},
            ),
          ],
        ],
        heading(admin ? CollectionsPdfText.cards : CollectionsPdfText.myCards),
        table(
          [
            CollectionsPdfText.customer,
            if (admin) CollectionsPdfText.employee,
            CollectionsPdfText.balance,
            CollectionsPdfText.lastState,
            CollectionsPdfText.receiptsCount,
          ],
          [
            for (final a in data.assignments)
              [
                a.customerName,
                if (admin) a.assigneeName ?? '—',
                lyd(a.balanceUnits),
                cardState(a),
                '${collectionCardHistory(data, a.id).length}',
              ],
          ],
          numeric: admin ? const {2, 4} : const {1, 3},
        ),
        heading(CollectionsPdfText.receipts),
        table(
          [
            CollectionsPdfText.customer,
            if (admin) CollectionsPdfText.employee,
            CollectionsPdfText.kind,
            CollectionsPdfText.amount,
            CollectionsPdfText.state,
            CollectionsPdfText.date,
          ],
          receiptRows,
          numeric: admin ? const {3, 5} : const {2, 4},
        ),
        heading(
          admin ? CollectionsPdfText.unlinked : CollectionsPdfText.myUnlinked,
        ),
        table(
          [
            CollectionsPdfText.name,
            if (admin) CollectionsPdfText.collector,
            CollectionsPdfText.amount,
            CollectionsPdfText.state,
            CollectionsPdfText.cash,
            CollectionsPdfText.date,
          ],
          [
            for (final r in data.unlinkedReceipts)
              [
                r.customerName,
                if (admin) r.collectorName ?? '—',
                lyd(r.amountUnits),
                unlinkedState(r),
                unlinkedCash(r),
                day(r.submittedAt),
              ],
          ],
          numeric: admin ? const {2, 5} : const {1, 4},
        ),
      ],
    ),
  );
  return doc.save();
}
