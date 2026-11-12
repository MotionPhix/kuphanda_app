import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/sync/offline_budget.dart';

const int mb = 1024 * 1024;

DocumentAsset copied(String id, int bytes, DateTime savedAt) => DocumentAsset(
      documentId: id,
      fileName: '$id.pdf',
      sizeBytes: bytes,
      addedAt: savedAt,
      remote: true,
    );

void main() {
  final now = DateTime(2026, 11, 12, 9);

  test('keeps everything when the new copy still fits', () {
    final evicted = OfflineBudget.chooseEvictions(
      assets: [copied('a', 10 * mb, now.subtract(const Duration(days: 9)))],
      incomingBytes: 5 * mb,
      lastTouched: (asset) => asset.addedAt,
      budget: 50 * mb,
    );

    expect(evicted, isEmpty);
  });

  test('drops the least recently read copies until the new one fits', () {
    final oldest = copied('oldest', 10 * mb, now.subtract(const Duration(days: 30)));
    final middle = copied('middle', 10 * mb, now.subtract(const Duration(days: 10)));
    final newest = copied('newest', 5 * mb, now.subtract(const Duration(days: 1)));

    // Recency is supplied separately from saved date on purpose: this is the
    // "downloaded long ago, opened yesterday" case that must survive.
    final touched = <String, DateTime>{
      'oldest': now.subtract(const Duration(days: 40)),
      'middle': now.subtract(const Duration(hours: 1)),
      'newest': now.subtract(const Duration(days: 2)),
    };

    final evicted = OfflineBudget.chooseEvictions(
      assets: [middle, oldest, newest],
      incomingBytes: 20 * mb,
      lastTouched: (asset) => touched[asset.documentId]!,
      budget: 30 * mb,
    );

    // 25 MB held + 20 MB incoming = 45 MB. Dropping the two least recently read
    // (oldest 10, newest 5) leaves exactly 10 MB + 20 MB.
    expect(evicted.map((asset) => asset.documentId), ['oldest', 'newest']);
  });

  test('a copy larger than the whole budget is refused, not paid for by wiping everything', () {
    expect(
      () => OfflineBudget.chooseEvictions(
        assets: [copied('a', 10 * mb, now)],
        incomingBytes: 51 * mb,
        lastTouched: (asset) => asset.addedAt,
        budget: 50 * mb,
      ),
      throwsA(isA<OfflineBudgetExceeded>()),
    );
  });

  test('the default budget is 50 MB', () {
    expect(OfflineBudget.defaultBudgetBytes, 50 * mb);
  });
}
