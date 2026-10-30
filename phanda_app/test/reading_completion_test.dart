import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/reading.dart';
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

Future<AppState> _state([AppSnapshot? snapshot]) async {
  final store = MemoryStateStore();
  if (snapshot != null) await store.write(snapshot);
  final state = AppState(store: store, files: _NoFiles(), tokenStore: MemoryTokenStore());
  await state.initialize();
  return state;
}

void main() {
  test('scrolling past five sixths of a paper does not finish it', () async {
    // The reader used to report page = ceil(fraction * 6) of 6, and completion
    // was page >= total, so 83% scrolled claimed the paper was done.
    final state = await _state();
    state.recordProgress(documentId: 'paper', page: 6, totalPages: 6, fraction: 0.85);

    final progress = state.progressFor('paper')!;
    expect(progress.percent, closeTo(85, 0.001));
    expect(progress.isComplete, isFalse);
  });

  test('reaching the end still finishes it', () async {
    final state = await _state();
    state.recordProgress(documentId: 'paper', page: 1, totalPages: 1, fraction: 0.999);

    expect(state.progressFor('paper')!.isComplete, isTrue);
  });

  test('a page-based document keeps the page rule', () async {
    final state = await _state();
    state.recordProgress(documentId: 'pdf', page: 12, totalPages: 12);

    expect(state.progressFor('pdf')!.isComplete, isTrue);
  });

  test('a stale "finished" from the old arithmetic is corrected', () async {
    // Real records exist with completed: true at 82% and a measured fraction.
    // The fraction is the honest one, so reading on must un-finish it.
    final snapshot = AppSnapshot(
      progress: {
        'paper': const ReadingProgress(
          documentId: 'paper',
          currentPage: 6,
          totalPages: 6,
          fraction: 0.82,
          completed: true,
        ),
      },
    );

    final state = await _state(snapshot);
    expect(state.progressFor('paper')!.isComplete, isFalse);

    state.recordProgress(documentId: 'paper', page: 1, totalPages: 1, fraction: 0.4);
    expect(state.progressFor('paper')!.isComplete, isFalse);
  });
}
