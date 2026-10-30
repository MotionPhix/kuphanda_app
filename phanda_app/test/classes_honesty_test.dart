import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/classroom.dart';
import 'package:kuphanda/data/models/document.dart';
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
  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(),
    clock: () => DateTime(2026, 10, 30, 12, 30),
  );
  await state.initialize();
  return state;
}

ClassGroup _class(String id, String code, {String name = 'Form 4A'}) => ClassGroup(
      id: id,
      name: name,
      code: code,
      form: 4,
      subjectId: 'biology',
      teacherName: 'Mr B. Banda',
      memberCount: 38,
      createdAt: DateTime(2026, 8, 27),
    );

void main() {
  test('a new account starts with no classes and no assignments', () async {
    // The tab reads "Reading set by your teachers". Until one exists, there is
    // nothing to show but the way to join one.
    final state = await _state();

    expect(state.classes, isEmpty);
    expect(state.upcomingAssignments, isEmpty);
  });

  test('the classes an earlier build invented are removed', () async {
    final snapshot = AppSnapshot(
      classes: [
        _class('class-f4a-sciences', 'KPH4A2'),
        _class('class-f4a-maths', 'KPH4M8'),
        _class('class-f2b-maths', 'KPH2B7'),
      ],
      assignments: [
        Assignment(
          id: 'asg-bio-p2',
          classId: 'class-f4a-sciences',
          documentId: 'ref-msce-biology-2023-paper2',
          dueDate: DateTime(2026, 11, 2),
          createdAt: DateTime(2026, 10, 26),
        ),
      ],
    );

    final state = await _state(snapshot);

    expect(state.classes, isEmpty);
    expect(state.upcomingAssignments, isEmpty);
  });

  test('a class the learner really joined survives the cleanup', () async {
    final snapshot = AppSnapshot(
      classes: [
        _class('class-f4a-sciences', 'KPH4A2'),
        _class('class-mine-2026', 'MZQ7XK', name: 'Form 3B — Agriculture'),
      ],
    );

    final state = await _state(snapshot);

    expect(state.classes.map((group) => group.id), ['class-mine-2026']);
  });

  test('joining needs a session, because the code is checked by the service',
      () async {
    // Joining used to be decided by a list inside the binary. It now asks the
    // classroom service, so a signed-out learner is told what is actually
    // missing instead of a code being called wrong.
    final state = await _state();

    final result = await state.joinClass('KPH4A2');

    expect(result.success, isFalse);
    expect(result.message, contains('Sign in'));
    expect(state.classes, isEmpty);
  });
}
