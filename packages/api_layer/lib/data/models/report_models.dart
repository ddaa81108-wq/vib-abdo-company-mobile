import 'dart:convert';
import 'dart:typed_data';

import '../../core/network/api_exception.dart';
import 'common.dart';

/// Contract `sectionKey` on a financial-ledger row.
///
/// Wire values are the server keys (`customer_debts`, …), not [SectionKey]
/// path keys (`customers`). A missing field is null. Any other value, including
/// a non-string, is [unknown] and does not throw. The original text, when the
/// value was a string, is [FinancialLedgerEntryDto.sectionKeyRaw].
enum FinancialLedgerSectionKey {
  customerDebts('customer_debts'),
  companyDebts('company_debts'),
  libyanDeposits('libyan_deposits'),
  egyptianDeposits('egyptian_deposits'),
  purchases('purchases'),
  treasury('treasury'),
  collections('collections'),
  unknown('');

  const FinancialLedgerSectionKey(this.wire);

  final String wire;
}

/// Contract `sourceStatus` on a financial-ledger row.
///
/// The samples use `posted` and `draft`. Anything else is [unknown] and does
/// not throw. A missing field is null, not [unknown].
enum FinancialLedgerSourceStatus {
  posted('posted'),
  draft('draft'),
  unknown('');

  const FinancialLedgerSourceStatus(this.wire);

  final String wire;
}

/// Contract `ReportStatus`: `normal | review | critical | missing_rate`.
///
/// A missing field is null. Any other value is [unknown] and does not throw.
/// The raw text stays on [DailyReportRowDto.status] so an older label still
/// reaches the screen.
enum ReportStatus {
  normal('normal'),
  review('review'),
  critical('critical'),
  missingRate('missing_rate'),
  unknown('');

  const ReportStatus(this.wire);

  final String wire;
}

/// Contract `fiveAmClosing.state`.
enum FiveAmClosingState {
  pending('pending'),
  missed('missed'),
  missingRate('missing_rate'),
  recorded('recorded'),
  unknown('');

  const FiveAmClosingState(this.wire);

  final String wire;
}

/// One movement inside a daily report (`daily` on the contract row).
///
/// Every amount is an integer [MoneyValue]. A bad amount marks that field
/// only. A missing object is null, not a row of zeros.
class ReportDailyDto {
  const ReportDailyDto({
    this.receivablesAddedUnits,
    this.paymentsUnits,
    this.liabilitiesEffectUnits,
    this.cashInUnits,
    this.cashOutUnits,
  });

  final MoneyValue? receivablesAddedUnits;
  final MoneyValue? paymentsUnits;
  final MoneyValue? liabilitiesEffectUnits;
  final MoneyValue? cashInUnits;
  final MoneyValue? cashOutUnits;

  factory ReportDailyDto.fromJson(Json j, {String? rowId}) => ReportDailyDto(
        receivablesAddedUnits: unitsOrNull(
          j['receivablesAddedUnits'],
          fieldPath: 'daily.receivablesAddedUnits',
          rowId: rowId,
        ),
        paymentsUnits: unitsOrNull(
          j['paymentsUnits'],
          fieldPath: 'daily.paymentsUnits',
          rowId: rowId,
        ),
        liabilitiesEffectUnits: unitsOrNull(
          j['liabilitiesEffectUnits'],
          fieldPath: 'daily.liabilitiesEffectUnits',
          rowId: rowId,
        ),
        cashInUnits: unitsOrNull(
          j['cashInUnits'],
          fieldPath: 'daily.cashInUnits',
          rowId: rowId,
        ),
        cashOutUnits: unitsOrNull(
          j['cashOutUnits'],
          fieldPath: 'daily.cashOutUnits',
          rowId: rowId,
        ),
      );
}

/// Contract `fiveAmClosing` on a daily report.
class ReportFiveAmClosingDto {
  const ReportFiveAmClosingDto({
    this.state,
    this.stateRaw,
    this.scheduledAt,
    this.capturedAt,
    this.netUnits,
  });

  final FiveAmClosingState? state;

  /// Original `state` text. Null when the field was absent or not a string.
  final String? stateRaw;
  final DateTime? scheduledAt;
  final DateTime? capturedAt;
  final MoneyValue? netUnits;

  factory ReportFiveAmClosingDto.fromJson(Json j, {String? rowId}) {
    final state = _readEnum(
      j['state'],
      FiveAmClosingState.values,
      (value) => value.wire,
      FiveAmClosingState.unknown,
    );
    return ReportFiveAmClosingDto(
      state: state.value,
      stateRaw: state.raw,
      scheduledAt: dateOrNull(j['scheduledAt']),
      capturedAt: dateOrNull(j['capturedAt']),
      netUnits: unitsOrNull(
        j['netUnits'],
        fieldPath: 'fiveAmClosing.netUnits',
        rowId: rowId,
      ),
    );
  }
}

/// GET /api/reports?limit=30 — one daily row, and the same shape for `current`.
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
    this.dayStatus,
    this.note,
    this.summary,
    this.reasons = const [],
    this.daily,
    this.egyptianRate,
    this.version,
    this.generatedAt,
    this.updatedAt,
    this.isFinalized,
    this.finalizedAt,
    this.fiveAmClosing,
  });

  final int sequence;
  final String? date;
  final MoneyValue? receivablesUnits; // LYD
  final MoneyValue? activeCashUnits; // LYD
  final MoneyValue? egyptianUnits; // EGP
  final MoneyValue? egyptianConvertedUnits; // LYD (server-converted)
  final MoneyValue? liabilitiesUnits; // LYD
  final MoneyValue? netUnits; // LYD

  /// Not on the contract row. Kept so an older payload can still be shown.
  final MoneyValue? netChangeUnits;

  /// Raw `status` text, including values outside [ReportStatus].
  final String? status;
  final ReportStatus? dayStatus;
  final String? note;

  /// Contract `summary` string. Null when absent or not a string.
  final String? summary;
  final List<ReportReasonDto> reasons;

  /// Contract `daily` object. Null when the object is absent.
  final ReportDailyDto? daily;

  /// Contract integer rate. A non-integer is null and is not stored as a double.
  final int? egyptianRate;
  final int? version;
  final DateTime? generatedAt;
  final DateTime? updatedAt;
  final bool? isFinalized;
  final DateTime? finalizedAt;
  final ReportFiveAmClosingDto? fiveAmClosing;

  /// Same text as [date]. The contract name is `businessDate`.
  String? get businessDate => date;

  factory DailyReportRowDto.fromJson(Json j) {
    final rowId = strOrNull(j['businessDate'] ?? j['date']);
    final status = _readEnum(
      j['status'],
      ReportStatus.values,
      (value) => value.wire,
      ReportStatus.unknown,
    );
    return DailyReportRowDto(
      sequence: intOrNull(j['sequence']) ?? 0,
      date: strOrNull(j['date'] ?? j['businessDate']),
      receivablesUnits: unitsOrNull(
        j['receivablesUnits'],
        fieldPath: 'receivablesUnits',
        rowId: rowId,
      ),
      activeCashUnits: unitsOrNull(
        j['activeCashUnits'],
        fieldPath: 'activeCashUnits',
        rowId: rowId,
      ),
      egyptianUnits: j.containsKey('egyptianSourceUnits')
          ? unitsOrNull(
              j['egyptianSourceUnits'],
              fieldPath: 'egyptianSourceUnits',
              rowId: rowId,
            )
          : unitsOrNull(
              j['egyptianUnits'],
              fieldPath: 'egyptianUnits',
              rowId: rowId,
            ),
      egyptianConvertedUnits: unitsOrNull(
        j['egyptianConvertedUnits'],
        fieldPath: 'egyptianConvertedUnits',
        rowId: rowId,
      ),
      liabilitiesUnits: unitsOrNull(
        j['liabilitiesUnits'],
        fieldPath: 'liabilitiesUnits',
        rowId: rowId,
      ),
      netUnits: unitsOrNull(
        j['netUnits'],
        fieldPath: 'netUnits',
        rowId: rowId,
      ),
      netChangeUnits: unitsOrNull(
        j['netChangeUnits'],
        fieldPath: 'netChangeUnits',
        rowId: rowId,
      ),
      status: strOrNull(j['status']),
      dayStatus: status.value,
      note: strOrNull(j['note'] ?? j['systemNote']),
      summary: j['summary'] is String ? j['summary'] as String : null,
      reasons: asJsonList(j['reasons'])
          .map(ReportReasonDto.fromJson)
          .toList(growable: false),
      daily: _objectOrNull(
        j,
        'daily',
        (object) => ReportDailyDto.fromJson(object, rowId: rowId),
      ),
      egyptianRate: j['egyptianRate'] is int ? j['egyptianRate'] as int : null,
      version: j['version'] is int ? j['version'] as int : null,
      generatedAt: dateOrNull(j['generatedAt']),
      updatedAt: dateOrNull(j['updatedAt']),
      isFinalized: j['isFinalized'] is bool ? j['isFinalized'] as bool : null,
      finalizedAt: dateOrNull(j['finalizedAt']),
      fiveAmClosing: _objectOrNull(
        j,
        'fiveAmClosing',
        (object) => ReportFiveAmClosingDto.fromJson(object, rowId: rowId),
      ),
    );
  }
}

class ReportReasonDto {
  const ReportReasonDto({this.key, this.label, this.text, this.changeUnits});

  final String? key;
  final String? label;
  final String? text;

  /// Proposed field, pending server confirmation. Absent stays null; the UI
  /// shows '—' and does not treat that as an error.
  final MoneyValue? changeUnits;

  factory ReportReasonDto.fromJson(Json j) => ReportReasonDto(
        key: j['key'] is String ? j['key'] as String : null,
        label: j['label'] is String ? j['label'] as String : null,
        text: strOrNull(j['text'] ?? j['message'] ?? j['label']),
        changeUnits: unitsOrNull(j['changeUnits'], fieldPath: 'changeUnits'),
      );
}

class ReportsDto {
  const ReportsDto({
    required this.rows,
    this.current,
    this.formula,
    this.methodologyNote,
  });

  /// Contract `current`. Null when the field is absent or JSON null.
  final DailyReportRowDto? current;
  final List<DailyReportRowDto> rows;
  final String? formula; // methodology.formula (server text)
  final String? methodologyNote;

  factory ReportsDto.fromData(Object? data) {
    final d = asJson(data);
    final m = asJson(d['methodology']);
    return ReportsDto(
      current: d['current'] == null
          ? null
          : DailyReportRowDto.fromJson(
              _requireObject(d['current'], 'current'),
            ),
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
  const FinancialLedgerEntryDto({
    required this.id,
    required this.section,
    required this.currency,
    this.amountUnits,
    this.status,
    this.description,
    this.createdAt,
    this.sectionKey,
    this.sectionKeyRaw,
    this.sourceStatus,
    this.sourceStatusRaw,
    this.occurredAt,
  });

  final String id;

  /// Legacy text. Filled from `sectionKey` when that string is present, else
  /// from `section`.
  final String section;
  final Currency currency;
  final MoneyValue? amountUnits;

  /// Legacy text. Filled from `sourceStatus` when that string is present.
  final String? status;
  final String? description;

  /// Legacy timestamp. `occurredAt` when that parses, else `createdAt`.
  final DateTime? createdAt;

  /// Contract `sectionKey`. Null when the field is absent.
  final FinancialLedgerSectionKey? sectionKey;

  /// Original `sectionKey` text, including an unknown value.
  final String? sectionKeyRaw;

  /// Contract `sourceStatus`. Null when the field is absent.
  final FinancialLedgerSourceStatus? sourceStatus;

  /// Original `sourceStatus` text, including an unknown value.
  final String? sourceStatusRaw;

  /// Contract `occurredAt`. Parsed with [dateOrNull] (UTC for `Z` and for an
  /// explicit offset). Absent or unparseable is null and does not throw.
  final DateTime? occurredAt;

  factory FinancialLedgerEntryDto.fromJson(Json j) {
    final sectionKey = _readEnum(
      j['sectionKey'],
      FinancialLedgerSectionKey.values,
      (value) => value.wire,
      FinancialLedgerSectionKey.unknown,
    );
    final sourceStatus = _readEnum(
      j['sourceStatus'],
      FinancialLedgerSourceStatus.values,
      (value) => value.wire,
      FinancialLedgerSourceStatus.unknown,
    );
    final occurredAt = dateOrNull(j['occurredAt']);
    return FinancialLedgerEntryDto(
      id: str(j['id']),
      section: str(sectionKey.raw ?? j['section']),
      currency: currencyOr(j['currency'], Currency.lyd),
      amountUnits: unitsOrNull(
        j['amountUnits'],
        fieldPath: 'amountUnits',
        rowId: strOrNull(j['id']),
      ),
      status: strOrNull(sourceStatus.raw ?? j['status']),
      description: strOrNull(j['description'] ?? j['note']),
      createdAt: occurredAt ?? dateOrNull(j['createdAt']),
      sectionKey: sectionKey.value,
      sectionKeyRaw: sectionKey.raw,
      sourceStatus: sourceStatus.value,
      sourceStatusRaw: sourceStatus.raw,
      occurredAt: occurredAt,
    );
  }
}

class FinancialLedgerPage {
  const FinancialLedgerPage({required this.page, this.pageTotals = const {}});
  final Paged<FinancialLedgerEntryDto> page;

  /// Required from the server, per API contract: net per currency for the displayed scope,
  /// e.g. {"LYD": 123, "EGP": 456}. The app never accumulates pageTotals across pages.
  final Map<String, MoneyValue> pageTotals;

  factory FinancialLedgerPage.fromData(Object? data) {
    requireJsonObject(data is List ? null : data, 'financial-ledger');
    final p = Paged.fromData(data, FinancialLedgerEntryDto.fromJson);
    final totalsRaw = p.raw['scopeTotals'] ?? p.raw['pageTotals'];
    requireJsonObject(totalsRaw, 'pageTotals');
    final totals = <String, MoneyValue>{};
    asJson(totalsRaw).forEach((k, v) {
      final u = unitsOrNull(v, fieldPath: 'pageTotals.$k');
      if (u != null) totals[k] = u;
    });
    return FinancialLedgerPage(page: p, pageTotals: totals);
  }
}

/// Bytes of a proposed statement PDF. The server has no PDF export; this
/// shape is used only by the fake client.
class StatementFile {
  const StatementFile({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;

  factory StatementFile.fromData(Object? data) {
    final map = asJson(data);
    final encoded = map['contentBase64'];
    if (encoded is! String || encoded.isEmpty) {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة',
      );
    }
    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) {
        throw const InvalidServerResponseException(
          message: 'استجابة الخادم غير صالحة',
        );
      }
      return StatementFile(
        filename: strOrNull(map['filename']) ?? 'statement.pdf',
        bytes: bytes,
      );
    } on FormatException {
      throw const InvalidServerResponseException(
        message: 'استجابة الخادم غير صالحة',
      );
    }
  }
}

final class _EnumRead<T> {
  const _EnumRead(this.value, this.raw);

  final T? value;
  final String? raw;
}

_EnumRead<T> _readEnum<T>(
  Object? raw,
  List<T> values,
  String Function(T value) wire,
  T unknown,
) {
  if (raw == null) return _EnumRead<T>(null, null);
  if (raw is! String || raw.isEmpty) {
    return _EnumRead(unknown, raw is String ? raw : null);
  }
  for (final value in values) {
    if (value != unknown && wire(value) == raw) return _EnumRead(value, raw);
  }
  return _EnumRead(unknown, raw);
}

T? _objectOrNull<T>(Json j, String key, T Function(Json object) parse) {
  if (!j.containsKey(key) || j[key] == null) return null;
  return parse(_requireObject(j[key], key));
}

Json _requireObject(Object? value, String label) {
  requireJsonObject(value, label);
  return asJson(value);
}
