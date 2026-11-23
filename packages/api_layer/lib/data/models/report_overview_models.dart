import 'common.dart';

/// Website 05:00 snapshot and comparison; no client arithmetic.
class ReportClosingOverviewDto {
  const ReportClosingOverviewDto(
      {this.state,
      this.businessDate,
      this.netUnits,
      this.changeUnits,
      this.previousBusinessDate});
  final String? state;
  final String? businessDate;
  final MoneyValue? netUnits;
  final MoneyValue? changeUnits;
  final String? previousBusinessDate;
  factory ReportClosingOverviewDto.fromData(Object? data) {
    requireJsonObject(data, 'reportOverview');
    requireJsonObject(asJson(data)['latestClosing'], 'latestClosing');
    final root = asJson(data), latest = asJson(root['latestClosing']);
    final date = strOrNull(latest['businessDate']);
    final comparison = asJsonList(root['closings'])
        .where((row) => row['businessDate'] == date)
        .firstOrNull;
    return ReportClosingOverviewDto(
      state: strOrNull(latest['state']),
      businessDate: date,
      netUnits:
          unitsOrNull(latest['netUnits'], fieldPath: 'latestClosing.netUnits'),
      changeUnits: unitsOrNull(comparison?['changeUnits'],
          fieldPath: 'closings.changeUnits'),
      previousBusinessDate: strOrNull(comparison?['previousBusinessDate']),
    );
  }
}

class ReportActivityDto {
  const ReportActivityDto(
      {required this.id,
      required this.description,
      this.name,
      this.currency,
      this.amountUnits,
      this.occurredAt});
  final String id;
  final String description;
  final String? name;
  final String? currency;
  final MoneyValue? amountUnits;
  final DateTime? occurredAt;
  factory ReportActivityDto.fromJson(Json row) => ReportActivityDto(
        id: str(row['id']),
        description: str(row['description']),
        name: strOrNull(row['name']),
        currency: strOrNull(row['currency']),
        amountUnits: unitsOrNull(row['amountUnits'],
            fieldPath: 'activity.amountUnits', rowId: str(row['id'])),
        occurredAt: dateOrNull(row['occurredAt']),
      );
}
