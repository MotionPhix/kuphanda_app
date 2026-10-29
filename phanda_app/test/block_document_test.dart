import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/features/reader/block_document_view.dart';

void main() {
  group('BlockDocument', () {
    test('parses the pilot sample', () {
      final source =
          File('assets/samples/mechanics_sample.json').readAsStringSync();
      final document = BlockDocument.fromJsonString(source);

      expect(document.title, contains('Mechanics'));
      expect(document.blocks, isNotEmpty);
      expect(document.blocks.first.type, 'heading');

      final question = document.blocks.firstWhere((b) => b.type == 'question');
      expect(question.marks, 4);
      expect(question.parts, hasLength(2));
      expect(question.parts.first.label, '(a)');
      expect(question.items.first, contains('a ='));
    });

    test('keeps unknown block types instead of dropping them', () {
      final source =
          File('assets/samples/mechanics_sample.json').readAsStringSync();
      final document = BlockDocument.fromJsonString(source);

      final extension = document.blocks.firstWhere((b) => b.type == 'extension');
      expect(extension.page, 3);
      expect(extension.text, isNotEmpty);
    });

    test('rejects a document that is not a JSON object', () {
      expect(() => BlockDocument.fromJsonString('[]'), throwsFormatException);
    });
  });

  group('BlockDocumentView', () {
    testWidgets('renders headings and paragraphs', (tester) async {
      const document = BlockDocument(
        title: 'Test paper',
        blocks: [
          DocumentBlock(type: 'heading', raw: {'text': 'Section A'}),
          DocumentBlock(
            type: 'paragraph',
            raw: {'text': 'Answer all questions.'},
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
      );

      expect(find.text('Test paper'), findsOneWidget);
      expect(find.text('Section A'), findsOneWidget);
      expect(find.text('Answer all questions.'), findsOneWidget);
    });

    testWidgets('falls back to the original page for unknown blocks',
        (tester) async {
      const document = BlockDocument(
        title: 'Future document',
        blocks: [
          DocumentBlock(type: 'hologram', page: 3, raw: <String, Object?>{}),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
      );

      expect(
        find.text('Open the original page 3 to read this part.'),
        findsOneWidget,
      );
    });

    testWidgets('reveals the marking guide only when asked', (tester) async {
      const document = BlockDocument(
        title: 'Q1',
        blocks: [
          DocumentBlock(
            type: 'question',
            raw: {
              'label': 'Question 1',
              'marks': 2,
              'text': 'State the principle of conservation of momentum.',
              'items': ['Total momentum before = total momentum after'],
            },
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BlockDocumentView(document: document)),
        ),
      );

      expect(find.text('Marking guide'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlockDocumentView(document: document, showAnswers: true),
          ),
        ),
      );

      expect(find.text('Marking guide'), findsOneWidget);
    });

    test('structures the real MSCE paper without inventing marks', () {
      final source =
          File('assets/samples/msce-maths-2002-p1.json').readAsStringSync();
      final document = BlockDocument.fromJsonString(source);

      final questions =
          document.blocks.where((b) => b.type == 'question').toList();

      expect(questions, hasLength(24));
      // Stem text must be present for every question.
      expect(questions.every((q) => q.text.isNotEmpty), isTrue);

      final marks = questions.map((q) => q.marks).whereType<int>();
      expect(marks.reduce((a, b) => a + b), lessThanOrEqualTo(100));
      // Two questions had their marks cut off in the scan and stay empty.
      expect(questions.where((q) => q.marks == null), hasLength(2));
    });

    test('flags the one question the scan obscured', () {
      final source =
          File('assets/samples/msce-maths-2002-p1.json').readAsStringSync();
      final document = BlockDocument.fromJsonString(source);

      final flagged =
          document.blocks.where((b) => b.raw['needs_review'] == true).toList();

      expect(flagged, hasLength(1));
      expect(flagged.single.label, '5.');
      expect(flagged.single.raw['review_note'], isNotNull);
    });
    testWidgets('lays out the full sample on a small phone without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final source =
          File('assets/samples/mechanics_sample.json').readAsStringSync();
      final document = BlockDocument.fromJsonString(source);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlockDocumentView(document: document, showAnswers: true),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Scroll the whole document; any RenderFlex overflow throws here.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders nested parts and indents each level', (tester) async {
      const document = BlockDocument(
        title: 'Q7',
        blocks: [
          DocumentBlock(
            type: 'question',
            raw: {
              'label': '7.',
              'marks': 6,
              'text': 'Table 1 shows farm gate and retail prices.',
              'parts': [
                {
                  'label': 'i.',
                  'text': 'Calculate the marketing margins:',
                  'parts': [
                    {'label': '(1)', 'text': 'Irish potatoes', 'marks': 2},
                    {'label': '(2)', 'text': 'Onions.', 'marks': 2},
                  ],
                },
                {
                  'label': 'ii.',
                  'text': '',
                  'parts': [
                    {
                      'label': '(1)',
                      'text': 'Which produce has the smaller margin?',
                      'marks': 1,
                    },
                    {
                      'label': '(2)',
                      'text': 'State one possible cause.',
                      'marks': 1,
                    },
                  ],
                },
              ],
            },
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
      );

      expect(find.text('i.'), findsOneWidget);
      expect(find.text('ii.'), findsOneWidget);
      // Both sub-lists share the same labels, so each appears twice.
      expect(find.text('(1)'), findsNWidgets(2));
      expect(find.text('(2)'), findsNWidgets(2));
      expect(find.text('6 marks'), findsOneWidget);

      // The second level must be visibly inset, otherwise a learner cannot tell
      // (1) from (2) apart from i.
      final parentLeft =
          tester.getTopLeft(find.text('Calculate the marketing margins:')).dx;
      final childLeft = tester.getTopLeft(find.text('Irish potatoes')).dx;
      expect(childLeft, greaterThan(parentLeft));

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not invent a mark for a container part', (tester) async {
      const document = BlockDocument(
        title: 'Q3',
        blocks: [
          DocumentBlock(
            type: 'question',
            raw: {
              'label': '3.',
              'marks': 2,
              'text': 'Seed treatment for pasture.',
              'parts': [
                {
                  'label': 'a.',
                  'text': 'Importance of each:',
                  'marks': null,
                  'parts': [
                    {'label': 'i.', 'text': 'Scarification', 'marks': 2},
                  ],
                },
              ],
            },
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
      );

      expect(find.text('2 marks'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the table a question refers to', (tester) async {
      const document = BlockDocument(
        title: 'Q7',
        blocks: [
          DocumentBlock(
            type: 'question',
            raw: {
              'label': '7.',
              'marks': 6,
              'text': 'Table 1 shows farm gate and retail prices.',
              'table': {
                'rows': [
                  ['Produce', 'Farm gate price (MK/kg)', 'Retail Price (MK/kg)'],
                  ['Irish potatoes', '350.00', '700.00'],
                  ['Onions', '600.00', '750.00'],
                ],
              },
              'parts': [
                {'label': 'i.', 'text': 'Calculate the marketing margins.', 'marks': 4},
              ],
            },
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
      );

      expect(find.text('Farm gate price (MK/kg)'), findsOneWidget);
      expect(find.text('Irish potatoes'), findsOneWidget);
      expect(find.text('750.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
