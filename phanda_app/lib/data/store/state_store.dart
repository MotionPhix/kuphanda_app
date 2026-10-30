import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'snapshot.dart';

/// Persistence boundary. Tests inject [MemoryStateStore]; the app uses
/// [FileStateStore], which keeps a JSON document in the app support directory.
abstract class StateStore {
  Future<AppSnapshot?> read();
  Future<void> write(AppSnapshot snapshot);
  Future<void> clear();
}

class FileStateStore implements StateStore {
  FileStateStore();

  Directory? _root;

  Future<Directory> _rootDir() async {
    final cached = _root;
    if (cached != null) return cached;

    final support = await getApplicationSupportDirectory();
    // path_provider already scopes this directory to the application, so we
    // write directly into it rather than nesting a second folder.
    if (!await support.exists()) {
      await support.create(recursive: true);
    }

    // Migrate state written by the first build, which nested a `kuphanda`
    // folder inside the support directory.
    final legacyState = File(
      '${support.path}${Platform.pathSeparator}kuphanda${Platform.pathSeparator}state.json',
    );
    final currentState = File('${support.path}${Platform.pathSeparator}state.json');
    if (!await currentState.exists() && await legacyState.exists()) {
      try {
        await legacyState.copy(currentState.path);
      } catch (_) {
        // A failed migration must not stop the app from starting.
      }
    }

    _root = support;
    return support;
  }

  Future<File> _stateFile() async {
    final directory = await _rootDir();
    return File('${directory.path}${Platform.pathSeparator}state.json');
  }

  Future<Directory> filesDirectory() async {
    final directory = await _rootDir();
    final files = Directory('${directory.path}${Platform.pathSeparator}files');
    if (!await files.exists()) {
      await files.create(recursive: true);
    }
    return files;
  }

  Future<Directory> blocksDirectory() async {
    final directory = await _rootDir();
    final blocks = Directory('${directory.path}${Platform.pathSeparator}blocks');
    if (!await blocks.exists()) {
      await blocks.create(recursive: true);
    }
    return blocks;
  }

  @override
  Future<AppSnapshot?> read() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return AppSnapshot.decode(raw);
    } on FormatException {
      // A corrupted snapshot must not brick the app: start fresh rather than
      // crash, and let the caller reseed.
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(AppSnapshot snapshot) async {
    final file = await _stateFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(snapshot.encode(), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _stateFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class MemoryStateStore implements StateStore {
  MemoryStateStore([this.snapshot]);

  AppSnapshot? snapshot;

  @override
  Future<AppSnapshot?> read() async => snapshot;

  @override
  Future<void> write(AppSnapshot next) async {
    snapshot = AppSnapshot.decode(next.encode());
  }

  @override
  Future<void> clear() async {
    snapshot = null;
  }
}
