import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/mutation_form.dart';

void main() {
  test('a retry of the same inputs reuses the request id', () {
    final lock = SubmissionLock(expectedVersion: 4);
    final first = lock.metaFor('100|note');
    final second = lock.metaFor('100|note');

    expect(second.requestId, first.requestId);
    expect(second.expectedVersion, 4);
  });

  test('a changed input or a new form gets a new request id', () {
    final lock = SubmissionLock();
    final first = lock.metaFor('100');
    final changed = lock.metaFor('200');
    final anotherForm = SubmissionLock().metaFor('100');

    expect(changed.requestId, isNot(first.requestId));
    expect(anotherForm.requestId, isNot(first.requestId));
  });

  test('success starts a new request id for the next send', () {
    final lock = SubmissionLock();
    final first = lock.metaFor('100');
    lock.succeed();
    final next = lock.metaFor('100');

    expect(next.requestId, isNot(first.requestId));
  });

  test('a new expected version starts a new request id', () {
    final lock = SubmissionLock(expectedVersion: 1);
    final first = lock.metaFor('pin');
    lock.expectedVersion = 2;
    final next = lock.metaFor('pin');

    expect(next.requestId, isNot(first.requestId));
    expect(next.expectedVersion, 2);
  });
}
