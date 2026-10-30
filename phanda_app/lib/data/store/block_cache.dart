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

  /// Which papers have a copy, so the library can say what opens without data.
  Future<Set<String>> saved();
}

/// A document together with where it came from.
///
/// The reader has to be able to say that it is showing yesterday's copy: a
/// paper served silently from disk looks live, and a learner who cannot tell
/// the difference will trust stale marks.
class LoadedBlockDocument {
  const LoadedBlockDocument(this.document, {this.fromCache = false});

  final BlockDocument document;
  final bool fromCache;
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

  @override
  Future<Set<String>> saved() async {
    const suffix = '.blocks.json';
    try {
      final directory = await _store.blocksDirectory();
      final ids = <String>{};

      await for (final entity in directory.list()) {
        final name = entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
        if (entity is File && name.endsWith(suffix)) {
          // The file name is the document id, sanitised. Ids the catalogue uses
          // (ref-msce-maths-2002-p1) survive unchanged.
          ids.add(name.substring(0, name.length - suffix.length));
        }
      }

      return ids;
    } catch (_) {
      return <String>{};
    }
  }
}
