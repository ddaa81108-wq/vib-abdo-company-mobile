import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/auth_strategy.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'error_mapper.dart';

/// Delegates credentials to the active [AuthStrategy].
/// - onRequest: strategy.acquireWrite (POST/PUT/PATCH/DELETE only), then attach
///   (cookies + X-CSRF-Token, or Bearer). GET and HEAD are not queued.
/// - onResponse/onError: strategy.capture (Set-Cookie) and releaseWrite.
/// - onError: maps the error; CSRF invalid -> strategy refetches token -> replay ONCE
///   while the write turn is still held; AUTH_REQUIRED -> forced logout
///   (no refresh flow on the cookie session). A 419 that is not a CSRF error
///   is session expiry and is not replayed.
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

  bool _isLogout(RequestOptions request) {
    final path = request.uri.path;
    return path == ApiEndpoints.logout || request.path == ApiEndpoints.logout;
  }

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      await _strategy.acquireWrite(options);
      await _strategy.attach(options, authenticated: _authenticated(options));
      handler.next(options);
    } catch (error, stack) {
      _strategy.releaseWrite(options);
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stack,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    try {
      await _strategy.capture(response);
      handler.next(response);
    } catch (error, stack) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          error: error,
          stackTrace: stack,
          type: DioExceptionType.unknown,
        ),
      );
    } finally {
      _strategy.releaseWrite(response.requestOptions);
    }
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    try {
      final response = err.response;
      if (response != null) await _strategy.capture(response);
      if (response == null) {
        handler.next(err);
        return;
      }

      final mapped = _mapper.map(err);
      final action = await _strategy.handleAuthError(mapped, req,
          authenticated: _authenticated(req));

      switch (action) {
        case AuthErrorAction.passThrough:
          handler.next(err);
          return;
        case AuthErrorAction.forceLogout:
          // Logout's own 401 must not announce session_expired. SessionManager
          // .logout() still wipes with reason 'logout'.
          if (!_isLogout(req)) await _onForcedLogout('session_expired');
          handler.next(err);
          return;
        case AuthErrorAction.retryOnce:
          // A dead session is never replayed, even if a strategy asks.
          if (mapped is SessionExpiredException) {
            if (_authenticated(req) && !_isLogout(req)) {
              await _onForcedLogout('session_expired');
            }
            handler.next(err);
            return;
          }
          if (req.extra['authRetried'] == true) {
            handler.next(err);
            return;
          }
          // The replay uses this same RequestOptions, so acquireWrite does not
          // take a second turn. releaseWrite stays until that replay settles.
          req.extra['authRetried'] = true;
          try {
            final replay = await retryDio.fetch<Object?>(req);
            handler.resolve(replay);
          } on DioException catch (e) {
            handler.next(e);
          }
          return;
      }
    } finally {
      // Idempotent. A replay releases on its own response or error first.
      _strategy.releaseWrite(req);
    }
  }
}
