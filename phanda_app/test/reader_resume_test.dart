import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/reader/block_reader_screen.dart';
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

/// A paper long enough that half way down is genuinely a different question.
Map<String, Object?> _longPaper() => {
      'title': 'Long paper',
      'subtitle': 'Structured.',
      'blocks': [
        for (var i = 1; i <= 24; i++)
          {
            'type': 'question',
            'label': '$i.',
            'marks': 4,
            'text': 'Question number $i, with enough words to take up space on '
                'the screen so the list has to measure each block separately.',
            'parts': const <Object?>[],
          },
      ],
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<AppState> _stateWithProgress(double fraction) async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/auth/google')) {
      return _json({
        'token': 'test-token',
        'user': {'id': 5, 'name': 'Test', 'email': 'test@kuphanda.test'},
      });
    }
    return _json({'data': _longPaper()});
  });

  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    api: ApiClient(baseUrl: 'https://example.test/api/v1', token: null, httpClient: client),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();
  await state.signInWithGoogle('google-id-token', sync: false);
  state.stopAutoSync();

  state.recordProgress(
    documentId: 'ref-msce-maths-2002-p1',
    page: 1,
    totalPages: 6,
    fraction: fraction,
  );
  return state;
}

Widget _reader(AppState state) => AppScope(
      state: state,
      child: const MaterialApp(
        home: BlockReaderScreen(documentId: 'ref-msce-maths-2002-p1'),
      ),
    );

void main() {
  testWidgets('reopening a paper resumes where the learner stopped',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _stateWithProgress(0.5);
    await tester.pumpWidget(_reader(state));
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    expect(position.pixels, greaterThan(0),
        reason: 'a saved position must scroll the list away from the top');
    // Halfway through a 24-question paper is not question 1.
    expect(find.text('1.'), findsNothing);
  });

  testWidgets('a paper never opened still starts at the first question',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _stateWithProgress(0);
    await tester.pumpWidget(_reader(state));
    await tester.pumpAndSettle();

    expect(find.text('1.'), findsOneWidget);
  });

  testWidgets('a finished paper opens at the start rather than its last line',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _stateWithProgress(1.0);
    await tester.pumpWidget(_reader(state));
    await tester.pumpAndSettle();

    expect(find.text('1.'), findsOneWidget);
  });
}
