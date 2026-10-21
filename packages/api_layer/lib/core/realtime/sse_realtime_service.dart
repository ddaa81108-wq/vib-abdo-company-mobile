import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../network/api_endpoints.dart';
import '../network/error_mapper.dart';
import '../network/precise_json.dart';
import 'realtime_service.dart';

/// SSE client over Dio streaming. Goes through the main Dio, so AuthInterceptor
/// attaches the session cookie (and 401 -> forced logout).
/// Reconnects with exponential backoff (1s .. 30s, ±20% jitter).
class SseRealtimeService implements RealtimeService {
  SseRealtimeService({
    required Dio dio,
    required SequenceCursor cursor,
    this.topics = RealtimeTopics.all,
    Random? random,
  })  : _dio = dio,
        _cursor = cursor,
        _random = random ?? Random();

  final Dio _dio;
  final SequenceCursor _cursor;
  final Set<String> topics;
  final Random _random;

  final _signals = StreamController<RealtimeSignal>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  CancelToken? _cancel;
  bool _running = false;
  bool _isConnected = false;
  int _failures = 0;

  @override
  Stream<RealtimeSignal> get signals => _signals.stream;

  /// true while the SSE stream is open (used by ResilientRealtimeService).
  Stream<bool> get connection => _connected.stream;
  bool get isConnected => _isConnected;

  @override
  RealtimeMode get mode => _running ? RealtimeMode.sse : RealtimeMode.stopped;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  @override
  Future<void> stop() async {
    _running = false;
    _cancel?.cancel('stopped');
    _setConnected(false);
  }

  void _setConnected(bool v) {
    if (_isConnected == v) return;
    _isConnected = v;
    if (!_connected.isClosed) _connected.add(v);
  }

  Future<void> _loop() async {
    while (_running) {
      try {
        await _connectOnce();
        _failures = 0;
      } catch (error) {
        // 401/419 ends the loop. Backoff would reconnect forever after logout.
        if (isUnrecoverableSessionError(error)) {
          _running = false;
        } else {
          _failures++;
        }
      }
      _setConnected(false);
      if (!_running) break;
      await Future<void>.delayed(_backoff());
    }
  }

  Duration _backoff() {
    final exp = min(30000, 1000 * pow(2, min(_failures, 5)).toInt());
    final jitter = 1 + (_random.nextDouble() * 0.4 - 0.2);
    return Duration(milliseconds: (exp * jitter).round());
  }

  Future<void> _connectOnce() async {
    _cancel = CancelToken();
    final res = await _dio.get<ResponseBody>(
      ApiEndpoints.events,
      queryParameters: {'after': _cursor.value},
      cancelToken: _cancel,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero, // long-lived stream
        headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
        extra: {'noRetry': true},
      ),
    );
    final body = res.data;
    if (body == null) return;

    _setConnected(true);
    _failures = 0;
    // Same as the web client: (re)open => resync what is on screen.
    _signals.add(RealtimeSignal.resync);

    String? event;
    String? id;
    final data = StringBuffer();

    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!_running) break;
      if (line.isEmpty) {
        _dispatch(event, id, data.toString());
        event = null;
        id = null;
        data.clear();
      } else if (line.startsWith(':')) {
        // comment / heartbeat
      } else if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('id:')) {
        id = line.substring(3).trim();
      } else if (line.startsWith('data:')) {
        if (data.isNotEmpty) data.write('\n');
        data.write(line.substring(5).trimLeft());
      }
    }
  }

  void _dispatch(String? event, String? id, String data) {
    final topic = event ?? 'message';
    if (topic == RealtimeTopics.fullResyncRequired) {
      _signals.add(RealtimeSignal.resync);
      return;
    }
    final seq = int.tryParse(id ?? '');
    if (seq == null || seq <= 0) {
      _signals.add(RealtimeSignal.resync); // same rule as the web client
      return;
    }
    _cursor.advance(seq);
    if (!topics.contains(topic)) return;
    String? aggregateId;
    try {
      final j = PreciseJson.decode(data);
      if (j is Map && j['aggregateId'] is String) {
        aggregateId = j['aggregateId'] as String;
      }
      // j['payload'] intentionally ignored.
    } catch (_) {}
    _signals.add(
        RealtimeSignal(sequence: seq, topic: topic, aggregateId: aggregateId));
  }

  Future<void> dispose() async {
    await stop();
    await _signals.close();
    await _connected.close();
  }
}
