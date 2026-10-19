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

  Map<String, dynamic> toJson() =>
      {'n': name, 'v': value, 'e': expiresAt?.toIso8601String()};
  static _StoredCookie fromJson(Map<String, dynamic> j) => _StoredCookie(
      '${j['n']}',
      '${j['v']}',
      j['e'] == null ? null : DateTime.tryParse('${j['e']}'));
}

class SecureCookieStore implements CookieStore {
  SecureCookieStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  final FlutterSecureStorage _s;
  static const _key = 'session.cookies.v1';
  Map<String, _StoredCookie>? _cache;

  Future<Map<String, _StoredCookie>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _s.read(key: _key);
    final map = <String, _StoredCookie>{};
    if (raw != null) {
      try {
        for (final e in (jsonDecode(raw) as List)) {
          final c = _StoredCookie.fromJson((e as Map).cast<String, dynamic>());
          if (!c.isExpired) map[c.name] = c;
        }
      } catch (_) {
        // Corrupt store -> start clean.
      }
    }
    return _cache = map;
  }

  Future<void> _persist(Map<String, _StoredCookie> map) async {
    _cache = map;
    if (map.isEmpty) {
      await _s.delete(key: _key);
    } else {
      await _s.write(
          key: _key,
          value: jsonEncode(map.values.map((c) => c.toJson()).toList()));
    }
  }

  @override
  Future<String?> cookieHeader() async {
    final map = await _load();
    map.removeWhere((_, c) => c.isExpired);
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
        final deleted = c.value.isEmpty ||
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
    await _s.delete(key: _key);
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
