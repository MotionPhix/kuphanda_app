import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/library/library_screen.dart';
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

Future<AppState> _stateWithDownload({int bytes = 5 * 1024 * 1024}) async {
  final document = Document(
    id: 'downloaded-paper',
    title: 'MSCE Biology 2024 Paper 2',
    subjectId: 'biology',
    form: 4,
    kind: DocumentKind.pastPaper,
    description: 'A paper the learner downloaded.',
    pages: 20,
    addedAt: DateTime(2026, 11, 1),
  );

  final state = AppState(
    store: MemoryStateStore(
      AppSnapshot(
        remoteDocuments: [document],
        assets: {
          document.id: DocumentAsset(
            documentId: document.id,
            fileName: 'biology-2024.pdf',
            sizeBytes: bytes,
            addedAt: DateTime(2026, 11, 1),
            remote: true,
          ),
        },
      ),
    ),
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();

  return state;
}

Widget _wrap(AppState state, Widget child) => AppScope(
      state: state,
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: child),
    );

void main() {
  testWidgets('the library shows how much of the download budget is used',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _stateWithDownload();
    await tester.pumpWidget(_wrap(state, const Scaffold(body: LibraryScreen())));
    await tester.pumpAndSettle();

    // 5 MB of the 50 MB budget, said where the download count already lives.
    expect(find.textContaining('5.0 MB of 50.0 MB'), findsOneWidget);
  });

  testWidgets('the library explains an eviction and lets it be dismissed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _stateWithDownload();
    state.noteOfflineEviction(2);

    await tester.pumpWidget(_wrap(state, const Scaffold(body: LibraryScreen())));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('2 older downloads were removed to make room'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('older downloads were removed to make room'),
      findsNothing,
    );
  });

  testWidgets('the availability filter explains the budget and the eviction rule',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _stateWithDownload();
    await tester.pumpWidget(_wrap(state, const Scaffold(body: LibraryScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Downloads share 50.0 MB on this device'),
      findsOneWidget,
    );
    expect(
      find.textContaining('opened longest ago are removed first'),
      findsOneWidget,
    );
  });
}
