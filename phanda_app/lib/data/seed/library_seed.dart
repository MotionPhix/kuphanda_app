import '../models/document.dart';
import '../models/subject.dart';
import 'curriculum_seed.dart';

/// The bundled catalogue — the first-run and signed-out library.
///
/// A bundled record has to be readable on the device with no server, so this
/// list carries study guides only: their sections ship in `curriculum_seed.dart`
/// and are opened by [Document.guideId].
///
/// The two sample PDFs that used to ship here (the how-to guide and a planner)
/// are gone. The guide now comes from the server as a structured block document,
/// and a bundled copy meant first-run learners kept reading instructions written
/// before sign-in existed — the one document explaining the app was the only one
/// that could not reflow.
///
/// It deliberately does not carry the wider catalogue the API serves. A bundled
/// record for a paper whose file lives on the server would appear in the library
/// and then do nothing when tapped — the placeholder problem this catalogue used
/// to have, where 154 of 171 entries described documents that did not exist.
/// Once the app has synced the server catalogue it uses that instead.
List<Document> buildCatalogue({DateTime? now}) {
  final today = now ?? DateTime.now();
  final documents = <Document>[];

  // 1. Study guides. The reader opens these from the bundled curriculum graph,
  //    so they are readable offline without a file of any kind.
  for (var index = 0; index < kStudyGuides.length; index++) {
    final guide = kStudyGuides[index];
    final subject = subjectById(guide.subjectId);
    final sectionWords = guide.sections.map((section) => section.title).take(4).join(', ');

    documents.add(
      Document(
        id: 'guide-${guide.id}',
        title: '${guide.title} — MSCE study guide',
        subjectId: guide.subjectId,
        form: 4,
        kind: DocumentKind.studyGuide,
        description: '${guide.blurb} Covers $sectionWords.',
        pages: guide.pageCount,
        rating: 4.5 + ((index % 4) * 0.1),
        ratingCount: 20 + ((index * 17) % 90),
        featured: index % 5 == 0,
        addedAt: today.subtract(Duration(days: 4 + (index % 120))),
        author: 'Kuphanda Curriculum Team',
        guideId: guide.id,
        tags: ['study guide', subject.shortName.toLowerCase()],
      ),
    );
  }

  documents.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return documents;
}

final List<DocumentAsset> kBundledAssets = const <DocumentAsset>[];
