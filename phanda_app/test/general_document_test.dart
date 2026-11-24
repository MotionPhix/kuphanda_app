import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/library_query.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/subject.dart';

Document _document({
  required String id,
  required int form,
  DocumentKind kind = DocumentKind.pastPaper,
}) {
  return Document(
    id: id,
    title: 'Document $id',
    subjectId: 'mathematics',
    form: form,
    kind: kind,
    description: '',
    pages: 10,
    addedAt: DateTime(2026),
  );
}

LibraryEntry _entry(Document document) => LibraryEntry(
      document: document,
      subject: subjectById(document.subjectId),
      locked: false,
      priceMwk: 0,
    );

void main() {
  test('a document for everyone is labelled all forms, not Form 1', () {
    // The how-to guide was filed under Form 1 in the original catalogue, so it
    // read as a Form 1 guide for a Form 4 learner opening it on day one.
    final guide = _document(
      id: 'sample-howto',
      form: Document.allForms,
      kind: DocumentKind.guide,
    );

    expect(guide.appliesToAllForms, isTrue);
    expect(guide.formLabel, 'All forms');
    expect(guide.formBadge, 'ALL');

    // "Form 1 · JCE" was the wrong claim in two ways: the form, and an exam
    // body the guide does not belong to.
    expect(guide.qualification, 'General');
  });

  test('a real paper still reads as its own form', () {
    final paper = _document(id: 'ref-msce-maths-2002-p1', form: 4);

    expect(paper.appliesToAllForms, isFalse);
    expect(paper.formLabel, 'Form 4');
    expect(paper.formBadge, 'F4');
    expect(paper.qualification, 'MSCE');
  });

  test('filtering by a form keeps the general document', () {
    final entries = [
      _entry(_document(id: 'form1', form: 1)),
      _entry(_document(id: 'form4', form: 4)),
      _entry(_document(
        id: 'sample-howto',
        form: Document.allForms,
        kind: DocumentKind.guide,
      )),
    ];

    final results = const LibraryQuery(forms: {4}).apply(entries);

    // The guide is not a Form 4 paper, but it is not excluded by a Form 4
    // filter either: it was written for whoever is reading.
    expect(
      results.map((entry) => entry.document.id),
      unorderedEquals(['sample-howto', 'form4']),
    );
  });

  test('a form filter still excludes other forms', () {
    final entries = [
      _entry(_document(id: 'form1', form: 1)),
      _entry(_document(id: 'form4', form: 4)),
    ];

    final results = const LibraryQuery(forms: {4}).apply(entries);

    expect(results.map((entry) => entry.document.id), ['form4']);
  });
}
