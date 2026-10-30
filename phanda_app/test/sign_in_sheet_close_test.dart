import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/onboarding/onboarding_screen.dart';
import 'package:kuphanda/state/app_state.dart';

class _NoFiles implements DocumentFiles {
  @override
  Future<PickedPdf?> pickPdf() async => null;
  @override
  Future<DocumentAsset> store({
    required String documentId,
    required PickedPdf picked,
  }) async =>
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
  testWidgets('closing the sign-in sheet leaves the onboarding screen usable',
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
    state.stopAutoSync();

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);

    // The phone raises the keyboard over the sheet and drops it again while the
    // sheet is still open; the inset coming and going is what the phone does
    // before Cancel is ever tapped.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // The gate is still there, and nothing threw while the sheet went away.
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
