import 'package:uuid/uuid.dart';

/// Dedup + concurrency metadata sent IN THE BODY of every business mutation
/// (the real system uses `requestId` + `expectedVersion` in the JSON body, not headers).
///
/// Rules:
/// - The UI creates one [MutationMeta] when the form or confirm dialog opens.
/// - A retry of that same attempt reuses the requestId.
/// - A changed input, a new form, or a successful send gets a new requestId.
/// - A failed send keeps the requestId. Mutations are not retried automatically
///   (GetRetryInterceptor only retries GET/HEAD).
/// - expectedVersion is the `version` the server returned for the record being changed;
///   VERSION_CONFLICT -> refetch and show the server's current state.
class MutationMeta {
  MutationMeta({this.expectedVersion, String? requestId})
      : requestId = requestId ?? RequestIds.newRequestId();

  final String requestId;
  final int? expectedVersion;

  /// Body fields. [versionField] is the server's name for it on this endpoint:
  /// `expectedVersion` (cards, masraweya, treasury), `expectedDayVersion` (purchases),
  /// `expectedFinancialVersion` (customer zero-review).
  Map<String, dynamic> toBody({String versionField = 'expectedVersion'}) => {
        'requestId': requestId,
        if (expectedVersion != null) versionField: expectedVersion,
      };
}

class RequestIds {
  RequestIds._();
  static const _uuid = Uuid();
  static String newRequestId() => _uuid.v4();
}
