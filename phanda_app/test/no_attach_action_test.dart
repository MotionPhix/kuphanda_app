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
import 'package:kuphanda/features/document/document_detail_screen.dart';
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

Future<AppState> _state({AppSnapshot? snapshot}) async {
  final state = AppState(
    store: MemoryStateStore(snapshot),
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
  testWidgets('the library never offers to add a PDF to our own papers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _state();
    await tester.pumpWidget(_wrap(state, const Scaffold(body: LibraryScreen())));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add PDF'), findsNothing);
    expect(find.textContaining('Attach'), findsNothing);

    // The learner path is adding something of their own, named in a form.
    expect(find.byTooltip('Add your own paper'), findsOneWidget);
  });

  testWidgets('a catalogue paper with nothing readable offers no upload',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The bundled catalogue no longer carries unreadable records, so the case
    // this screen has to survive is a server row that arrived without a file or
    // blocks — built here rather than borrowed from the seed.
    final document = Document(
      id: 'server-metadata-only',
      title: 'MSCE Biology 2024 Paper 2',
      subjectId: 'biology',
      form: 4,
      kind: DocumentKind.pastPaper,
      description: 'A catalogue record whose file has not been published.',
      pages: 24,
      addedAt: DateTime(2026, 9, 1),
    );

    final state = await _state(
      snapshot: AppSnapshot(remoteDocuments: [document]),
    );
    expect(state.hasRemoteFile(document.id), isFalse);
    await tester.pumpWidget(
      _wrap(state, DocumentDetailScreen(documentId: document.id)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Attach'), findsNothing);
    expect(find.textContaining('Add PDF'), findsNothing);
    expect(find.text('Not readable yet'), findsOneWidget);

    // Nothing to act on, so the primary button is inert rather than misleading.
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);
  });

}
