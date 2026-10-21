import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zeroReview is pending only for an explicit server signal', () {
    expect(readZeroReview(null), ZeroReviewRead.unknown);
    expect(readZeroReview(const {}), ZeroReviewRead.unknown);
    expect(readZeroReview({'status': 'pending'}), ZeroReviewRead.pending);
    expect(readZeroReview({'state': 'pending'}), ZeroReviewRead.pending);
    expect(readZeroReview({'pending': true}), ZeroReviewRead.pending);
    expect(
      readZeroReview({'status': 'pending', 'pending': true}),
      ZeroReviewRead.pending,
    );

    for (final status in ['confirmed', 'reviewed', 'done', 'none']) {
      expect(readZeroReview({'status': status}), ZeroReviewRead.closed);
      expect(readZeroReview({'state': status}), ZeroReviewRead.closed);
    }
    expect(readZeroReview({'pending': false}), ZeroReviewRead.closed);
  });

  test('an unrecognized or conflicting zeroReview is not pending', () {
    expect(readZeroReview({'status': 'maybe'}), ZeroReviewRead.unknown);
    expect(readZeroReview({'status': 'Pending'}), ZeroReviewRead.unknown);
    expect(readZeroReview({'status': 'zero'}), ZeroReviewRead.unknown);
    expect(readZeroReview({'pending': 1}), ZeroReviewRead.unknown);
    expect(readZeroReview({'pending': 'true'}), ZeroReviewRead.unknown);
    expect(
      readZeroReview({'status': 'pending', 'pending': false}),
      ZeroReviewRead.unknown,
    );
    expect(
      readZeroReview({'state': 'confirmed', 'pending': true}),
      ZeroReviewRead.unknown,
    );
    expect(readZeroReview({'note': 'ينتظر'}), ZeroReviewRead.unknown);
  });
}
