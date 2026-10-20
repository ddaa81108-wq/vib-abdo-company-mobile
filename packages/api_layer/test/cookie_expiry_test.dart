import 'dart:convert';

import 'package:flutter_api_layer/core/auth/cookie_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryKeys implements SecureKeyValue {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test('expired cookies are deleted from the jar, live ones stay', () async {
    final keys = _MemoryKeys();
    final store = SecureCookieStore(keys: keys);
    await store.saveFromSetCookie([
      'session=super-secret; Max-Age=3600',
      'kept=yes; Max-Age=3600',
    ]);
    expect(keys.values.values.single, contains('super-secret'));

    final key = keys.values.keys.single;
    final list = (jsonDecode(keys.values[key]!) as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    for (final entry in list) {
      if (entry['n'] == 'session') {
        entry['e'] = '1970-01-01T00:00:00.000Z';
      }
    }
    keys.values[key] = jsonEncode(list);

    final reloaded = SecureCookieStore(keys: keys);
    expect(await reloaded.cookieHeader(), 'kept=yes');
    expect(keys.values[key], isNot(contains('super-secret')));
    expect(keys.values[key], contains('kept'));

    await reloaded.clear();
    expect(keys.values, isEmpty);
    expect(await reloaded.isEmpty(), isTrue);
  });
}
