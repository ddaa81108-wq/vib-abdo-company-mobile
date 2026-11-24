import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/live_refresh_batch.dart';

void main() {
  testWidgets('a commit burst refreshes each affected provider once', (
    tester,
  ) async {
    final batches = <List<String>>[];
    final batch = LiveRefreshBatch<String>(batches.add);
    batch.addAll(['customers', 'home']);
    await tester.pump(const Duration(milliseconds: 8));
    batch.addAll(['customers', 'home', 'ledger']);
    await tester.pump(const Duration(milliseconds: 8));
    expect(batches, [
      ['customers', 'home', 'ledger'],
    ]);
    batch.addAll(['customers']);
    await tester.pump(const Duration(milliseconds: 16));
    expect(batches.last, ['customers']);
    expect(batches, hasLength(2));
    batch.cancel();
  });

  testWidgets('logout cancels pending reads and a new session can refresh', (
    tester,
  ) async {
    final batches = <List<int>>[];
    final batch = LiveRefreshBatch<int>(batches.add);
    batch.addAll([1]);
    batch.cancel();
    await tester.pump(const Duration(milliseconds: 20));
    expect(batches, isEmpty);
    batch.addAll([2]);
    await tester.pump(const Duration(milliseconds: 16));
    expect(batches, [
      [2],
    ]);
    batch.cancel();
  });

  testWidgets('a new commit during refresh is retained for the next frame', (
    tester,
  ) async {
    final batches = <List<int>>[];
    late LiveRefreshBatch<int> batch;
    batch = LiveRefreshBatch<int>((ready) {
      batches.add(ready);
      if (batches.length == 1) batch.addAll([2]);
    });
    batch.addAll([1]);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(batches, [
      [1],
      [2],
    ]);
    batch.cancel();
  });
}
