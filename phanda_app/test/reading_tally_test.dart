import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/reading.dart';
import 'package:kuphanda/data/models/reading_tally.dart';

Document _paper({int? questions = 24, bool structured = true, int pages = 6}) => Document(
      id: 'paper',
      title: 'Paper I',
      subjectId: 'mathematics',
      form: 4,
      kind: DocumentKind.pastPaper,
      description: '',
      pages: pages,
      addedAt: DateTime(2026),
      hasBlocks: structured,
      format: structured ? 'blocks' : 'pdf',
      questionCount: questions,
    );

Document _pdf({int pages = 12}) => Document(
      id: 'pdf',
      title: 'Scan',
      subjectId: 'biology',
      form: 4,
      kind: DocumentKind.pastPaper,
      description: '',
      pages: pages,
      addedAt: DateTime(2026),
    );

void main() {
  test('a structured paper is counted in questions, not its fabricated page', () {
    final tally = tallyReading(
      [_paper()],
      {
        'paper': const ReadingProgress(
          documentId: 'paper',
          currentPage: 1,
          totalPages: 1,
          fraction: 0.82,
        ),
      },
    );

    expect(tally.measuredInQuestions, isTrue);
    expect(tally.questions, 20); // 82% of 24 questions
    expect(tally.papers, 1);
    expect(tally.pages, 0);
  });

  test('a PDF is still counted in pages', () {
    final tally = tallyReading(
      [_pdf()],
      {'pdf': const ReadingProgress(documentId: 'pdf', currentPage: 3, totalPages: 12)},
    );

    expect(tally.measuredInQuestions, isFalse);
    expect(tally.pages, 3);
  });

  test('both kinds are kept apart rather than added together', () {
    final tally = tallyReading(
      [_paper(), _pdf()],
      {
        'paper': const ReadingProgress(
          documentId: 'paper',
          currentPage: 1,
          totalPages: 1,
          fraction: 0.5,
        ),
        'pdf': const ReadingProgress(documentId: 'pdf', currentPage: 4, totalPages: 12),
      },
    );

    expect(tally.questions, 12);
    expect(tally.papers, 1);
    expect(tally.pages, 4);
    expect(tally.pdfs, 1);
  });

  test('a paper opened but not yet scrolled does not count as read', () {
    final tally = tallyReading(
      [_paper()],
      {
        'paper': const ReadingProgress(
          documentId: 'paper',
          currentPage: 1,
          totalPages: 1,
          fraction: 0,
        ),
      },
    );

    expect(tally.papers, 0);
    expect(tally.questions, 0);
  });
}
