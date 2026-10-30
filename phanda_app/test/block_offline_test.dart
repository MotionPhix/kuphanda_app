import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/features/reader/block_reader_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/block_cache.dart';
import 'package:kuphanda/data/store/document_files.dart';
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

class _MemoryCache implements BlockDocumentCache {
  _MemoryCache([this.stored]);

  BlockDocument? stored;
  int writes = 0;

  @override
  Future<BlockDocument?> read(String documentId) async => stored;

  @override
  Future<void> write(String documentId, BlockDocument document) async {
    stored = document;
    writes++;
  }

  @override
  Future<void> delete(String documentId) async => stored = null;

  @override
  Future<Set<String>> saved() async =>
      stored == null ? <String>{} : {'ref-msce-maths-2002-p1'};
}

const _payload = <String, Object?>{
  'title': 'Mathematics Paper I',
  'subtitle': 'Paper I, 100 marks.',
  'blocks': [
    {'type': 'callout', 'text': 'Answer all questions.'},
    {
      'type': 'question',
      'label': '1.',
      'marks': 4,
      'text': 'Evaluate.',
      'parts': [
        {'label': 'a.', 'text': 'First.', 'marks': 2},
      ],
    },
  ],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Signs in through the endpoint the app itself uses, so the state is
/// authenticated without running a full [AppState.initialize] against stubs.
Future<AppState> _signedIn({
  required BlockDocumentCache cache,
  required Future<http.Response> Function() onBlocks,
}) async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/auth/google')) {
      return _json({
        'token': 'test-token',
        'user': {'id': 1, 'name': 'Test', 'email': 'test@kuphanda.test'},
      });
    }
    return onBlocks();
  });

  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    api: ApiClient(baseUrl: 'https://example.test/api/v1', token: null, httpClient: client),
    tokenStore: MemoryTokenStore(),
    blockCache: cache,
  );

  await state.signInWithGoogle('google-id-token', sync: false);
  // Signing in starts a 15-minute refresh timer; a widget test fails when one is
  // still pending as the tree is torn down.
  state.stopAutoSync();
  return state;
}

void main() {
  test('a fetched paper is kept for offline reading', () async {
    final cache = _MemoryCache();
    final state = await _signedIn(
      cache: cache,
      onBlocks: () async => _json({'data': _payload}),
    );

    final loaded = await state.loadBlockDocument('ref-msce-maths-2002-p1');

    expect(loaded.document.blocks, hasLength(2));
    expect(loaded.fromCache, isFalse);
    expect(state.savedOffline('ref-msce-maths-2002-p1'), isTrue);
    expect(cache.writes, 1);
    expect(cache.stored!.blocks, hasLength(2));
  });

  test('a paper opened before still opens with no connection', () async {
    final cache = _MemoryCache(BlockDocument.fromMap(_payload));
    final state = await _signedIn(
      cache: cache,
      onBlocks: () async => throw http.ClientException('offline'),
    );

    final loaded = await state.loadBlockDocument('ref-msce-maths-2002-p1');

    expect(loaded.fromCache, isTrue);
    expect(loaded.document.title, 'Mathematics Paper I');
    expect(loaded.document.blocks, hasLength(2));
  });

  test('a lapsed entitlement is not served from the cache', () async {
    // 402 means the account may not read this paper now; answering from the
    // cache would quietly ignore the subscription.
    final cache = _MemoryCache(BlockDocument.fromMap(_payload));
    final state = await _signedIn(
      cache: cache,
      onBlocks: () async => _json({'message': 'Subscription required.'}, 402),
    );

    await expectLater(
      state.loadBlockDocument('ref-msce-maths-2002-p1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a cached paper keeps its content through the round trip', () {
    final round = BlockDocument.fromMap(
      jsonDecode(jsonEncode(BlockDocument.fromMap(_payload).toMap()))
          as Map<String, Object?>,
    );

    expect(round.title, 'Mathematics Paper I');
    expect(round.subtitle, 'Paper I, 100 marks.');
    expect(round.blocks, hasLength(2));
    expect(round.blocks.last.raw['parts'], isA<List<Object?>>());
  });

  testWidgets('the reader says when it is showing a saved copy', (tester) async {
    final cache = _MemoryCache(BlockDocument.fromMap(_payload));
    final state = await _signedIn(
      cache: cache,
      onBlocks: () async => throw http.ClientException('offline'),
    );

    await tester.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(
        home: BlockReaderScreen(documentId: 'ref-msce-maths-2002-p1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Saved copy'), findsOneWidget);
    expect(find.text('Mathematics Paper I'), findsOneWidget);
  });

  testWidgets('a live paper carries no saved-copy banner', (tester) async {
    final state = await _signedIn(
      cache: _MemoryCache(),
      onBlocks: () async => _json({'data': _payload}),
    );

    await tester.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(
        home: BlockReaderScreen(documentId: 'ref-msce-maths-2002-p1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Saved copy'), findsNothing);
  });
}
