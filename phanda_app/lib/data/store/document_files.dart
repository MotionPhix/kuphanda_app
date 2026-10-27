import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/document.dart';
import 'state_store.dart';

class PickedPdf {
  const PickedPdf({required this.path, required this.fileName, required this.sizeBytes});

  final String path;
  final String fileName;
  final int sizeBytes;
}

/// File handling boundary, so the state layer can be tested without touching
/// the file system or a native picker.
abstract class DocumentFiles {
  Future<PickedPdf?> pickPdf();
  Future<DocumentAsset> store({required String documentId, required PickedPdf picked});
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  });
  Future<void> delete(DocumentAsset asset);
}

class LocalDocumentFiles implements DocumentFiles {
  LocalDocumentFiles(this._store);

  final FileStateStore _store;

  String _safeId(String documentId) =>
      documentId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  @override
  Future<PickedPdf?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final path = file.path;
    if (path == null) return null;

    final handle = File(path);
    if (!await handle.exists()) return null;

    // Verify the magic number rather than trusting the extension.
    final header = await handle.openRead(0, 5).first;
    final isPdf = header.length >= 4 &&
        header[0] == 0x25 &&
        header[1] == 0x50 &&
        header[2] == 0x44 &&
        header[3] == 0x46;
    if (!isPdf) {
      throw const FormatException('That file is not a PDF.');
    }

    return PickedPdf(
      path: path,
      fileName: file.name,
      sizeBytes: await handle.length(),
    );
  }

  @override
  Future<DocumentAsset> store({required String documentId, required PickedPdf picked}) async {
    final directory = await _store.filesDirectory();
    final target = File('${directory.path}${Platform.pathSeparator}${_safeId(documentId)}.pdf');
    if (await target.exists()) {
      await target.delete();
    }
    await File(picked.path).copy(target.path);

    return DocumentAsset(
      documentId: documentId,
      fileName: picked.fileName,
      sizeBytes: await target.length(),
      addedAt: DateTime.now(),
      path: target.path,
    );
  }

  @override
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  }) async {
    final directory = await _store.filesDirectory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}${_safeId(documentId)}.v$version.pdf',
    );
    await target.writeAsBytes(bytes, flush: true);

    return DocumentAsset(
      documentId: documentId,
      fileName: fileName,
      sizeBytes: await target.length(),
      addedAt: DateTime.now(),
      path: target.path,
      pageCount: pageCount,
      version: version,
      checksum: checksum,
      remote: true,
    );
  }

  @override
  Future<void> delete(DocumentAsset asset) async {
    if (asset.path == null) return;
    final file = File(asset.path!);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// In-memory implementation used by tests and by the "reset" path.
class FakeDocumentFiles implements DocumentFiles {
  PickedPdf? nextPick;
  final Map<String, DocumentAsset> stored = <String, DocumentAsset>{};
  int _sequence = 0;

  @override
  Future<PickedPdf?> pickPdf() async => nextPick;

  @override
  Future<DocumentAsset> store({required String documentId, required PickedPdf picked}) async {
    _sequence++;
    final asset = DocumentAsset(
      documentId: documentId,
      fileName: picked.fileName,
      sizeBytes: picked.sizeBytes,
      addedAt: DateTime.now(),
      path: '/memory/$documentId-$_sequence.pdf',
      pageCount: 4,
    );
    stored[documentId] = asset;
    return asset;
  }

  @override
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  }) async {
    _sequence++;
    final asset = DocumentAsset(
      documentId: documentId,
      fileName: fileName,
      sizeBytes: bytes.length,
      addedAt: DateTime.now(),
      path: '/memory/$documentId-v$version-$_sequence.pdf',
      pageCount: pageCount,
      version: version,
      checksum: checksum,
      remote: true,
    );
    stored[documentId] = asset;
    return asset;
  }

  @override
  Future<void> delete(DocumentAsset asset) async {
    stored.remove(asset.documentId);
  }
}
