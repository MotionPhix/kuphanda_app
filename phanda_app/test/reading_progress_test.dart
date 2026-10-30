import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/reading.dart';

void main() {
  test('measured reflowable progress survives a save and reload', () {
    const progress = ReadingProgress(
      documentId: 'ref-msce-maths-2002-p1',
      currentPage: 1,
      totalPages: 6,
      fraction: 0.85,
    );

    final restored = ReadingProgress.fromJson(progress.toJson());

    expect(restored.fraction, 0.85);
    expect(restored.percent, 85);
  });

  test('a PDF with no measured fraction still reports by page', () {
    const progress = ReadingProgress(
      documentId: 'ref-msce-agriculture-2017-p1',
      currentPage: 3,
      totalPages: 12,
    );

    final restored = ReadingProgress.fromJson(progress.toJson());

    expect(restored.fraction, isNull);
    expect(restored.percent, 25);
  });
}
