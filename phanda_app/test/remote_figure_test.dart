import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/features/reader/block_document_view.dart';

/// A figure fetched from the API. In a widget test every HTTP request answers
/// 400, which is exactly the failure a learner sees with no data — so these
/// tests pin the degraded path, not the happy one.
Future<void> _pump(WidgetTester tester, List<DocumentBlock> blocks) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlockDocumentView(
          document: BlockDocument(title: 'Remote figure', blocks: blocks),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a figure with a url degrades to a placeholder, not a crash',
      (tester) async {
    await _pump(tester, const [
      DocumentBlock(
        type: 'figure',
        page: 1,
        raw: {
          'text': 'Figure 8: cells X and Y',
          'figure': {
            'url': 'https://app.kuphanda.com/media/figures/bio-cells.svg',
            'alt': 'Two cell outlines',
          },
        },
      ),
    ]);

    expect(tester.takeException(), isNull);
    // The caption still identifies what is missing, rather than the block
    // vanishing or printing a bare error.
    expect(find.text('Figure 8: cells X and Y'), findsWidgets);
    expect(find.textContaining('Figure not included'), findsNothing);
  });

  testWidgets('a raster url is handled the same way', (tester) async {
    await _pump(tester, const [
      DocumentBlock(
        type: 'figure',
        page: 1,
        raw: {
          'figure': {
            'url': 'https://app.kuphanda.com/media/figures/heart.png',
            'alt': 'Heart diagram',
          },
        },
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Heart diagram'), findsWidgets);
  });

  testWidgets('a question can attach a remote figure', (tester) async {
    await _pump(tester, const [
      DocumentBlock(
        type: 'question',
        page: 1,
        raw: {
          'label': '1',
          'text': 'Study the diagram and name the parts.',
          'marks': 4,
          'figure': {
            'url': 'https://app.kuphanda.com/media/figures/frog.svg',
            'alt': 'Frog with right leg labelled',
          },
        },
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Study the diagram and name the parts.'), findsOneWidget);
    expect(find.textContaining('Figure not included'), findsNothing);
  });

  testWidgets('a figure with neither url nor asset still says so',
      (tester) async {
    await _pump(tester, const [
      DocumentBlock(
        type: 'figure',
        page: 1,
        raw: {'figure': <String, Object?>{}},
      ),
    ]);

    expect(find.textContaining('not included'), findsOneWidget);
  });
}
