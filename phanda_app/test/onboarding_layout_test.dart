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

/// A 720x1640 phone at 2x with a 48 dp gesture bar, which is what the device
/// reports — the inset that used to be counted twice.
void _phoneWithSystemBar(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1640);
  tester.view.devicePixelRatio = 2.0;
  tester.view.padding = const FakeViewPadding(bottom: 96); // 48 dp
  addTearDown(tester.view.reset);
}

Future<void> _toSubjectsStep(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Get started'));
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Chisomo');
  await tester.enterText(find.widgetWithText(TextField, 'Last name'), 'Banda');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the subjects step leaves no dead band under the button',
      (tester) async {
    _phoneWithSystemBar(tester);

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const OnboardingScreen(),
        ),
      ),
    );

    await _toSubjectsStep(tester);

    expect(find.text('Pick your subjects'), findsOneWidget);

    // Content bottom = screen height minus the system bar the SafeArea reserved.
    const contentBottom = 820.0 - 48.0;
    final caption = tester.getRect(
      find.text('You can add more subjects whenever you like.'),
    );

    // 16 dp of padding below the caption, and nothing else.
    expect(
      contentBottom - caption.bottom,
      lessThanOrEqualTo(20),
      reason: 'the footer reserved the system inset a second time '
          '(gap was ${contentBottom - caption.bottom} dp)',
    );
    expect(contentBottom - caption.bottom, greaterThan(8));
  });
}
