import 'dart:typed_data';

import '../models/document.dart';
import 'document_files.dart';

/// The file boundary on web, where there is no application documents directory.
///
/// Downloads are not wired for the browser yet: a PDF kept offline needs a
/// browser-side store (IndexedDB) and a reader that is not `pdfx`, which renders
/// through native code. Rather than let those calls fail somewhere deep in the
/// state layer, they fail here with a sentence that says what happened — the
/// library still opens every structured paper and every guide from the API.
class WebDocumentFiles implements DocumentFiles {
  static const _message =
      'Saving PDFs for offline reading is not available in the browser yet.';

  @override
  Future<PickedPdf?> pickPdf() async => null;

  @override
  Future<DocumentAsset> store({
    required String documentId,
    required PickedPdf picked,
  }) async =>
      throw UnsupportedError(_message);

  @override
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  }) async =>
      throw UnsupportedError(_message);

  @override
  Future<void> delete(DocumentAsset asset) async {}
}
