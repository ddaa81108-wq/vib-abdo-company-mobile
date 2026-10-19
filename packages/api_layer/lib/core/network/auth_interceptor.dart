import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/auth_strategy.dart';
import 'error_mapper.dart';

/// Delegates credentials to the active [AuthStrategy].
/// - onRequest: strategy.attach (cookies + X-CSRF-Token, or Bearer).
/// - onResponse/onError: strategy.capture (Set-Cookie).
/// - onError: maps the error; CSRF invalid -> strategy refetches token -> replay ONCE;
///   AUTH_REQUIRED -> forced logout (no refresh flow on the cookie session).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthStrategy strategy,
    required Future<void> Function(String reason) onForcedLogout,
    ErrorMapper errorMapper = const ErrorMapper(),
  })  : _strategy = strategy,
        _onForcedLogout = onForcedLogout,
        _mapper = errorMapper;

  final AuthStrategy _strategy;
  final Future<void> Function(String reason) _onForcedLogout;
  final ErrorMapper _mapper;

  /// The main Dio, used to replay a request after recovery.
  late Dio retryDio;

  bool _authenticated(RequestOptions o) => o.extra['skipAuth'] != true;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    await _strategy.attach(options, authenticated: _authenticated(options));
    handler.next(options);
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    await _strategy.capture(response);
    handler.next(response);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response != null) await _strategy.capture(response);
    if (response == null) return handler.next(err);

    final req = err.requestOptions;
    final mapped = _mapper.map(err);
    final action = await _strategy.handleAuthError(mapped, req,
        authenticated: _authenticated(req));

    switch (action) {
      case AuthErrorAction.passThrough:
        return handler.next(err);
      case AuthErrorAction.forceLogout:
        await _onForcedLogout('session_expired');
        return handler.next(err);
      case AuthErrorAction.retryOnce:
        if (req.extra['authRetried'] == true) return handler.next(err);
        req.extra['authRetried'] = true;
        try {
          final replay = await retryDio.fetch<Object?>(req);
          handler.resolve(replay);
        } on DioException catch (e) {
          handler.next(e);
        }
    }
  }
}
