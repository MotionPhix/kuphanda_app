// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/classroom.dart';
import '../data/models/document.dart';
import '../data/models/profile.dart';
import '../data/models/reading.dart';
import '../data/models/study_guide.dart';
import '../data/models/subject.dart';
import '../data/seed/classroom_seed.dart';
import '../data/seed/curriculum_seed.dart';
import '../data/seed/library_seed.dart';
import '../data/store/document_files.dart';
import '../data/store/snapshot.dart';
import '../data/store/state_store.dart';

/// Result of a class action, shaped so the UI never has to catch exceptions
/// for ordinary validation failures.
class ClassActionResult {
  const ClassActionResult.ok(this.message) : success = true;
  const ClassActionResult.error(this.message) : success = false;

  final bool success;
  final String message;
}

class DayStat {
  const DayStat({
    required this.date,
    required this.minutes,
    required this.isToday,
    required this.label,
  });

  final DateTime date;
  final int minutes;
  final bool isToday;
  final String label;
}

class StudyStats {
  const StudyStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.weeklyGoalMinutes,
    required this.weekDays,
  });

  final int currentStreak;
  final int longestStreak;
  final int todayMinutes;
  final int weekMinutes;
  final int weeklyGoalMinutes;
  final List<DayStat> weekDays;

  double get weekPercent =>
      weeklyGoalMinutes <= 0 ? 0 : (weekMinutes / weeklyGoalMinutes).clamp(0, 1).toDouble();

  bool get studiedToday => todayMinutes > 0;
}

/// The single source of truth for the app.
///
/// Offline-first by design: every mutation lands in an in-memory snapshot and
/// is persisted to disk shortly afterwards. There is no read path that needs a
/// network, which matters in a country where most schools are not connected.
class AppState extends ChangeNotifier {
  AppState({
    required StateStore store,
    required DocumentFiles files,
    DateTime Function()? clock,
  })  : _store = store,
        _files = files,
        _clock = clock ?? DateTime.now;

  final StateStore _store;
  final DocumentFiles _files;
  final DateTime Function() _clock;

  AppSnapshot _snapshot = AppSnapshot();
  List<Document> _seedCatalogue = const <Document>[];
  List<Document> _allDocuments = const <Document>[];
  bool _ready = false;
  String? _lastError;
  Timer? _persistTimer;

  bool get isReady => _ready;
  String? get lastError => _lastError;
  Profile get profile => _snapshot.profile;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    _ready = false;
    notifyListeners();

    final now = _clock();
    var snapshot = await _store.read();
    final isFirstRun = snapshot == null;

    if (snapshot == null) {
      final classrooms = buildSeedClassrooms(now: now);
      snapshot = AppSnapshot(
        profile: Profile(
          examYear: now.year + 1,
          subjectIds: subjectsForForm(4).map((subject) => subject.id).toList(),
        ),
        classes: classrooms.classes,
        assignments: classrooms.assignments,
        studyDays: _starterActivity(now),
      );
    }

    // Bundled files are always available, even if an older snapshot predates
    // them. Imported files survive because they are keyed by document id.
    for (final asset in kBundledAssets) {
      snapshot.assets.putIfAbsent(asset.documentId, () => asset);
    }

    _snapshot = snapshot;
    _seedCatalogue = buildCatalogue(now: now);
    _allDocuments = _mergeDocuments();
    _ready = true;
    if (isFirstRun) {
      await _persistNow();
    }
    notifyListeners();
  }

  /// A little history so the weekly chart and streak are not empty on a brand
  /// new install. It is obviously demo data, and resetting the app regenerates
  /// it rather than pretending it is real activity.
  List<StudyDay> _starterActivity(DateTime now) {
    StudyDay day(int daysAgo, int minutes, int sessions) {
      final date = now.subtract(Duration(days: daysAgo));
      return StudyDay(
        date: dayKey(date),
        seconds: minutes * 60,
        sessions: sessions,
      );
    }

    return <StudyDay>[
      day(1, 35, 2),
      day(2, 20, 1),
      day(4, 48, 3),
      day(5, 15, 1),
    ];
  }

  List<Document> _mergeDocuments() {
    final merged = <String, Document>{};
    for (final document in _snapshot.personalDocuments) {
      merged[document.id] = document;
    }
    for (final document in _seedCatalogue) {
      merged.putIfAbsent(document.id, () => document);
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  void _recomputeDocuments() {
    _allDocuments = _mergeDocuments();
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  List<Document> get documents => _allDocuments;

  List<LibraryEntry> get entries =>
      _allDocuments.map(_entryFor).toList(growable: false);

  Document? documentById(String id) {
    for (final document in _allDocuments) {
      if (document.id == id) return document;
    }
    return null;
  }

  DocumentAsset? assetFor(String documentId) => _snapshot.assets[documentId];

  ReadingProgress? progressFor(String documentId) => _snapshot.progress[documentId];

  ReadingProgress progressOrDefault(Document document) =>
      _snapshot.progress[document.id] ??
      ReadingProgress(documentId: document.id, totalPages: document.pages);

  bool isSaved(String documentId) => _snapshot.savedIds.contains(documentId);

  bool isLocked(Document document) => !profile.plan.covers(document.accessTier);

  LibraryEntry _entryFor(Document document) {
    final progress = _snapshot.progress[document.id];
    return LibraryEntry(
      document: document,
      subject: subjectById(document.subjectId),
      asset: _snapshot.assets[document.id],
      progressPercent: progress?.percent ?? 0,
      saved: _snapshot.savedIds.contains(document.id),
      locked: isLocked(document),
      rating: _snapshot.ratings[document.id],
    );
  }

  LibraryEntry? entryFor(String id) {
    final document = documentById(id);
    return document == null ? null : _entryFor(document);
  }

  List<LibraryEntry> entriesForForm(int form, {int limit = 10}) {
    return entries.where((entry) => entry.document.form == form).take(limit).toList();
  }

  List<LibraryEntry> recommended({int limit = 8}) {
    final subjects = profile.subjects.map((subject) => subject.id).toSet();
    final list = entries.where((entry) {
      if (entry.locked) return false;
      if (entry.document.form != profile.form) return false;
      return subjects.isEmpty || subjects.contains(entry.document.subjectId);
    }).toList();
    list.sort((a, b) => b.document.rating.compareTo(a.document.rating));
    return list.take(limit).toList();
  }

  List<LibraryEntry> get continueReading {
    final list = entries
        .where((entry) => entry.progressPercent > 0 && entry.progressPercent < 100)
        .toList();
    list.sort((a, b) {
      final aDate = progressFor(a.document.id)?.lastReadAt ?? DateTime(1970);
      final bDate = progressFor(b.document.id)?.lastReadAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  List<LibraryEntry> get recentlyAdded => entries.take(8).toList();

  List<LibraryEntry> get offlineDocuments =>
      entries.where((entry) => entry.onDevice).toList();

  List<LibraryEntry> get savedDocuments =>
      entries.where((entry) => entry.saved).toList();

  double averageRating(Document document) {
    final mine = _snapshot.ratings[document.id];
    if (mine == null) return document.rating;
    final total = document.rating * document.ratingCount + mine;
    return total / (document.ratingCount + 1);
  }

  List<Bookmark> bookmarksFor(String documentId) {
    final list = _snapshot.bookmarks.where((bookmark) => bookmark.documentId == documentId).toList();
    list.sort((a, b) => a.page.compareTo(b.page));
    return list;
  }

  List<DocumentNote> notesFor(String documentId) {
    final list = _snapshot.notes.where((note) => note.documentId == documentId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Documents with a bookmark or note, for the "Your marks" screen.
  List<LibraryEntry> get annotatedDocuments {
    final ids = <String>{
      ..._snapshot.bookmarks.map((bookmark) => bookmark.documentId),
      ..._snapshot.notes.map((note) => note.documentId),
    };
    return entries.where((entry) => ids.contains(entry.document.id)).toList();
  }

  StudyGuide? guideFor(Document document) {
    if (document.guideId == null) return null;
    for (final guide in kStudyGuides) {
      if (guide.id == document.guideId) return guide;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<void> updateProfile(Profile next) async {
    _snapshot.profile = next;
    notifyListeners();
    _schedulePersist();
  }

  Future<void> completeOnboarding({
    required String name,
    required String school,
    required int form,
    required int examYear,
    required StudentRole role,
    required List<String> subjectIds,
  }) async {
    _snapshot.profile = profile.copyWith(
      name: name.trim(),
      school: school.trim(),
      form: form,
      examYear: examYear,
      role: role,
      subjectIds: subjectIds,
      onboardingComplete: true,
    );
    await _persistNow();
    notifyListeners();
  }

  Future<void> setTheme(AppThemePreference preference) async {
    _snapshot.profile = profile.copyWith(theme: preference);
    await _persistNow();
    notifyListeners();
  }

  Future<void> setPlan(LibraryPlan plan) async {
    _snapshot.profile = profile.copyWith(plan: plan);
    await _persistNow();
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int minutes) async {
    final clamped = minutes.clamp(60, 1440);
    _snapshot.profile = profile.copyWith(weeklyGoalMinutes: clamped);
    await _persistNow();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Saved / ratings
  // ---------------------------------------------------------------------------

  Future<void> toggleSaved(String documentId) async {
    if (!_snapshot.savedIds.remove(documentId)) {
      _snapshot.savedIds.add(documentId);
    }
    notifyListeners();
    _schedulePersist();
  }

  Future<void> rateDocument(String documentId, int stars) async {
    _snapshot.ratings[documentId] = stars.clamp(1, 5);
    notifyListeners();
    _schedulePersist();
  }

  // ---------------------------------------------------------------------------
  // Reading progress, bookmarks and notes
  // ---------------------------------------------------------------------------

  void recordProgress({
    required String documentId,
    required int page,
    required int totalPages,
    int seconds = 0,
  }) {
    final existing = _snapshot.progress[documentId] ??
        ReadingProgress(documentId: documentId, totalPages: totalPages);
    final safeTotal = totalPages <= 0 ? existing.totalPages : totalPages;
    final safePage = page.clamp(1, safeTotal <= 0 ? 1 : safeTotal);
    final completed = safeTotal > 0 && safePage >= safeTotal;

    _snapshot.progress[documentId] = existing.copyWith(
      currentPage: safePage,
      totalPages: safeTotal,
      secondsSpent: existing.secondsSpent + seconds,
      lastReadAt: _clock(),
      completed: existing.completed || completed,
    );

    if (seconds > 0) {
      _addStudySeconds(seconds);
    }

    _autoCompleteAssignments(documentId);
    notifyListeners();
    _schedulePersist();
  }

  void _addStudySeconds(int seconds) {
    final key = dayKey(_clock());
    final index = _snapshot.studyDays.indexWhere((day) => day.date == key);
    if (index >= 0) {
      final day = _snapshot.studyDays[index];
      _snapshot.studyDays[index] = day.copyWith(
        seconds: day.seconds + seconds,
        sessions: day.sessions + (seconds >= 60 ? 1 : 0),
      );
    } else {
      _snapshot.studyDays.add(StudyDay(date: key, seconds: seconds, sessions: 1));
    }
  }

  void _autoCompleteAssignments(String documentId) {
    final progress = _snapshot.progress[documentId];
    if (progress == null || progress.percent < 90) return;
    for (var index = 0; index < _snapshot.assignments.length; index++) {
      final assignment = _snapshot.assignments[index];
      if (assignment.documentId == documentId && !assignment.completed) {
        _snapshot.assignments[index] = assignment.copyWith(completed: true);
      }
    }
  }

  Future<Bookmark> addBookmark(String documentId, int page, {String? label}) async {
    final bookmark = Bookmark(
      id: 'bm-${_clock().microsecondsSinceEpoch}',
      documentId: documentId,
      page: page,
      createdAt: _clock(),
      label: label,
    );
    _snapshot.bookmarks.add(bookmark);
    notifyListeners();
    _schedulePersist();
    return bookmark;
  }

  Future<void> removeBookmark(String bookmarkId) async {
    _snapshot.bookmarks.removeWhere((bookmark) => bookmark.id == bookmarkId);
    notifyListeners();
    _schedulePersist();
  }

  Future<void> addNote(String documentId, int page, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _snapshot.notes.add(
      DocumentNote(
        id: 'note-${_clock().microsecondsSinceEpoch}',
        documentId: documentId,
        page: page,
        text: trimmed,
        createdAt: _clock(),
      ),
    );
    notifyListeners();
    _schedulePersist();
  }

  Future<void> removeNote(String noteId) async {
    _snapshot.notes.removeWhere((note) => note.id == noteId);
    notifyListeners();
    _schedulePersist();
  }

  // ---------------------------------------------------------------------------
  // Files and documents
  // ---------------------------------------------------------------------------

  Future<PickedPdf?> pickPdf() => _files.pickPdf();

  Future<void> attachPdf(String documentId, PickedPdf picked) async {
    final document = documentById(documentId);
    if (document == null) throw StateError('Unknown document');

    final previous = _snapshot.assets[documentId];
    if (previous != null && previous.path != null) {
      await _files.delete(previous);
    }

    final asset = await _files.store(documentId: documentId, picked: picked);
    _snapshot.assets[documentId] = asset;
    notifyListeners();
    await _persistNow();
  }

  Future<Document> importPdf({
    required PickedPdf picked,
    required String title,
    required String subjectId,
    required int form,
    required DocumentKind kind,
  }) async {
    final timestamp = _clock().microsecondsSinceEpoch;
    final document = Document(
      id: 'personal-$timestamp',
      title: title.trim().isEmpty ? _titleFromFile(picked.fileName) : title.trim(),
      subjectId: subjectId,
      form: form,
      kind: kind,
      description: 'Imported from this device on ${_shortDate(_clock())}.',
      pages: 1,
      addedAt: _clock(),
      author: 'Imported',
      personal: true,
      tags: const <String>['imported'],
    );

    final asset = await _files.store(documentId: document.id, picked: picked);
    _snapshot.personalDocuments.add(document);
    _snapshot.assets[document.id] = asset;
    _recomputeDocuments();
    notifyListeners();
    await _persistNow();
    return document;
  }

  Future<void> removeFile(String documentId) async {
    final asset = _snapshot.assets.remove(documentId);
    if (asset != null && !asset.isBundled) {
      await _files.delete(asset);
    }
    notifyListeners();
    await _persistNow();
  }

  Future<void> updatePersonalDocument(
    String documentId, {
    String? title,
    String? subjectId,
    int? form,
    DocumentKind? kind,
  }) async {
    final index = _snapshot.personalDocuments.indexWhere((doc) => doc.id == documentId);
    if (index < 0) return;
    _snapshot.personalDocuments[index] = _snapshot.personalDocuments[index].copyWith(
      title: title,
      subjectId: subjectId,
      form: form,
      kind: kind,
    );
    _recomputeDocuments();
    notifyListeners();
    await _persistNow();
  }

  Future<void> deletePersonalDocument(String documentId) async {
    await removeFile(documentId);
    _snapshot.personalDocuments.removeWhere((document) => document.id == documentId);
    _snapshot.progress.remove(documentId);
    _snapshot.savedIds.remove(documentId);
    _snapshot.ratings.remove(documentId);
    _snapshot.bookmarks.removeWhere((bookmark) => bookmark.documentId == documentId);
    _snapshot.notes.removeWhere((note) => note.documentId == documentId);
    _snapshot.assignments.removeWhere((assignment) => assignment.documentId == documentId);
    _recomputeDocuments();
    notifyListeners();
    await _persistNow();
  }

  int get storageBytes => _snapshot.assets.values
      .where((asset) => !asset.isBundled)
      .fold<int>(0, (total, asset) => total + asset.sizeBytes);

  int get importedFileCount => _snapshot.assets.values.where((asset) => !asset.isBundled).length;

  // ---------------------------------------------------------------------------
  // Classes and assignments
  // ---------------------------------------------------------------------------

  List<ClassGroup> get classes => _snapshot.classes;

  List<Assignment> assignmentsForClass(String classId) {
    final list = _snapshot.assignments.where((a) => a.classId == classId).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  Assignment? assignmentForDocument(String documentId) {
    for (final assignment in _snapshot.assignments) {
      if (assignment.documentId == documentId) return assignment;
    }
    return null;
  }

  List<Assignment> get upcomingAssignments {
    final list = _snapshot.assignments.where((assignment) => !assignment.completed).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  ClassGroup? classById(String id) {
    for (final group in _snapshot.classes) {
      if (group.id == id) return group;
    }
    return null;
  }

  Future<ClassActionResult> joinClass(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length != 6) {
      return const ClassActionResult.error('A class code has six characters, like KPH4A2.');
    }
    if (_snapshot.classes.any((group) => group.code == code)) {
      return const ClassActionResult.error('You have already joined this class.');
    }

    final seeds = buildSeedClassrooms(now: _clock());
    ClassGroup? match;
    for (final group in seeds.classes) {
      if (group.code == code) match = group;
    }

    if (match == null) {
      return const ClassActionResult.error('No class uses that code. Check it with your teacher.');
    }

    _snapshot.classes.add(match);
    for (final assignment in seeds.assignments) {
      if (assignment.classId == match.id) {
        _snapshot.assignments.add(assignment);
      }
    }
    notifyListeners();
    await _persistNow();
    return ClassActionResult.ok('Joined ${match.name}.');
  }

  Future<ClassGroup> createClass({
    required String name,
    required int form,
    required String subjectId,
    required String teacherName,
  }) async {
    final group = ClassGroup(
      id: 'class-${_clock().microsecondsSinceEpoch}',
      name: name.trim(),
      code: _generateCode(),
      form: form,
      subjectId: subjectId,
      teacherName: teacherName.trim().isEmpty ? profile.name : teacherName.trim(),
      memberCount: 1,
      createdAt: _clock(),
      isMine: true,
    );
    _snapshot.classes.add(group);
    notifyListeners();
    await _persistNow();
    return group;
  }

  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = _clock().microsecondsSinceEpoch;
    final buffer = StringBuffer('KPH');
    for (var index = 0; index < 3; index++) {
      buffer.write(alphabet[(random >> (index * 5)) % alphabet.length]);
    }
    var candidate = buffer.toString();
    var attempt = 0;
    while (_snapshot.classes.any((group) => group.code == candidate)) {
      attempt++;
      candidate = 'KPH${(random + attempt * 7919) % 999}'.padRight(6, 'X');
    }
    return candidate;
  }

  Future<void> addAssignment({
    required String classId,
    required String documentId,
    required DateTime dueDate,
    String note = '',
  }) async {
    _snapshot.assignments.add(
      Assignment(
        id: 'asg-${_clock().microsecondsSinceEpoch}',
        classId: classId,
        documentId: documentId,
        dueDate: dueDate,
        createdAt: _clock(),
        note: note.trim(),
      ),
    );
    notifyListeners();
    await _persistNow();
  }

  Future<void> toggleAssignmentDone(String assignmentId) async {
    final index = _snapshot.assignments.indexWhere((a) => a.id == assignmentId);
    if (index < 0) return;
    final assignment = _snapshot.assignments[index];
    _snapshot.assignments[index] = assignment.copyWith(completed: !assignment.completed);
    notifyListeners();
    await _persistNow();
  }

  Future<void> deleteAssignment(String assignmentId) async {
    _snapshot.assignments.removeWhere((a) => a.id == assignmentId);
    notifyListeners();
    await _persistNow();
  }

  // ---------------------------------------------------------------------------
  // Study statistics
  // ---------------------------------------------------------------------------

  StudyStats get stats {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = <String, StudyDay>{
      for (final day in _snapshot.studyDays) day.date: day,
    };

    int minutesOn(DateTime date) => byDate[dayKey(date)]?.minutes ?? 0;

    var current = 0;
    var cursor = today;
    if (minutesOn(today) == 0 && minutesOn(today.subtract(const Duration(days: 1))) > 0) {
      cursor = today.subtract(const Duration(days: 1));
    }
    while (minutesOn(cursor) > 0) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final dates = _snapshot.studyDays
        .where((day) => day.minutes > 0)
        .map((day) => DateTime.tryParse(day.date))
        .whereType<DateTime>()
        .toList()
      ..sort();

    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final date in dates) {
      if (previous != null && date.difference(previous).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      previous = date;
    }

    final monday = today.subtract(Duration(days: today.weekday - 1));
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekDays = <DayStat>[
      for (var index = 0; index < 7; index++)
        DayStat(
          date: monday.add(Duration(days: index)),
          minutes: minutesOn(monday.add(Duration(days: index))),
          isToday: monday.add(Duration(days: index)) == today,
          label: labels[index],
        ),
    ];

    return StudyStats(
      currentStreak: current,
      longestStreak: longest < current ? current : longest,
      todayMinutes: minutesOn(today),
      weekMinutes: weekDays.fold<int>(0, (sum, day) => sum + day.minutes),
      weeklyGoalMinutes: profile.weeklyGoalMinutes,
      weekDays: weekDays,
    );
  }

  // ---------------------------------------------------------------------------
  // Exam window
  // ---------------------------------------------------------------------------

  DateTime get examDate {
    final now = _clock();
    final year = profile.examYear < now.year ? now.year + 1 : profile.examYear;
    final month = profile.examTarget == 'JCE' ? 11 : 10;
    final day = profile.examTarget == 'JCE' ? 3 : 15;
    var date = DateTime(year, month, day);
    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
      date = DateTime(year + 1, month, day);
    }
    return date;
  }

  int get daysToExam {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    return examDate.difference(today).inDays;
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  Future<void> resetEverything() async {
    for (final asset in _snapshot.assets.values) {
      if (!asset.isBundled) {
        try {
          await _files.delete(asset);
        } catch (_) {
          // Best effort: a file may already be gone.
        }
      }
    }
    await _store.clear();
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    try {
      await _store.write(_snapshot);
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not save your changes: $error';
      notifyListeners();
    }
  }

  Future<void> flush() => _persistNow();

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}

String dayKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _titleFromFile(String fileName) {
  final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  return base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
}

String _shortDate(DateTime date) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
