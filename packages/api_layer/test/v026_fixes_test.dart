import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/core/money/money_formatter.dart';
import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/core/network/dio_api_client.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/core/permissions/permission_codes.dart';
import 'package:flutter_api_layer/core/permissions/permission_service.dart';
import 'package:flutter_api_layer/data/models/common.dart';
import 'package:flutter_test/flutter_test.dart';

final _invalid = throwsA(isA<InvalidServerResponseException>()
    .having((e) => e.code, 'code', 'INVALID_SERVER_RESPONSE'));

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(body, 200, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
  @override
  void close({bool force = false}) {}
}

void main() {
  group('canWrite needs the read code too, per API contract', () {
    PermissionService emp(List<String> codes, Map<String, String> access) =>
        PermissionService()
          ..applyFromServer(codes, role: 'employee', sectionAccess: access);

    test('write code + manage without read code => no write', () {
      final p = emp(['debts.write'], {'customerDebts': 'manage'});
      expect(p.canWrite(SectionKey.customers), isFalse);
      expect(p.canRead(SectionKey.customers), isFalse);
    });
    test('read + write + manage => write', () {
      final p = emp(['debts.read', 'debts.write'], {'customerDebts': 'manage'});
      expect(p.canWrite(SectionKey.customers), isTrue);
    });
    test('collections (no sectionAccess key): write needs read+write codes',
        () {
      expect(emp(['collections.write'], {}).canWrite(SectionKey.collections),
          isFalse);
      expect(
          emp(['collections.read', 'collections.write'], {})
              .canWrite(SectionKey.collections),
          isTrue);
    });
    test(
        'finalize = purchases.finalize + purchases write gate (read+write+manage)',
        () {
      expect(
          emp(['purchases.write', 'purchases.finalize'],
              {'purchases': 'manage'}).canFinalizePurchases,
          isFalse);
      expect(
          emp(['purchases.read', 'purchases.write', 'purchases.finalize'],
              {'purchases': 'manage'}).canFinalizePurchases,
          isTrue);
    });
    test('reports never writable, even with full access', () {
      final p = PermissionService()..applyFromServer(const [], role: 'admin');
      expect(p.fullAccess, isTrue);
      expect(p.canWrite(SectionKey.reports), isFalse);
    });
  });

  group('financial ledger / PDF export: full access only, per API contract',
      () {
    test('admin role flag (empty lists) and fullAccess=true => allowed', () {
      final a = PermissionService()..applyFromServer(const [], role: 'admin');
      final f = PermissionService()
        ..applyFromServer(const [], role: 'employee', fullAccess: true);
      for (final p in [a, f]) {
        expect(p.canViewFinancialLedger, isTrue);
        expect(p.canExportPdf, isTrue);
      }
    });
    test('every code + manage everywhere, but no full access => hidden', () {
      final all = [
        for (final c in Permission.values) c.code,
        for (final m in ManagementAction.values) m.proposedCode
      ];
      final access = {
        for (final s in SectionKey.values)
          if (s.accessKey != null) s.accessKey!: 'manage'
      };
      for (final p in [
        PermissionService()
          ..applyFromServer(all, role: 'employee', sectionAccess: access),
        PermissionService()
          ..applyFromServer(all, role: 'admin', sectionAccess: access),
        PermissionService()
          ..applyFromServer(const [], role: 'admin', fullAccess: false),
        PermissionService()..applyFromServer(const [], role: 'boss'),
      ]) {
        expect(p.canViewFinancialLedger, isFalse);
        expect(p.canExportPdf, isFalse);
      }
    });
  });

  group('unitsOrNull, per API contract', () {
    test('int passes; null/missing stays null (UI dash)', () {
      expect(unitsOrNull(150000), 150000);
      expect(unitsOrNull(null), isNull);
      expect(unitsOrNull(<String, dynamic>{}['missing']), isNull);
      expect(
          const MoneyFormatter().formatOrDash(unitsOrNull(null), Currency.lyd),
          '—');
    });
    test('string / fractional / exponent / double => INVALID_SERVER_RESPONSE',
        () {
      expect(() => unitsOrNull('1500'), _invalid);
      final d = PreciseJson.decode('{"a":15.5,"b":1e5}') as Map;
      expect(() => unitsOrNull(d['a']), _invalid);
      expect(() => unitsOrNull(d['b']), _invalid);
      expect(() => unitsOrNull(15.0), _invalid);
      expect(() => unitsOrNull(true), _invalid);
    });
  });

  group('DecimalString: exact numeric text, no comma, no exponent', () {
    test('PreciseJson keeps numeric text; ints stay int; no double ever', () {
      final d = PreciseJson.decode(
              '{"r":9.50,"x":0.105263000,"n":-3,"big":123456789012345678901234,"s":"a\\"b"}')
          as Map;
      expect(d['r'], const JsonNumberText('9.50'));
      expect(d['x'], const JsonNumberText('0.105263000'));
      expect(d['n'], -3);
      expect(d['big'], const JsonNumberText('123456789012345678901234'));
      expect(d['s'], 'a"b');
      expect(DecimalString.fromJson(d['r'])!.value,
          '9.50'); // not "9.5" from toString()
      expect(DecimalString.fromJson(d['x'])!.value, '0.105263000');
      expect(() => PreciseJson.decode('{"r": 01}'), throwsFormatException);
      expect(() => PreciseJson.decode('[1,]'), throwsFormatException);
    });
    test('server: comma separators and exponents rejected', () {
      for (final bad in ['9,5', '1,000', '1e5', '1E-2', '٩.٥', 'abc', '']) {
        expect(() => DecimalString.fromJson(bad), _invalid, reason: bad);
      }
      final d = PreciseJson.decode('[1e5, 1E-2, 2.5e3]') as List;
      for (final v in d) {
        expect(() => DecimalString.fromJson(v), _invalid, reason: '$v');
      }
      expect(DecimalString.fromJson(null), isNull);
    });
    test('user input: one decimal mark, no grouping or exponent', () {
      expect(DecimalString.tryParse('9,5')!.value, '9.5');
      expect(DecimalString.tryParse('1,000')!.value, '1.000');
      expect(DecimalString.tryParse('1,000,000'), isNull);
      expect(DecimalString.tryParse('1,000.5'), isNull);
      expect(DecimalString.tryParse('1e5'), isNull);
      expect(DecimalString.tryParse('1E-2'), isNull);
      expect(DecimalString.tryParse('٩٫٥')!.value, '9.5');
    });
    test(
        'DioApiClient decodes the raw body with PreciseJson (local adapter, no network)',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://local.invalid'))
        ..httpClientAdapter = _Adapter(jsonEncode({'ok': true})
            .replaceFirst('}', ',"data":{"egpPerLyd":9.50,"amountUnits":12}}'));
      final res = await DioApiClient(dio).get('/api/x');
      expect(DecimalString.fromJson(res.dataMap['egpPerLyd'])!.value, '9.50');
      expect(unitsOrNull(res.dataMap['amountUnits']), 12);
    });
  });

  test('no double/float on money or rates in lib/', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].trimLeft();
        if (l.startsWith('//')) continue;
        if (RegExp(r'\bdouble\b|\btoDouble\(|\bas num\b|double\.parse')
            .hasMatch(l)) {
          offenders.add('${f.path}:${i + 1}: $l');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
