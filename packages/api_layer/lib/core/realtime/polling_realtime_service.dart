import 'dart:async';

import '../../data/models/common.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/error_mapper.dart';
import 'realtime_service.dart';

/// Fallback: GET /api/event-changes?after=<seq> every [interval] (default 4s)
/// -> { events: [{sequence, topic, aggregateId, payload, createdAt}], latest, fullResync }.
class PollingRealtimeService implements RealtimeService {
  PollingRealtimeService({
    required ApiClient api,
    required SequenceCursor cursor,
    this.interval = const Duration(seconds: 4),
    this.topics = RealtimeTopics.all,
  })  : _api = api,
        _cursor = cursor;

  final ApiClient _api;
  final SequenceCursor _cursor;
  final Duration interval;
  final Set<String> topics;

  final _signals = StreamController<RealtimeSignal>.broadcast();
  Timer? _timer;
  bool _busy = false;

  @override
  Stream<RealtimeSignal> get signals => _signals.stream;

  @override
  RealtimeMode get mode =>
      _timer == null ? RealtimeMode.stopped : RealtimeMode.polling;

  @override
  Future<void> start() async {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _tick());
    unawaited(_tick());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await _api.get(ApiEndpoints.eventChanges,
          query: {'after': _cursor.value},
          options: const ApiRequestOptions(noRetry: true));
      final d = res.dataMap;
      final latest = intOrNull(d['latest']);
      if (d['fullResync'] == true) _signals.add(RealtimeSignal.resync);
      for (final e in (d['events'] is List ? d['events'] as List : const [])) {
        if (e is! Map) continue;
        final seq = intOrNull(e['sequence']) ?? 0;
        final topic = '${e['topic'] ?? ''}';
        _cursor.advance(seq);
        if (!topics.contains(topic)) continue;
        _signals.add(RealtimeSignal(
          sequence: seq,
          topic: topic,
          aggregateId:
              e['aggregateId'] is String ? e['aggregateId'] as String : null,
        ));
      }
      if (latest != null) _cursor.advance(latest);
    } catch (error) {
      // Transport failures wait for the next tick. Session expiry stops the timer
      // so a dead cookie cannot poll forever if logout is late.
      if (isUnrecoverableSessionError(error)) await stop();
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    await stop();
    await _signals.close();
  }
}
