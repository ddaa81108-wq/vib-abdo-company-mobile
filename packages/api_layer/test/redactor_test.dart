import 'package:flutter_api_layer/core/security/redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const redactor = Redactor();

  test('tokens, cookies, passwords, names, and amounts are redacted', () {
    final redacted = redactor.redact({
      'id': 'c_55',
      'status': 'pending',
      'role': 'employee',
      'section': 'customers',
      'version': 3,
      'code': 'AUTH_REQUIRED',
      'correlationId': 'cid-1',
      'x-correlation-id': 'cid-2',
      'password': 'pw',
      'current_password': 'old',
      'current-password': 'old-2',
      'newPassword': 'new',
      'confirmPassword': 'new',
      'access_token': 'access',
      'refreshToken': 'refresh',
      'X-CSRF-Token': 'csrf',
      'Cookie': 'session=abc',
      'Set-Cookie': 'session=abc',
      'Authorization': 'Bearer abc',
      'loginTicket': 'ticket',
      'customerName': 'Secret Name',
      'createdByName': 'Person',
      'employeeName': 'Person',
      'phone': '0910000000',
      'email': 'person@example.com',
      'displayNote': 'private note',
      'systemNote': 'private note',
      'note': 'private note',
      'balanceUnits': 320,
      'openingBalance': 10,
      'factorMicros': 5,
      'exchangeRate': '9.5',
      'egpPerLyd': '9.5',
      'body': 'استلام باسم Person',
      'message': 'راجع Person',
      'label': 'نوع خاص',
      'details': {'password': 'nested', 'id': 'keep-me-out'},
      'items': [
        {'name': 'Person', 'id': 'c_55'},
      ],
    });

    expect(redacted, {
      'id': 'c_55',
      'status': 'pending',
      'role': 'employee',
      'section': 'customers',
      'version': 3,
      'code': 'AUTH_REQUIRED',
      'correlationId': 'cid-1',
      'x-correlation-id': 'cid-2',
      'password': '***',
      'current_password': '***',
      'current-password': '***',
      'newPassword': '***',
      'confirmPassword': '***',
      'access_token': '***',
      'refreshToken': '***',
      'X-CSRF-Token': '***',
      'Cookie': '***',
      'Set-Cookie': '***',
      'Authorization': '***',
      'loginTicket': '***',
      'customerName': '***',
      'createdByName': '***',
      'employeeName': '***',
      'phone': '***',
      'email': '***',
      'displayNote': '***',
      'systemNote': '***',
      'note': '***',
      'balanceUnits': '***',
      'openingBalance': '***',
      'factorMicros': '***',
      'exchangeRate': '***',
      'egpPerLyd': '***',
      'body': '***',
      'message': '***',
      'label': '***',
      'details': '***',
      'items': [
        {'name': '***', 'id': 'c_55'},
      ],
    });
  });

  test('secret-shaped text is scrubbed and ordinary text is not', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature';
    final text = redactor.scrub(
      'see person@example.com and https://user:secret-pass@host/api '
      'Authorization: Bearer leak-token $jwt password=hunter2',
    );
    expect(text, contains('person@example.com'));
    expect(text, isNot(contains('secret-pass')));
    expect(text, isNot(contains('leak-token')));
    expect(text, isNot(contains('hunter2')));
    expect(text, isNot(contains('eyJhbGci')));
    expect(
      redactor.scrub('بيانات الدخول غير صحيحة'),
      'بيانات الدخول غير صحيحة',
    );
  });
}
