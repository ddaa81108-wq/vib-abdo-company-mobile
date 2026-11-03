import 'dart:convert';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One collections write whose outcome the app has not seen yet.
///
/// Saved BEFORE the request leaves the device and kept until the server gives
/// a final answer, so a lost reply, a killed app, or a restart cannot turn a
/// retry into a second receipt. A retry always reuses [requestId] and the
/// exact same inputs ([fingerprint]); the inputs cannot be edited while it is
/// open.
class CollectionAttempt {
  const CollectionAttempt({
    required this.userId,
    required this.slot,
    required this.fingerprint,
    required this.requestId,
    this.knownSubmissionIds = const [],
  });

  final String userId;

  /// `submit:<assignmentId>` or `unlinked`.
  final String slot;

  /// `partial|50`, `full|320`, or `<name>|<amount>` for an unlinked receipt.
  final String fingerprint;
  final String requestId;

  /// Submission ids already on this card when the attempt was saved. The
  /// 537f073 server does not replay submissions by request id, so a retry
  /// first checks for a new matching row and does not resend if it exists.
  final List<String> knownSubmissionIds;

  String get mode => fingerprint.split('|').first;
  int? get amountUnits => int.tryParse(fingerprint.split('|').last);

  Map<String, Object?> toJson() => {
    'userId': userId,
    'slot': slot,
    'fingerprint': fingerprint,
    'requestId': requestId,
    'known': knownSubmissionIds,
  };

  static CollectionAttempt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final userId = raw['userId'];
    final slot = raw['slot'];
    final fingerprint = raw['fingerprint'];
    final requestId = raw['requestId'];
    if (userId is! String ||
        slot is! String ||
        fingerprint is! String ||
        requestId is! String) {
      return null;
    }
    final known = raw['known'];
    return CollectionAttempt(
      userId: userId,
      slot: slot,
      fingerprint: fingerprint,
      requestId: requestId,
      knownSubmissionIds: known is List
          ? known.map((e) => '$e').toList(growable: false)
          : const [],
    );
  }
}

/// Where the journal lives between app runs.
abstract interface class CollectionAttemptStore {
  Future<List<CollectionAttempt>> load();
  Future<void> save(List<CollectionAttempt> attempts);
}

/// SharedPreferences store. A platform without the plugin (widget tests)
/// keeps the journal in memory for the run.
class PrefsCollectionAttemptStore implements CollectionAttemptStore {
  static const key = 'collections.pendingAttempts.v1';
  List<CollectionAttempt> _memory = const [];

  @override
  Future<List<CollectionAttempt>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return _memory;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          ?CollectionAttempt.fromJson(item),
      ];
    } catch (_) {
      return _memory;
    }
  }

  @override
  Future<void> save(List<CollectionAttempt> attempts) async {
    _memory = List.unmodifiable(attempts);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode([for (final a in attempts) a.toJson()]),
      );
    } catch (_) {
      // In-memory copy above is kept.
    }
  }
}

class MemoryCollectionAttemptStore implements CollectionAttemptStore {
  MemoryCollectionAttemptStore([List<CollectionAttempt>? seed])
    : saved = [...?seed];
  List<CollectionAttempt> saved;

  @override
  Future<List<CollectionAttempt>> load() async => List.of(saved);

  @override
  Future<void> save(List<CollectionAttempt> attempts) async =>
      saved = List.of(attempts);
}

final collectionAttemptStoreProvider = Provider<CollectionAttemptStore>(
  (ref) => PrefsCollectionAttemptStore(),
);

/// True when the server's answer is final (accepted or refused), so the
/// attempt can be dropped. A transport failure, a timeout, a 5xx, a session
/// expiry, or an unreadable reply leaves the outcome unknown.
bool isFinalCollectionAnswer(Object error) => switch (error) {
  NetworkException() ||
  TimeoutApiException() ||
  ServerException() ||
  UnknownApiException() ||
  InvalidServerResponseException() ||
  SessionExpiredException() ||
  UnauthorizedException() => false,
  _ => true,
};

class CollectionRequestJournal
    extends AsyncNotifier<List<CollectionAttempt>> {
  @override
  Future<List<CollectionAttempt>> build() =>
      ref.read(collectionAttemptStoreProvider).load();

  Future<List<CollectionAttempt>> _current() async {
    final value = state.value;
    if (value != null) return value;
    return future;
  }

  /// The open attempt for [slot], if any.
  CollectionAttempt? pending(String? userId, String slot) {
    final list = state.value ?? const <CollectionAttempt>[];
    for (final attempt in list) {
      if (attempt.userId == userId && attempt.slot == slot) return attempt;
    }
    return null;
  }

  Future<CollectionAttempt?> pendingAsync(String? userId, String slot) async {
    final list = await _current();
    for (final attempt in list) {
      if (attempt.userId == userId && attempt.slot == slot) return attempt;
    }
    return null;
  }

  /// Saves the attempt and returns the request id to send. The same open
  /// attempt (same inputs) keeps its id. Different inputs while one is open
  /// throw [StateError]: the UI locks the inputs, so this is a bug guard.
  Future<CollectionAttempt> begin({
    required String userId,
    required String slot,
    required String fingerprint,
    List<String> knownSubmissionIds = const [],
  }) async {
    final list = [...await _current()];
    for (final attempt in list) {
      if (attempt.userId == userId && attempt.slot == slot) {
        if (attempt.fingerprint != fingerprint) {
          throw StateError('An unconfirmed attempt is open for $slot');
        }
        return attempt;
      }
    }
    final attempt = CollectionAttempt(
      userId: userId,
      slot: slot,
      fingerprint: fingerprint,
      requestId: RequestIds.newRequestId(),
      knownSubmissionIds: knownSubmissionIds,
    );
    list.add(attempt);
    await ref.read(collectionAttemptStoreProvider).save(list);
    state = AsyncData(list);
    return attempt;
  }

  /// Drops the attempt after a final server answer.
  Future<void> settle(String userId, String slot) async {
    final list = [...await _current()]
      ..removeWhere((a) => a.userId == userId && a.slot == slot);
    await ref.read(collectionAttemptStoreProvider).save(list);
    state = AsyncData(list);
  }
}

final collectionRequestJournalProvider =
    AsyncNotifierProvider<CollectionRequestJournal, List<CollectionAttempt>>(
      CollectionRequestJournal.new,
    );
