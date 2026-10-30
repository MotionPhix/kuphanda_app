import 'document.dart';
import 'reading.dart';

/// What an account has actually read, in the unit each document has.
///
/// A structured paper has questions and no pages, so the old "pages read" tile
/// summed a page number the reader invented — one page per paper, whether the
/// learner had read two questions or twenty. Splitting the two keeps each
/// number honest: questions for reflowable papers, pages for PDFs.
class ReadingTally {
  const ReadingTally({
    this.questions = 0,
    this.papers = 0,
    this.pages = 0,
    this.pdfs = 0,
  });

  /// Questions reached across measured papers, from the scroll fraction and the
  /// paper's own question count.
  final int questions;

  /// Papers that have been opened.
  final int papers;

  /// Pages reached in PDFs, where a page is a real unit.
  final int pages;

  final int pdfs;

  /// Whether there is measured reading to report in questions at all.
  bool get measuredInQuestions => papers > 0;
}

ReadingTally tallyReading(
  Iterable<Document> documents,
  Map<String, ReadingProgress> progress,
) {
  var questions = 0;
  var papers = 0;
  var pages = 0;
  var pdfs = 0;

  for (final document in documents) {
    final reading = progress[document.id];
    if (reading == null) continue;

    final fraction = reading.fraction;
    final count = document.questionCount;

    if (document.hasBlocks && fraction != null && count != null && count > 0) {
      final reached = (fraction * count).round();
      if (reached > 0) {
        questions += reached;
        papers++;
      }
      continue;
    }

    if (!document.hasBlocks && reading.currentPage > 0) {
      pages += reading.currentPage;
      pdfs++;
    }
  }

  return ReadingTally(questions: questions, papers: papers, pages: pages, pdfs: pdfs);
}
