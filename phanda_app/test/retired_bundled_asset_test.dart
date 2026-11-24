import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
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

/// What an install left behind when the how-to guide still shipped as a PDF:
/// a bundled asset pointing at a file that is no longer in the APK.
DocumentAsset _retiredBundledGuide() => DocumentAsset(
      documentId: 'sample-howto',
      fileName: 'kuphanda-quick-start.pdf',
      sizeBytes: 3072,
      addedAt: DateTime(2026, 11, 12),
      assetPath: 'assets/samples/kuphanda-quick-start.pdf',
    );

void main() {
  test('a bundled file the build no longer ships is dropped on upgrade',
      () async {
    final store = MemoryStateStore();
    final snapshot = AppSnapshot()..assets['sample-howto'] = _retiredBundledGuide();
    await store.write(snapshot);

    final state = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();

    // The detail page read this asset and printed "kuphanda-quick-start.pdf ·
    // 3 KB" under a document that has been structured blocks since the cleanup.
    expect(state.assetFor('sample-howto'), isNull);
  });

  test('a file the learner downloaded is kept, same document id or not',
      () async {
    final store = MemoryStateStore();
    final snapshot = AppSnapshot()
      ..assets['sample-howto'] = DocumentAsset(
        documentId: 'sample-howto',
        fileName: 'downloaded-guide.pdf',
        sizeBytes: 90000,
        addedAt: DateTime(2026, 11, 20),
        remote: true,
        version: 3,
        checksum: 'abc',
      );
    await store.write(snapshot);

    final state = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();

    // Not bundled, so it is the learner's copy and survives the migration.
    expect(state.assetFor('sample-howto')?.fileName, 'downloaded-guide.pdf');
  });
}
