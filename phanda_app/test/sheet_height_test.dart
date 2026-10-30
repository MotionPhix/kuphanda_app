import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/core/widgets/common.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/classes/classes_screen.dart';
import 'package:kuphanda/state/app_state.dart';

class _NoFiles implements DocumentFiles {
  @override
  Future<PickedPdf?> pickPdf() async => null;
  @override
  Future<DocumentAsset> store({required String documentId, required PickedPdf picked}) async =>
      throw UnimplementedError();
  @override
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  }) async =>
      throw UnimplementedError();
  @override
  Future<void> delete(DocumentAsset asset) async {}
}

void main() {
  testWidgets('a short sheet takes the height of its content, not the screen',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: ClassesScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // The join form is four short widgets; it used to be padded out to a full
    // screen of sheet with empty space under the buttons.
    await tester.tap(find.text('Join a class').first);
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byType(SheetBody));
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;

    expect(sheet.height, lessThan(screen * 0.6),
        reason: 'the sheet was ${sheet.height} dp tall on an $screen dp screen');
    expect(sheet.height, greaterThan(200), reason: 'the form still has to fit');

    // A short sheet is only right if the form is actually in it: the first
    // attempt at this sized the sheet by collapsing the field to nothing.
    final field = tester.getRect(find.byType(TextField));
    expect(field.height, greaterThan(40), reason: 'the code field must be visible');
    expect(find.text('Class code'), findsOneWidget);
    expect(field.bottom, lessThan(sheet.bottom));
  });

  testWidgets('a sheet does not reserve the keyboard twice', (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    // 300 dp of keyboard, and the route already lifts the sheet above it.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.reset);

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: ClassesScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join a class').first);
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byType(SheetBody));
    final field = tester.getRect(find.byType(TextField));

    // The form, not the form plus a keyboard's worth of padding.
    expect(sheet.height, lessThan(500),
        reason: 'sheet was ${sheet.height} dp with the keyboard up');
    expect(field.height, greaterThan(40));
  });
}
