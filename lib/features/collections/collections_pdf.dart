import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Words used only in the exported statement.
abstract final class CollectionsPdfText {
  static const title = 'كشف استلامات الديون';
  static String workDay(String date) => 'يوم العمل: \u2066$date\u2069';
  static String employee(String name) => 'الموظف: $name';
  static const name = 'الاسم';
  static const received = 'القيمة المستلمة';
  static const total = 'الإجمالي';
  static const none = 'لا توجد استلامات معتمدة في هذه الدفعة.';
  static String page(int n, int of) => 'صفحة $n من $of';
  static const failed = 'تعذر إنشاء ملف PDF.';
}

String collectionsPdfFileName(DateTime at) =>
    'collections-${_date(at)}-${_two(at.hour)}${_two(at.minute)}.pdf';

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

/// One line of the statement: who paid and how much was received.
class DailyStatementRow {
  const DailyStatementRow(this.name, this.units);
  final String name;
  final int units;
}

/// The daily statement, as the 537f073 website builds it
/// (`AdminCollectionsSection.exportPdf`): the batch's `approved`
/// submissions, then its `approved` standalone receipts. Only the name and
/// the received value are kept.
class DailyStatement {
  const DailyStatement({
    required this.businessDate,
    required this.rows,
    this.employeeName,
  });

  final String businessDate;
  final List<DailyStatementRow> rows;

  /// Set on an employee's statement.
  final String? employeeName;

  int get totalUnits => rows.fold(0, (sum, r) => sum + r.units);

  /// [batchId]: the open batch on screen. [collectorUserId]: the signed-in
  /// employee; 537 already scopes an employee's overview to their own rows,
  /// and their submissions are narrowed once more by `collectorUserId`.
  static DailyStatement of(
    CollectionsOverviewDto data, {
    required String? batchId,
    required DateTime now,
    String? collectorUserId,
    String? employeeName,
  }) {
    bool inBatch(String? id) => batchId != null && id == batchId;
    final batch = data.openBatches.where((b) => b.id == batchId).firstOrNull;
    return DailyStatement(
      businessDate: batch?.businessDate ?? _date(now),
      employeeName: employeeName,
      rows: [
        for (final s in data.submissions)
          if (inBatch(s.batchId) &&
              s.status == 'approved' &&
              (collectorUserId == null ||
                  s.collectorUserId == null ||
                  s.collectorUserId == collectorUserId))
            DailyStatementRow(s.customerName ?? '—', s.amountUnits?.asInt ?? 0),
        for (final r in data.unlinkedReceipts)
          if (inBatch(r.batchId) && r.status == 'approved')
            DailyStatementRow(r.customerName, r.amountUnits?.asInt ?? 0),
      ],
    );
  }
}

/// A4 in PDF points, and how many device pixels each point is drawn with.
const _pageW = 595.0, _pageH = 842.0, _scale = 2.5;
const _margin = 40.0, _rowH = 30.0;
const _font = 'IBMPlexSansArabic';
const _ink = Color(0xFF17221F);
const _muted = Color(0xFF5B6177);
const _line = Color(0xFFC9CED8);
const _head = Color(0xFFEEF0FA);

/// Draws the statement with Flutter's own text engine (full Arabic shaping,
/// as on screen) and places each page in the PDF as one image, the way the
/// website does with html2canvas + jsPDF.
Future<Uint8List> buildCollectionsPdf({
  required DailyStatement statement,
  required MoneyFormatter money,
}) async {
  final pages = await renderDailyStatementPages(statement, money: money);
  final doc = pw.Document(
    title: CollectionsPdfText.title,
    author: 'VIB',
    creator: 'VIB mobile',
  );
  for (final png in pages) {
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  return doc.save();
}

/// The pages as PNG bytes (also used for the preview in the deliverables).
Future<List<Uint8List>> renderDailyStatementPages(
  DailyStatement statement, {
  required MoneyFormatter money,
}) async {
  // Rows that fit under the header on page one, and on later pages.
  const firstTop = 150.0, laterTop = _margin + _rowH;
  const bottom = _pageH - _margin - 2 * _rowH - 20;
  final firstCap = ((bottom - firstTop) / _rowH).floor();
  final laterCap = ((bottom - laterTop) / _rowH).floor();
  final chunks = <List<DailyStatementRow>>[];
  final rows = statement.rows;
  var i = 0;
  do {
    final cap = chunks.isEmpty ? firstCap : laterCap;
    chunks.add(rows.sublist(i, math.min(rows.length, i + cap)));
    i += cap;
  } while (i < rows.length);

  final out = <Uint8List>[];
  for (var p = 0; p < chunks.length; p++) {
    out.add(
      await _renderPage(
        statement,
        chunks[p],
        page: p,
        pages: chunks.length,
        money: money,
      ),
    );
  }
  return out;
}

Future<Uint8List> _renderPage(
  DailyStatement s,
  List<DailyStatementRow> rows, {
  required int page,
  required int pages,
  required MoneyFormatter money,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_scale);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _pageW, _pageH),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  const right = _pageW - _margin, width = _pageW - 2 * _margin;
  // The value column on the left, the name column on the right.
  const valueW = 170.0, split = _margin + valueW;

  void text(
    String value, {
    required double top,
    required double start,
    required double end,
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = _ink,
    TextAlign align = TextAlign.right,
    double height = _rowH,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: _font,
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: end - start, maxWidth: end - start);
    painter.paint(canvas, Offset(start, top + (height - painter.height) / 2));
    painter.dispose();
  }

  final linePaint = Paint()
    ..color = _line
    ..strokeWidth = .8;

  void tableRow(
    double top,
    String name,
    String value, {
    bool header = false,
    bool total = false,
  }) {
    if (header || total) {
      canvas.drawRect(
        Rect.fromLTWH(_margin, top, width, _rowH),
        Paint()..color = _head,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(_margin, top, width, _rowH),
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    canvas.drawLine(Offset(split, top), Offset(split, top + _rowH), linePaint);
    final weight = header || total ? FontWeight.w700 : FontWeight.w400;
    text(name, top: top, start: split + 10, end: right - 10, weight: weight);
    text(value, top: top, start: _margin + 10, end: split - 10, weight: weight);
  }

  var y = _margin;
  if (page == 0) {
    text(
      CollectionsPdfText.title,
      top: y,
      start: _margin,
      end: right,
      size: 20,
      weight: FontWeight.w700,
      height: 34,
    );
    y += 38;
    text(
      CollectionsPdfText.workDay(s.businessDate),
      top: y,
      start: _margin,
      end: right,
      color: _muted,
      height: 20,
    );
    y += 22;
    if (s.employeeName != null) {
      text(
        CollectionsPdfText.employee(s.employeeName!),
        top: y,
        start: _margin,
        end: right,
        color: _muted,
        height: 20,
      );
    }
    y = 150 - _rowH;
  }
  tableRow(
    y,
    CollectionsPdfText.name,
    CollectionsPdfText.received,
    header: true,
  );
  y += _rowH;
  if (s.rows.isEmpty) {
    text(
      CollectionsPdfText.none,
      top: y,
      start: _margin + 10,
      end: right - 10,
      color: _muted,
    );
    y += _rowH;
  }
  for (final r in rows) {
    tableRow(y, r.name, money.format(r.units, Currency.lyd));
    y += _rowH;
  }
  if (page == pages - 1) {
    tableRow(
      y + 6,
      CollectionsPdfText.total,
      money.format(s.totalUnits, Currency.lyd),
      total: true,
    );
  }
  if (pages > 1) {
    text(
      CollectionsPdfText.page(page + 1, pages),
      top: _pageH - _margin,
      start: _margin,
      end: right,
      size: 9,
      color: _muted,
      align: TextAlign.center,
      height: 14,
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (_pageW * _scale).round(),
    (_pageH * _scale).round(),
  );
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
