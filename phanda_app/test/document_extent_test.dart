import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/document.dart';

Document _paper({
  bool hasBlocks = true,
  int? questions = 24,
  int? blockMarks = 100,
  int? totalMarks,
  int pages = 6,
}) =>
    Document(
      id: 'ref-msce-maths-2002-p1',
      title: 'Mathematics Paper I',
      subjectId: 'mathematics',
      form: 4,
      kind: DocumentKind.pastPaper,
      description: '',
      pages: pages,
      addedAt: DateTime(2026),
      hasBlocks: hasBlocks,
      format: hasBlocks ? 'blocks' : 'pdf',
      questionCount: questions,
      blockMarks: blockMarks,
      totalMarks: totalMarks,
    );

void main() {
  test('a structured paper is described by questions and marks', () {
    expect(_paper().extentLabel, '24 questions · 100 marks');
  });

  test('a declared total wins over the counted one', () {
    expect(_paper(totalMarks: 100, blockMarks: 98).extentLabel, '24 questions · 100 marks');
  });

  test('a paper with no marks still reports its questions', () {
    expect(_paper(blockMarks: null).extentLabel, '24 questions');
  });

  test('a PDF is still described by pages', () {
    expect(_paper(hasBlocks: false, questions: null, blockMarks: null).extentLabel, '6 pages');
  });

  test('a cached structured paper stays structured when reloaded', () {
    // toJson wrote `hasBlocks` while fromJson read `has_blocks`, so every
    // cached paper came back as an unreadable PDF record after a restart.
    final restored = Document.fromJson(_paper().toJson());

    expect(restored.hasBlocks, isTrue);
    expect(restored.format, 'blocks');
    expect(restored.questionCount, 24);
    expect(restored.blockMarks, 100);
    expect(restored.extentLabel, '24 questions · 100 marks');
  });

  test('a cached document written in snake case still loads', () {
    final restored = Document.fromJson(<String, Object?>{
      'id': 'x',
      'title': 't',
      'subjectId': 'mathematics',
      'form': 4,
      'kind': 'pastPaper',
      'has_blocks': true,
    });

    expect(restored.hasBlocks, isTrue);
  });
}
