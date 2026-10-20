/// Redacts sensitive keys and secret-shaped text before logs or crash reports.
///
/// `correlationId` / `x-correlation-id` stay visible. Everything else that
/// names a credential, a person, or an amount is replaced. Key matching ignores
/// case and `_` / `-`, so `access_token` and `accessToken` are the same key.
class Redactor {
  const Redactor();

  static const _exact = {
    'otp',
    'pin',
    'details',
    'payload',
    'reason',
    'description',
    'body',
    'title',
    'label',
    'message',
    'itemlabel',
    'loginticket',
    'maskeddestination',
    'session',
    'inputvalue',
    'factor',
    'factormicros',
    'egpperlyd',
    'openingbalance',
    'iban',
  };

  static final _userinfo = RegExp(r'://[^/\s:]+:[^@\s]+@');
  static final _bearer = RegExp(r'\bbearer\s+\S+', caseSensitive: false);
  static final _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b',
  );
  static final _assignment = RegExp(
    r'\b(set-cookie|csrf[-_]?token|access[-_]?token|refresh[-_]?token|'
    r'api[-_]?key|password|passwd|pwd|cookie|csrf|authorization|token|secret|'
    r'session)\b\s*[:=]\s*\S+',
    caseSensitive: false,
  );

  static String normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool isSensitiveKey(String key) {
    final k = normalizeKey(key);
    if (k.isEmpty) return false;
    // The only identifier logs may keep. Check before the token rule.
    if (k.contains('correlation')) return false;
    if (_exact.contains(k)) return true;
    if (k.contains('password') ||
        k.contains('passwd') ||
        k.contains('secret') ||
        k.contains('token') ||
        k.contains('cookie') ||
        k.contains('authorization') ||
        k.contains('bearer')) {
      return true;
    }
    if (k.contains('phone') ||
        k.contains('email') ||
        k.contains('mobile') ||
        k.contains('address') ||
        k.contains('nationalid') ||
        k.contains('apikey')) {
      return true;
    }
    if (k.endsWith('name') || k.endsWith('note')) return true;
    if (k.endsWith('units') ||
        k.contains('balance') ||
        k.contains('salary') ||
        k.contains('commission') ||
        k.endsWith('rate')) {
      return true;
    }
    return false;
  }

  /// Drops bearer tokens, JWTs, URL userinfo, and `password=` / `cookie=` style
  /// assignments inside a free string. Emails are not rewritten here: a
  /// user-facing server sentence may need one, and structured email fields are
  /// removed by [isSensitiveKey].
  String scrub(String input) {
    var s = input.replaceAll(_userinfo, '://***@');
    s = s.replaceAll(_bearer, 'Bearer ***');
    s = s.replaceAll(_jwt, '***');
    s = s.replaceAllMapped(_assignment, (m) => '${m[1]}=***');
    return s;
  }

  Object? redact(Object? value) {
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k, isSensitiveKey('$k') ? '***' : redact(v)),
      );
    }
    if (value is List) return value.map(redact).toList();
    if (value is String) return scrub(value);
    return value;
  }
}
