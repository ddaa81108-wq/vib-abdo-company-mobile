import 'common.dart';

/// GET /api/reports?limit=30 — daily rows auto-generated from treasury totals.
class DailyReportRowDto {
  const DailyReportRowDto({
    required this.sequence,
    this.date,
    this.receivablesUnits,
    this.activeCashUnits,
    this.egyptianUnits,
    this.egyptianConvertedUnits,
    this.liabilitiesUnits,
    this.netUnits,
    this.netChangeUnits,
    this.status,
    this.note,
    this.reasons = const [],
  });
  final int sequence;
  final String? date;
  final int? receivablesUnits; // LYD
  final int? activeCashUnits; // LYD
  final int? egyptianUnits; // EGP
  final int? egyptianConvertedUnits; // LYD (server-converted)
  final int? liabilitiesUnits; // LYD
  final int? netUnits; // LYD

  /// REQUIRED FROM SERVER (contract §12): web client computes net[i] − net[i+1]; we must not.
  final int?
      netChangeUnits; // server-computed (contract §12 #4); hidden when null
  final String?
      status; // normal | needs_review | urgent_review | rate_missing (🔶)
  final String? note;
  final List<ReportReasonDto> reasons;

  factory DailyReportRowDto.fromJson(Json j) => DailyReportRowDto(
        sequence: intOrNull(j['sequence']) ?? 0,
        date: strOrNull(j['date'] ?? j['businessDate']),
        receivablesUnits: unitsOrNull(j['receivablesUnits']),
        activeCashUnits: unitsOrNull(j['activeCashUnits']),
        egyptianUnits:
            unitsOrNull(j['egyptianSourceUnits'] ?? j['egyptianUnits']),
        egyptianConvertedUnits: unitsOrNull(j['egyptianConvertedUnits']),
        liabilitiesUnits: unitsOrNull(j['liabilitiesUnits']),
        netUnits: unitsOrNull(j['netUnits']),
        netChangeUnits: unitsOrNull(j['netChangeUnits']),
        status: strOrNull(j['status']),
        note: strOrNull(j['note'] ?? j['systemNote']),
        reasons: asJsonList(j['reasons'])
            .map(ReportReasonDto.fromJson)
            .toList(growable: false),
      );
}

class ReportReasonDto {
  const ReportReasonDto({this.text, this.changeUnits});
  final String? text;
  final int? changeUnits;
  factory ReportReasonDto.fromJson(Json j) => ReportReasonDto(
        text: strOrNull(j['text'] ?? j['message'] ?? j['label']),
        changeUnits: unitsOrNull(j['changeUnits']),
      );
}

class ReportsDto {
  const ReportsDto({required this.rows, this.formula, this.methodologyNote});
  final List<DailyReportRowDto> rows;
  final String? formula; // methodology.formula (server text)
  final String? methodologyNote;
  factory ReportsDto.fromData(Object? data) {
    final d = asJson(data);
    final m = asJson(d['methodology']);
    return ReportsDto(
      rows: asJsonList(d['items'] ?? d['rows'])
          .map(DailyReportRowDto.fromJson)
          .toList(growable: false),
      formula: strOrNull(m['formula']),
      methodologyNote: strOrNull(m['note']),
    );
  }
}

/// GET /api/financial-ledger?before&section&currency&q (admin). Read-only.
class FinancialLedgerEntryDto {
  const FinancialLedgerEntryDto(
      {required this.id,
      required this.section,
      required this.currency,
      this.amountUnits,
      this.status,
      this.description,
      this.createdAt});
  final String id;
  final String section;
  final Currency currency;
  final int? amountUnits;
  final String? status;
  final String? description;
  final DateTime? createdAt;
  factory FinancialLedgerEntryDto.fromJson(Json j) => FinancialLedgerEntryDto(
        id: str(j['id']),
        section: str(j['section']),
        currency: currencyOr(j['currency'], Currency.lyd),
        amountUnits: unitsOrNull(j['amountUnits']),
        status: strOrNull(j['status']),
        description: strOrNull(j['description'] ?? j['note']),
        createdAt: dateOrNull(j['createdAt']),
      );
}

class FinancialLedgerPage {
  const FinancialLedgerPage({required this.page, this.pageTotals = const {}});
  final Paged<FinancialLedgerEntryDto> page;

  /// REQUIRED FROM SERVER (contract §12): net per currency for the displayed scope,
  /// e.g. {"LYD": 123, "EGP": 456}. The app never accumulates pageTotals across pages.
  final Map<String, int> pageTotals;

  factory FinancialLedgerPage.fromData(Object? data) {
    final p = Paged.fromData(data, FinancialLedgerEntryDto.fromJson);
    final totals = <String, int>{};
    asJson(p.raw['scopeTotals'] ?? p.raw['pageTotals']).forEach((k, v) {
      final u = unitsOrNull(v);
      if (u != null) totals[k] = u;
    });
    return FinancialLedgerPage(page: p, pageTotals: totals);
  }
}
