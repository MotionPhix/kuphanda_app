import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/block_document.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/seed/library_seed.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/classes/classes_screen.dart';
import 'package:kuphanda/features/document/document_detail_screen.dart';
import 'package:kuphanda/features/library/library_screen.dart';
import 'package:kuphanda/features/reader/block_document_view.dart';
import 'package:kuphanda/features/reader/guide_reader_screen.dart';
import 'package:kuphanda/features/shell/app_shell.dart';
import 'package:kuphanda/state/app_state.dart';

class _NoFiles implements DocumentFiles {
  @override
  Future<PickedPdf?> pickPdf() async => null;

  @override
  Future<DocumentAsset> store({
    required String documentId,
    required PickedPdf picked,
  }) async => throw UnimplementedError();

  @override
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  }) async => throw UnimplementedError();

  @override
  Future<void> delete(DocumentAsset asset) async {}
}

Future<AppState> _state() async {
  final store = MemoryStateStore();
  await store.write(
    AppSnapshot(
      accountId: 1,
      accountEmail: 'catalogue.check@kuphanda.test',
      accountName: 'Catalogue Check',
      profile: const Profile(
        name: 'Catalogue Check',
        givenName: 'Catalogue',
        familyName: 'Check',
        form: 4,
        onboardingComplete: true,
      ),
    ),
  );

  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore('token'),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'token',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"data":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

/// A 360dp phone with the reader's text size turned up, which is where the
/// chrome — not the content — used to break. Returns every layout error raised
/// while pumping, so a failure names the widget rather than a pixel count.
Future<List<FlutterErrorDetails>> _pumpPhone(
  WidgetTester tester,
  double scale, {
  Widget home = const AppShell(),
}) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final state = await _state();
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The reader records progress on first build, which schedules a 350ms
  // persistence debounce; let it fire so the test does not end holding a timer.
  await tester.pump(const Duration(milliseconds: 400));

  FlutterError.onError = previous;
  return errors;
}

String _describe(List<FlutterErrorDetails> errors) =>
    errors.map((error) => error.exceptionAsString()).join('\n\n');

void main() {
  testWidgets('the home chrome survives 1.3x text without overflowing', (
    tester,
  ) async {
    final errors = await _pumpPhone(tester, 1.3);

    expect(errors, isEmpty, reason: _describe(errors));
    // Named after the fix: these labels used to ellipsise to "Downloa…".
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Find a paper'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
  });

  testWidgets('the home chrome survives 2.0x text without overflowing', (
    tester,
  ) async {
    final errors = await _pumpPhone(tester, 2.0);

    expect(errors, isEmpty, reason: _describe(errors));
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
  });

  testWidgets('the library grid survives 1.3x text', (tester) async {
    final errors = await _pumpPhone(
      tester,
      1.3,
      home: const Scaffold(body: LibraryScreen()),
    );

    expect(errors, isEmpty, reason: _describe(errors));
    expect(find.textContaining('document'), findsWidgets);
  });

  testWidgets('a document page survives 1.3x text', (tester) async {
    final id = buildCatalogue().first.id;

    final errors = await _pumpPhone(
      tester,
      1.3,
      home: DocumentDetailScreen(documentId: id),
    );

    expect(errors, isEmpty, reason: _describe(errors));
  });

  testWidgets('a structured paper reads at 1.3x without overflowing', (
    tester,
  ) async {
    final document = BlockDocument.fromJsonString(
      File('assets/samples/mechanics_sample.json').readAsStringSync(),
    );

    final errors = await _pumpPhone(
      tester,
      1.3,
      home: Scaffold(body: BlockDocumentView(document: document)),
    );

    expect(errors, isEmpty, reason: _describe(errors));
    expect(find.textContaining('Mechanics'), findsWidgets);
  });

  testWidgets('a structured paper reads at 2.0x without overflowing', (
    tester,
  ) async {
    final document = BlockDocument.fromJsonString(
      File('assets/samples/mechanics_sample.json').readAsStringSync(),
    );

    final errors = await _pumpPhone(
      tester,
      2.0,
      home: Scaffold(body: BlockDocumentView(document: document)),
    );

    expect(errors, isEmpty, reason: _describe(errors));
  });

  testWidgets('the classes screen survives 1.3x text', (tester) async {
    final errors = await _pumpPhone(
      tester,
      1.3,
      home: const Scaffold(body: ClassesScreen()),
    );

    expect(errors, isEmpty, reason: _describe(errors));
    expect(find.textContaining('class'), findsWidgets);
  });

  testWidgets('a study guide reads at 1.3x without overflowing', (
    tester,
  ) async {
    final guide = buildCatalogue().firstWhere(
      (document) => document.guideId != null,
    );

    final errors = await _pumpPhone(
      tester,
      1.3,
      home: GuideReaderScreen(documentId: guide.id),
    );

    expect(errors, isEmpty, reason: _describe(errors));
    expect(find.textContaining('Section'), findsWidgets);
  });
}


