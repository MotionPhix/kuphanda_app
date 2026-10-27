import 'package:flutter/material.dart';

/// A secondary-school subject offered in Malawian schools.
///
/// Forms run 1–4: Forms 1–2 sit the JCE (junior certificate), Forms 3–4 the
/// MSCE (Malawi School Certificate of Education). Subjects therefore carry the
/// forms they are actually taught in rather than a single "level" flag.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.shortName,
    required this.emoji,
    required this.color,
    required this.forms,
    required this.blurb,
  });

  final String id;
  final String name;
  final String shortName;
  final String emoji;
  final Color color;
  final List<int> forms;
  final String blurb;

  bool isTaughtIn(int form) => forms.contains(form);

  /// Qualification a Form sits: JCE for Forms 1–2, MSCE for Forms 3–4.
  static String qualificationForForm(int form) => form <= 2 ? 'JCE' : 'MSCE';
}

/// The 14 subjects seeded from the Kuphanda catalogue, ordered so the core
/// examinable subjects appear first.
const List<Subject> kSubjects = <Subject>[
  Subject(
    id: 'mathematics',
    name: 'Mathematics',
    shortName: 'Maths',
    emoji: '📐',
    color: Color(0xFF2F6B9A),
    forms: [1, 2, 3, 4],
    blurb: 'Number, algebra, geometry, trigonometry and statistics, with '
        'past-paper drills for JCE and MSCE.',
  ),
  Subject(
    id: 'biology',
    name: 'Biology',
    shortName: 'Biology',
    emoji: '🧬',
    color: Color(0xFF2E7D4F),
    forms: [3, 4],
    blurb: 'Cells, genetics, ecology and human systems, with Malawi-specific '
        'examples for MSCE Paper 2.',
  ),
  Subject(
    id: 'physical-science',
    name: 'Physical Science',
    shortName: 'Science',
    emoji: '⚗️',
    color: Color(0xFF4B7A8A),
    forms: [1, 2],
    blurb: 'Combined physics and chemistry for JCE: measurement, matter, '
        'forces, energy and simple circuits.',
  ),
  Subject(
    id: 'chemistry',
    name: 'Chemistry',
    shortName: 'Chemistry',
    emoji: '🧪',
    color: Color(0xFF8A5A2B),
    forms: [3, 4],
    blurb: 'Atomic structure, moles, reactions, organic chemistry and the '
        'practical skills MSCE candidates are examined on.',
  ),
  Subject(
    id: 'physics',
    name: 'Physics',
    shortName: 'Physics',
    emoji: '🔭',
    color: Color(0xFF4C5B9A),
    forms: [3, 4],
    blurb: 'Mechanics, waves, electricity and modern physics, taught through '
        'worked MANEB-style questions.',
  ),
  Subject(
    id: 'english',
    name: 'English',
    shortName: 'English',
    emoji: '📖',
    color: Color(0xFF8C3A52),
    forms: [1, 2, 3, 4],
    blurb: 'Comprehension, summary, composition and literature set books for '
        'JCE and MSCE.',
  ),
  Subject(
    id: 'chichewa',
    name: 'Chichewa',
    shortName: 'Chichewa',
    emoji: '🗣️',
    color: Color(0xFF9A5B2F),
    forms: [1, 2, 3, 4],
    blurb: 'Galamala, ndakatulo, nkhani ndi mawu a m\u2019mabuku a Chichewa.',
  ),
  Subject(
    id: 'geography',
    name: 'Geography',
    shortName: 'Geography',
    emoji: '🌍',
    color: Color(0xFF2F7A6B),
    forms: [1, 2, 3, 4],
    blurb: 'Physical and human geography, map work and Malawi case studies.',
  ),
  Subject(
    id: 'history',
    name: 'History',
    shortName: 'History',
    emoji: '🏛️',
    color: Color(0xFF7A5B3A),
    forms: [1, 2, 3, 4],
    blurb: 'Malawian, African and world history with model essay structures.',
  ),
  Subject(
    id: 'agriculture',
    name: 'Agriculture',
    shortName: 'Agriculture',
    emoji: '🌾',
    color: Color(0xFF5C7A2F),
    forms: [1, 2, 3, 4],
    blurb: 'Crop and livestock production tuned to the Malawian syllabus and '
        'smallholder practice.',
  ),
  Subject(
    id: 'computer-studies',
    name: 'Computer Studies',
    shortName: 'Computing',
    emoji: '💻',
    color: Color(0xFF3F6E8C),
    forms: [3, 4],
    blurb: 'Computer systems, data representation, networks and spreadsheets '
        'for MSCE.',
  ),
  Subject(
    id: 'business-studies',
    name: 'Business Studies',
    shortName: 'Business',
    emoji: '📊',
    color: Color(0xFF7A6B2F),
    forms: [3, 4],
    blurb: 'Business ownership, finance, marketing and commerce for MSCE.',
  ),
  Subject(
    id: 'religious-studies',
    name: 'Religious Studies',
    shortName: 'RE',
    emoji: '🕊️',
    color: Color(0xFF6A5B8C),
    forms: [1, 2, 3, 4],
    blurb: 'Christianity and Islam in Malawi: scripture, ethics and practice.',
  ),
  Subject(
    id: 'social-studies',
    name: 'Social Studies',
    shortName: 'Social',
    emoji: '🌐',
    color: Color(0xFF8C6A3A),
    forms: [1, 2],
    blurb: 'Civics, culture, community life and Malawi\u2019s place in the '
        'world for JCE.',
  ),
];

Subject subjectById(String id) =>
    kSubjects.firstWhere((subject) => subject.id == id, orElse: () => kSubjects.first);

Subject? subjectByIdOrNull(String id) {
  for (final subject in kSubjects) {
    if (subject.id == id) return subject;
  }
  return null;
}

List<Subject> subjectsForForm(int form) =>
    kSubjects.where((subject) => subject.isTaughtIn(form)).toList(growable: false);
