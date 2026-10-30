import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/classes/classes_screen.dart';
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

Future<AppState> _readyState({bool signedIn = false}) async {
  if (!signedIn) {
    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();
    return state;
  }

  // The details step sits behind the account now, so a test that wants to see
  // the form has to start the way a signed-in learner does: an account, a
  // token, and a stub API so the start-up fetch does not reach the network.
  final store = MemoryStateStore();
  await store.write(AppSnapshot(
    accountId: 1,
    accountEmail: 'learner@kuphanda.test',
    profile: const Profile(examYear: 2027),
  ));
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
  state.stopAutoSync();
  return state;
}

void main() {
  testWidgets('onboarding asks for and confirms first and last name', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await _readyState(signedIn: true);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Who should we call you?'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    // With an account behind the form the Google button has done its job; the
    // line names the account the details will be saved to instead.
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.textContaining('Signed in as'), findsOneWidget);
  });

  testWidgets('students do not get a create-class action', (tester) async {
    final state = await _readyState();
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(body: ClassesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsNothing);
    expect(find.text('Create a class'), findsNothing);
    expect(find.text('Join'), findsOneWidget);
  });
}

