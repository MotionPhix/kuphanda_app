import '../models/classroom.dart';

/// Two classes the learner is enrolled in, plus the assignments teachers have
/// set. Codes are deliberately short and readable — the join-code path is the
/// one that works for students who have no email address.
class SeedClassrooms {
  const SeedClassrooms(this.classes, this.assignments);

  final List<ClassGroup> classes;
  final List<Assignment> assignments;
}

SeedClassrooms buildSeedClassrooms({DateTime? now}) {
  final today = now ?? DateTime.now();
  final date = DateTime(today.year, today.month, today.day);

  final classes = <ClassGroup>[
    ClassGroup(
      id: 'class-f4a-sciences',
      name: 'Form 4A — Sciences',
      code: 'KPH4A2',
      form: 4,
      subjectId: 'biology',
      teacherName: 'Mr B. Banda',
      memberCount: 38,
      createdAt: today.subtract(const Duration(days: 64)),
    ),
    ClassGroup(
      id: 'class-f4a-maths',
      name: 'Form 4A — Mathematics',
      code: 'KPH4M8',
      form: 4,
      subjectId: 'mathematics',
      teacherName: 'Mrs T. Chirwa',
      memberCount: 41,
      createdAt: today.subtract(const Duration(days: 64)),
    ),
    ClassGroup(
      id: 'class-f2b-maths',
      name: 'Form 2B — Mathematics',
      code: 'KPH2B7',
      form: 2,
      subjectId: 'mathematics',
      teacherName: 'Mr S. Kamanga',
      memberCount: 44,
      createdAt: today.subtract(const Duration(days: 51)),
    ),
  ];

  final assignments = <Assignment>[
    Assignment(
      id: 'asg-bio-p2',
      classId: 'class-f4a-sciences',
      documentId: 'ref-msce-biology-2023-paper2',
      dueDate: date.add(const Duration(days: 3)),
      createdAt: date.subtract(const Duration(days: 4)),
      note: 'Read sections A and B, then answer questions 1–4 in your exercise book.',
    ),
    Assignment(
      id: 'asg-chem-organic',
      classId: 'class-f4a-sciences',
      documentId: 'guide-chem-organic',
      dueDate: date.add(const Duration(days: 6)),
      createdAt: date.subtract(const Duration(days: 3)),
      note: 'Learn the general formulas before Thursday. We will do a timed question in class.',
    ),
    Assignment(
      id: 'asg-phys-mechanics',
      classId: 'class-f4a-sciences',
      documentId: 'ref-msce-physics-mechanics',
      dueDate: date.add(const Duration(days: 10)),
      createdAt: date.subtract(const Duration(days: 2)),
      note: 'Work through the momentum examples and mark them yourself.',
    ),
    Assignment(
      id: 'asg-maths-2024-p2',
      classId: 'class-f4a-maths',
      documentId: 'paper-msce-mathematics-2024-p2',
      dueDate: date.add(const Duration(days: 2)),
      createdAt: date.subtract(const Duration(days: 5)),
      note: 'Full paper under exam conditions: 150 minutes, no notes.',
    ),
    Assignment(
      id: 'asg-maths-planner',
      classId: 'class-f4a-maths',
      documentId: 'sample-planner',
      dueDate: date.add(const Duration(days: 7)),
      createdAt: date.subtract(const Duration(days: 1)),
      note: 'Fill in your week and bring it to the next lesson.',
    ),
    Assignment(
      id: 'asg-jce-toolkit',
      classId: 'class-f2b-maths',
      documentId: 'ref-jce-mathematics-toolkit',
      dueDate: date.add(const Duration(days: 1)),
      createdAt: date.subtract(const Duration(days: 6)),
      note: 'Chapter 2 exercises 1–10. Show all working.',
    ),
  ];

  return SeedClassrooms(classes, assignments);
}
