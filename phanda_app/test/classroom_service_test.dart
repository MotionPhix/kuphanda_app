import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
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

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> _classroom({
  String id = 'cls_abc',
  String code = 'KPH4A2',
  String name = 'Form 4A — Sciences',
  List<Map<String, Object?>> assignments = const [],
}) =>
    {
      'id': id,
      'name': name,
      'code': code,
      'form': 4,
      'subject_id': 'biology',
      'teacher_name': 'Mr B. Banda',
      'member_count': 38,
      'created_at': '2026-08-27T09:00:00+00:00',
      'assignments': assignments,
    };

Future<AppState> _state({
  required Future<http.Response> Function(http.Request request) onClassrooms,
}) async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/auth/google')) {
      return _json({
        'token': 'test-token',
        'user': {'id': 5, 'name': 'Test', 'email': 'test@kuphanda.test'},
      });
    }
    if (request.url.path.contains('classrooms')) return onClassrooms(request);
    return _json({'data': []});
  });

  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    api: ApiClient(baseUrl: 'https://example.test/api/v1', token: null, httpClient: client),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();
  await state.signInWithGoogle('google-id-token', sync: false);
  state.stopAutoSync();
  return state;
}

void main() {
  test('joining a class stores what the service says', () async {
    final state = await _state(
      onClassrooms: (request) async => request.method == 'POST'
          ? _json({
              'data': _classroom(
                assignments: [
                  {
                    'id': 'asg_1',
                    'document_id': 'ref-msce-biology-2023-paper2',
                    'title': 'Biology Paper 2',
                    'due_date': '2026-11-02',
                    'created_at': '2026-10-26T08:00:00+00:00',
                  },
                ],
              ),
              'message': 'Joined Form 4A — Sciences.',
            }, 200)
          : _json({'data': []}),
    );

    final result = await state.joinClass('kph4a2');

    expect(result.success, isTrue);
    expect(result.message, contains('Form 4A'));
    expect(state.classes.single.code, 'KPH4A2');
    expect(state.classes.single.teacherName, 'Mr B. Banda');
    expect(state.upcomingAssignments.single.documentId, 'ref-msce-biology-2023-paper2');
  });

  test('an unknown code reports what the service said', () async {
    final state = await _state(
      onClassrooms: (request) async => _json(
        {'success': false, 'message': 'No class uses that code. Check it with your teacher.'},
        404,
      ),
    );

    final result = await state.joinClass('ZZZZZZ');

    expect(result.success, isFalse);
    expect(result.message, contains('No class uses that code'));
    expect(state.classes, isEmpty);
  });

  test('an assignment without a due date is shown as undated', () async {
    final classroom = _classroom(
      assignments: [
        {
          'id': 'asg_1',
          'document_id': 'ref-msce-biology-2023-paper2',
          'title': 'Biology Paper 2',
          'due_date': null,
          'created_at': '2026-10-26T08:00:00+00:00',
        },
      ],
    );

    final state = await _state(
      onClassrooms: (request) async => request.method == 'POST'
          ? _json({'data': classroom})
          : _json({'data': [classroom]}),
    );

    await state.joinClass('KPH4A2');

    expect(state.upcomingAssignments, hasLength(1));
    expect(state.upcomingAssignments.single.dueDate, isNull);
  });

  test('a class the service no longer lists disappears on sync', () async {
    var served = <Map<String, Object?>>[_classroom()];
    final state = await _state(
      onClassrooms: (request) async => request.method == 'POST'
          ? _json({'data': _classroom()})
          : _json({'data': served}),
    );

    await state.joinClass('KPH4A2');
    expect(state.classes, hasLength(1));

    served = [];
    await state.syncNow(silent: true);

    expect(state.classes, isEmpty);
  });

  test('reading a set paper finishes the assignment, and a sync keeps it done',
      () async {
    final classroom = _classroom(
      assignments: [
        {
          'id': 'asg_1',
          'document_id': 'ref-msce-biology-2023-paper2',
          'title': 'Biology Paper 2',
          'due_date': '2026-11-02',
          'created_at': '2026-10-26T08:00:00+00:00',
        },
      ],
    );

    final state = await _state(
      onClassrooms: (request) async => request.method == 'POST'
          ? _json({'data': classroom})
          : _json({'data': [classroom]}),
    );

    await state.joinClass('KPH4A2');
    expect(state.upcomingAssignments, hasLength(1));

    // Read the paper through to the end.
    state.recordProgress(
      documentId: 'ref-msce-biology-2023-paper2',
      page: 1,
      totalPages: 1,
      fraction: 1.0,
    );
    expect(state.upcomingAssignments, isEmpty, reason: 'it is done');

    // The service does not track who read what, so the local flag has to survive
    // a refresh or the class would keep asking for work already done.
    await state.syncNow(silent: true);

    expect(state.upcomingAssignments, isEmpty);
  });
}
