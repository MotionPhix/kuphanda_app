import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/features/reader/block_document_view.dart';

/// Figures the renderer cannot draw correctly, expressed as SVG elements.
///
/// `flutter_svg` does not implement these; it logs `unhandled element` and
/// paints the figure without them. That is how the tobacco sector of the pie
/// chart lost its stipple and how the dimension arrows on the parallel-lines
/// figure lost their heads — both silently, both only visible on a device.
final _unsupported = RegExp(
  r'<(marker|pattern|mask|filter|foreignObject|image)\b',
  caseSensitive: false,
);

/// Every SVG a sample paper actually points at.
Set<String> _referencedFigures() {
  final references = <String>{};
  final pattern = RegExp(r'"asset":\s*"([^"]+\.svg)"');

  for (final paper in Directory('assets/samples').listSync()) {
    if (paper is! File || !paper.path.endsWith('.json')) continue;
    for (final match in pattern.allMatches(paper.readAsStringSync())) {
      references.add(match.group(1)!);
    }
  }

  return references;
}

void main() {
  test('no paper references a figure flutter_svg would half-draw', () {
    final references = _referencedFigures();
    expect(references, isNotEmpty, reason: 'the papers point at no figures');

    for (final asset in references) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: '$asset is referenced but missing');

      final source = file.readAsStringSync();
      final hit = _unsupported.firstMatch(source);

      expect(
        hit,
        isNull,
        reason: '$asset uses <${hit?.group(1)}>, which flutter_svg drops '
            'without failing — bake the effect into geometry instead',
      );
      expect(source, contains('viewBox'),
          reason: '$asset must scale from its viewBox, not a fixed pixel size');
    }
  });

  testWidgets('a referenced vector figure renders on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final document = BlockDocument(
      title: 'Figure check',
      blocks: const [
        DocumentBlock(
          type: 'question',
          page: 7,
          raw: {
            'text': 'The diagram shows four parallel lines crossed by QR and SU.',
            'marks': 4,
            'figure': {
              'asset': 'assets/samples/figures/fig5-parallel-lines.svg',
              'alt': 'Four parallel lines AB, CD, EF, GH with transversals QR and SU',
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
