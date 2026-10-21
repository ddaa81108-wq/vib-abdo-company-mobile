import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'error_mapper.dart';
import 'precise_json.dart';
import 'reachability.dart';
import 'wire_json.dart';

/// Dio-based implementation for the REAL envelope:
///   success { "ok": true, "data": ... }   error { "ok": false, "error": {...} }
/// Interceptors (Auth -> GetRetry -> Logging) are attached by ApiStack.
class DioApiClient implements ApiClient {
  DioApiClient(this._dio,
      {ErrorMapper errorMapper = const ErrorMapper(),
      this.rateWireFormat = RateWireFormat.number})
      : _errorMapper = errorMapper {
    usePreciseJson(_dio);
  }

  /// Response JSON is decoded by [PreciseJson]: non-integer numbers keep their exact
  /// text ([JsonNumberText]); no double is ever produced, per API contract.
  static void usePreciseJson(Dio dio) {
    dio.transformer = BackgroundTransformer()
      ..jsonDecodeCallback = PreciseJson.decode;
  }

  final Dio _dio;
  final RateWireFormat rateWireFormat;
  final ErrorMapper _errorMapper;

  Dio get dio => _dio;

  /// Same headers the web client sends (per API contract).
  static BaseOptions baseOptions(ApiConfig config, {String? baseUrl}) =>
      BaseOptions(
        baseUrl: baseUrl ?? config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
          'X-Client-Api-Version': '1',
        },
      );

  @override
  Future<ApiResponse> get(String path,
          {Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _send('GET', path, query: query, options: options);

  @override
  Future<ApiResponse> post(String path,
          {Object? body,
          Map<String, dynamic>? query,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _send('POST', path, body: body, query: query, options: options);

  @override
  Future<ApiResponse> put(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _send('PUT', path, body: body, options: options);

  @override
  Future<ApiResponse> patch(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _send('PATCH', path, body: body, options: options);

  @override
  Future<ApiResponse> delete(String path,
          {Object? body,
          ApiRequestOptions options = const ApiRequestOptions()}) =>
      _send('DELETE', path, body: body, options: options);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required ApiRequestOptions options,
  }) async {
    try {
      final res = await _dio.request<Object?>(
        path,
        data: body == null
            ? null
            : WireJson.encode(body, rateWireFormat), // pre-encoded JSON text
        queryParameters: _clean(query),
        options: Options(
          method: method,
          headers: {
            ...options.headers,
            if (body != null) 'Content-Type': 'application/json',
          },
          extra: {
            'skipAuth': !options.authenticated,
            'noRetry': options.noRetry
          },
        ),
      );
      final normalized = _normalize(res);
      ApiReachability.instance.recordSuccess();
      return normalized;
    } on ApiException catch (error) {
      if (error is NetworkException || error is TimeoutApiException) {
        ApiReachability.instance.recordTransportFailure();
      }
      rethrow;
    } catch (e) {
      final mapped = _errorMapper.map(e);
      if (mapped is NetworkException || mapped is TimeoutApiException) {
        ApiReachability.instance.recordTransportFailure();
      }
      throw mapped;
    }
  }

  /// Unwraps `{ok:true, data}`. Anything else is an error, like the web client.
  ApiResponse _normalize(Response<Object?> res) {
    final status = res.statusCode ?? 200;
    final cid = res.headers.value('x-correlation-id');
    final body = res.data;
    if (status == 204 || body == null || (body is String && body.isEmpty)) {
      return ApiResponse(statusCode: status, correlationId: cid);
    }
    if (body is Map && body['ok'] == true && body.containsKey('data')) {
      return ApiResponse(
          statusCode: status, data: body['data'], correlationId: cid);
    }
    if (body is Map && body['ok'] == false) {
      throw _errorMapper.fromResponse(status, body, res.headers);
    }
    throw InvalidServerResponseException(
        statusCode: status, correlationId: cid);
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.fromEntries(
        q.entries.where((e) => e.value != null && e.value != ''));
  }
}
