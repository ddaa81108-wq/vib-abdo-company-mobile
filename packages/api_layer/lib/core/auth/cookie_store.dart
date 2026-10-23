import 'dart:convert';
import 'dart:io' show Cookie;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent cookie jar whose contents live ONLY in flutter_secure_storage
/// (Keychain / Android Keystore-backed) — never in plain files or SharedPreferences.
/// Single-origin client: cookies are only sent to the configured API origin.
///
/// The real session cookie is `abdo_session` (HttpOnly, Secure, SameSite=Strict).
/// The jar stores every name `Set-Cookie` sends, including a cleared `abdo_mfa`
/// (`Max-Age=0`), and does not look up an older cookie name.
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

/// One `Set-Cookie` line. [remove] is true for an empty value, `Max-Age=0`,
/// or an expiry already in the past. The cookie value is never logged.
class _ParsedSetCookie {
  const _ParsedSetCookie(this.name, this.value, this.expiresAt, this.remove);

  final String name;
  final String value;
  final DateTime? expiresAt;
  final bool remove;
}

_ParsedSetCookie? _parseSetCookie(String header) {
  Cookie? cookie;
  try {
    cookie = Cookie.fromSetCookieValue(header);
  } catch (_) {
    // Some parsers reject SameSite. Drop that attribute and try once more.
    // The raw header is not logged: it contains the cookie value.
    final stripped = header.replaceAll(
      RegExp(r';\s*SameSite=[^;]*', caseSensitive: false),
      '',
    );
    try {
      cookie = Cookie.fromSetCookieValue(stripped);
    } catch (_) {
      return null;
    }
  }
  final DateTime? exp = cookie.maxAge != null
      ? DateTime.now().toUtc().add(Duration(seconds: cookie.maxAge!))
      : cookie.expires?.toUtc();
  final removed = cookie.value.isEmpty ||
      (cookie.maxAge != null && cookie.maxAge! <= 0) ||
      (exp != null && !DateTime.now().toUtc().isBefore(exp));
  return _ParsedSetCookie(cookie.name, cookie.value, exp, removed);
}

/// Key/value store used by [SecureCookieStore]. Production uses the platform
/// keystore. Tests use [SecureCookieStore.memory] so the same persistence
/// code runs without a plugin.
abstract interface class _CookieSecretStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class _FlutterCookieSecretStore implements _CookieSecretStore {
  _FlutterCookieSecretStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class _MemoryCookieSecretStore implements _CookieSecretStore {
  _MemoryCookieSecretStore(Map<String, String>? backing)
      : _data = backing ?? <String, String>{};

  final Map<String, String> _data;

  @override
  Future<String?> read({required String key}) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }
}

class SecureCookieStore implements CookieStore {
  SecureCookieStore([FlutterSecureStorage? storage])
      : _secrets = _FlutterCookieSecretStore(
          storage ??
              const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
                iOptions: IOSOptions(
                    accessibility:
                        KeychainAccessibility.first_unlock_this_device),
              ),
        );

  /// Same JSON persistence as the keystore-backed store, with an in-memory map.
  ///
  /// A second instance constructed with the same [backing] map reads what the
  /// first wrote. Production keeps using [SecureCookieStore.new].
  SecureCookieStore.memory([Map<String, String>? backing])
      : _secrets = _MemoryCookieSecretStore(backing);

  final _CookieSecretStore _secrets;
  static const _key = 'session.cookies.v1';
  Map<String, _StoredCookie>? _cache;

  Future<Map<String, _StoredCookie>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _secrets.read(key: _key);
    final map = <String, _StoredCookie>{};
    if (raw != null) {
      try {
        for (final e in (jsonDecode(raw) as List)) {
          final c = _StoredCookie.fromJson((e as Map).cast<String, dynamic>());
          if (!c.isExpired) map[c.name] = c;
        }
      } catch (_) {
        // Corrupt store -> start clean. Do not log the payload.
      }
    }
    return _cache = map;
  }

  Future<void> _persist(Map<String, _StoredCookie> map) async {
    _cache = map;
    if (map.isEmpty) {
      await _secrets.delete(key: _key);
    } else {
      await _secrets.write(
        key: _key,
        value: jsonEncode(map.values.map((c) => c.toJson()).toList()),
      );
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
    var changed = false;
    for (final header in setCookieHeaders) {
      final parsed = _parseSetCookie(header);
      if (parsed == null) continue;
      changed = true;
      if (parsed.remove) {
        map.remove(parsed.name);
      } else {
        map[parsed.name] =
            _StoredCookie(parsed.name, parsed.value, parsed.expiresAt);
      }
    }
    if (changed) await _persist(map);
  }

  @override
  Future<bool> isEmpty() async => (await cookieHeader()) == null;

  @override
  Future<void> clear() async {
    _cache = <String, _StoredCookie>{};
    await _secrets.delete(key: _key);
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
    for (final header in setCookieHeaders) {
      final parsed = _parseSetCookie(header);
      if (parsed == null) continue;
      if (parsed.remove) {
        _c.remove(parsed.name);
      } else {
        _c[parsed.name] = parsed.value;
      }
    }
  }

  @override
  Future<bool> isEmpty() async => _c.isEmpty;
  @override
  Future<void> clear() async => _c.clear();
}
