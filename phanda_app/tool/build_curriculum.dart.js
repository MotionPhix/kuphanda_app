// Generates lib/data/seed/curriculum_seed.dart from the curriculum graph
// extracted out of the Geli reference project (src/lib/curriculum.ts).
// Run: node tool/build_curriculum.dart.js
const fs = require('fs');
const path = require('path');

const data = require('./curriculum_raw.json');

const subjectMap = {
  'biology-msce': 'biology',
  'chemistry-msce': 'chemistry',
  'mathematics-msce': 'mathematics',
  'physics-msce': 'physics',
};

const dart = (value) => JSON.stringify(value).replace(/\$/g, '\\$');

const list = (values) => `<String>[${values.map(dart).join(', ')}]`;

const topics = [...data.topics].sort((a, b) => a.order - b.order);

const guides = topics.map((topic) => {
  const sections = data.subtopics
    .filter((subtopic) => subtopic.topicId === topic.id)
    .sort((a, b) => a.order - b.order)
    .map(
      (section) => `      GuideSection(
        id: ${dart(section.id)},
        title: ${dart(section.name)},
        objectives: ${list(section.learningObjectives)},
        keyIdeas: ${list(section.keyIdeas)},
        mistakes: ${list(section.commonMistakes)},
        minutes: ${section.estimatedMinutes},
        difficulty: ${section.difficulty},
      ),`,
    )
    .join('\n');

  return `  StudyGuide(
    id: ${dart(topic.id)},
    subjectId: ${dart(subjectMap[topic.subjectSlug] || 'biology')},
    title: ${dart(topic.name)},
    blurb: ${dart(topic.blurb)},
    sections: <GuideSection>[
${sections}
    ],
  ),`;
});

const output = `// GENERATED FILE — do not edit by hand.
// Source: Geli curriculum graph (src/lib/curriculum.ts), 37 subtopics across
// Biology, Chemistry, Mathematics and Physics.
// Regenerate with: node tool/build_curriculum.dart.js

import '../models/study_guide.dart';

const List<StudyGuide> kStudyGuides = <StudyGuide>[
${guides.join('\n')}
];

StudyGuide? findStudyGuide(String? id) {
  if (id == null) return null;
  for (final guide in kStudyGuides) {
    if (guide.id == id) return guide;
  }
  return null;
}

List<StudyGuide> guidesForSubject(String subjectId) =>
    kStudyGuides.where((guide) => guide.subjectId == subjectId).toList(growable: false);
`;

const target = path.join(__dirname, '..', 'lib', 'data', 'seed', 'curriculum_seed.dart');
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, output, 'utf8');
console.log('Wrote', target, 'with', guides.length, 'guides');
