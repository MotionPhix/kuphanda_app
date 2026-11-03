// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_config.dart';
import '../data/api/api_models.dart';
import '../data/api/token_store.dart';
import '../data/models/classroom.dart';
import '../data/models/document.dart';
import '../data/models/profile.dart';
import '../data/models/reading.dart';
import '../data/models/reading_tally.dart';
import '../data/models/study_guide.dart';
import '../data/models/subject.dart';
import '../data/notifications/push_service.dart';
import '../data/seed/curriculum_seed.dart';
import '../data/seed/library_seed.dart';
import '../data/store/block_cache.dart';
import '../data/store/document_files.dart';
import '../data/store/snapshot.dart';
import '../data/store/state_store.dart';
import '../data/sync/offline_plan.dart';

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

enum OfflineState { none, queued, downloading, downloaded, updateAvailable, failed }

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
    ApiClient? api,
    TokenStore? tokenStore,
    BlockDocumentCache? blockCache,
  })  : _store = store,
        _files = files,
        _clock = clock ?? DateTime.now,
        _api = api,
        _tokenStore = tokenStore ?? SecureTokenStore(),
        _blockCache = blockCache;

  final StateStore _store;
  final DocumentFiles _files;
  final BlockDocumentCache? _blockCache;
  final DateTime Function() _clock;
  final TokenStore _tokenStore;
  ApiClient? _api;

  AppSnapshot _snapshot = AppSnapshot();
  List<Document> _seedCatalogue = const <Document>[];
  List<Document> _allDocuments = const <Document>[];
  List<RemoteDocument> _remoteCatalogue = const <RemoteDocument>[];
  final Map<String, int> _remoteVersions = <String, int>{};
  final Map<String, double> _downloadProgress = <String, double>{};
  final Set<String> _downloading = <String>{};
  final Map<String, String> _downloadErrors = <String, String>{};
  final Map<String, bool> _entitled = <String, bool>{};

  /// Documents with a copy on this phone, in either format.
  Set<String> _savedOffline = <String>{};
  List<RemotePlan> _plans = const <RemotePlan>[];
  String? _billingError;
  List<PaymentRecord> _payments = const <PaymentRecord>[];
  List<AppNotification> _notifications = const <AppNotification>[];
  BillingStatus? _billing;
  String? _token;
  AuthSession? _account;
  bool _syncing = false;
  String? _syncError;
  bool _ready = false;
  String? _lastError;
  Timer? _persistTimer;
  Timer? _autoSyncTimer;
  PushService? _push;
  PushNotification? _lastPush;

  bool get isReady => _ready;
  String? get lastError => _lastError;
  Profile get profile => _snapshot.profile;

  // ---------------------------------------------------------------------------
  // Account and sync surface
  // ---------------------------------------------------------------------------

  bool get isSignedIn => _token != null && _token!.isNotEmpty;
  // The snapshot carries the flag that was persisted with the session, so staff
  // tools survive a restart and a later account refresh that does not repeat it.
  bool get isStaff => _snapshot.accountStaff || (_account?.isStaff ?? false);
  AuthSession? get account => _account;
  String? get accountName => _snapshot.accountName;
  String? get accountEmail => _snapshot.accountEmail;
  String? get accountPlan => _snapshot.accountPlan;
  bool get isSyncing => _syncing;
  String? get syncError => _syncError;

  /// Why the last billing fetch failed, if it did. The subscription page
  /// uses it to stop showing a spinner that never resolves.
  String? get billingError => _billingError;

  /// Why the phone stopped being signed in, when it was not the learner's own
  /// doing — a password changed elsewhere, or an account closed by the school.
  /// The gate says it once, so being dropped to the landing page is explained
  /// instead of looking like a crash.
  String? get sessionEndedReason => _sessionEndedReason;
  String? _sessionEndedReason;

  void _endSession(String reason) {
    _sessionEndedReason = reason;
    _token = null;
    _account = null;
    _api?.token = null;
    stopAutoSync();
  }

  /// Messages the library or a teacher has sent to this learner, newest first.
  List<AppNotification> get notifications => _notifications;

  /// The most recent notification received while the app was open. The shell
  /// shows it as a banner; it is cleared once presented.
  PushNotification? get lastPush => _lastPush;
  bool get pushAvailable => _push?.isAvailable ?? false;

  void clearLastPush() {
    _lastPush = null;
  }
  DateTime? get lastSyncAt => _snapshot.lastSyncAt;
  int get offlineMarkCount => _snapshot.offlineMarked.length;
  int get pendingRemovalCount => _snapshot.pendingRemovals.length;

  String? get pendingPaymentTxRef => _snapshot.pendingPaymentTxRef;
  String? get pendingPaymentKind => _snapshot.pendingPaymentKind;
  bool get hasPendingPayment => _snapshot.pendingPaymentTxRef != null;

  List<RemotePlan> get plans => _plans;
  List<PaymentRecord> get payments => _payments;
  BillingStatus? get billing => _billing;
  AccessTier get entitlementTier => _billing?.tier ?? AccessTier.fromName(profile.plan.name);
  bool get hasPaidAccess => _billing?.hasPaidAccess ?? false;

  int priceFor(String documentId) {
    for (final item in _remoteCatalogue) {
      if (item.document.id == documentId) return item.priceMwk;
    }
    return 0;
  }

  /// Server entitlement wins; without a loaded catalogue, fall back to the
  /// locally cached plan.
  bool canAccess(Document document) {
    if (document.accessTier == AccessTier.free) return true;

    final override = _entitled[document.id];
    if (override != null) return override;

    // Paid content requires an account. Bundled free material stays readable.
    if (!isSignedIn) return false;

    if (profile.plan == LibraryPlan.school) return true;

    final billing = _billing;
    if (billing != null) {
      if (billing.tier.rank >= document.accessTier.rank) return true;
      if (billing.purchases.contains(document.id)) return true;
      return false;
    }

    return profile.plan.covers(document.accessTier);
  }

  /// A document has a server file and can therefore be downloaded or updated.
  bool hasRemoteFile(String documentId) =>
      _remoteCatalogue.any((item) => item.document.id == documentId && item.file != null);

  int? remoteVersionFor(String documentId) => _remoteVersions[documentId];

  bool isMarkedOffline(String documentId) =>
      _snapshot.offlineMarked.contains(documentId);

  bool updateAvailable(String documentId) {
    final asset = _snapshot.assets[documentId];
    final latest = _remoteVersions[documentId];
    return asset != null && asset.remote && latest != null && asset.version < latest;
  }

  OfflineState offlineStateFor(String documentId) {
    if (_downloading.contains(documentId)) return OfflineState.downloading;
    final error = _downloadErrors[documentId];
    if (error != null) return OfflineState.failed;

    final asset = _snapshot.assets[documentId];
    if (asset != null && asset.remote) {
      return updateAvailable(documentId) ? OfflineState.updateAvailable : OfflineState.downloaded;
    }
    if (isMarkedOffline(documentId)) return OfflineState.queued;
    return OfflineState.none;
  }

  double downloadProgressFor(String documentId) => _downloadProgress[documentId] ?? 0;
  String? downloadErrorFor(String documentId) => _downloadErrors[documentId];

  /// Starts the periodic refresh. Safe to call more than once.
  void startAutoSync({Duration interval = const Duration(minutes: 15)}) {
    _autoSyncTimer?.cancel();
    if (!isSignedIn) return;
    _autoSyncTimer = Timer.periodic(interval, (_) {
      unawaited(syncNow(silent: true));
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    _ready = false;
    notifyListeners();

    final now = _clock();
    var snapshot = await _store.read();
    final isFirstRun = snapshot == null;

    snapshot ??= AppSnapshot(
      profile: Profile(
        examYear: now.year + 1,
        subjectIds: subjectsForForm(4).map((subject) => subject.id).toList(),
      ),
    );

    var migrated = _releaseRetiredSampleProfile(snapshot);
    migrated = _clearDemoStudyHistory(snapshot) || migrated;
    migrated = _clearDemoClasses(snapshot) || migrated;

    // Bundled files are always available, even if an older snapshot predates
    // them. Imported files survive because they are keyed by document id.
    for (final asset in kBundledAssets) {
      snapshot.assets.putIfAbsent(asset.documentId, () => asset);
    }

    _snapshot = snapshot;
    _seedCatalogue = buildCatalogue(now: now);
    final restoredCatalogue = <RemoteDocument>[];
    for (final document in snapshot.remoteDocuments) {
      final asset = snapshot.assets[document.id];
      RemoteFile? file;
      if (asset != null && asset.remote) {
        file = RemoteFile(
          version: asset.version,
          fileName: asset.fileName,
          sizeBytes: asset.sizeBytes,
          pageCount: asset.pageCount ?? document.pages,
          checksum: asset.checksum ?? '',
          publishedAt: asset.addedAt,
        );
      }
      restoredCatalogue.add(RemoteDocument(document: document, file: file));
    }
    _remoteCatalogue = restoredCatalogue;
    for (final entry in snapshot.assets.entries) {
      if (entry.value.remote) {
        _remoteVersions[entry.key] = entry.value.version;
      }
    }

    _savedOffline = await _blockCache?.saved() ?? <String>{};

    _token = await _tokenStore.read();
    if (_token != null && _token!.isNotEmpty) {
      _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: _token);
      _api!.token = _token;
      _account = AuthSession(
        token: _token!,
        userId: snapshot.accountId ?? 0,
        name: snapshot.accountName ?? '',
        email: snapshot.accountEmail ?? '',
        plan: snapshot.accountPlan ?? 'free',
        school: snapshot.accountSchool,
        isStaff: snapshot.accountStaff,
      );
    } else {
      _token = null;
    }


    // Runs after the token is known: only a signed-in learner can be restored.
    if (_restoreEjectedSession(snapshot)) migrated = true;

    _allDocuments = _mergeDocuments();
    _ready = true;
    if (isFirstRun || migrated) {
      await _persistNow();
    }
    notifyListeners();
    startAutoSync();
    if (isSignedIn) {
      // Online-first means the server catalogue wins, but the timer below only
      // fires after 15 minutes: without this a cold start shows whatever was
      // cached, so newly published papers stay invisible until a manual sync.
      unawaited(syncNow(silent: true));
      // Refresh entitlements in the background so a returning subscriber sees
      // their plan without opening the subscription screen.
      unawaited(loadBilling());
      unawaited(loadNotifications());
      unawaited(startPush());
    }
  }


  List<Document> _mergeDocuments() {
    final merged = <String, Document>{};
    // Online-first: once a server catalogue has been synced it becomes the
    // catalogue. The bundled seed is only a first-run / signed-out fallback,
    // so learners never see stale records the library has already removed.
    if (_remoteCatalogue.isEmpty) {
      for (final document in _seedCatalogue) {
        merged[document.id] = document;
      }
    }
    for (final document in _remoteCatalogue) {
      merged[document.document.id] = document.document;
    }
    for (final document in _snapshot.personalDocuments) {
      merged[document.id] = document;
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

  /// Reading counted in the unit each document actually has.
  ReadingTally get readingTally => tallyReading(_allDocuments, _snapshot.progress);

  ReadingProgress? progressFor(String documentId) => _snapshot.progress[documentId];

  ReadingProgress progressOrDefault(Document document) =>
      _snapshot.progress[document.id] ??
      ReadingProgress(documentId: document.id, totalPages: document.pages);

  bool isSaved(String documentId) => _snapshot.savedIds.contains(documentId);

  bool isLocked(Document document) => !canAccess(document);

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
      priceMwk: priceFor(document.id),
      hasRemoteFile: hasRemoteFile(document.id),
      offlineCopy: _savedOffline.contains(document.id),
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

    if (isSignedIn) {
      try {
        await _api!.updateProfile(
          firstName: next.firstName == 'learner' ? '' : next.firstName,
          lastName: next.lastName,
          school: next.school,
          // Role and form decide which notifications this account receives.
          role: next.role == StudentRole.teacher ? 'teacher' : 'student',
          form: next.role == StudentRole.student ? next.form : null,
        );
      } on ApiException catch (error) {
        _syncError = 'Profile saved on this phone. ${error.message}';
        notifyListeners();
      }
    }
  }

  /// "Preview with sample data" wrote this identity straight into the profile
  /// and dropped the learner into the library. It offered no way back: sign out
  /// only clears the account, and onboarding was already marked complete, so
  /// the button stranded anyone who touched it — and discarded the details they
  /// had typed, since it overwrote the profile in place.
  ///
  /// The entry point is gone; this releases snapshots that still carry it. Only
  /// the profile is reset — progress, notes, downloads and classes survive, so
  /// signing in again restores the same library.
  static const _retiredSampleProfile = (
    name: 'Chisomo Banda',
    givenName: 'Chisomo',
    familyName: 'Banda',
    school: 'Bwaila Secondary School',
    form: 4,
  );

  /// Returns true when it changed the snapshot, so the new marker is persisted
  /// immediately rather than waiting for some later write.
  bool _releaseRetiredSampleProfile(AppSnapshot snapshot) {
    // Once only. The reset leaves the identity untouched, so without this the
    // next launch matches again and ejects the learner from their own account
    // on every start.
    if (snapshot.sampleProfileReleased) return false;

    final profile = snapshot.profile;

    // An account settles it: this is a real learner whose name happens to match
    // the sample. The real Chisomo Banda at Bwaila in Form 4 is exactly who the
    // first version of this released by mistake.
    if (snapshot.accountId != null || snapshot.accountEmail != null) return false;

    final isRetiredSample =
        profile.name == _retiredSampleProfile.name &&
            profile.givenName == _retiredSampleProfile.givenName &&
            profile.familyName == _retiredSampleProfile.familyName &&
            profile.school == _retiredSampleProfile.school &&
            profile.form == _retiredSampleProfile.form;

    if (!isRetiredSample) return false;

    snapshot.profile = profile.copyWith(onboardingComplete: false);
    snapshot.sampleProfileReleased = true;
    return true;
  }

  /// The classes an earlier build invented, complete with teacher names and
  /// learner counts, under a heading that reads "Reading set by your teachers."
  /// A learner shown a class they never joined has no way to tell it apart from
  /// a real one, so they are removed. Classes joined with a code are kept.
  static const _seededClassIds = <String>{
    'class-f4a-sciences',
    'class-f4a-maths',
    'class-f2b-maths',
  };

  bool _clearDemoClasses(AppSnapshot snapshot) {
    final seeded = snapshot.classes
        .where((group) => _seededClassIds.contains(group.id))
        .map((group) => group.id)
        .toSet();

    if (seeded.isEmpty) return false;

    snapshot.classes.removeWhere((group) => seeded.contains(group.id));
    snapshot.assignments.removeWhere((assignment) => seeded.contains(assignment.classId));
    return true;
  }

  /// Deletes the study history an earlier build seeded so the chart would not
  /// look empty. It claimed minutes nobody studied — on the device it read
  /// "1h 43m this week" for an account that had opened the app twice — which is
  /// the one claim this screen exists to make honestly.
  /// The four days the old seeder wrote: minutes and session count, in order of
  /// the days it produced. Kept here so the pattern can be recognised without
  /// guessing at minutes somebody really studied.
  static const _seededStudyPattern = <(int, int)>[(35, 2), (20, 1), (48, 3), (15, 1)];

  bool _clearDemoStudyHistory(AppSnapshot snapshot) {
    if (snapshot.studyDays.isEmpty) return false;

    // Snapshots written by a build that flagged its own seeding, or by one that
    // did not but carries the pattern exactly.
    if (!snapshot.demoStudyHistory && !_looksSeeded(snapshot.studyDays)) {
      return false;
    }

    snapshot.studyDays.clear();
    snapshot.demoStudyHistory = false;
    return true;
  }

  bool _looksSeeded(List<StudyDay> days) {
    if (days.length != _seededStudyPattern.length) return false;

    String signature(Iterable<(int, int)> pairs) =>
        (pairs.map((pair) => '${pair.$1}x${pair.$2}').toList()..sort()).join(',');

    final actual = days.map((day) => (day.seconds ~/ 60, day.sessions));
    return signature(actual) == signature(_seededStudyPattern);
  }

  /// Undoes the damage of releasing a signed-in learner: their profile was
  /// complete before it was reset, so the details are still on the record and
  /// asking for them again would be busywork caused by our bug.
  bool _restoreEjectedSession(AppSnapshot snapshot) {
    final profile = snapshot.profile;
    if (profile.onboardingComplete) return false;
    if (!isSignedIn) return false;
    if (profile.name.trim().isEmpty || profile.school.trim().isEmpty) return false;

    snapshot.profile = profile.copyWith(onboardingComplete: true);
    snapshot.sampleProfileReleased = true;
    return true;
  }

  Future<void> completeOnboarding({
    required String name,
    String givenName = '',
    String familyName = '',
    required String school,
    required int form,
    required int examYear,
    required StudentRole role,
    required List<String> subjectIds,
  }) async {
    final fullName = name.trim().isEmpty
        ? '$givenName $familyName'.trim()
        : name.trim();
    _snapshot.profile = profile.copyWith(
      name: fullName,
      givenName: givenName.trim(),
      familyName: familyName.trim(),
      school: school.trim(),
      form: form,
      examYear: examYear,
      role: role,
      subjectIds: subjectIds,
      onboardingComplete: true,
    );
    await _persistNow();
    notifyListeners();

    // A Google sign-in during onboarding already created the account; push the
    // names the learner just confirmed so the server copy matches.
    if (isSignedIn) {
      unawaited(
        _api!.updateProfile(
          firstName: profile.firstName == 'learner' ? '' : profile.firstName,
          lastName: profile.lastName,
          school: profile.school,
          role: role == StudentRole.teacher ? 'teacher' : 'student',
          form: role == StudentRole.student ? form : null,
        ).catchError((Object _) {}),
      );
    }
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
    double? fraction,
  }) {
    final existing = _snapshot.progress[documentId] ??
        ReadingProgress(documentId: documentId, totalPages: totalPages);
    final safeTotal = totalPages <= 0 ? existing.totalPages : totalPages;
    final safePage = page.clamp(1, safeTotal <= 0 ? 1 : safeTotal);
    // Completion follows the measure in use. Mixing the two marked a
    // twenty-four-question paper finished at 83%, because the reader's page
    // number is derived from the scroll fraction out of an invented six.
    final measured = fraction;
    final completed = measured != null
        ? measured >= 0.995
        : (safeTotal > 0 && safePage >= safeTotal);

    _snapshot.progress[documentId] = existing.copyWith(
      currentPage: safePage,
      totalPages: safeTotal,
      secondsSpent: existing.secondsSpent + seconds,
      lastReadAt: _clock(),
      // Sticky only for page-based documents: a PDF that was finished stays
      // finished. A measured fraction is re-derived on every report, which is
      // what corrects the stale "finished" written by the old arithmetic.
      completed: measured != null ? completed : (existing.completed || completed),
      fraction: fraction,
    );

    if (seconds > 0) {
      _addStudySeconds(seconds);
    }

    _autoCompleteAssignments(documentId);
    notifyListeners();
    _schedulePersist();
  }

  /// Banks time spent reading without touching where the reader is.
  ///
  /// A paper is read in one sitting, so minutes have to be captured as they are
  /// spent: the PDF reader commits on a timer, the guide on exit, and the block
  /// reader used to do neither — every structured paper contributed nothing to
  /// "minutes studied" or to the streak, which is the app's whole promise.
  void addStudyTime(String documentId, int seconds) {
    if (seconds <= 0) return;

    // A record created for time alone must not claim page 1 of 1: that reads as
    // 100% and would auto-complete an assignment the learner has not opened.
    final existing = _snapshot.progress[documentId] ??
        ReadingProgress(documentId: documentId, currentPage: 0, totalPages: 0);

    _snapshot.progress[documentId] = existing.copyWith(
      secondsSpent: existing.secondsSpent + seconds,
      lastReadAt: _clock(),
    );
    _addStudySeconds(seconds);
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
        // "Done" is the class's record, not a private note on this phone: tell
        // the teacher as soon as the learner closes the paper.
        unawaited(markAssignmentDone(assignment.id));
      }
    }
  }

  /// Records a finished paper on the class so the teacher's report can show it.
  ///
  /// Deliberately quiet on failure: a lost connection should not interrupt
  /// reading, and the next sync of the same document will try again.
  Future<void> markAssignmentDone(String assignmentId) async {
    final api = _api;
    if (api == null) return;
    try {
      await api.completeAssignment(assignmentId);
    } on ApiException catch (error) {
      debugPrint('Could not record completion for $assignmentId: ${error.message}');
    }
  }

  ClassReport? classReportFor(String classroomId) => _reports[classroomId];

  /// Loads the teacher's report for one class: who is in it, what was set, and
  /// who has read it.
  Future<ClassReport?> loadClassReport(String classroomId) async {
    final api = _api;
    if (api == null) return null;
    try {
      final report = await api.fetchClassReport(classroomId);
      _reports[classroomId] = report;
      notifyListeners();
      return report;
    } on ApiException catch (error) {
      debugPrint('Could not load the report for $classroomId: ${error.message}');
      return null;
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

  Future<List<StaffDocument>> loadStaffDocuments() async {
    if (!isSignedIn) throw const ApiException('Sign in with a staff account.');

    return _api!.fetchStaffDocuments();
  }

  Future<StaffVersion> uploadStaffVersion({
    required String documentId,
    required PickedPdf file,
    required int pages,
    String? notes,
  }) async {
    if (!isStaff) throw const ApiException('Staff access is required.');

    return _api!.uploadStaffVersion(
      documentId: documentId,
      filePath: file.path,
      fileName: file.fileName,
      pages: pages,
      notes: notes,
    );
  }

  Future<void> setStaffPublication(String documentId, bool published) async {
    if (!isStaff) throw const ApiException('Staff access is required.');

    await _api!.setStaffPublication(documentId, published);
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

  /// The last report fetched per class, keyed by classroom id.
  final Map<String, ClassReport> _reports = {};

  List<Assignment> assignmentsForClass(String classId) {
    final list = _snapshot.assignments.where((a) => a.classId == classId).toList();
    // Undated reading sorts last: it is never urgent.
    list.sort((a, b) {
      final left = a.dueDate;
      final right = b.dueDate;
      if (left == null) return right == null ? 0 : 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
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
    // Undated reading sorts last: it is never urgent.
    list.sort((a, b) {
      final left = a.dueDate;
      final right = b.dueDate;
      if (left == null) return right == null ? 0 : 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
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
      return const ClassActionResult.error('A class code has six characters.');
    }
    if (_snapshot.classes.any((group) => group.code == code)) {
      return const ClassActionResult.error('You have already joined this class.');
    }

    if (!isSignedIn) {
      return const ClassActionResult.error('Sign in to join a class.');
    }

    if (_snapshot.classes.any((group) => group.code == code)) {
      return const ClassActionResult.error('You have already joined this class.');
    }

    try {
      final classroom = await _api!.joinClass(code);
      _snapshot.classes.add(classroom.group);
      _snapshot.assignments
        ..removeWhere((assignment) => assignment.classId == classroom.group.id)
        ..addAll(classroom.assignments);
      notifyListeners();
      await _persistNow();

      return ClassActionResult.ok('Joined ${classroom.group.name}.');
    } on ApiException catch (error) {
      // The service says whether the code is unknown; passing that through keeps
      // the message in one place instead of inventing a second wording here.
      return ClassActionResult.error(error.message);
    }
  }

  /// Creates a class on the service, which issues the code. A learner on another
  /// phone can only find this class if it exists server-side.
  Future<ClassGroup> createClass({
    required String name,
    required int form,
    String? subjectId,
  }) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to create a class.');
    }

    final classroom = await _api!.createClass(name: name, form: form, subjectId: subjectId);
    _snapshot.classes.add(classroom.group);
    notifyListeners();
    await _persistNow();

    return classroom.group;
  }

  /// Sets a paper for a class the signed-in teacher runs.
  Future<void> assignPaper({
    required String classroomId,
    required String documentId,
    DateTime? dueDate,
  }) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to set reading.');
    }

    final classroom = await _api!.assignPaper(
      classroomId: classroomId,
      documentId: documentId,
      dueDate: dueDate,
    );

    _snapshot.classes
      ..removeWhere((group) => group.id == classroom.group.id)
      ..add(classroom.group);
    _snapshot.assignments
      ..removeWhere((assignment) => assignment.classId == classroom.group.id)
      ..addAll(classroom.assignments);

    notifyListeners();
    await _persistNow();
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
  // Authentication
  // ---------------------------------------------------------------------------

  Future<void> signInWithGoogle(String idToken, {bool sync = true}) async {
    final api = _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: null);
    final session = await api.googleAuth(idToken);
    await _adoptSession(session);
    if (sync) {
      await loadBilling();
      await syncNow();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // Two accounts, one at a time. Swapping means signing out of the account in
    // use and then signing in with the other — never replacing a live session
    // from underneath the person holding the phone.
    if (isSignedIn && (_snapshot.accountEmail ?? '') != email.trim()) {
      throw const ApiException('Sign out before signing in with another account.');
    }

    final api = _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: null);
    final session = await api.login(email: email.trim(), password: password);
    await _adoptSession(session);
    await loadBilling();
    await syncNow();
  }

  Future<void> registerAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final api = _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: null);
    final session = await api.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
    );
    await _adoptSession(session);
    await loadBilling();
    await syncNow();
  }

  /// Changes the password from this phone. Other devices are signed out by the
  /// server; this session carries on.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    final api = _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: _token);
    await api.changePassword(currentPassword: currentPassword, password: password);
  }

  /// Sends a password reset link. The learner follows it on the web app, so
  /// nothing changes on the phone until they sign in again.
  Future<void> requestPasswordReset(String email) async {
    final api = _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: _token);
    await api.forgotPassword(email: email.trim());
  }

  Future<void> _adoptSession(AuthSession session) async {
    // A fresh session answers whatever ended the last one.
    _sessionEndedReason = null;

    // A different person on the same phone: the profile follows the account, or
    // the teacher's classes would be listed under the learner's name. Signing out
    // clears the stored identity, so this covers both "switched directly" and
    // "signed out, then someone else signed in".
    final switched = _snapshot.accountEmail == null ||
        _snapshot.accountEmail != session.email ||
        _snapshot.accountId != session.userId;

    _token = session.token;
    _account = session;
    final api = _api ??= ApiClient(baseUrl: ApiConfig.baseUrl, token: session.token);
    api.token = session.token;
    await _tokenStore.write(session.token);

    _snapshot
      ..accountId = session.userId
      ..accountName = session.name
      ..accountEmail = session.email
      ..accountPlan = session.plan
      ..accountSchool = session.school
      ..accountStaff = session.isStaff;

    // The server is authoritative about entitlement. Mirror it locally so the
    // lock badges and the API's 403 responses agree.
    var merged = profile.copyWith(
      plan: session.plan == 'school' ? LibraryPlan.school : LibraryPlan.free,
    );

    // Merge Google's profile data only into an empty local profile. Anything
    // the learner has already confirmed is kept, including edited names.
    if (profile.name.trim().isEmpty || switched) {
      final given = session.firstName.trim();
      final family = session.lastName.trim();
      merged = merged.copyWith(
        givenName: given,
        familyName: family,
        name: session.name.trim().isNotEmpty
            ? session.name.trim()
            : '$given $family'.trim(),
      );
    }

    // Who the account is and which side of the classroom they are on come back
    // with the session, so a teacher opens the teaching side on any phone and a
    // learner keeps their form.
    final form = session.form ?? merged.form;
    merged = merged.copyWith(
      // A payload that did not name a role leaves the local one alone.
      role: session.role == null
          ? merged.role
          : (session.isTeacher ? StudentRole.teacher : StudentRole.student),
      form: form,
    );

    if (switched) {
      // A different person on this phone inherits nothing: the subjects on the
      // device belonged to the last account.
      merged = merged.copyWith(
        subjectIds: subjectsForForm(form).take(4).map((subject) => subject.id).toList(),
      );
    }

    // Whether onboarding was finished is the server's answer, not a guess from a
    // blank optional field. A learner who never named a school used to be
    // interviewed again on every new phone.
    //
    // An account that already finished on this device keeps that, so an older
    // server (one without the flag) cannot drag a settled profile backwards.
    final completed = session.profileCompleted || (profile.onboardingComplete && !switched);
    merged = merged.copyWith(onboardingComplete: completed);

    _snapshot.profile = merged;

    await _persistNow();
    startAutoSync();
    notifyListeners();
    unawaited(loadNotifications());
    unawaited(startPush());
  }

  /// Starts Firebase Cloud Messaging once per session and registers the device
  /// token with the API. Safe to call repeatedly and on platforms without push.
  Future<void> startPush() async {
    if (!PushService.isSupported) return;
    if (_push != null) {
      if (isSignedIn) {
        final token = _push!.token;
        if (token != null) unawaited(_registerDeviceToken(token));
      }
      return;
    }

    final push = PushService(
      onToken: _registerDeviceToken,
      onForeground: (notification) {
        _lastPush = notification;
        notifyListeners();
      },
    );
    _push = push;

    await push.start();
    if (!push.isAvailable) return;

    await push.joinTopics(_audienceTopics());
    final token = push.token;
    if (token != null) await _registerDeviceToken(token);
  }

  /// Topics mirror the server audiences: everyone, the account's role, and the
  /// learner's form.
  List<String> _audienceTopics() {
    if (!isSignedIn) return const <String>[];
    final topics = <String>{'all'};
    topics.add(
      profile.role == StudentRole.teacher ? 'teachers' : 'students',
    );
    if (profile.role == StudentRole.student) {
      topics.add('form-${profile.form}');
    }
    return topics.toList();
  }

  Future<void> _registerDeviceToken(String token) async {
    if (!isSignedIn) return;
    try {
      await _api?.registerDevice(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : 'other',
        appVersion: '1.0.0',
      );
    } catch (error) {
      // Push registration must never block the app; the token is retried on
      // the next launch, token refresh or manual sync.
      debugPrint('Could not register the push token: $error');
    }
  }

  Future<void> signOut() async {
    // Leaving on purpose: nothing to explain on the gate afterwards.
    _sessionEndedReason = null;

    if (isSignedIn) {
      try {
        await _api?.logout();
      } catch (_) {
        // Signing out must work offline; the token is discarded locally.
      }

      // Stop this device from receiving another account's notifications.
      final push = _push;
      if (push != null) {
        await push.leaveTopics(_audienceTopics());
        final token = push.token;
        if (token != null) {
          try {
            await _api?.removeDevice(token);
          } catch (_) {
            // The server also drops tokens that FCM reports as unregistered.
          }
        }
      }
    }

    _token = null;

    // The next person to hold this phone must not inherit a name, a school or
    // an open profile: logging out is the end of the session, not a pause.
    // Library files stay on disk — they are only reachable after signing in.
    // A fresh snapshot, not just a fresh profile: progress, notes, saved
    // classes and the record of downloaded papers all belonged to the person who
    // just left. Theme and the weekly goal are device settings and stay.
    final theme = _snapshot.profile.theme;
    final weeklyGoal = _snapshot.profile.weeklyGoalMinutes;
    _snapshot = AppSnapshot(
      profile: Profile(
        examYear: _clock().year + 1,
        subjectIds: subjectsForForm(4).map((subject) => subject.id).toList(),
        theme: theme,
        weeklyGoalMinutes: weeklyGoal,
      ),
    );
    _account = null;
    _api?.token = null;
    await _tokenStore.clear();
    stopAutoSync();

    _snapshot
      ..accountId = null
      ..accountName = null
      ..accountEmail = null
      ..accountPlan = null
      ..accountSchool = null
      ..pendingPaymentTxRef = null
      ..pendingPaymentKind = null
      ..pendingPaymentAt = null;
    _syncError = null;
    _notifications = const <AppNotification>[];

    notifyListeners();
    await _persistNow();
  }

  // ---------------------------------------------------------------------------
  // Billing and subscriptions
  // ---------------------------------------------------------------------------

  /// Loads the reflowable version of a document, keeping a copy on the phone.
  ///
  /// A connection failure falls back to that copy, so a paper already opened
  /// stays readable in a blackout. A refusal does not: 401, 403 and the
  /// entitlement failures must still reach the learner, or a lapsed subscription
  /// would keep serving papers from the cache.
  Future<LoadedBlockDocument> loadBlockDocument(String documentId) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to read this paper.');
    }

    try {
      final document = await _api!.fetchBlockDocument(documentId);
      await _blockCache?.write(documentId, document);
      if (_savedOffline.add(documentId)) notifyListeners();
      return LoadedBlockDocument(document);
    } on ApiException catch (error) {
      final offline = error.isNetworkError || (error.statusCode ?? 0) >= 500;
      if (offline) {
        final cached = await _blockCache?.read(documentId);
        if (cached != null) return LoadedBlockDocument(cached, fromCache: true);
      }
      rethrow;
    }
  }

  /// True when this document can be opened without a connection — a saved
  /// structured paper or a downloaded file.
  bool savedOffline(String documentId) =>
      _savedOffline.contains(documentId) || assetFor(documentId)?.path != null;

  /// Pulls the recent messages addressed to this learner's audiences. A failure
  /// keeps whatever was already loaded: an inbox must not break the app when a
  /// school has no signal.
  Future<void> loadNotifications() async {
    if (!isSignedIn) return;
    try {
      final items = await _api!.fetchNotifications();
      _notifications = items;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load notifications: $error');
    }
  }

  Future<void> loadBilling() async {
    if (!isSignedIn) return;
    _billingError = null;
    try {
      final (plans, status, payments, account) = await (
        _api!.fetchPlans(),
        _api!.fetchBillingStatus(),
        _api!.fetchPayments(),
        _api!.me(),
      ).wait;
      _plans = plans;
      _billing = status;
      _payments = payments;
      _account = account;
      _snapshot
        ..accountName = account.name
        ..accountEmail = account.email
        ..accountPlan = account.plan
        ..accountSchool = account.school
        ..accountStaff = account.isStaff;

      // /me carries the same account payload as login, which settles a cold
      // start that restored an older snapshot: the role, the form, and whether
      // onboarding was ever finished. Without this a teacher who signed in
      // before this release kept the learner's screen until they next signed in.
      final role = account.role == null
          ? profile.role
          : (account.isTeacher ? StudentRole.teacher : StudentRole.student);
      final form = account.form ?? profile.form;
      final completed = profile.onboardingComplete || account.profileCompleted;
      if (profile.role != role || profile.form != form || profile.onboardingComplete != completed) {
        _snapshot.profile = profile.copyWith(
          role: role,
          form: form,
          onboardingComplete: completed,
        );
      }

      _billingError = null;
      _schedulePersist();
      notifyListeners();
    } on ApiException catch (error) {
      // The subscription page needs to hear about this: it used to keep a
      // spinner turning for ever when the plans never arrived.
      _billingError = error.message;
      notifyListeners();
    } catch (error) {
      _billingError = 'Could not reach the library. Check the connection and try again.';
      debugPrint('Could not load billing: $error');
      notifyListeners();
    }
  }

  Future<CheckoutSession> startPlanCheckout(RemotePlan plan) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to subscribe.');
    }
    final session = await _api!.checkoutPlan(plan.id);
    await _rememberPending(session);
    return session;
  }

  Future<CheckoutSession> startDocumentCheckout(String documentId) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to buy this document.');
    }
    final session = await _api!.checkoutDocument(documentId);
    await _rememberPending(session);
    return session;
  }

  Future<PaymentStatus> verifyPayment(String txRef) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to check the payment.');
    }
    final status = await _api!.paymentStatus(txRef);
    if (status.isComplete) {
      await _clearPendingPayment(txRef);
      await loadBilling();
      await syncNow();
    }
    return status;
  }

  /// Called when the app returns to the foreground. A learner may have paid in
  /// the browser after closing the payment sheet; the reference survives a
  /// restart, so the entitlement can still be confirmed.
  Future<PaymentStatus?> resumePendingPayment() async {
    if (!isSignedIn) return null;
    final txRef = _snapshot.pendingPaymentTxRef;
    if (txRef == null || txRef.isEmpty) return null;

    final startedAt = _snapshot.pendingPaymentAt;
    if (startedAt != null && _clock().difference(startedAt) > const Duration(hours: 48)) {
      await clearPendingPayment();
      return null;
    }

    try {
      final status = await _api!.paymentStatus(txRef);
      if (status.isComplete) {
        await _clearPendingPayment(txRef);
        await loadBilling();
        await syncNow();
      }
      return status;
    } on ApiException {
      // Offline or provider unavailable: keep the reference and retry later.
      return null;
    }
  }

  Future<void> clearPendingPayment() async {
    _snapshot
      ..pendingPaymentTxRef = null
      ..pendingPaymentKind = null
      ..pendingPaymentAt = null;
    notifyListeners();
    await _persistNow();
  }

  Future<void> _rememberPending(CheckoutSession session) async {
    _snapshot
      ..pendingPaymentTxRef = session.txRef
      ..pendingPaymentKind = session.kind
      ..pendingPaymentAt = _clock();
    notifyListeners();
    await _persistNow();
  }

  Future<void> _clearPendingPayment(String txRef) async {
    if (_snapshot.pendingPaymentTxRef == txRef) {
      await clearPendingPayment();
    }
  }

  // ---------------------------------------------------------------------------
  // Offline library sync
  // ---------------------------------------------------------------------------

  /// Replaces the stored classes with the service's copy, keeping the flags only
  /// this phone knows — whether a learner has finished an assignment.
  Future<void> _refreshClassrooms(ApiClient api) async {
    try {
      final classrooms = await api.fetchClassrooms();
      final done = {
        for (final assignment in _snapshot.assignments)
          if (assignment.completed) assignment.id,
      };

      _snapshot.classes
        ..clear()
        ..addAll(classrooms.map((classroom) => classroom.group));

      _snapshot.assignments
        ..clear()
        ..addAll(
          classrooms.expand(
            (classroom) => classroom.assignments.map(
              (assignment) => done.contains(assignment.id)
                  ? assignment.copyWith(completed: true)
                  : assignment,
            ),
          ),
        );
    } on ApiException {
      // A class list is not worth failing a sync over: the stored copy stands.
    }
  }

  /// Refreshes the catalogue, then makes every marked document match the
  /// server: new marks download, newer versions replace older ones, and marks
  /// removed elsewhere delete their local file. A failed item never removes a
  /// working copy.
  Future<void> syncNow({bool silent = false}) async {
    if (_syncing) return;

    if (!isSignedIn) {
      if (!silent) {
        _syncError = 'Sign in to sync the library.';
        notifyListeners();
      }
      return;
    }

    _syncing = true;
    _syncError = null;
    notifyListeners();

    final api = _api!;
    var failed = 0;

    try {
      await _flushPendingRemovals(api);

      // Classes change in a staffroom, not on this phone: a sync is the only
      // way a learner sees a paper set for them since they last opened the app.
      await _refreshClassrooms(api);

      final catalogue = await api.fetchDocuments();
      _remoteCatalogue = catalogue;
      _entitled.clear();
      for (final item in catalogue) {
        _entitled[item.document.id] = item.isEntitled;
      }
      _snapshot.remoteDocuments
        ..clear()
        ..addAll(catalogue.map((item) => item.document));
      for (final item in catalogue) {
        if (item.file != null) _remoteVersions[item.document.id] = item.file!.version;
      }
      _recomputeDocuments();
      notifyListeners();

      final offline = await api.fetchOffline();
      _snapshot.offlineMarked
        ..clear()
        ..addAll(offline.map((item) => item.documentId));

      for (final item in offline) {
        if (item.file != null) _remoteVersions[item.documentId] = item.file!.version;
        _entitled[item.documentId] = item.isEntitled;
      }

      final actions = planOfflineSync(remote: offline, local: _snapshot.assets);

      for (final action in actions) {
        try {
          if (action.isDownload) {
            await _downloadAction(api, action);
          } else {
            await _removeLocalOnly(action.documentId);
          }
        } on ApiException catch (error) {
          failed++;
          _downloadErrors[action.documentId] = error.message;
        } catch (error) {
          failed++;
          _downloadErrors[action.documentId] = 'Sync failed: $error';
        }
      }

      _snapshot.lastSyncAt = _clock();
      if (failed > 0) {
        _syncError = '$failed document${failed == 1 ? '' : 's'} could not be downloaded.';
      }
    } on ApiException catch (error) {
      _syncError = error.message;
      if (error.isUnauthorized) {
        // Keep downloaded files: losing a session must not lose reading access.
        // The token is dead because the password was changed on another phone,
        // so say that rather than silently emptying the shell.
        _endSession(
          'This phone was signed out. If you changed your password, sign in with the new one.',
        );
        await _tokenStore.clear();
      }
    } catch (error) {
      _syncError = 'Sync failed: $error';
    } finally {
      _syncing = false;
      await _persistNow();
      notifyListeners();
    }
  }

  Future<void> _flushPendingRemovals(ApiClient api) async {
    if (_snapshot.pendingRemovals.isEmpty) return;
    final pending = List<String>.from(_snapshot.pendingRemovals);
    for (final id in pending) {
      try {
        await api.removeOffline(id);
        _snapshot.pendingRemovals.remove(id);
      } on ApiException catch (error) {
        if (error.statusCode == 404) {
          _snapshot.pendingRemovals.remove(id);
        } else if (error.isNetworkError) {
          break;
        }
      }
    }
  }

  Future<void> _downloadAction(ApiClient api, OfflineAction action) async {
    final file = action.file;
    final url = action.downloadUrl;
    if (file == null || url == null || url.isEmpty) return;

    final id = action.documentId;
    _downloading.add(id);
    _downloadProgress[id] = 0;
    _downloadErrors.remove(id);
    notifyListeners();

    try {
      final bytes = await api.download(
        url,
        onProgress: (progress) {
          final previous = _downloadProgress[id] ?? 0;
          if (progress >= 1 || progress - previous >= 0.02) {
            _downloadProgress[id] = progress;
            notifyListeners();
          }
        },
      );

      if (file.sizeBytes > 0 && bytes.length != file.sizeBytes) {
        throw const ApiException('The download was incomplete. Try again.');
      }

      final digest = sha256.convert(bytes).toString();
      if (file.checksum.isNotEmpty && digest != file.checksum) {
        throw const ApiException('The downloaded file failed its integrity check.');
      }

      final previous = _snapshot.assets[id];
      final asset = await _files.storeBytes(
        documentId: id,
        fileName: file.fileName,
        bytes: bytes,
        version: file.version,
        checksum: file.checksum,
        pageCount: file.pageCount,
      );

      // Only replace the working copy after the new bytes are safely stored.
      if (previous != null && previous.path != null && previous.path != asset.path) {
        await _files.delete(previous);
      }

      _snapshot.assets[id] = asset;
      _snapshot.offlineMarked.add(id);
      _remoteVersions[id] = file.version;

      try {
        await api.acknowledge(id, file.version);
      } on ApiException {
        // The local copy is valid; the acknowledgement will retry next sync.
      }

      await _persistNow();
    } finally {
      _downloading.remove(id);
      _downloadProgress.remove(id);
      notifyListeners();
    }
  }

  Future<void> _removeLocalOnly(String documentId) async {
    final asset = _snapshot.assets[documentId];
    if (asset != null && asset.remote) {
      await _files.delete(asset);
      _snapshot.assets.remove(documentId);
    }
    _snapshot.offlineMarked.remove(documentId);
    _remoteVersions.remove(documentId);
  }

  /// Explicitly marks a document for offline reading and downloads it now.
  Future<void> markForOffline(String documentId) async {
    if (!isSignedIn) {
      throw const ApiException('Sign in to download documents for offline reading.');
    }
    final api = _api!;
    final item = await api.markOffline(documentId);

    _snapshot.offlineMarked.add(documentId);
    final file = item.file;
    if (file == null) {
      throw const ApiException(
        'The library has no file for this document yet. It will download when one is published.',
        statusCode: 409,
      );
    }

    _remoteVersions[documentId] = file.version;
    await _downloadAction(
      api,
      OfflineAction(
        type: OfflineActionType.download,
        documentId: documentId,
        version: file.version,
        downloadUrl: item.downloadUrl,
        file: file,
      ),
    );
    await _persistNow();
    notifyListeners();
  }

  /// Re-downloads a marked document, keeping the old copy until verification.
  Future<void> refreshOffline(String documentId) => markForOffline(documentId);

  /// Removes the file and the mark. Works offline by queueing the server call.
  Future<void> removeOffline(String documentId, {bool removeFromServer = true}) async {
    await _removeLocalOnly(documentId);

    if (removeFromServer && isSignedIn) {
      try {
        await _api!.removeOffline(documentId);
      } on ApiException catch (error) {
        if (error.isNetworkError) {
          if (!_snapshot.pendingRemovals.contains(documentId)) {
            _snapshot.pendingRemovals.add(documentId);
          }
          _syncError = 'Removal saved. It will reach the library on the next sync.';
        } else if (error.statusCode != 404) {
          _downloadErrors[documentId] = error.message;
        }
      }
    }

    await _persistNow();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  Future<void> resetEverything() async {
    await _tokenStore.clear();
    _token = null;
    _account = null;
    _api?.token = null;
    stopAutoSync();
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
    _autoSyncTimer?.cancel();
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

