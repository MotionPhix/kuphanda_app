import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
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

    // Signed in: the details step is behind the sign-in gate now.
    final store = MemoryStateStore();
    await store.write(AppSnapshot(
      accountId: 1,
      accountEmail: 'learner@kuphanda.test',
      profile: const Profile(examYear: 2027),
    ));
    // A signed-in start reaches for billing and the catalogue; a stub keeps the
    // test about layout rather than the network.
    final state = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: MemoryTokenStore('token'),
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        httpClient: MockClient((request) async => http.Response(
              '{"data":[]}',
              200,
              headers: {'content-type': 'application/json'},
            )),
      ),
    );
    await state.initialize();
    // A signed-in start arms the fifteen-minute auto-sync timer; this test is
    // about layout, so stop it rather than fail on a pending timer at teardown.
    state.stopAutoSync();

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

  testWidgets('the payment line under Get started is not glued to it',
      (tester) async {
    _phoneWithSystemBar(tester);

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
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final button = tester.getRect(find.widgetWithText(FilledButton, 'Get started'));
    final footnote = tester.getRect(
      find.text('Mobile money payments · Powered by PayChangu'),
    );

    // Removing the sign-in shortcut left the footnote hard against the button;
    // it belongs to the page, not to the button's lower edge.
    expect(footnote.top - button.bottom, greaterThanOrEqualTo(12),
        reason: 'only ${footnote.top - button.bottom} dp between the button and '
            'the payment line');
    expect(footnote.top - button.bottom, lessThan(40),
        reason: 'the footnote drifted ${footnote.top - button.bottom} dp away');
  });
}
