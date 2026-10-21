import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const dest = 'android/app/google-services.json';

  tearDown(() {
    final file = File(dest);
    if (file.existsSync()) file.deleteSync();
  });

  test('the path is ignored and an empty secret is a no-op', () async {
    final ignored = await Process.run('git', ['check-ignore', '-q', dest]);
    expect(ignored.exitCode, 0, reason: ignored.stderr.toString());

    final skipped = await Process.run(
      'bash',
      ['tool/decode_google_services_json.sh'],
      environment: {'GOOGLE_SERVICES_JSON_BASE64': ''},
    );
    expect(skipped.exitCode, 0, reason: skipped.stderr.toString());
    expect(skipped.stdout.toString(), contains('not set'));
    expect(File(dest).existsSync(), isFalse);
  });

  test('a valid payload is written and its key is not printed', () async {
    const marker = 'not-a-secret';
    final payload = jsonEncode({
      'project_info': {'project_id': 'demo-project'},
      'client': [
        {
          'client_info': {
            'android_client_info': {
              'package_name': 'com.example.vib_abdo_company_mobile',
            },
          },
          'api_key': [
            {'current_key': marker},
          ],
        },
      ],
    });
    final encoded = base64Encode(utf8.encode(payload));
    final result = await Process.run(
      'bash',
      ['tool/decode_google_services_json.sh'],
      environment: {'GOOGLE_SERVICES_JSON_BASE64': encoded},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final output = '${result.stdout}${result.stderr}';
    expect(output, contains('com.example.vib_abdo_company_mobile'));
    expect(output.contains(marker), isFalse);
    expect(output.contains(encoded), isFalse);
    final written = jsonDecode(File(dest).readAsStringSync()) as Map;
    expect(
      (written['client'] as List)
          .first['client_info']['android_client_info']['package_name'],
      'com.example.vib_abdo_company_mobile',
    );
  });

  test('a mismatched package is rejected and the file is removed', () async {
    final payload = jsonEncode({
      'project_info': {'project_id': 'demo-project'},
      'client': [
        {
          'client_info': {
            'android_client_info': {'package_name': 'com.example.other'},
          },
        },
      ],
    });
    final result = await Process.run(
      'bash',
      ['tool/decode_google_services_json.sh'],
      environment: {
        'GOOGLE_SERVICES_JSON_BASE64': base64Encode(utf8.encode(payload)),
      },
    );
    expect(result.exitCode, isNonZero);
    expect('${result.stdout}${result.stderr}', contains('com.example.other'));
    expect(File(dest).existsSync(), isFalse);
  });

  test('non-JSON is rejected and the file is removed', () async {
    final result = await Process.run(
      'bash',
      ['tool/decode_google_services_json.sh'],
      environment: {
        'GOOGLE_SERVICES_JSON_BASE64': base64Encode(utf8.encode('nope')),
      },
    );
    expect(result.exitCode, isNonZero);
    expect(File(dest).existsSync(), isFalse);
  });
}
