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
import 'package:kuphanda/features/profile/profile_screen.dart';
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
  testWidgets('the profile stats do not tower over the numbers in them',
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
        home: const ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final tiles = find.byType(StatTile);
    expect(tiles, findsWidgets);

    // Three short lines: a label, a number and a caption. Anything over ~110 dp
    // is padding pretending to be content.
    for (var index = 0; index < tiles.evaluate().length; index++) {
      final height = tester.getSize(tiles.at(index)).height;
      expect(height, lessThanOrEqualTo(110), reason: 'tile $index was $height dp');
    }
  });

  testWidgets('the About section clears the navigation bar', (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    // 48 dp of navigation bar, and a status bar above.
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 96);
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
        home: const ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Scroll to the end of the page, where the About card is.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    const navigationBar = 48.0;
    final last = find.textContaining('remain the property of MANEB');
    expect(last, findsOneWidget);

    final rect = tester.getRect(last);
    expect(rect.bottom, lessThanOrEqualTo(screen - navigationBar),
        reason: 'the last About paragraph ended at ${rect.bottom} dp with the '
            'navigation bar starting at ${screen - navigationBar} dp');
    expect(rect.top, greaterThan(0));
  });
}
