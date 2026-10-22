import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _j(String s) => PreciseJson.decode(s) as Map<String, dynamic>;
final _invalid = throwsA(isA<InvalidServerResponseException>());

void main() {
  group('AccountCardDto system fields', () {
    test('systemLinkKey and systemKind are parsed independently', () {
      final c = AccountCardDto.fromJson(
          _j('{"id":"system-egp-masraweya:org-default","name":"x","balanceUnits":5,'
              '"systemManaged":true,"systemKind":"legacy","systemLinkKey":"masraweya_remainder"}'),
          AccountSection.egyptianDeposits);
      expect(c.systemManaged, isTrue);
      expect(c.systemLinkKey, 'masraweya_remainder');
      expect(c.systemKind, 'legacy');
      final kindOnly = AccountCardDto.fromJson(
          _j('{"id":"2","name":"z","balanceUnits":0,"systemKind":"legacy"}'),
          AccountSection.customers);
      expect(kindOnly.systemLinkKey, isNull);
      expect(kindOnly.systemKind, 'legacy');
      final linkOnly = AccountCardDto.fromJson(
          _j('{"id":"3","name":"w","balanceUnits":0,"systemLinkKey":"purchases_vodafone_remainder"}'),
          AccountSection.customers);
      expect(linkOnly.systemLinkKey, 'purchases_vodafone_remainder');
      expect(linkOnly.systemKind, isNull);
      final absent = AccountCardDto.fromJson(
          _j('{"id":"1","name":"y","balanceUnits":0}'), AccountSection.customers);
      expect(absent.systemLinkKey, isNull);
      expect(absent.systemKind, isNull);
    });
  });

  group('LedgerEntryDto', () {
    test('paymentMode as sent; displayNote preferred over note', () {
      final e = LedgerEntryDto.fromJson(_j('{"id":"t","sequence":1,"type":"payment","status":"posted",'
          '"amountUnits":500,"paymentMode":"partial","note":"raw","displayNote":"استلام"}'));
      expect(e.paymentMode, 'partial');
      expect(e.note, 'استلام');
      final f = LedgerEntryDto.fromJson(_j('{"id":"t","type":"debt","status":"posted","amountUnits":1,"note":"raw"}'));
      expect(f.paymentMode, isNull);
      expect(f.note, 'raw');
    });
    test('allowedActions is a list or absent', () {
      final listed = LedgerEntryDto.fromJson(_j('{"id":"t","type":"debt","status":"posted","allowedActions":["correct","pin"]}'));
      expect(listed.allowedActions, ['correct', 'pin']);
      final absent = LedgerEntryDto.fromJson(_j('{"id":"t","type":"debt","status":"posted"}'));
      expect(absent.allowedActions, isNull);
      final notAList = LedgerEntryDto.fromJson(_j('{"id":"t","type":"debt","status":"posted","allowedActions":"correct"}'));
      expect(notAList.allowedActions, isNull);
    });
    test('full payment omits a date the user did not choose', () {
      final omitted = AccountTransactionRequest.fullPayment();
      expect(omitted.toJson().containsKey('date'), isFalse);
      final chosen = AccountTransactionRequest.fullPayment(date: DateTime.utc(2026, 1, 15));
      expect(chosen.toJson()['date'], '2026-01-15T00:00:00.000Z');
    });
    test('malformed amountUnits marks that field and keeps the entry', () {
      final entry = LedgerEntryDto.fromJson(
        _j('{"id":"t","type":"debt","status":"posted","amountUnits":1.5}'),
      );
      expect(entry.id, 't');
      expect(entry.type, 'debt');
      expect(entry.status, 'posted');
      expect(entry.amountUnits, const MoneyValue.invalid());
      expect(entry.amountUnits?.units, isNull);
      expect(entry.amountUnits?.units, isNot(1));
      expect(entry.amountUnits?.units, isNot(2));
    });
  });

  group('CollectionsOverviewDto counters (server-computed)', () {
    test('assignedCount is top-level, then metrics; other counters stay in metrics', () {
      final o = CollectionsOverviewDto.fromData(_j('{"assignments":[],"submissions":[{"id":"s","status":"pending"}],'
          '"metrics":{"collectedUnits":900,"pendingCount":3,"executedCount":2,"cashOutstandingUnits":450,'
          '"unlinkedPendingCount":1,"assignedCount":1},"employeeTotals":[],"assignedCount":7}'));
      expect(o.assignedCount, 7);
      expect(o.pendingCount, 3); // from server, not counted from submissions (1 here)
      expect(o.unlinkedPendingCount, 1);
      expect(o.cashOutstandingUnits?.units, 450);
    });
    test('assignedCount falls back to metrics; absent => null', () {
      final o = CollectionsOverviewDto.fromData(_j('{"metrics":{"assignedCount":4}}'));
      expect(o.assignedCount, 4);
      final n = CollectionsOverviewDto.fromData(_j('{"metrics":{}}'));
      expect([n.assignedCount, n.pendingCount, n.unlinkedPendingCount, n.cashOutstandingUnits], everyElement(isNull));
    });
    test('malformed cashOutstandingUnits marks that metric only', () {
      final text = CollectionsOverviewDto.fromData(
        _j('{"metrics":{"cashOutstandingUnits":"450","collectedUnits":12}}'),
      );
      expect(text.cashOutstandingUnits!.isInvalid, isTrue);
      expect(text.cashOutstandingUnits?.units, isNot(450));
      expect(text.collectedUnits?.units, 12);
      final exponent = CollectionsOverviewDto.fromData(
        _j('{"metrics":{"cashOutstandingUnits":4.5e2,"collectedUnits":12}}'),
      );
      expect(exponent.cashOutstandingUnits!.isInvalid, isTrue);
      expect(exponent.collectedUnits?.units, 12);
    });
  });

  test('lifetimeTotals rejects a bad value and stays null when omitted', () {
    PurchasesBookPage pageOf(String json) =>
        PurchasesBookPage.fromData(PreciseJson.decode(json));

    final paid = pageOf('{"days":[],"lifetimeTotals":{"paidUnits":"47447","resultUnits":50000}}');
    expect(paid.lifetimeTotals?.paidUnits!.isInvalid, isTrue);
    expect(paid.lifetimeTotals?.paidUnits?.units, isNot(47447));
    expect(paid.lifetimeTotals?.resultUnits?.units, 50000);
    final fraction = pageOf('{"days":[],"lifetimeTotals":{"resultUnits":1.5,"paidUnits":2}}');
    expect(fraction.lifetimeTotals?.resultUnits!.isInvalid, isTrue);
    expect(fraction.lifetimeTotals?.resultUnits?.units, isNot(1));
    expect(fraction.lifetimeTotals?.resultUnits?.units, isNot(2));
    expect(fraction.lifetimeTotals?.paidUnits?.units, 2);
    final exponent = pageOf('{"days":[],"lifetimeTotals":{"remainingUnits":4.5e2}}');
    expect(exponent.lifetimeTotals?.remainingUnits!.isInvalid, isTrue);
    expect(() => pageOf('{"days":[],"lifetimeTotals":[50000]}'), _invalid);

    expect(pageOf('{"days":[]}').lifetimeTotals, isNull);
    expect(PurchasesLifetimeTotalsDto.fromJsonOrNull(null), isNull);

    final page = pageOf(
      '{"days":[],"lifetimeTotals":{"resultUnits":50000,"paidUnits":null,"remainingUnits":2553}}',
    );
    expect(page.lifetimeTotals?.resultUnits?.units, 50000);
    expect(page.lifetimeTotals?.paidUnits, isNull);
    expect(page.lifetimeTotals?.remainingUnits?.units, 2553);
  });

  test('proposed changeUnits and activeCashTone stay null when absent', () {
    final reason = ReportReasonDto.fromJson(_j('{"text":"سبب"}'));
    expect(reason.changeUnits, isNull);
    final badReason = ReportReasonDto.fromJson(
      _j('{"text":"سبب","changeUnits":"1200"}'),
    );
    expect(badReason.text, 'سبب');
    expect(badReason.changeUnits!.isInvalid, isTrue);
    expect(badReason.changeUnits?.units, isNot(1200));
    final treasury = TreasurySummaryDto.fromData({
      'totals': {'activeCashUnits': 10, 'netUnits': 10},
    });
    expect(treasury.activeCashTone, isNull);
    final unknown = TreasurySummaryDto.fromData({
      'totals': {'activeCashUnits': 10, 'activeCashTone': 'vivid'},
    });
    expect(unknown.activeCashTone, isNull);
  });

  test('extra model exports are reachable from api_layer.dart', () {
    // Compiles only if the seven exports exist.
    expect(<Type>[AccountsPage, CalculationMode, TreasurySummaryDto, PurchaseEntryDto, DailyReportRowDto,
      NotificationDto, MasraweyaDayDto], hasLength(7));
  });
}
