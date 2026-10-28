import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/library_query.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/subject.dart';

Document _document({
  required String id,
  required AccessTier tier,
}) {
  return Document(
    id: id,
    title: 'Document $id',
    subjectId: 'mathematics',
    form: 4,
    kind: DocumentKind.notes,
    description: '',
    pages: 10,
    accessTier: tier,
    addedAt: DateTime(2026),
  );
}

LibraryEntry _entry(Document document, {bool entitled = true}) {
  return LibraryEntry(
    document: document,
    subject: subjectById(document.subjectId),
    locked: !entitled,
    priceMwk: document.accessTier == AccessTier.free ? 0 : 1500,
  );
}

void main() {
  test('filters to free documents only', () {
    final entries = [
      _entry(_document(id: 'free', tier: AccessTier.free)),
      _entry(_document(id: 'paid', tier: AccessTier.weekly)),
    ];

    final results = const LibraryQuery(access: AccessFilter.free).apply(entries);

    expect(results.map((entry) => entry.document.id), ['free']);
  });

  test('filters to premium documents only', () {
    final entries = [
      _entry(_document(id: 'free', tier: AccessTier.free)),
      _entry(_document(id: 'paid', tier: AccessTier.weekly)),
      _entry(_document(id: 'daily', tier: AccessTier.daily)),
    ];

    final results = const LibraryQuery(access: AccessFilter.premium).apply(entries);

    expect(results.map((entry) => entry.document.id), unorderedEquals(['paid', 'daily']));
  });

  test('access filter counts toward active filters and clears', () {
    const query = LibraryQuery(access: AccessFilter.premium);

    expect(query.hasFilters, isTrue);
    expect(query.activeFilterCount, 1);
    expect(query.cleared().access, AccessFilter.all);
  });
}
