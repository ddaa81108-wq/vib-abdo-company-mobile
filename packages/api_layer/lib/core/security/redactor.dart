/// Redacts sensitive keys before anything reaches logs / crash reports.
/// Only `correlationId` / `x-correlation-id` may be logged as an identifier.
class Redactor {
  const Redactor();
  static const _sensitive = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-csrf-token',
    'csrftoken',
    'password',
    'currentpassword',
    'newpassword',
    'accesstoken',
    'refreshtoken',
    'username',
    'displayname',
    'name',
    'customername',
    'phone',
    'note',
    'description',
    'reason',
    'details',
    'payload',
  };

  static bool isSensitiveKey(String key) {
    final k = key.toLowerCase();
    return _sensitive.contains(k) ||
        k.endsWith('units') ||
        k == 'inputvalue' ||
        k == 'factor' ||
        k == 'exchangerate';
  }

  Object? redact(Object? value) {
    if (value is Map) {
      return value
          .map((k, v) => MapEntry(k, isSensitiveKey('$k') ? '***' : redact(v)));
    }
    if (value is List) return value.map(redact).toList();
    return value;
  }
}
