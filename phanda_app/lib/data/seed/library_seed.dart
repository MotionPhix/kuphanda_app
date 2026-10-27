import '../models/document.dart';
import '../models/subject.dart';
import 'curriculum_seed.dart';

/// The bundled catalogue.
///
/// This is the merge point of the two reference products: Kuphanda's document
/// catalogue (papers, marking schemes, books, syllabi, categories) and Geli's
/// curriculum tree (topic guides with objectives and key ideas). Documents that
/// come from the Geli seed keep their original titles and copy.
///
/// Important: catalogue records are metadata, not the files themselves. Only
/// the two Kuphanda guides ship with a PDF; every other record must have its
/// official file attached by the learner or the school. This keeps the app
/// honest about copyright and lets it work without a backend.
List<Document> buildCatalogue({DateTime? now}) {
  final today = now ?? DateTime.now();
  final documents = <Document>[];

  Document add(Document document) {
    documents.add(document);
    return document;
  }

  int stamp(int index) => index % 120;

  // ---------------------------------------------------------------------------
  // 1. Documents carried over from the Geli catalogue.
  // ---------------------------------------------------------------------------
  final references = <Document>[
    Document(
      id: 'ref-msce-biology-2023-paper2',
      title: 'MSCE Biology 2023 — Paper 2 with worked solutions',
      subjectId: 'biology',
      form: 4,
      kind: DocumentKind.pastPaper,
      description:
          'Complete Paper 2 with structured answers and examiner-style commentary for every '
          'question. Section A covers cell biology; later sections cover genetics, ecology and '
          'human systems.',
      pages: 24,
      year: 2023,
      paperNumber: 2,
      session: 'November',
      totalMarks: 100,
      durationMinutes: 150,
      rating: 4.8,
      ratingCount: 312,
      featured: true,
      addedAt: _fixed(2026, 9, 12),
      author: 'Geli Editors',
      publisher: 'Kuphanda Library',
      tags: ['worked solutions', 'paper 2'],
    ),
    Document(
      id: 'ref-jce-mathematics-toolkit',
      title: 'JCE Mathematics — full toolkit',
      subjectId: 'mathematics',
      form: 2,
      kind: DocumentKind.notes,
      description:
          'Every JCE topic distilled into one workbook: number, algebra, geometry and statistics, '
          'with 300 practice problems and worked answers.',
      pages: 96,
      rating: 4.7,
      ratingCount: 188,
      featured: true,
      addedAt: _fixed(2026, 9, 20),
      author: 'T. Banda',
      tags: ['workbook', 'practice'],
    ),
    Document(
      id: 'ref-msce-chemistry-organic',
      title: 'MSCE Chemistry — Organic chemistry masterclass',
      subjectId: 'chemistry',
      form: 4,
      kind: DocumentKind.guide,
      description:
          'Alkanes to esters, IUPAC naming and every reaction pathway you need for Paper 2, with '
          'the general formulas examiners award marks for.',
      pages: 58,
      accessTier: AccessTier.weekly,
      rating: 4.6,
      ratingCount: 94,
      addedAt: _fixed(2026, 8, 30),
      author: 'Dr. C. Phiri',
      tags: ['organic chemistry', 'paper 2'],
    ),
    Document(
      id: 'ref-msce-physics-mechanics',
      title: 'MSCE Physics — Mechanics workbook',
      subjectId: 'physics',
      form: 4,
      kind: DocumentKind.notes,
      description:
          'Vectors, motion, forces and momentum. Every worked example is a real MANEB-style '
          'question, with the marking points called out.',
      pages: 72,
      accessTier: AccessTier.daily,
      rating: 4.5,
      ratingCount: 76,
      addedAt: _fixed(2026, 9, 2),
      author: 'E. Mwale',
      tags: ['mechanics', 'workbook'],
    ),
    Document(
      id: 'ref-chichewa-ndakatulo',
      title: 'Chichewa — Ndakatulo essay technique',
      subjectId: 'chichewa',
      form: 4,
      kind: DocumentKind.guide,
      description:
          'How to unpack any ndakatulo in under eight minutes, with three fully worked essays and '
          'a vocabulary bank for Paper 2.',
      pages: 32,
      rating: 4.9,
      ratingCount: 141,
      featured: true,
      addedAt: _fixed(2026, 9, 24),
      author: 'M. Nyirenda',
      language: 'Chichewa',
      tags: ['ndakatulo', 'essay'],
    ),
    Document(
      id: 'ref-msce-geography-mapwork',
      title: 'MSCE Geography — Map-work drills',
      subjectId: 'geography',
      form: 4,
      kind: DocumentKind.notes,
      description:
          'Bearings, scales, cross-sections and relief: forty pages of nothing but map-work '
          'practice, with a mark scheme for each drill.',
      pages: 40,
      rating: 4.4,
      ratingCount: 63,
      addedAt: _fixed(2026, 8, 22),
      author: 'Geli Editors',
      tags: ['map work', 'drills'],
    ),
    Document(
      id: 'ref-agriculture-livestock',
      title: 'Agriculture — Livestock production',
      subjectId: 'agriculture',
      form: 4,
      kind: DocumentKind.guide,
      description:
          'Housing, feeding and disease control for cattle, goats and poultry, covering every '
          'syllabus point and the seven diseases that repeat in exams.',
      pages: 44,
      accessTier: AccessTier.weekly,
      rating: 4.3,
      ratingCount: 51,
      addedAt: _fixed(2026, 9, 6),
      author: 'R. Kachale',
      tags: ['livestock', 'disease'],
    ),
  ];
  documents.addAll(references);

  // ---------------------------------------------------------------------------
  // 2. Study guides generated from the Geli curriculum graph.
  // ---------------------------------------------------------------------------
  for (var index = 0; index < kStudyGuides.length; index++) {
    final guide = kStudyGuides[index];
    final subject = subjectById(guide.subjectId);
    final sectionWords = guide.sections.map((section) => section.title).take(4).join(', ');
    add(
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
        addedAt: today.subtract(Duration(days: 4 + stamp(index))),
        author: 'Kuphanda Curriculum Team',
        guideId: guide.id,
        tags: ['study guide', subject.shortName.toLowerCase()],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Form-by-form study notes for every subject taught in that form.
  // ---------------------------------------------------------------------------
  var noteIndex = 0;
  for (final subject in kSubjects) {
    for (final form in subject.forms) {
      final qualification = Subject.qualificationForForm(form);
      add(
        Document(
          id: 'notes-${subject.id}-f$form',
          title: '${subject.name} — Form $form study notes',
          subjectId: subject.id,
          form: form,
          kind: DocumentKind.notes,
          description:
              '${subject.blurb} Organised term by term for the $qualification syllabus, with '
              'worked examples and end-of-topic questions.',
          pages: 28 + ((noteIndex * 7) % 42),
          rating: 4.2 + ((noteIndex % 6) * 0.1),
          ratingCount: 8 + ((noteIndex * 13) % 70),
          addedAt: today.subtract(Duration(days: 6 + stamp(noteIndex))),
          author: 'Kuphanda Library',
          tags: ['notes', 'form $form'],
        ),
      );
      noteIndex++;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Syllabi — one per subject, at the form that sits the national exam.
  // ---------------------------------------------------------------------------
  for (var index = 0; index < kSubjects.length; index++) {
    final subject = kSubjects[index];
    final form = subject.forms.contains(4) ? 4 : 2;
    add(
      Document(
        id: 'syllabus-${subject.id}',
        title: '${Subject.qualificationForForm(form)} ${subject.name} syllabus',
        subjectId: subject.id,
        form: form,
        kind: DocumentKind.syllabus,
        description:
            'The examinable syllabus: topics, learning outcomes and suggested time allocation. '
            'Use it to check that your revision covers every objective.',
        pages: 18 + (index % 12),
        accessTier: AccessTier.free,
        rating: 4.6,
        ratingCount: 30 + index,
        addedAt: today.subtract(Duration(days: 20 + index)),
        author: 'Malawi curriculum reference',
        tags: ['syllabus'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Past papers, JCE (Form 2) and MSCE (Form 4).
  // ---------------------------------------------------------------------------
  const jceSubjects = <String>[
    'mathematics',
    'english',
    'chichewa',
    'geography',
    'history',
    'agriculture',
    'physical-science',
  ];
  const msceSubjects = <String>[
    'mathematics',
    'biology',
    'chemistry',
    'physics',
    'english',
    'chichewa',
    'geography',
    'history',
    'agriculture',
    'computer-studies',
    'business-studies',
  ];

  var paperIndex = 0;
  void addPaper({
    required Subject subject,
    required int form,
    required int year,
    required int paper,
    required String session,
  }) {
    final qualification = Subject.qualificationForForm(form);
    final id = 'paper-${qualification.toLowerCase()}-${subject.id}-$year-p$paper';
    if (documents.any((document) => document.id == id)) return;

    final isRecent = year >= 2023;
    final premium = isRecent && paper == 2 && paperIndex % 3 == 0;
    add(
      Document(
        id: id,
        title: '$qualification ${subject.name} $year — Paper $paper',
        subjectId: subject.id,
        form: form,
        kind: DocumentKind.pastPaper,
        description:
            '$qualification ${subject.name}, $session $year, Paper $paper. Attach the official '
            'question paper to work through it under timed conditions, then mark it with the '
            'matching scheme.',
        pages: 16 + ((paperIndex * 5) % 24),
        year: year,
        paperNumber: paper,
        session: session,
        totalMarks: paper == 1 ? 80 : 100,
        durationMinutes: paper == 1 ? 120 : 150,
        accessTier: premium ? AccessTier.weekly : AccessTier.free,
        rating: 4.3 + ((paperIndex % 5) * 0.1),
        ratingCount: 14 + ((paperIndex * 11) % 80),
        addedAt: today.subtract(Duration(days: 12 + stamp(paperIndex))),
        author: 'MANEB past paper',
        publisher: 'Malawi National Examinations Board',
        tags: ['past paper', '$year', 'paper $paper'],
      ),
    );
    paperIndex++;
  }

  for (final subjectId in jceSubjects) {
    final subject = subjectById(subjectId);
    for (final year in <int>[2022, 2023, 2024]) {
      addPaper(subject: subject, form: 2, year: year, paper: 1, session: 'June');
    }
  }

  for (final subjectId in msceSubjects) {
    final subject = subjectById(subjectId);
    for (final year in <int>[2022, 2023, 2024]) {
      addPaper(subject: subject, form: 4, year: year, paper: 1, session: 'June');
      addPaper(subject: subject, form: 4, year: year, paper: 2, session: 'November');
    }
  }

  // A handful of marking schemes, deliberately premium in the free tier.
  for (final subjectId in <String>['mathematics', 'biology', 'chemistry', 'physics']) {
    final subject = subjectById(subjectId);
    add(
      Document(
        id: 'scheme-msce-${subject.id}-2024-p2',
        title: 'MSCE ${subject.name} 2024 — Paper 2 marking scheme',
        subjectId: subject.id,
        form: 4,
        kind: DocumentKind.markingScheme,
        description:
            'Official-style marking scheme for the 2024 Paper 2, showing where method marks are '
            'awarded and the common answers that lose the final mark.',
        pages: 10,
        year: 2024,
        paperNumber: 2,
        session: 'November',
        accessTier: AccessTier.monthly,
        rating: 4.7,
        ratingCount: 22,
        addedAt: today.subtract(const Duration(days: 9)),
        author: 'MANEB past paper',
        tags: ['marking scheme', 'paper 2'],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. The two documents that ship with a real PDF.
  // ---------------------------------------------------------------------------
  add(
    Document(
      id: 'sample-howto',
      title: 'How to use Kuphanda',
      subjectId: 'english',
      form: 1,
      kind: DocumentKind.guide,
      description:
          'A short guide to finding documents, attaching PDFs, keeping notes and working offline. '
          'Ships with the app and is readable immediately.',
      pages: 2,
      rating: 4.9,
      ratingCount: 12,
      addedAt: today.subtract(const Duration(days: 30)),
      author: 'Kuphanda',
      tags: ['getting started'],
    ),
  );
  add(
    Document(
      id: 'sample-planner',
      title: 'Weekly study planner',
      subjectId: 'mathematics',
      form: 4,
      kind: DocumentKind.other,
      description:
          'A printable week plan with a 40-minute study block, marking routine and weekly review '
          'questions. Copy it into your exercise book or write on the PDF.',
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
    addedAt: _fixed(2026, 9, 1),
    assetPath: 'assets/samples/kuphanda-quick-start.pdf',
    pageCount: 2,
  ),
  DocumentAsset(
    documentId: 'sample-planner',
    fileName: 'weekly-study-planner.pdf',
    sizeBytes: 2460,
    addedAt: _fixed(2026, 9, 1),
    assetPath: 'assets/samples/weekly-study-planner.pdf',
    pageCount: 2,
  ),
];

DateTime _fixed(int year, int month, int day) => DateTime(year, month, day);

