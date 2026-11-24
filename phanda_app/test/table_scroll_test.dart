import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/features/reader/block_document_view.dart';

/// A data question from the Mathematics guide: five columns, one of which holds
/// prose. This is the shape that used to be crushed into the card.
const _wideRows = [
  ['Month', 'Snacks (MWK)', 'Drinks (MWK)', 'Stationery (MWK)', 'Note'],
  ['January', '48 000', '36 000', '12 000', 'Opening month'],
  ['February', '52 000', '40 000', '8 000', 'Half term'],
  ['March', '45 000', '39 000', '16 000', 'Examinations'],
];

Future<void> _pumpTable(WidgetTester tester, List<List<String>> rows) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final document = BlockDocument(
    title: 'Table check',
    blocks: [
      DocumentBlock(
        type: 'table',
        page: 1,
        raw: {'rows': rows},
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: BlockDocumentView(document: document))),
  );
  await tester.pumpAndSettle();
}

ScrollableState _horizontalScrollable(WidgetTester tester) {
  return tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((state) => state.position.axis == Axis.horizontal);
}

void main() {
  testWidgets('a wide table scrolls sideways instead of squeezing the columns',
      (tester) async {
    await _pumpTable(tester, _wideRows);

    // The content is wider than the 360pt screen, so the table must offer the
    // overflow as a scroll rather than compressing five columns into the card.
    final scrollable = _horizontalScrollable(tester);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    // Nothing overflowed its box: an unbounded Row would have thrown here.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a header is never wrapped or clipped', (tester) async {
    await _pumpTable(tester, _wideRows);

    final header = tester.widget<Text>(find.text('Stationery (MWK)'));

    expect(header.softWrap, isFalse);
    expect(header.maxLines, 1);
  });

  testWidgets('the reader is told the table continues', (tester) async {
    await _pumpTable(tester, _wideRows);

    expect(find.text('Swipe the table to see every column'), findsOneWidget);
  });

  testWidgets('a table that fits is left alone', (tester) async {
    await _pumpTable(tester, [
      ['Form', 'Papers'],
      ['1', '12'],
      ['2', '9'],
    ]);

    expect(_horizontalScrollable(tester).position.maxScrollExtent, 0);
    // No hint and no fade when there is nothing to scroll to.
    expect(find.text('Swipe the table to see every column'), findsNothing);
  });

  testWidgets('ragged rows are padded instead of throwing', (tester) async {
    // A transcription that lost a cell must still render: Table requires every
    // row to have the same number of children.
    await _pumpTable(tester, [
      ['A', 'B', 'C'],
      ['1', '2'],
      ['3', '4', '5'],
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
  });
}
