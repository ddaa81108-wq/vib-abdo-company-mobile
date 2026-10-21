import 'package:flutter/foundation.dart';

/// Counts of push and poll rows the transport refused.
///
/// The line that is printed contains only the counts. Payload maps, names,
/// amounts, phones, and tokens are never fields of this object.
class PushDropLog {
  int loggedOut = 0;
  int missingRecipient = 0;
  int wrongUser = 0;
  int duplicate = 0;
  int emptyId = 0;

  int get total =>
      loggedOut + missingRecipient + wrongUser + duplicate + emptyId;

  void logCounts() {
    debugPrint(
      'push drops loggedOut=$loggedOut missingRecipient=$missingRecipient '
      'wrongUser=$wrongUser duplicate=$duplicate emptyId=$emptyId',
    );
  }

  void clear() {
    loggedOut = 0;
    missingRecipient = 0;
    wrongUser = 0;
    duplicate = 0;
    emptyId = 0;
  }
}
