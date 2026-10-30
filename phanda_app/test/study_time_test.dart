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

Future<AppState> _state() async {
  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(),
    clock: () => DateTime(2026, 10, 30, 12, 30),
  );
  await state.initialize();
  return state;
}

void main() {
  test('time spent on a structured paper counts as study', () async {
    // The block reader recorded position but never time, so a paper read for
    // twenty minutes added nothing to "minutes studied" or to the streak.
    final state = await _state();
    state.addStudyTime('ref-msce-maths-2002-p1', 600);

    expect(state.progressFor('ref-msce-maths-2002-p1')!.secondsSpent, 600);
    expect(state.stats.todayMinutes * 60, 600);
    expect(state.stats.currentStreak, 1);
  });

  test('a second session adds to the same day rather than replacing it',
      () async {
    final state = await _state();
    state.addStudyTime('paper', 120);
    state.addStudyTime('paper', 90);

    expect(state.progressFor('paper')!.secondsSpent, 210);
    expect(state.stats.todayMinutes, greaterThanOrEqualTo(3));
  });

  test('nothing is banked for a zero-length tick', () async {
    final state = await _state();
    state.addStudyTime('paper', 0);

    expect(state.stats.todayMinutes * 60, 0);
    expect(state.progressFor('paper'), isNull);
  });

  test('study time does not fake a reading position', () async {
    final state = await _state();
    state.addStudyTime('paper', 300);

    final progress = state.progressFor('paper')!;
    expect(progress.fraction, isNull, reason: 'no scroll happened');
    expect(progress.isComplete, isFalse);
    expect(progress.percent, 0);
  });

  test('study days an earlier build invented are deleted', () async {
    // The device read "1h 43m this week" for an account that had opened the app
    // twice: four seeded days, credited to a learner who did not study them.
    final seeded = AppSnapshot(
      studyDays: [
        StudyDay(date: '2026-10-29', seconds: 35 * 60, sessions: 2),
        StudyDay(date: '2026-10-28', seconds: 20 * 60, sessions: 1),
        StudyDay(date: '2026-10-26', seconds: 48 * 60, sessions: 3),
      ],
    )..demoStudyHistory = true;

    final store = MemoryStateStore();
    await store.write(seeded);

    final state = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
      clock: () => DateTime(2026, 10, 30, 12, 30),
    );
    await state.initialize();

    expect(state.stats.weekMinutes, 0);
    expect(state.stats.currentStreak, 0);
  });
}
