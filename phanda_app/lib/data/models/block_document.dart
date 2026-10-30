import 'dart:convert';

/// One structural unit of a reflowable document.
///
/// The block keeps its raw map so a document produced by a newer schema can
/// still be opened by an older build: unknown fields are ignored and unknown
/// types render as a link to the original page instead of throwing.
class DocumentBlock {
  const DocumentBlock({
    required this.type,
    required this.raw,
    this.page,
  });

  /// `heading`, `paragraph`, `bullets`, `callout`, `figure`, `table`,
  /// `question`, `divider`, `answer`.
  final String type;

  /// 1-based page in the source PDF, used to fall back to the original scan.
  final int? page;

  final Map<String, Object?> raw;

  String get text => (raw['text'] as String? ?? '').trim();

  String? get label => raw['label'] as String?;

  /// Extra material under a question, e.g. `[{"label":"(a)","text":"..."}]`.
  List<DocumentBlock> get parts {
    final parts = raw['parts'];
    if (parts is! List) return const <DocumentBlock>[];
    return parts
        .whereType<Map<Object?, Object?>>()
        .map((part) => DocumentBlock.fromJson(
              part.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  /// Bullet or numbered items.
  List<String> get items {
    final items = raw['items'];
    if (items is! List) return const <String>[];
    return items.map((item) => '$item').toList();
  }

  /// Table rows, each a list of cells.
  List<List<String>> get rows {
    final rows = raw['rows'];
    if (rows is! List) return const <List<String>>[];
    return rows
        .whereType<List<Object?>>()
        .map((row) => row.map((cell) => '$cell').toList())
        .toList();
  }

  Map<String, Object?> get figure =>
      (raw['figure'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
          .map((key, value) => MapEntry(key.toString(), value));

  int? get marks => (raw['marks'] as num?)?.toInt();

  int? get difficulty => (raw['difficulty'] as num?)?.toInt();

  factory DocumentBlock.fromJson(Map<String, Object?> json) {
    final page = json['page'];
    return DocumentBlock(
      type: json['type'] as String? ?? 'paragraph',
      page: page is num ? page.toInt() : int.tryParse('$page'),
      raw: json,
    );
  }
}

/// A whole document as blocks, optionally with the source PDF as a fallback.
class BlockDocument {
  const BlockDocument({
    required this.title,
    this.subtitle,
    this.sourceAsset,
    this.blocks = const <DocumentBlock>[],
  });

  final String title;
  final String? subtitle;

  /// Original PDF, so a learner can always check the source page.
  final String? sourceAsset;

  final List<DocumentBlock> blocks;

  /// Round-trips through [fromMap]. Used to keep a copy on disk so a paper stays
  /// readable without a connection; the payload is written unchanged, because
  /// anything dropped here is content the learner loses offline.
  Map<String, Object?> toMap() => <String, Object?>{
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (sourceAsset != null) 'source_asset': sourceAsset,
        'blocks': blocks.map((block) => block.raw).toList(),
      };

  factory BlockDocument.fromMap(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];

    return BlockDocument(
      title: json['title'] as String? ?? 'Untitled',
      subtitle: json['subtitle'] as String?,
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map<Object?, Object?>>()
              .map((block) => DocumentBlock.fromJson(
                    block.map((key, value) => MapEntry(key.toString(), value)),
                  ))
              .toList()
          : const <DocumentBlock>[],
    );
  }

  factory BlockDocument.fromJsonString(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('A block document must be a JSON object.');
    }

    final json = decoded.map((key, value) => MapEntry(key.toString(), value));
    final rawBlocks = json['blocks'];

    return BlockDocument(
      title: json['title'] as String? ?? 'Untitled',
      subtitle: json['subtitle'] as String?,
      sourceAsset: json['source_asset'] as String?,
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map<Object?, Object?>>()
              .map((block) => DocumentBlock.fromJson(
                    block.map((key, value) => MapEntry(key.toString(), value)),
                  ))
              .toList()
          : const <DocumentBlock>[],
    );
  }
}
