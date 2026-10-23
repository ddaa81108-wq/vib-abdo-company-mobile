import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/overpayment_warning.dart';

void main() {
  test('an amount at or below the balance is not a warning', () {
    expect(
      OverpaymentPreview.aboveBalance(amountUnits: 320, balanceUnits: 320),
      isNull,
    );
    expect(
      OverpaymentPreview.aboveBalance(amountUnits: 100, balanceUnits: 320),
      isNull,
    );
  });

  test('overage and expected balance are whole currency units', () {
    final preview = OverpaymentPreview.aboveBalance(
      amountUnits: 400,
      balanceUnits: 320,
    );
    expect(preview, isNotNull);
    expect(preview!.overageUnits, 80);
    expect(preview.expectedBalanceUnits, -80);
  });

  test('posted balance is only an integer on the acknowledgement', () {
    expect(
      postedBalanceUnits(const MutationAck(raw: {'balanceUnits': 750})),
      750,
    );
    expect(
      postedBalanceUnits(const MutationAck(raw: {'balanceUnits': -100})),
      -100,
    );
    expect(postedBalanceUnits(const MutationAck(raw: {'id': 'tx'})), isNull);
    expect(
      postedBalanceUnits(const MutationAck(raw: {'balanceUnits': '750'})),
      isNull,
    );
    expect(
      postedBalanceUnits(const MutationAck(raw: {'balanceUnits': 750.5})),
      isNull,
    );
  });
}
