import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/classroom.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/classes/class_detail_screen.dart';
import 'package:kuphanda/features/teacher/teacher_home_screen.dart';
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

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// The class record a teacher's phone gets back: one paper, two learners, one
/// of whom has finished it.
MockClient _reporter({bool fails = false}) => MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/remind')) {
        return _json({
          'data': {'sent': 1, 'assignment_id': 'a1'},
        });
      }

      if (path.endsWith('/classrooms/c1/report')) {
        if (fails) return _json({'message': 'Server Error'}, 500);
        return _json({
          'data': {
            'classroom': {'id': 'c1', 'name': 'Form 4 Physics', 'code': 'K4P9QZ'},
            'assignments': [
              {
                'id': 'a1',
                'document_id': 'doc-1',
                'title': 'Mechanics — MSCE study guide',
                'due_date': null,
                'completed_count': 1,
              },
            ],
            'learners': [
              {'id': 1, 'name': 'Tadala Phiri', 'completed_assignment_ids': ['a1'], 'completed_count': 1},
              {'id': 2, 'name': 'Chisomo Banda', 'completed_assignment_ids': [], 'completed_count': 0},
            ],
            'assignment_count': 1,
            'learner_count': 2,
          },
        });
      }

      if (path.endsWith('/classrooms')) {
        return _json({
          'data': [
            {
              'id': 'c1',
              'name': 'Form 4 Physics',
              'code': 'K4P9QZ',
              'form': 4,
              'subject_id': 'physics',
              'teacher_name': 'Grace Mwale',
              'is_owner': true,
              'member_count': 2,
              'created_at': DateTime.now().toIso8601String(),
              'assignments': [
                {
                  'id': 'a1',
                  'document_id': 'doc-1',
                  'due_date': null,
                  'created_at': DateTime.now().toIso8601String(),
                },
              ],
            },
          ],
        });
      }

      return _json({'data': []});
    });

Future<AppState> _teacherState({bool fails = false}) async {
  final now = DateTime.now();
  final store = MemoryStateStore();
  await store.write(AppSnapshot(
    accountId: 6,
    accountEmail: 'grace@example.test',
    accountName: 'Grace Mwale',
    accountStaff: true,
    profile: const Profile(
      name: 'Grace Mwale',
      givenName: 'Grace',
      familyName: 'Mwale',
      school: 'Bwaila Secondary School',
      role: StudentRole.teacher,
      onboardingComplete: true,
    ),
    classes: [
      ClassGroup(
        id: 'c1',
        name: 'Form 4 Physics',
        code: 'K4P9QZ',
        form: 4,
        subjectId: 'physics',
        teacherName: 'Grace Mwale',
        memberCount: 2,
        createdAt: now,
        isMine: true,
      ),
    ],
  ));

  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore('token'),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'token',
      httpClient: _reporter(fails: fails),
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppScope(
    state: state,
    child: MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const ClassDetailScreen(classId: 'c1'),
    ),
  ));
  await tester.pumpAndSettle();
  state.stopAutoSync();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a teacher sees how much of the class has read the paper',
      (tester) async {
    final state = await _teacherState();
    await _pump(tester, state);

    expect(find.text('Who has read it'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Tadala Phiri'), findsOneWidget);
    expect(find.text('1 of 1 read'), findsOneWidget);
    expect(find.text('0 of 1 read'), findsOneWidget);
  });

  testWidgets('a report that will not load says so and offers another try',
      (tester) async {
    final state = await _teacherState(fails: true);
    await _pump(tester, state);

    expect(find.text('Who has read it'), findsOneWidget);
    expect(find.textContaining('class record is not available'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
  testWidgets('the teaching home counts what the class has actually read',
      (tester) async {
    final state = await _teacherState();
    tester.view.physicalSize = const Size(2600, 1700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: TeacherHomeScreen(onNavigate: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    state.stopAutoSync();
    await tester.pumpAndSettle();

    // One paper set for two learners, one of whom has finished it.
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('1 read'), findsWidgets);
  });
  test('a classroom payload carries what this learner has already read', () {
    final classroom = RemoteClassroom.fromJson({
      'id': 'c1',
      'name': 'Form 4 Physics',
      'code': 'K4P9QZ',
      'form': 4,
      'subject_id': 'physics',
      'teacher_name': 'Grace Mwale',
      'is_owner': false,
      'member_count': 38,
      'created_at': DateTime.now().toIso8601String(),
      'assignments': [
        {
          'id': 'a1',
          'document_id': 'doc-1',
          'due_date': null,
          'created_at': DateTime.now().toIso8601String(),
          'completed': true,
        },
        {
          'id': 'a2',
          'document_id': 'doc-2',
          'due_date': null,
          'created_at': DateTime.now().toIso8601String(),
          'completed': false,
        },
      ],
    });

    expect(classroom.assignments.first.completed, isTrue);
    expect(classroom.assignments.last.completed, isFalse);
  });
  testWidgets('tapping a learner shows which papers they still owe',
      (tester) async {
    final state = await _teacherState();
    await _pump(tester, state);

    await tester.ensureVisible(find.text('Chisomo Banda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chisomo Banda'));
    await tester.pumpAndSettle();

    // Chisomo has read none of it: his row opens to say so, paper by paper.
    expect(find.text('Mechanics — MSCE study guide · read'), findsNothing);

    await tester.tap(find.text('Tadala Phiri'));
    await tester.pumpAndSettle();
    expect(find.text('Mechanics — MSCE study guide · read'), findsOneWidget);
  });
  test('a paper past its deadline counts who is still to read it', () {
    final report = ClassReport(
      assignments: [
        ReportedAssignment(
          id: 'a1',
          documentId: 'doc-1',
          title: 'Mechanics',
          completedCount: 1,
          dueDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      learners: const [
        ReportedLearner(id: 1, name: 'Tadala', completedAssignmentIds: ['a1']),
        ReportedLearner(id: 2, name: 'Chisomo', completedAssignmentIds: []),
      ],
      assignmentCount: 1,
      learnerCount: 2,
    );

    expect(lateCountFor(report, report.assignments.single), 1);
  });

  test('the whole of the due day still counts as on time', () {
    final report = ClassReport(
      assignments: [
        ReportedAssignment(
          id: 'a1',
          documentId: 'doc-1',
          title: 'Mechanics',
          completedCount: 0,
          dueDate: DateTime.now(),
        ),
      ],
      learners: const [
        ReportedLearner(id: 2, name: 'Chisomo', completedAssignmentIds: []),
      ],
      assignmentCount: 1,
      learnerCount: 1,
    );

    expect(lateCountFor(report, report.assignments.single), 0);
  });

  test('a paper with no deadline is never late', () {
    final report = ClassReport(
      assignments: const [
        ReportedAssignment(id: 'a1', documentId: 'doc-1', title: 'Mechanics', completedCount: 0),
      ],
      learners: const [
        ReportedLearner(id: 2, name: 'Chisomo', completedAssignmentIds: []),
      ],
      assignmentCount: 1,
      learnerCount: 1,
    );

    expect(lateCountFor(report, report.assignments.single), 0);
  });
  testWidgets('a teacher can chase the ones still to read it', (tester) async {
    final state = await _teacherState();
    await _pump(tester, state);

    // One of the two learners has read it, so one is left to chase.
    expect(find.text('Remind 1'), findsOneWidget);

    await tester.tap(find.text('Remind 1'));
    await tester.pumpAndSettle();

    expect(find.text('Reminded one learner.'), findsOneWidget);
  });
}
