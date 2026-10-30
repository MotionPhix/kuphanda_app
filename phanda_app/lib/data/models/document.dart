import 'package:flutter/material.dart';

import 'subject.dart';

/// What a document *is*, independent of the form or qualification it serves.
///
/// This mirrors Kuphanda's `ResourceKind` redesign: format and qualification
/// used to be fused into one lookup table, which made every new combination a
/// new row. Here [DocumentKind] carries the format and [Document.form] carries
/// the level.
enum DocumentKind {
  pastPaper('Past paper', 'Past papers', Icons.assignment_outlined),
  markingScheme('Marking scheme', 'Marking schemes', Icons.fact_check_outlined),
  textbook('Textbook', 'Textbooks', Icons.menu_book_outlined),
  notes('Study notes', 'Study notes', Icons.sticky_note_2_outlined),
  syllabus('Syllabus', 'Syllabi', Icons.rule_folder_outlined),
  studyGuide('Study guide', 'Study guides', Icons.auto_stories_outlined),
  guide('Guide', 'Guides', Icons.lightbulb_outline),
  other('Document', 'Documents', Icons.description_outlined);

  const DocumentKind(this.label, this.pluralLabel, this.icon);

  final String label;
  final String pluralLabel;
  final IconData icon;
}

/// Entitlement tier, ranked exactly like Kuphanda's `PlanTier`.
enum AccessTier {
  free('Free', 0),
  daily('Day pass', 1),
  weekly('Weekly pass', 2),
  monthly('Monthly', 3),
  school('School licence', 4);

  const AccessTier(this.label, this.rank);

  final String label;
  final int rank;

  bool isCoveredBy(AccessTier plan) => plan.rank >= rank;

  static AccessTier fromName(String? name) => AccessTier.values.firstWhere(
        (tier) => tier.name == name,
        orElse: () => AccessTier.free,
      );
}

class Document {
  const Document({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.form,
    required this.kind,
    required this.description,
    required this.pages,
    required this.addedAt,
    this.author = 'Kuphanda Library',
    this.publisher,
    this.year,
    this.paperNumber,
    this.session,
    this.totalMarks,
    this.durationMinutes,
    this.accessTier = AccessTier.free,
    this.rating = 0,
    this.ratingCount = 0,
    this.featured = false,
    this.guideId,
    this.language = 'English',
    this.tags = const <String>[],
    this.personal = false,
    this.format = 'pdf',
    this.hasBlocks = false,
    this.questionCount,
    this.blockMarks,
  });

  final String id;
  final String title;
  final String subjectId;

  /// 1–4. Forms 1–2 are junior (JCE), Forms 3–4 senior (MSCE).
  final int form;
  final DocumentKind kind;
  final String description;
  final int pages;
  final DateTime addedAt;
  final String author;
  final String? publisher;
  final int? year;
  final int? paperNumber;

  /// `June` or `November`, the two MANEB sitting windows.
  final String? session;
  final int? totalMarks;
  final int? durationMinutes;
  final AccessTier accessTier;
  final double rating;
  final int ratingCount;
  final bool featured;

  /// Links a study-guide document to its topic in the curriculum tree.
  final String? guideId;
  final String language;
  final List<String> tags;

  /// True for documents the learner imported themselves.
  final bool personal;

  /// Questions and marks counted from the blocks themselves. A structured paper
  /// has no meaningful page count — `pages` describes the scan it was built
  /// from — so these are what the library and detail screens show instead.
  final int? questionCount;
  final int? blockMarks;

  /// Marks to quote: the declared total when the record has one, otherwise the
  /// sum counted from the blocks.
  int? get displayMarks => totalMarks ?? (hasBlocks ? blockMarks : null);

  /// How much there is to do, in the units a learner counts in.
  ///
  /// `pages` is an import artefact — the maths paper claims six pages while
  /// holding twenty-four questions — so a structured paper is described by its
  /// questions and marks instead.
  String get extentLabel {
    final questions = questionCount;
    if (hasBlocks && questions != null && questions > 0) {
      final marks = displayMarks;
      return marks == null ? '$questions questions' : '$questions questions · $marks marks';
    }
    return '$pages pages';
  }

  /// `pdf`, `blocks` or `hybrid`. Only the latter two can reflow.
  final String format;

  /// Whether the API holds a structured version of this document.
  final bool hasBlocks;

  String get qualification => Subject.qualificationForForm(form);

  String get examLabel {
    if (kind != DocumentKind.pastPaper && kind != DocumentKind.markingScheme) {
      return kind.label;
    }
    final parts = <String>[qualification];
    if (year != null) parts.add('$year');
    if (paperNumber != null) parts.add('Paper $paperNumber');
    return parts.join(' · ');
  }

  Document copyWith({
    String? title,
    String? subjectId,
    int? form,
    DocumentKind? kind,
    String? description,
    int? pages,
    String? author,
    AccessTier? accessTier,
  }) {
    return Document(
      id: id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      form: form ?? this.form,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      pages: pages ?? this.pages,
      addedAt: addedAt,
      author: author ?? this.author,
      publisher: publisher,
      year: year,
      paperNumber: paperNumber,
      session: session,
      totalMarks: totalMarks,
      durationMinutes: durationMinutes,
      accessTier: accessTier ?? this.accessTier,
      rating: rating,
      ratingCount: ratingCount,
      featured: featured,
      guideId: guideId,
      language: language,
      tags: tags,
      personal: personal,
      format: format,
      hasBlocks: hasBlocks,
      questionCount: questionCount,
      blockMarks: blockMarks,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'subjectId': subjectId,
        'form': form,
        'kind': kind.name,
        'description': description,
        'pages': pages,
        'addedAt': addedAt.toIso8601String(),
        'author': author,
        'publisher': publisher,
        'year': year,
        'paperNumber': paperNumber,
        'session': session,
        'totalMarks': totalMarks,
        'durationMinutes': durationMinutes,
        'accessTier': accessTier.name,
        'rating': rating,
        'ratingCount': ratingCount,
        'featured': featured,
        'guideId': guideId,
        'language': language,
        'tags': tags,
        'personal': personal,
        // Cached copies need these too, otherwise a stored document reverts to
        // pdf + hasBlocks=false and a structured paper looks unreadable until
        // the next successful sync.
        'format': format,
        'hasBlocks': hasBlocks,
        'questionCount': questionCount,
        'blockMarks': blockMarks,
      };

  static Document fromJson(Map<String, Object?> json) {
    return Document(
      id: json['id']! as String,
      title: json['title']! as String,
      subjectId: json['subjectId']! as String,
      form: (json['form'] as num).toInt(),
      kind: DocumentKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => DocumentKind.other,
      ),
      description: (json['description'] as String?) ?? '',
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime(2025),
      author: (json['author'] as String?) ?? 'Kuphanda Library',
      publisher: json['publisher'] as String?,
      year: (json['year'] as num?)?.toInt(),
      paperNumber: (json['paperNumber'] as num?)?.toInt(),
      session: json['session'] as String?,
      totalMarks: (json['totalMarks'] as num?)?.toInt(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      accessTier: AccessTier.fromName(json['accessTier'] as String?),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      featured: json['featured'] as bool? ?? false,
      guideId: json['guideId'] as String?,
      language: (json['language'] as String?) ?? 'English',
      tags: (json['tags'] as List<Object?>?)?.map((tag) => tag.toString()).toList() ??
          const <String>[],
      personal: json['personal'] as bool? ?? false,
      format: json['format'] as String? ?? 'pdf',
      // toJson has always written `hasBlocks`; this read `has_blocks`, so every
      // cached structured paper reloaded as an unreadable PDF record.
      hasBlocks: (json['hasBlocks'] as bool?) ?? (json['has_blocks'] as bool?) ?? false,
      questionCount: (json['questionCount'] as num?)?.toInt(),
      blockMarks: (json['blockMarks'] as num?)?.toInt(),
    );
  }
}

/// A file stored on the device for a [Document].
///
/// [assetPath] is used for the two documents that ship with the app; [path] is
/// used for PDFs the learner imported, which live in the app's documents
/// directory.
class DocumentAsset {
  const DocumentAsset({
    required this.documentId,
    required this.fileName,
    required this.sizeBytes,
    required this.addedAt,
    this.path,
    this.assetPath,
    this.pageCount,
    this.version = 1,
    this.checksum,
    this.remote = false,
  });

  final String documentId;
  final String fileName;
  final int sizeBytes;
  final DateTime addedAt;
  final String? path;
  final String? assetPath;
  final int? pageCount;

  /// Version published by the library API. Bundled and imported files are
  /// version 1; server downloads carry the server's version number.
  final int version;

  /// SHA-256 of the stored bytes, used to verify a download before it replaces
  /// a working copy.
  final String? checksum;

  /// True when the file came from the API and can be refreshed or removed by
  /// sync. Bundled and imported files are never touched by sync.
  final bool remote;

  bool get isBundled => assetPath != null;

  DocumentAsset copyWith({
    String? fileName,
    String? path,
    int? pageCount,
    int? version,
    String? checksum,
    bool? remote,
  }) {
    return DocumentAsset(
      documentId: documentId,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes,
      addedAt: addedAt,
      path: path ?? this.path,
      assetPath: assetPath,
      pageCount: pageCount ?? this.pageCount,
      version: version ?? this.version,
      checksum: checksum ?? this.checksum,
      remote: remote ?? this.remote,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'documentId': documentId,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'path': path,
        'assetPath': assetPath,
        'pageCount': pageCount,
        'version': version,
        'checksum': checksum,
        'remote': remote,
      };

  static DocumentAsset fromJson(Map<String, Object?> json) {
    return DocumentAsset(
      documentId: json['documentId']! as String,
      fileName: (json['fileName'] as String?) ?? 'document.pdf',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime(2025),
      path: json['path'] as String?,
      assetPath: json['assetPath'] as String?,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      checksum: json['checksum'] as String?,
      remote: json['remote'] as bool? ?? false,
    );
  }
}

/// A document joined with the learner's local state, used by every list view.
class LibraryEntry {
  const LibraryEntry({
    required this.document,
    required this.subject,
    this.asset,
    this.progressPercent = 0,
    this.saved = false,
    this.locked = false,
    this.rating,
    this.priceMwk = 0,
    this.hasRemoteFile = false,
  });

  final Document document;
  final Subject subject;
  final DocumentAsset? asset;

  /// 0–100.
  final double progressPercent;
  final bool saved;
  final bool locked;

  /// The learner's own rating, when they have given one.
  final int? rating;

  /// Single-document price in MWK from the server; zero means free or
  /// subscription-only.
  final int priceMwk;

  /// True when the library API holds a file for this document, so it can be
  /// downloaded rather than expecting the learner to attach one.
  final bool hasRemoteFile;

  bool get onDevice => asset != null;
  bool get hasFile => asset != null || document.guideId != null;
  bool get started => progressPercent > 0;
}
