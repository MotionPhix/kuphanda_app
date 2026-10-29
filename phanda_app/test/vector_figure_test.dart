import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/features/reader/block_document_view.dart';

void main() {
  test('the redrawn pie chart is valid SVG', () {
    final source =
        File('assets/samples/figures/fig1-pie-chart.svg').readAsStringSync();

    expect(source, contains('<svg'));
    expect(source, contains('slice-tobacco'));
    // Guards against a vector export that quietly grew a raster payload.
    expect(source.length, lessThan(20000));
  });

  testWidgets('a vector figure renders without throwing on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final document = BlockDocument(
      title: 'Figure check',
      blocks: const [
        DocumentBlock(
          type: 'question',
          page: 1,
          raw: {
            'text': 'Figure 1 is a pie-chart of three commodities.',
            'marks': 4,
            'figure': {
              'asset': 'assets/samples/figures/fig1-pie-chart.svg',
              'alt': 'Pie chart: tobacco 208, tea 107',
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
