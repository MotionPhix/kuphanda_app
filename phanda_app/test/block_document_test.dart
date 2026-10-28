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
  });
}
