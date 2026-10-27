import 'dart:convert';

import '../models/classroom.dart';
import '../models/document.dart';
import '../models/profile.dart';
import '../models/reading.dart';

/// Everything the learner owns, in one serialisable object.
///
/// A single snapshot keeps local writes atomic (write temp, then rename) and
/// makes the app trivially backup-able later. The shape is deliberately close
/// to the Laravel tables it mirrors: reading_progress, bookmarks, annotations,
/// ratings, classrooms, classroom_assignments and study activity.
class AppSnapshot {
  AppSnapshot({
    Profile? profile,
    List<Document>? personalDocuments,
    Map<String, DocumentAsset>? assets,
    Map<String, ReadingProgress>? progress,
    List<Bookmark>? bookmarks,
    List<DocumentNote>? notes,
    Map<String, int>? ratings,
    Set<String>? savedIds,
    List<ClassGroup>? classes,
    List<Assignment>? assignments,
    List<StudyDay>? studyDays,
    this.version = 1,
  })  : profile = profile ?? const Profile(),
        personalDocuments = personalDocuments ?? <Document>[],
        assets = assets ?? <String, DocumentAsset>{},
        progress = progress ?? <String, ReadingProgress>{},
        bookmarks = bookmarks ?? <Bookmark>[],
        notes = notes ?? <DocumentNote>[],
        ratings = ratings ?? <String, int>{},
        savedIds = savedIds ?? <String>{},
        classes = classes ?? <ClassGroup>[],
        assignments = assignments ?? <Assignment>[],
        studyDays = studyDays ?? <StudyDay>[];

  Profile profile;
  final List<Document> personalDocuments;
  final Map<String, DocumentAsset> assets;
  final Map<String, ReadingProgress> progress;
  final List<Bookmark> bookmarks;
  final List<DocumentNote> notes;
  final Map<String, int> ratings;
  final Set<String> savedIds;
  final List<ClassGroup> classes;
  final List<Assignment> assignments;
  final List<StudyDay> studyDays;
  final int version;

  String encode() => jsonEncode(toJson());

  static AppSnapshot decode(String raw) {
    final map = jsonDecode(raw) as Map<String, Object?>;
    return AppSnapshot.fromJson(map);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'version': version,
        'profile': profile.toJson(),
        'personalDocuments': personalDocuments.map((doc) => doc.toJson()).toList(),
        'assets': assets.map((key, value) => MapEntry(key, value.toJson())),
        'progress': progress.map((key, value) => MapEntry(key, value.toJson())),
        'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'ratings': ratings,
        'savedIds': savedIds.toList(),
        'classes': classes.map((group) => group.toJson()).toList(),
        'assignments': assignments.map((assignment) => assignment.toJson()).toList(),
        'studyDays': studyDays.map((day) => day.toJson()).toList(),
      };

  static AppSnapshot fromJson(Map<String, Object?> json) {
    Profile profile = const Profile();
    final rawProfile = json['profile'];
    if (rawProfile is Map<String, Object?>) {
      profile = Profile.fromJson(rawProfile);
    }

    return AppSnapshot(
      profile: profile,
      personalDocuments: _list(json['personalDocuments'])
          .whereType<Map<String, Object?>>()
          .map(Document.fromJson)
          .toList(),
      assets: _map(json['assets']).map(
        (key, value) => MapEntry(key, DocumentAsset.fromJson(value as Map<String, Object?>)),
      ),
      progress: _map(json['progress']).map(
        (key, value) => MapEntry(key, ReadingProgress.fromJson(value as Map<String, Object?>)),
      ),
      bookmarks: _list(json['bookmarks'])
          .whereType<Map<String, Object?>>()
          .map(Bookmark.fromJson)
          .toList(),
      notes: _list(json['notes'])
          .whereType<Map<String, Object?>>()
          .map(DocumentNote.fromJson)
          .toList(),
      ratings: _map(json['ratings'])
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      savedIds: _list(json['savedIds']).map((id) => id.toString()).toSet(),
      classes: _list(json['classes'])
          .whereType<Map<String, Object?>>()
          .map(ClassGroup.fromJson)
          .toList(),
      assignments: _list(json['assignments'])
          .whereType<Map<String, Object?>>()
          .map(Assignment.fromJson)
          .toList(),
      studyDays: _list(json['studyDays'])
          .whereType<Map<String, Object?>>()
          .map(StudyDay.fromJson)
          .toList(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  static List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

  static Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    return <String, Object?>{};
  }
}
