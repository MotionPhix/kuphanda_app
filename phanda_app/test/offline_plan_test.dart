import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/api/api_models.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/sync/offline_plan.dart';

Document _document(String id) => Document(
      id: id,
      title: 'Paper',
      subjectId: 'mathematics',
      form: 4,
      kind: DocumentKind.pastPaper,
      description: '',
      pages: 10,
      addedAt: DateTime(2026),
    );

RemoteFile _file(int version) => RemoteFile(
      version: version,
      fileName: 'paper-$version.pdf',
      sizeBytes: 100,
      pageCount: 10,
      checksum: 'checksum-$version',
      publishedAt: DateTime(2026),
    );

RemoteOfflineItem _item(String id, {int version = 1, bool entitled = true, bool withFile = true}) {
  return RemoteOfflineItem(
    documentId: id,
    document: _document(id),
    file: withFile ? _file(version) : null,
    downloadedVersion: null,
    updateAvailable: false,
    downloadUrl: 'https://library.test/$id',
    markedAt: DateTime(2026),
    isEntitled: entitled,
  );
}

DocumentAsset _asset(String id, {int version = 1, bool remote = true}) => DocumentAsset(
      documentId: id,
      fileName: 'paper.pdf',
      sizeBytes: 100,
      addedAt: DateTime(2026),
      path: '/files/$id.pdf',
      version: version,
      remote: remote,
    );

void main() {
  test('downloads a newly marked document', () {
    final actions = planOfflineSync(remote: [_item('a')], local: {});
    expect(actions, hasLength(1));
    expect(actions.single.type, OfflineActionType.download);
    expect(actions.single.version, 1);
  });

  test('updates when the server has a newer version', () {
    final actions = planOfflineSync(
      remote: [_item('a', version: 2)],
      local: {'a': _asset('a', version: 1)},
    );
    expect(actions.single.type, OfflineActionType.update);
    expect(actions.single.version, 2);
  });

  test('keeps a current file untouched', () {
    final actions = planOfflineSync(
      remote: [_item('a', version: 2)],
      local: {'a': _asset('a', version: 2)},
    );
    expect(actions, isEmpty);
  });

  test('removes a stored file when entitlement has expired', () {
    final actions = planOfflineSync(
      remote: [_item('a', entitled: false)],
      local: {'a': _asset('a')},
    );
    expect(actions.single.type, OfflineActionType.remove);
    expect(actions.single.documentId, 'a');
  });

  test('removes a stored file when the mark was removed elsewhere', () {
    final actions = planOfflineSync(remote: const [], local: {'a': _asset('a')});
    expect(actions.single.type, OfflineActionType.remove);
  });

  test('never removes bundled or imported files', () {
    final actions = planOfflineSync(
      remote: const [],
      local: {
        'bundled': _asset('bundled', remote: false),
        'imported': _asset('imported', remote: false, version: 3),
      },
    );
    expect(actions, isEmpty);
  });

  test('skips a mark with no current file', () {
    final actions = planOfflineSync(
      remote: [_item('a', withFile: false)],
      local: {'a': _asset('a')},
    );
    expect(actions, isEmpty);
  });
}
