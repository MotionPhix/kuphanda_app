// Dumps the bundled curriculum guides as JSON for the API catalogue seeder.
//
// The guides are authored once, in `curriculum_seed.dart`, and their sections
// ship inside the app. The API still has to know they exist, otherwise an online
// learner sees a smaller library than an offline one. Rather than retype fifteen
// titles into PHP — where they would drift — the seeder reads this dump.
//
// Usage, from phanda_app/:
//   dart run tool/dump_guides.dart ../phanda_api/database/seeders/files/guides.json
import 'dart:convert';
import 'dart:io';

import 'package:kuphanda/data/seed/curriculum_seed.dart';

void main(List<String> args) {
  final guides = <Map<String, Object?>>[];

  for (final guide in kStudyGuides) {
    guides.add(<String, Object?>{
      'id': guide.id,
      'subject_id': guide.subjectId,
      'title': guide.title,
      'blurb': guide.blurb,
      'pages': guide.pageCount,
      'sections': guide.sections.map((section) => section.title).toList(),
    });
  }

  final encoded = const JsonEncoder.withIndent('  ').convert({'guides': guides});

  if (args.isEmpty) {
    stdout.writeln(encoded);
    return;
  }

  File(args.first).writeAsStringSync('$encoded\n');
  stdout.writeln('Wrote ${guides.length} guides to ${args.first}');
}
