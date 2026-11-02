import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/features/onboarding/onboarding_screen.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
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
  testWidgets('a revoked session is explained on the gate, not thrown away',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // The phone still holds a token; the server has already revoked it, which
    // is what happens when the password is changed somewhere else.
    // Everything answers normally until the server revokes the token, which is
    // what a password change on another phone does.
    var revoked = false;
    final client = MockClient((request) async {
      if (revoked) {
        return http.Response(
          jsonEncode({'success': false, 'message': 'Unauthenticated.'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final store = MemoryStateStore(
      AppSnapshot(
        accountId: 7,
        accountEmail: 'learner@kuphanda.test',
        accountName: 'Learner',
        profile: const Profile(name: 'Learner One', givenName: 'Learner', familyName: 'One', onboardingComplete: true),
      ),
    );
    final tokens = MemoryTokenStore('revoked-token');

    final state = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: tokens,
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        token: 'revoked-token',
        httpClient: client,
      ),
    );
    await state.initialize();
    state.stopAutoSync();

    // The gate itself is what this checks, so the shell is not pumped: it would
    // only be torn down again a moment later.
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(state.isSignedIn, isTrue);

    revoked = true;
    await state.syncNow();
    await tester.pumpAndSettle();

    expect(state.isSignedIn, isFalse);
    // The library is still readable offline; the session is what ended.
    expect(
      find.textContaining('This phone was signed out'),
      findsOneWidget,
      reason: 'the gate should say why the app went back to the landing page',
    );
  });
}




