import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/theme.dart';

/// Collection card colours, ported from the deployed website
/// (`src/shared/collectionCardState.ts` at 537f073). Only server fields are
/// read; timestamps are compared as the ISO text the server sent, exactly as
/// the website compares them. Display only: no money is computed.
enum CollectionTone { base, yellow, red, green, zero, rejected }

bool _after(String? a, String? b) =>
    a != null && b != null && a.compareTo(b) > 0;

/// `hasAdministrativeMovement`: the card balance changed outside collections
/// after the card was assigned and after the last collection action.
bool collectionHasAdministrativeMovement(CollectionAssignmentDto card) {
  final last = card.latestStatus == 'rejected' && card.latestDecisionAt != null
      ? card.latestDecisionAt
      : card.latestSubmissionAt;
  return _after(card.externalFinancialUpdatedAt, card.assignedAt) &&
      (last == null || _after(card.externalFinancialUpdatedAt, last));
}

/// `collectionCardTone`. A missing balance keeps the neutral base card.
CollectionTone collectionCardTone(CollectionAssignmentDto card) {
  if (card.latestStatus == 'rejected' &&
      !collectionHasAdministrativeMovement(card)) {
    return CollectionTone.rejected;
  }
  final balance = card.balanceUnits?.asInt;
  if (balance != null && balance < 0) return CollectionTone.green;
  if (balance == 0) {
    final cash = card.latestCashReceivedAt;
    final external = card.externalFinancialUpdatedAt;
    final settled =
        cash != null &&
        (external == null || cash.compareTo(external) >= 0) &&
        !card.hasPending &&
        card.cashOutstandingCount == 0;
    return settled ? CollectionTone.red : CollectionTone.zero;
  }
  if (collectionHasAdministrativeMovement(card)) return CollectionTone.base;
  return card.latestMode == 'partial'
      ? CollectionTone.yellow
      : CollectionTone.base;
}

/// The website gradients (`.collection-base` … `.zero-collection-card`),
/// with the app's glossy finish. Same colours in dark and light, as on the
/// website. A rejected card has no website colour: the neutral grey gloss.
Gloss collectionToneGloss(BuildContext context, CollectionTone tone) {
  return switch (tone) {
    CollectionTone.base => const Gloss(
      top: Color(0xFF3548FF),
      bottom: Color(0xFF15126F),
      border: Color(0xFF5B6BFF),
      glow: Color(0x553548FF),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
    ),
    CollectionTone.yellow => const Gloss(
      top: Color(0xFFFFE477),
      bottom: Color(0xFFD4A514),
      border: Color(0xFFFFEE9E),
      glow: Color(0x55F1C232),
      ink: Color(0xFF241C00),
      amount: Color(0xFF241C00),
      sheen: 0.22,
    ),
    CollectionTone.red => const Gloss(
      top: Color(0xFFFF164E),
      bottom: Color(0xFF870021),
      border: Color(0xFFFF5A80),
      glow: Color(0x55D30036),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
    ),
    CollectionTone.green => const Gloss(
      top: Color(0xFF00C77B),
      bottom: Color(0xFF00603E),
      border: Color(0xFF3EE0A0),
      glow: Color(0x5500965E),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
    ),
    CollectionTone.zero => const Gloss(
      top: Color(0xFF151515),
      bottom: Color(0xFF000000),
      border: Color(0xFF3A3A3A),
      glow: Color(0x55000000),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.10,
    ),
    CollectionTone.rejected => context.look.glossGrey,
  };
}

/// Test and screenshot label for a tone.
String collectionToneName(CollectionTone tone) => tone.name;
