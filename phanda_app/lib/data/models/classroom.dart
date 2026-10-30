import 'subject.dart';

/// A class group.
///
/// The reference products disagreed here: Kuphanda's classrooms joined people
/// by matching an existing account's email (silently skipping anyone without
/// one), while Geli generated a short join code. The school design document is
/// explicit that email must be optional in Malawi, so the join-code path is the
/// one carried forward. A class is a delivery and reporting unit, not a live
/// chat room.
class ClassGroup {
  const ClassGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.form,
    required this.subjectId,
    required this.teacherName,
    required this.memberCount,
    required this.createdAt,
    this.isMine = false,
  });

  final String id;
  final String name;
  final String code;
  final int form;
  final String subjectId;
  final String teacherName;
  final int memberCount;
  final DateTime createdAt;

  /// True when the learner created the class (they act as the teacher).
  final bool isMine;

  String get qualification => Subject.qualificationForForm(form);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'code': code,
        'form': form,
        'subjectId': subjectId,
        'teacherName': teacherName,
        'memberCount': memberCount,
        'createdAt': createdAt.toIso8601String(),
        'isMine': isMine,
      };

  static ClassGroup fromJson(Map<String, Object?> json) {
    return ClassGroup(
      id: json['id']! as String,
      name: json['name']! as String,
      code: json['code']! as String,
      form: (json['form'] as num?)?.toInt() ?? 1,
      subjectId: (json['subjectId'] as String?) ?? 'mathematics',
      teacherName: (json['teacherName'] as String?) ?? 'Teacher',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isMine: json['isMine'] as bool? ?? false,
    );
  }
}

/// A directed reading task: "read this document by this date".
///
/// Kuphanda's classroom_assignments shape was kept; submissions and grading
/// were deliberately not ported (they are the LMS trap the design document
/// warns about, and they duplicate free products).
class Assignment {
  const Assignment({
    required this.id,
    required this.classId,
    required this.documentId,
    this.dueDate,
    required this.createdAt,
    this.note = '',
    this.completed = false,
  });

  final String id;
  final String classId;
  final String documentId;
  /// Null when the teacher set the paper without a deadline.
  final DateTime? dueDate;
  final DateTime createdAt;
  final String note;
  final bool completed;

  Assignment copyWith({bool? completed, DateTime? dueDate, String? note}) {
    return Assignment(
      id: id,
      classId: classId,
      documentId: documentId,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      note: note ?? this.note,
      completed: completed ?? this.completed,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'classId': classId,
        'documentId': documentId,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'completed': completed,
      };

  static Assignment fromJson(Map<String, Object?> json) {
    return Assignment(
      id: json['id']! as String,
      classId: json['classId']! as String,
      documentId: json['documentId']! as String,
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      note: (json['note'] as String?) ?? '',
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Presentation helpers that depend on "today" — kept pure for testing.
class AssignmentStatus {
  const AssignmentStatus({required this.label, required this.daysLeft, required this.urgent});

  final String label;
  final int daysLeft;
  final bool urgent;
}

AssignmentStatus assignmentStatus(Assignment assignment, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final due = _dateOnly(assignment.dueDate ?? today);
  final days = due.difference(today).inDays;

  if (assignment.completed) {
    return const AssignmentStatus(label: 'Done', daysLeft: 0, urgent: false);
  }
  if (assignment.dueDate == null) {
    // A teacher may set reading without a deadline; saying "due" would be
    // inventing one.
    return const AssignmentStatus(label: 'No due date', daysLeft: 999, urgent: false);
  }
  if (days < 0) {
    return AssignmentStatus(
      label: days == -1 ? '1 day overdue' : '${-days} days overdue',
      daysLeft: days,
      urgent: true,
    );
  }
  if (days == 0) {
    return const AssignmentStatus(label: 'Due today', daysLeft: 0, urgent: true);
  }
  if (days == 1) {
    return const AssignmentStatus(label: 'Due tomorrow', daysLeft: 1, urgent: true);
  }
  if (days <= 7) {
    return AssignmentStatus(label: 'Due in $days ${days == 1 ? 'day' : 'days'}', daysLeft: days, urgent: false);
  }
  return AssignmentStatus(label: 'Due in $days ${days == 1 ? 'day' : 'days'}', daysLeft: days, urgent: false);
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
