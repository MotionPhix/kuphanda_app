import 'dart:convert';
import 'dart:io';

import '../models/block_document.dart';
import 'state_store.dart';

/// Keeps the last copy of a reflowable document on the phone.
///
/// The catalogue's own papers are read from the API, and until now every open
/// meant a request: a learner who had already read a paper could not reopen it
/// with no signal, which is the exact case the app advertises for. The bytes are
/// small (a paper is tens of kilobytes of JSON), so caching every paper that has
/// been opened costs far less than a single PDF.
///
/// Being a cache, every failure is silent: a missing or unreadable copy simply
/// means the reader goes to the network.
abstract class BlockDocumentCache {
  Future<BlockDocument?> read(String documentId);
  Future<void> write(String documentId, BlockDocument document);
  Future<void> delete(String documentId);
}

class LocalBlockDocumentCache implements BlockDocumentCache {
  LocalBlockDocumentCache(this._store);

  final FileStateStore _store;

  String _fileName(String documentId) =>
      '${documentId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.blocks.json';

  Future<File> _file(String documentId) async {
    final directory = await _store.blocksDirectory();
    return File('${directory.path}${Platform.pathSeparator}${_fileName(documentId)}');
  }

  @override
  Future<BlockDocument?> read(String documentId) async {
    try {
      final file = await _file(documentId);
      if (!await file.exists()) return null;
      return BlockDocument.fromJsonString(await file.readAsString());
    } catch (_) {
      // A truncated or corrupt copy must not stop the reader; the network is
      // still there, and the next successful fetch replaces this file.
      return null;
    }
  }

  @override
  Future<void> write(String documentId, BlockDocument document) async {
    try {
      final file = await _file(documentId);
      final temp = File('${file.path}.tmp');
      // Write beside the target, then rename: being killed mid-write cannot
      // leave a half document that decodes as a shorter paper.
      await temp.writeAsString(jsonEncode(document.toMap()), flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // Caching is a convenience, never a precondition for reading.
    }
  }

  @override
  Future<void> delete(String documentId) async {
    try {
      final file = await _file(documentId);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing to recover from.
    }
  }
}
