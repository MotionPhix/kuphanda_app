/// Reading telemetry and the learner's own marks on a document.
///
/// Kuphanda tracked `pages_read`, `total_pages`, `time_spent_seconds`,
/// `last_read_at` and a per-page seconds map. Geli tracked mastery and daily
/// study minutes. This app keeps the page/time record (it is what makes
/// progress real rather than a checkbox) and adds a daily activity log for
/// streaks and the weekly chart.
class ReadingProgress {
  const ReadingProgress({
    required this.documentId,
    this.currentPage = 1,
    this.totalPages = 1,
    this.secondsSpent = 0,
    this.lastReadAt,
    this.completed = false,
    this.fraction,
  });

  final String documentId;
  final int currentPage;
  final int totalPages;
  final int secondsSpent;
  final DateTime? lastReadAt;
  final bool completed;

  /// 0-1 through the document as measured by the reader, used when pages are a
  /// poor proxy: a reflowable book has one scroll, not fixed pages.
  final double? fraction;

  /// 0–100, clamped.
  double get percent {
    final measured = fraction;
    if (measured != null) return (measured * 100).clamp(0, 100).toDouble();
    if (totalPages <= 0) return 0;
    final ratio = (currentPage / totalPages) * 100;
    return ratio.clamp(0, 100).toDouble();
  }

  int get minutesSpent => (secondsSpent / 60).round();

  ReadingProgress copyWith({
    int? currentPage,
    int? totalPages,
    int? secondsSpent,
    DateTime? lastReadAt,
    bool? completed,
    double? fraction,
  }) {
    return ReadingProgress(
      documentId: documentId,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      secondsSpent: secondsSpent ?? this.secondsSpent,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      completed: completed ?? this.completed,
      fraction: fraction ?? this.fraction,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'documentId': documentId,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'secondsSpent': secondsSpent,
        'lastReadAt': lastReadAt?.toIso8601String(),
        'completed': completed,
        'fraction': fraction,
      };

  static ReadingProgress fromJson(Map<String, Object?> json) {
    return ReadingProgress(
      documentId: json['documentId']! as String,
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      secondsSpent: (json['secondsSpent'] as num?)?.toInt() ?? 0,
      lastReadAt: DateTime.tryParse(json['lastReadAt'] as String? ?? ''),
      completed: json['completed'] as bool? ?? false,
      // Written since the reader started measuring scroll, but never read back:
      // every restart silently fell back to page arithmetic, so a reflowable
      // paper reopened at whatever its page number implied.
      fraction: (json['fraction'] as num?)?.toDouble(),
    );
  }
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.documentId,
    required this.page,
    required this.createdAt,
    this.label,
  });

  final String id;
  final String documentId;
  final int page;
  final DateTime createdAt;
  final String? label;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'documentId': documentId,
        'page': page,
        'createdAt': createdAt.toIso8601String(),
        'label': label,
      };

  static Bookmark fromJson(Map<String, Object?> json) {
    return Bookmark(
      id: json['id']! as String,
      documentId: json['documentId']! as String,
      page: (json['page'] as num).toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      label: json['label'] as String?,
    );
  }
}

/// A margin note attached to a page (Kuphanda called these annotations).
class DocumentNote {
  const DocumentNote({
    required this.id,
    required this.documentId,
    required this.page,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final int page;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'documentId': documentId,
        'page': page,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  static DocumentNote fromJson(Map<String, Object?> json) {
    return DocumentNote(
      id: json['id']! as String,
      documentId: json['documentId']! as String,
      page: (json['page'] as num).toInt(),
      text: (json['text'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DocumentRating {
  const DocumentRating({required this.documentId, required this.stars, required this.createdAt});

  final String documentId;
  final int stars;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'documentId': documentId,
        'stars': stars,
        'createdAt': createdAt.toIso8601String(),
      };

  static DocumentRating fromJson(Map<String, Object?> json) {
    return DocumentRating(
      documentId: json['documentId']! as String,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// One calendar day of study, in device-local time — a streak is about the
/// learner's day, never UTC.
class StudyDay {
  const StudyDay({required this.date, required this.seconds, required this.sessions});

  /// `YYYY-MM-DD`.
  final String date;
  final int seconds;
  final int sessions;

  int get minutes => (seconds / 60).round();

  StudyDay copyWith({int? seconds, int? sessions}) =>
      StudyDay(date: date, seconds: seconds ?? this.seconds, sessions: sessions ?? this.sessions);

  Map<String, Object?> toJson() => <String, Object?>{
        'date': date,
        'seconds': seconds,
        'sessions': sessions,
      };

  static StudyDay fromJson(Map<String, Object?> json) {
    final seconds = (json['seconds'] as num?)?.toInt();
    return StudyDay(
      date: json['date']! as String,
      seconds: seconds ?? ((json['minutes'] as num?)?.toInt() ?? 0) * 60,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

