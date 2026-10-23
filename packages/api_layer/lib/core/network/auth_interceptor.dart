import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/auth_strategy.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'error_mapper.dart';

/// Delegates credentials to the active [AuthStrategy].
/// - onRequest: GET /api/auth/csrf is [AuthStrategy.adoptCsrfGet] (write mutex
///   and the single-flight refresh). Other requests call acquireWrite
///   (POST/PUT/PATCH/DELETE only), then attach (cookies + X-CSRF-Token, or
///   Bearer). Other GETs and HEADs are not queued.
/// - onResponse/onError: strategy.capture (Set-Cookie) and releaseWrite.
/// - onError: maps the error; 403 CSRF_REJECTED -> strategy refetches token
///   -> replay ONCE while the write turn is still held. Any other status or
///   code, including a 419, is not replayed. AUTH_REQUIRED -> forced logout
///   (no refresh flow on the cookie session). A 419 that is not a CSRF error
///   is session expiry and is not replayed.
/// - The write turn is released before the forced-logout callback. Logout
///   cleanups post through this same client (device unregister). Waiting for
///   that post while the failed write still holds the mutex deadlocks every
///   later write.
/// - A 401 from GET /api/auth/csrf on this client uses that same wipe. The
///   catalog has no 419; a non-CSRF 419 on a write still wipes and is not replayed.
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

  bool _isCsrfGet(RequestOptions request) {
    if (request.method.toUpperCase() != 'GET') return false;
    final path = request.uri.path.isEmpty ? request.path : request.uri.path;
    return path == ApiEndpoints.csrf ||
        request.path == ApiEndpoints.csrf ||
        path.endsWith(ApiEndpoints.csrf) ||
        request.path.endsWith(ApiEndpoints.csrf);
  }

  /// Drops the write turn, then wipes. releaseWrite is idempotent, so the
  /// `onError` finally may call it again.
  Future<void> _releaseAndWipe(RequestOptions request) async {
    _strategy.releaseWrite(request);
    if (!_isLogout(request) && _authenticated(request)) {
      await _onForcedLogout('session_expired');
    }
  }

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final adopted = await _strategy.adoptCsrfGet(options);
      if (adopted != null) {
        if (_isCsrfGet(options) && adopted.statusCode == 401) {
          await _releaseAndWipe(options);
          handler.reject(
            DioException(
              requestOptions: options,
              response: adopted,
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(adopted);
        return;
      }
      await _strategy.acquireWrite(options);
      await _strategy.attach(options, authenticated: _authenticated(options));
      handler.next(options);
    } on DioException catch (error) {
      if (_isCsrfGet(options) && error.response?.statusCode == 401) {
        await _releaseAndWipe(options);
        handler.reject(error);
        return;
      }
      _strategy.releaseWrite(options);
      handler.reject(error);
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
          // .logout() still wipes with reason 'logout'. The turn is released
          // before that wipe so its cleanup post can take the mutex.
          await _releaseAndWipe(req);
          handler.next(err);
          return;
        case AuthErrorAction.retryOnce:
          // A dead session is never replayed, even if a strategy asks.
          if (mapped is SessionExpiredException) {
            await _releaseAndWipe(req);
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
