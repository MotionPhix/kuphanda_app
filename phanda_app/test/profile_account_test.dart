import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/api_client.dart';
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

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<AppState> _state({bool signedIn = false}) async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/auth/google')) {
      return _json({
        'token': 'test-token',
        'user': {'id': 5, 'name': 'Chisomo Banda', 'email': 'aishootsmo@gmail.com'},
      });
    }
    return _json({'data': []});
  });

  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    api: ApiClient(baseUrl: 'https://example.test/api/v1', token: null, httpClient: client),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();

  if (signedIn) {
    await state.signInWithGoogle('google-id-token', sync: false);
  }
  state.stopAutoSync();
  return state;
}

Widget _wrap(AppState state) => AppScope(
      state: state,
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const ProfileScreen()),
    );

void main() {
  testWidgets('a signed-out learner is offered a way to sign in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _state();
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Tap to sign in and sync your progress'), findsOneWidget);
  });

  testWidgets('signing out says what survives and can be cancelled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _state(signedIn: true);
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.text('Signed in'), findsOneWidget);

    await tester.tap(find.text('Signed in'));
    await tester.pumpAndSettle();

    // The point of the copy: the downloaded papers survive, the reading does
    // not — saying the progress stays would be a promise the sign-out breaks.
    expect(find.text('Sign out?'), findsOneWidget);
    expect(find.textContaining('Downloaded papers stay on this phone'), findsOneWidget);
    expect(find.textContaining('reading progress, classes and notes'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(state.isSignedIn, isTrue);
  });
}
