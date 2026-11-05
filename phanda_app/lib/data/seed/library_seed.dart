import '../models/document.dart';
import '../models/subject.dart';
import 'curriculum_seed.dart';

/// The bundled catalogue — the first-run and signed-out library.
///
/// A bundled record has to be readable on the device with no server, so this
/// list contains exactly two kinds of document:
///
///  * study guides, whose sections ship in `curriculum_seed.dart` and are opened
///    by [Document.guideId], and
///  * the two guides that ship as PDF assets in `kBundledAssets`.
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

  // 2. The two documents that ship with a real PDF, mapped in `kBundledAssets`.
  documents.add(
    Document(
      id: 'sample-howto',
      title: 'How to use Kuphanda',
      subjectId: 'english',
      form: 1,
      kind: DocumentKind.guide,
      description:
          'A short guide to finding papers, subscribing, downloading for offline reading and '
          'keeping notes. Ships with the app and is readable immediately.',
      pages: 2,
      rating: 4.9,
      ratingCount: 12,
      addedAt: today.subtract(const Duration(days: 30)),
      author: 'Kuphanda',
      tags: ['getting started'],
    ),
  );
  documents.add(
    Document(
      id: 'sample-planner',
      title: 'Weekly study planner',
      subjectId: 'mathematics',
      form: 4,
      kind: DocumentKind.other,
      description:
          'A printable week plan with a 40-minute study block, a marking routine and weekly '
          'review questions. Copy it into your exercise book or write on the PDF.',
      pages: 2,
      rating: 4.8,
      ratingCount: 9,
      addedAt: today.subtract(const Duration(days: 25)),
      author: 'Kuphanda',
      tags: ['planner', 'revision'],
    ),
  );

  documents.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return documents;
}

final List<DocumentAsset> kBundledAssets = <DocumentAsset>[
  DocumentAsset(
    documentId: 'sample-howto',
    fileName: 'kuphanda-quick-start.pdf',
    sizeBytes: 2612,
    addedAt: DateTime(2026, 9, 1),
    assetPath: 'assets/samples/kuphanda-quick-start.pdf',
    pageCount: 2,
  ),
  DocumentAsset(
    documentId: 'sample-planner',
    fileName: 'weekly-study-planner.pdf',
    sizeBytes: 2460,
    addedAt: DateTime(2026, 9, 1),
    assetPath: 'assets/samples/weekly-study-planner.pdf',
    pageCount: 2,
  ),
];
