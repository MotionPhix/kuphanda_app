/// A structured study guide, built from Geli's curriculum knowledge graph.
///
/// Geli's `subtopics` carried learning objectives, key ideas, common mistakes,
/// difficulty and an estimated study time. Those are far more useful on a
/// phone than an unindexed PDF, so a guide is a first-class readable document
/// in this app: one page per subtopic.
class StudyGuide {
  const StudyGuide({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.blurb,
    required this.sections,
  });

  final String id;
  final String subjectId;
  final String title;
  final String blurb;
  final List<GuideSection> sections;

  int get pageCount => sections.length;

  int get estimatedMinutes =>
      sections.fold<int>(0, (total, section) => total + section.minutes);
}

class GuideSection {
  const GuideSection({
    required this.id,
    required this.title,
    required this.objectives,
    required this.keyIdeas,
    required this.mistakes,
    required this.minutes,
    required this.difficulty,
  });

  final String id;
  final String title;
  final List<String> objectives;
  final List<String> keyIdeas;
  final List<String> mistakes;
  final int minutes;

  /// 1 (introductory) to 5 (demanding).
  final int difficulty;

  String get difficultyLabel => switch (difficulty) {
        1 => 'Introductory',
        2 => 'Foundation',
        3 => 'Standard',
        4 => 'Demanding',
        _ => 'Challenge',
      };
}
