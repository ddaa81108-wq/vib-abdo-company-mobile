/// Backend-agnostic HTTP abstraction. Repositories depend on this only.
/// Implementations: DioApiClient (real), FakeApiClient (mock, before server access).
library;

class ApiRequestOptions {
  const ApiRequestOptions({
    this.authenticated = true,
    this.headers = const {},
    this.noRetry = false,
  });

  /// false for login / csrf / public endpoints.
  final bool authenticated;
  final Map<String, String> headers;

  /// Disable GetRetryInterceptor for this request (e.g. heavy downloads, SSE).
  final bool noRetry;
}

/// Normalized response: `data` is the unwrapped `data` of `{ok:true, data}`.
/// The real server has no separate `meta`; pagination lives inside `data`.
class ApiResponse {
  const ApiResponse({required this.statusCode, this.data, this.correlationId});
  final int statusCode;
  final Object? data;

  /// From the `x-correlation-id` response header (safe to log).
  final String? correlationId;

  Map<String, dynamic> get dataMap =>
      data is Map ? (data as Map).cast<String, dynamic>() : <String, dynamic>{};
  List<Map<String, dynamic>> get dataList => data is List
      ? (data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false)
      : const [];
}

abstract interface class ApiClient {
  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? query,
      ApiRequestOptions options = const ApiRequestOptions()});
  Future<ApiResponse> post(String path,
      {Object? body,
      Map<String, dynamic>? query,
      ApiRequestOptions options = const ApiRequestOptions()});
  Future<ApiResponse> put(String path,
      {Object? body, ApiRequestOptions options = const ApiRequestOptions()});
  Future<ApiResponse> patch(String path,
      {Object? body, ApiRequestOptions options = const ApiRequestOptions()});
  Future<ApiResponse> delete(String path,
      {Object? body, ApiRequestOptions options = const ApiRequestOptions()});
}
