import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cookie jar and token store injected into the real API stack.
///
/// Both default to [flutter_secure_storage] (Android Keystore / iOS Keychain).
/// The in-memory fake client does not write either store. Tests pass
/// [InMemoryCookieStore] and [InMemoryTokenStorage].
class AppSecureStores {
  AppSecureStores({CookieStore? cookies, TokenStorage? tokens})
    : cookies = cookies ?? SecureCookieStore(),
      tokens = tokens ?? SecureTokenStorage();

  final CookieStore cookies;
  final TokenStorage tokens;
}

final secureStoresProvider = Provider<AppSecureStores>(
  (ref) => AppSecureStores(),
);
