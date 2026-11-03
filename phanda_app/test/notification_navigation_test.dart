import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/classes/class_detail_screen.dart';
import 'package:kuphanda/features/notifications/notifications_screen.dart';
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

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

/// A learner with one unread message about a paper set for their class.
Future<AppState> _learner() async {
  final now = DateTime.now();
  final store = MemoryStateStore();
  await store.write(AppSnapshot(
    accountId: 7,
    accountEmail: 'tadala@example.test',
    accountName: 'Tadala Phiri',
    profile: const Profile(
      name: 'Tadala Phiri',
      givenName: 'Tadala',
      familyName: 'Phiri',
      school: 'Bwaila Secondary School',
      role: StudentRole.student,
      form: 4,
      onboardingComplete: true,
    ),
  ));

  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore('token'),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'token',
      httpClient: MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/me/notifications')) {
          return _json({
            'data': [
              {
                'id': 1,
                'category': 'assignment',
                'title': 'New reading: Physics Paper I',
                'body': 'Grace Mwale set this for Form 4 Physics',
                'sent_at': now.toIso8601String(),
                'data': {
                  'classroom_id': 'c1',
                  'assignment_id': 'a1',
                  'document_id': 'doc-1',
                },
              },
              {
                'id': 2,
                'category': 'general',
                'title': 'Library closed on Monday',
                'body': 'No reading that day.',
                'sent_at': now.toIso8601String(),
                'data': <String, Object?>{},
              },
            ],
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
                'is_owner': false,
                'member_count': 38,
                'created_at': now.toIso8601String(),
                'assignments': [
                  {
                    'id': 'a1',
                    'document_id': 'doc-1',
                    'due_date': null,
                    'created_at': now.toIso8601String(),
                    'completed': false,
                  },
                ],
              },
            ],
          });
        }

        return _json({'data': []});
      }),
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

void main() {
  testWidgets('a message about a paper opens the class it was set for',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _learner();
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const NotificationsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(find.text('New reading: Physics Paper I'), findsOneWidget);

    await tester.tap(find.text('New reading: Physics Paper I'));
    await tester.pumpAndSettle();

    expect(find.byType(ClassDetailScreen), findsOneWidget);
    expect(find.text('Form 4 Physics'), findsWidgets);
  });

  testWidgets('a message that points nowhere is not a button', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _learner();
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const NotificationsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    state.stopAutoSync();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library closed on Monday'));
    await tester.pumpAndSettle();

    // Still on the inbox: a notice with nowhere to go does nothing.
    expect(find.byType(ClassDetailScreen), findsNothing);
    expect(find.text('New reading: Physics Paper I'), findsOneWidget);
  });
}
