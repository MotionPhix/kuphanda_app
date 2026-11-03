import '../models/classroom.dart';
import '../models/document.dart';

/// Everything the API returns about one published file. Immutable, because a
/// new upload is always a new version rather than an edit of this one.
class RemoteFile {
  const RemoteFile({
    required this.version,
    required this.fileName,
    required this.sizeBytes,
    required this.pageCount,
    required this.checksum,
    required this.publishedAt,
  });

  final int version;
  final String fileName;
  final int sizeBytes;
  final int pageCount;
  final String checksum;
  final DateTime publishedAt;

  static RemoteFile fromJson(Map<String, Object?> json) {
    return RemoteFile(
      version: (json['number'] as num?)?.toInt() ?? 1,
      fileName: (json['file_name'] as String?) ?? 'document.pdf',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      pageCount: (json['page_count'] as num?)?.toInt() ?? 1,
      checksum: (json['checksum'] as String?) ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class RemoteDocument {
  const RemoteDocument({
    required this.document,
    this.file,
    this.isEntitled = false,
    this.priceMwk = 0,
  });

  final Document document;
  final RemoteFile? file;
  final bool isEntitled;
  final int priceMwk;

  bool get hasFile => file != null;

  static RemoteDocument fromJson(Map<String, Object?> json) {
    final versionJson = json['current_version'];
    final subject = json['subject'] as Map<String, Object?>?;

    final document = Document(
      id: json['id']! as String,
      title: (json['title'] as String?) ?? 'Untitled',
      subjectId: (json['subject_id'] as String?) ?? (subject?['id'] as String?) ?? 'mathematics',
      form: (json['form'] as num?)?.toInt() ?? 1,
      kind: DocumentKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => DocumentKind.other,
      ),
      description: (json['description'] as String?) ?? '',
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      addedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      author: (json['author'] as String?) ?? 'Kuphanda Library',
      publisher: json['publisher'] as String?,
      year: (json['year'] as num?)?.toInt(),
      paperNumber: (json['paper_number'] as num?)?.toInt(),
      session: json['session'] as String?,
      totalMarks: (json['total_marks'] as num?)?.toInt(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      accessTier: AccessTier.fromName(json['access_tier'] as String?),
      featured: json['featured'] as bool? ?? false,
      guideId: json['guide_id'] as String?,
      language: (json['language'] as String?) ?? 'English',
      tags: (json['tags'] as List<Object?>?)?.map((tag) => tag.toString()).toList() ??
          const <String>[],
      // Without these two the catalogue silently treated a structured paper as
      // a catalogue-only record with no file, so it could not be opened.
      format: (json['format'] as String?) ?? 'pdf',
      hasBlocks: json['has_blocks'] as bool? ?? false,
      questionCount: (json['questions'] as num?)?.toInt(),
      blockMarks: (json['block_marks'] as num?)?.toInt(),
    );

    return RemoteDocument(
      document: document,
      file: versionJson is Map<String, Object?> ? RemoteFile.fromJson(versionJson) : null,
      isEntitled: json['is_entitled'] as bool? ?? false,
      priceMwk: (json['price_mwk'] as num?)?.toInt() ?? 0,
    );
  }
}

class RemoteOfflineItem {
  const RemoteOfflineItem({
    required this.documentId,
    required this.document,
    required this.file,
    required this.downloadedVersion,
    required this.updateAvailable,
    required this.downloadUrl,
    required this.markedAt,
    this.isEntitled = false,
  });

  final String documentId;
  final Document? document;
  final RemoteFile? file;
  final int? downloadedVersion;
  final bool updateAvailable;
  final String downloadUrl;
  final DateTime markedAt;
  final bool isEntitled;

  /// True when the server has no current file (unpublished or a missing
  /// version), so the mark cannot be satisfied.
  bool get isUnavailable => file == null;

  bool isCurrentFor(int? localVersion) =>
      file != null && localVersion != null && localVersion >= file!.version;

  static RemoteOfflineItem fromJson(Map<String, Object?> json) {
    final documentJson = json['document'];
    final versionJson = json['current_version'];

    return RemoteOfflineItem(
      documentId: (json['document_id'] as String?) ??
          (documentJson is Map<String, Object?> ? documentJson['id'] as String? : null) ??
          '',
      document: documentJson is Map<String, Object?>
          ? RemoteDocument.fromJson(documentJson).document
          : null,
      file: versionJson is Map<String, Object?> ? RemoteFile.fromJson(versionJson) : null,
      downloadedVersion: (json['downloaded_version'] as num?)?.toInt(),
      updateAvailable: json['update_available'] as bool? ?? false,
      downloadUrl: (json['download_url'] as String?) ?? '',
      markedAt: DateTime.tryParse(json['marked_at'] as String? ?? '') ?? DateTime.now(),
      isEntitled: json['is_entitled'] as bool? ?? false,
    );
  }
}

class RemoteSyncResult {
  const RemoteSyncResult({
    required this.documents,
    required this.removed,
    required this.serverTime,
  });

  final List<RemoteOfflineItem> documents;
  final List<String> removed;
  final DateTime serverTime;

  static RemoteSyncResult fromJson(Map<String, Object?> json) {
    final items = (json['documents'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(RemoteOfflineItem.fromJson)
        .toList();
    final removed = (json['removed'] as List<Object?>? ?? const <Object?>[])
        .map((id) => id.toString())
        .toList();

    return RemoteSyncResult(
      documents: items,
      removed: removed,
      serverTime: DateTime.tryParse(json['server_time'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.plan,
    this.school,
    this.firstName = '',
    this.lastName = '',
    this.avatarUrl,
    this.googleLinked = false,
    this.isStaff = false,
    this.role,
    this.form,
    this.profileCompleted = false,
  });

  final String token;
  final int userId;
  final String name;
  final String email;
  final String plan;
  final String? school;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final bool googleLinked;
  final bool isStaff;

  /// 'student' or 'teacher' — the server's copy of the answer onboarding asks
  /// once, so a returning account is not asked again on another phone.
  ///
  /// Null when the payload did not say (an older server, or a reply that is not
  /// an account). That must never be read as "student": it would demote a
  /// teacher on the next refresh.
  final String? role;

  /// The school form a learner sits in. Teachers have none.
  final int? form;

  /// True once the account has answered onboarding (name, role, and form for a
  /// learner). Only a genuinely new account is sent through it.
  final bool profileCompleted;

  bool get isTeacher => role == 'teacher';

  bool get isSchoolPlan => plan == 'school';

  Map<String, Object?> toJson() => <String, Object?>{
        'user_id': userId,
        'name': name,
        'email': email,
        'plan': plan,
        'school': school,
        'first_name': firstName,
        'last_name': lastName,
        'avatar_url': avatarUrl,
        'google_linked': googleLinked,
        'is_staff': isStaff,
        'role': role,
        'form': form,
        'profile_completed': profileCompleted,
      };

  static AuthSession fromJson(Map<String, Object?> json, {required String token}) {
    return AuthSession(
      token: token,
      userId: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      plan: (json['plan'] as String?) ?? 'free',
      school: json['school'] as String?,
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      googleLinked: json['google_linked'] as bool? ?? false,
      isStaff: json['is_staff'] as bool? ?? false,
      role: json['role'] as String?,
      form: (json['form'] as num?)?.toInt(),
      profileCompleted: json['profile_completed'] as bool? ?? false,
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// A purchasable subscription plan from the server.
class RemotePlan {
  const RemotePlan({
    required this.id,
    required this.slug,
    required this.name,
    required this.tier,
    required this.priceMwk,
    required this.durationDays,
    this.description,
  });

  final int id;
  final String slug;
  final String name;
  final AccessTier tier;
  final int priceMwk;
  final int durationDays;
  final String? description;

  static RemotePlan fromJson(Map<String, Object?> json) {
    return RemotePlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Plan',
      tier: AccessTier.fromName(json['tier'] as String?),
      priceMwk: (json['price_mwk'] as num?)?.toInt() ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
    );
  }
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.plan,
    required this.tier,
    required this.endsAt,
    required this.status,
  });

  final String plan;
  final AccessTier tier;
  final DateTime? endsAt;
  final String status;

  bool get isActive => status == 'active' && (endsAt == null || endsAt!.isAfter(DateTime.now()));

  static SubscriptionInfo fromJson(Map<String, Object?> json) {
    return SubscriptionInfo(
      plan: (json['plan'] as String?) ?? 'Subscription',
      tier: AccessTier.fromName(json['tier'] as String?),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      status: (json['status'] as String?) ?? 'active',
    );
  }
}

class BillingStatus {
  const BillingStatus({
    required this.tier,
    required this.plan,
    required this.purchases,
    this.subscription,
  });

  final AccessTier tier;
  final String plan;
  final Set<String> purchases;
  final SubscriptionInfo? subscription;

  bool get hasPaidAccess => tier.rank > 0 || purchases.isNotEmpty;

  static BillingStatus fromJson(Map<String, Object?> json) {
    return BillingStatus(
      tier: AccessTier.fromName(json['tier'] as String?),
      plan: (json['plan'] as String?) ?? 'free',
      purchases: (json['purchases'] as List<Object?>? ?? const <Object?>[])
          .map((id) => id.toString())
          .toSet(),
      subscription: json['subscription'] is Map<String, Object?>
          ? SubscriptionInfo.fromJson(json['subscription'] as Map<String, Object?>)
          : null,
    );
  }
}

class CheckoutSession {
  const CheckoutSession({
    required this.txRef,
    required this.checkoutUrl,
    required this.amountMwk,
    required this.kind,
  });

  final String txRef;
  final String checkoutUrl;
  final int amountMwk;
  final String kind;

  static CheckoutSession fromJson(Map<String, Object?> json) {
    return CheckoutSession(
      txRef: (json['tx_ref'] as String?) ?? '',
      checkoutUrl: (json['checkout_url'] as String?) ?? '',
      amountMwk: (json['amount_mwk'] as num?)?.toInt() ?? 0,
      kind: (json['kind'] as String?) ?? 'subscription',
    );
  }
}

class PaymentStatus {
  const PaymentStatus({required this.txRef, required this.status, required this.kind});

  final String txRef;
  final String status;
  final String kind;

  bool get isComplete => status == 'paid' || status == 'active';

  static PaymentStatus fromJson(Map<String, Object?> json) {
    return PaymentStatus(
      txRef: (json['tx_ref'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      kind: (json['kind'] as String?) ?? 'subscription',
    );
  }
}

/// A subscription or single-document purchase, as shown in receipts.
class PaymentRecord {
  const PaymentRecord({
    required this.txRef,
    required this.kind,
    required this.title,
    required this.amountMwk,
    required this.status,
    this.createdAt,
    this.paidAt,
    this.endsAt,
    this.documentId,
  });

  final String txRef;
  final String kind;
  final String title;
  final int amountMwk;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? endsAt;
  final String? documentId;

  bool get isSubscription => kind == 'subscription';
  bool get isSettled => status == 'paid' || status == 'active';

  static PaymentRecord fromJson(Map<String, Object?> json) {
    return PaymentRecord(
      txRef: (json['tx_ref'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'subscription',
      title: (json['title'] as String?) ?? 'Payment',
      amountMwk: (json['amount_mwk'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      documentId: json['document_id'] as String?,
    );
  }
}

class StaffVersion {
  const StaffVersion({
    required this.number,
    required this.fileName,
    required this.sizeBytes,
    required this.pageCount,
    required this.checksum,
    this.mediaId,
    this.notes,
    this.publishedAt,
  });

  final int number;
  final String fileName;
  final int sizeBytes;
  final int pageCount;
  final String checksum;
  final int? mediaId;
  final String? notes;
  final DateTime? publishedAt;

  factory StaffVersion.fromJson(Map<String, Object?> json) => StaffVersion(
        number: (json['number'] as num?)?.toInt() ?? 0,
        fileName: (json['file_name'] as String?) ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
        checksum: (json['checksum'] as String?) ?? '',
        mediaId: (json['media_id'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      );
}

class StaffDocument {
  const StaffDocument({
    required this.id,
    required this.title,
    required this.isPublished,
    required this.latestVersion,
    required this.pages,
    required this.versionCount,
    this.subject,
    this.form,
    this.kind,
    this.currentVersion,
  });

  final String id;
  final String title;
  final String? subject;
  final int? form;
  final String? kind;
  final bool isPublished;
  final int latestVersion;
  final int pages;
  final int versionCount;
  final StaffVersion? currentVersion;

  factory StaffDocument.fromJson(Map<String, Object?> json) => StaffDocument(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        subject: json['subject'] as String?,
        form: (json['form'] as num?)?.toInt(),
        kind: json['kind'] as String?,
        isPublished: json['is_published'] as bool? ?? false,
        latestVersion: (json['latest_version'] as num?)?.toInt() ?? 0,
        pages: (json['pages'] as num?)?.toInt() ?? 0,
        versionCount: (json['version_count'] as num?)?.toInt() ?? 0,
        currentVersion: json['current_version'] is Map<String, Object?>
            ? StaffVersion.fromJson(json['current_version']! as Map<String, Object?>)
            : null,
      );
}

/// A message the library or a teacher sent, as returned by /me/notifications.
/// Mirrors the push payload so a learner can re-read it in the app.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.sentAt,
  });

  final int id;
  final String category;
  final String title;
  final String body;
  final DateTime? sentAt;

  factory AppNotification.fromJson(Map<String, Object?> json) {
    return AppNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? ''),
    );
  }
}

/// A class as the service returns it: the class itself plus what was set for it.
class RemoteClassroom {
  const RemoteClassroom({required this.group, required this.assignments});

  final ClassGroup group;
  final List<Assignment> assignments;

  factory RemoteClassroom.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String? ?? '';
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now();

    final assignments = (json['assignments'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(
          (row) => Assignment(
            id: row['id'] as String? ?? '',
            classId: id,
            documentId: row['document_id'] as String? ?? '',
            dueDate: DateTime.tryParse(row['due_date'] as String? ?? ''),
            // The server now knows what this learner has finished, so a paper
            // read on one device is not "unread" on the next.
            completed: row['completed'] as bool? ?? false,
            createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? createdAt,
            note: row['title'] as String? ?? '',
          ),
        )
        .toList();

    return RemoteClassroom(
      group: ClassGroup(
        id: id,
        name: json['name'] as String? ?? 'Class',
        code: json['code'] as String? ?? '',
        form: (json['form'] as num?)?.toInt() ?? 4,
        subjectId: json['subject_id'] as String? ?? 'mathematics',
        teacherName: json['teacher_name'] as String? ?? 'Teacher',
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        isMine: json['is_owner'] as bool? ?? false,
        createdAt: createdAt,
      ),
      assignments: assignments,
    );
  }
}

/// One line of a teacher's class report: a paper they set, and how many of the
/// class have finished it.
class ReportedAssignment {
  const ReportedAssignment({
    required this.id,
    required this.documentId,
    required this.completedCount,
    this.title,
    this.dueDate,
  });

  factory ReportedAssignment.fromJson(Map<String, Object?> json) => ReportedAssignment(
        id: json['id'] as String,
        documentId: json['document_id'] as String? ?? '',
        title: json['title'] as String?,
        dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
        completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String documentId;
  final String? title;
  final DateTime? dueDate;
  final int completedCount;
}

/// One learner in a class, with the assignments they have finished.
class ReportedLearner {
  const ReportedLearner({
    required this.id,
    required this.name,
    required this.completedAssignmentIds,
  });

  factory ReportedLearner.fromJson(Map<String, Object?> json) => ReportedLearner(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        completedAssignmentIds: [
          for (final id in (json['completed_assignment_ids'] as List<Object?>? ?? const []))
            id as String,
        ],
      );

  final int id;
  final String name;
  final List<String> completedAssignmentIds;

  bool hasFinished(String assignmentId) => completedAssignmentIds.contains(assignmentId);
}

class ClassReport {
  const ClassReport({
    required this.assignments,
    required this.learners,
    required this.assignmentCount,
    required this.learnerCount,
  });

  factory ClassReport.fromJson(Map<String, Object?> json) => ClassReport(
        assignments: [
          for (final item in (json['assignments'] as List<Object?>? ?? const []))
            ReportedAssignment.fromJson(item as Map<String, Object?>),
        ],
        learners: [
          for (final item in (json['learners'] as List<Object?>? ?? const []))
            ReportedLearner.fromJson(item as Map<String, Object?>),
        ],
        assignmentCount: (json['assignment_count'] as num?)?.toInt() ??
            (json['assignments'] as List<Object?>? ?? const []).length,
        learnerCount: (json['learner_count'] as num?)?.toInt() ??
            (json['learners'] as List<Object?>? ?? const []).length,
      );

  final List<ReportedAssignment> assignments;
  final List<ReportedLearner> learners;
  final int assignmentCount;
  final int learnerCount;
}
