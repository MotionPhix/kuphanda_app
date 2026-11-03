import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/api_models.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/classes/classes_screen.dart';
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

Future<AppState> _state({required StudentRole role}) async {
  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();
  await state.completeOnboarding(
    name: 'Mrs T. Chirwa',
    givenName: 'T.',
    familyName: 'Chirwa',
    school: 'Bwaila Secondary School',
    form: 4,
    examYear: 2027,
    role: role,
    subjectIds: const ['mathematics'],
  );
  return state;
}

Widget _wrap(AppState state) => AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: ClassesScreen()),
      ),
    );

void main() {
  testWidgets('a teacher is offered the create action, a learner is not',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final teacher = await _state(role: StudentRole.teacher);
    await tester.pumpWidget(_wrap(teacher));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);

    final learner = await _state(role: StudentRole.student);
    await tester.pumpWidget(_wrap(learner));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsNothing);
  });

  test('creating a class needs a session, because the code is issued there',
      () async {
    // A code generated on the phone would be unknown to every other phone: the
    // learner joining with it would be told no class uses it.
    final state = await _state(role: StudentRole.teacher);

    await expectLater(
      state.createClass(name: 'Form 3B', form: 3),
      throwsA(isA<ApiException>()),
    );
    expect(state.classes, isEmpty);
  });
  testWidgets('a teacher reads the page as the person running the class', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final teacher = await _state(role: StudentRole.teacher);
    await tester.pumpWidget(_wrap(teacher));
    await tester.pumpAndSettle();

    // Not "your teachers", and not a code that "comes from your teacher".
    expect(find.text('TEACHING'), findsOneWidget);
    expect(find.text('YOUR TEACHERS'), findsNothing);
    expect(find.textContaining('comes from your teacher'), findsNothing);
    expect(find.textContaining('Learners join with the six-character code'), findsOneWidget);
  });

  testWidgets('an empty page offers the teacher a class of their own to make', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final teacher = await _state(role: StudentRole.teacher);
    await tester.pumpWidget(_wrap(teacher));
    await tester.pumpAndSettle();
    expect(find.text('Create a class'), findsWidgets);

    final learner = await _state(role: StudentRole.student);
    await tester.pumpWidget(_wrap(learner));
    await tester.pumpAndSettle();
    expect(find.text('Join a class'), findsOneWidget);
    expect(find.text('Create a class'), findsNothing);
  });
}
