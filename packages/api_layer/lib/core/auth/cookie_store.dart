import 'dart:convert';
import 'dart:io' show Cookie;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent cookie jar whose contents live ONLY in flutter_secure_storage
/// (Keychain / Android Keystore-backed) — never in plain files or SharedPreferences.
/// Single-origin client: cookies are only sent to the configured API origin.
abstract interface class CookieStore {
  Future<String?> cookieHeader();
  Future<void> saveFromSetCookie(List<String> setCookieHeaders);
  Future<bool> isEmpty();
  Future<void> clear();
}

class _StoredCookie {
  _StoredCookie(this.name, this.value, this.expiresAt);
  final String name;
  final String value;
  final DateTime?
  expiresAt; // null = session cookie (kept until logout/expiry on server)

  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'n': name,
    'v': value,
    'e': expiresAt?.toIso8601String(),
  };
  static _StoredCookie fromJson(Map<String, dynamic> j) => _StoredCookie(
    '${j['n']}',
    '${j['v']}',
    j['e'] == null ? null : DateTime.tryParse('${j['e']}'),
  );
}

/// Small key/value surface so tests can exercise the cookie jar without the
/// platform keystore. Production uses [FlutterSecureStorage].
abstract interface class SecureKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureKeyValue implements SecureKeyValue {
  _FlutterSecureKeyValue(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

FlutterSecureStorage _defaultSecureStorage() => const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class SecureCookieStore implements CookieStore {
  SecureCookieStore({FlutterSecureStorage? storage, SecureKeyValue? keys})
    : _keys =
          keys ?? _FlutterSecureKeyValue(storage ?? _defaultSecureStorage());

  final SecureKeyValue _keys;
  static const _key = 'session.cookies.v1';
  Map<String, _StoredCookie>? _cache;

  Future<Map<String, _StoredCookie>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _keys.read(_key);
    final map = <String, _StoredCookie>{};
    var dropped = false;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          dropped = true;
        } else {
          for (final e in decoded) {
            if (e is! Map) {
              dropped = true;
              continue;
            }
            final c = _StoredCookie.fromJson(Map<String, dynamic>.from(e));
            if (c.isExpired) {
              dropped = true;
              continue;
            }
            map[c.name] = c;
          }
        }
      } catch (_) {
        // Corrupt store -> start clean.
        dropped = true;
      }
    }
    _cache = map;
    // Expired or corrupt entries must not stay in the encrypted jar.
    if (dropped) await _persist(map);
    return map;
  }

  Future<void> _persist(Map<String, _StoredCookie> map) async {
    _cache = map;
    if (map.isEmpty) {
      await _keys.delete(_key);
    } else {
      await _keys.write(
        _key,
        jsonEncode(map.values.map((c) => c.toJson()).toList()),
      );
    }
  }

  @override
  Future<String?> cookieHeader() async {
    final map = await _load();
    final before = map.length;
    map.removeWhere((_, c) => c.isExpired);
    if (map.length != before) await _persist(map);
    if (map.isEmpty) return null;
    return map.values.map((c) => '${c.name}=${c.value}').join('; ');
  }

  @override
  Future<void> saveFromSetCookie(List<String> setCookieHeaders) async {
    if (setCookieHeaders.isEmpty) return;
    final map = Map<String, _StoredCookie>.of(await _load());
    for (final header in setCookieHeaders) {
      try {
        final c = Cookie.fromSetCookieValue(header);
        final DateTime? exp = c.maxAge != null
            ? DateTime.now().toUtc().add(Duration(seconds: c.maxAge!))
            : c.expires?.toUtc();
        final deleted =
            c.value.isEmpty ||
            (c.maxAge != null && c.maxAge! <= 0) ||
            (exp != null && DateTime.now().toUtc().isAfter(exp));
        if (deleted) {
          map.remove(c.name);
        } else {
          map[c.name] = _StoredCookie(c.name, c.value, exp);
        }
      } catch (_) {
        // Ignore malformed Set-Cookie; never log its value.
      }
    }
    await _persist(map);
  }

  @override
  Future<bool> isEmpty() async => (await cookieHeader()) == null;

  @override
  Future<void> clear() async {
    _cache = <String, _StoredCookie>{};
    await _keys.delete(_key);
  }
}

/// Tests / fake mode only.
class InMemoryCookieStore implements CookieStore {
  final Map<String, String> _c = {};
  @override
  Future<String?> cookieHeader() async => _c.isEmpty
      ? null
      : _c.entries.map((e) => '${e.key}=${e.value}').join('; ');
  @override
  Future<void> saveFromSetCookie(List<String> setCookieHeaders) async {
    for (final h in setCookieHeaders) {
      final c = Cookie.fromSetCookieValue(h);
      if (c.value.isEmpty) {
        _c.remove(c.name);
      } else {
        _c[c.name] = c.value;
      }
    }
  }

  @override
  Future<bool> isEmpty() async => _c.isEmpty;
  @override
  Future<void> clear() async => _c.clear();
}
