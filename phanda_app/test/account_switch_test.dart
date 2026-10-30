import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';
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

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

/// Two accounts on one phone, as a shared school handset would have.
Map<String, Object?> _user(String email) => email == 'teacher@kuphanda.test'
    ? {
        'id': 6,
        'name': 'Mrs T. Chirwa',
        'first_name': 'T.',
        'last_name': 'Chirwa',
        'email': 'teacher@kuphanda.test',
        'plan': 'free',
        'is_staff': true,
      }
    : {
        'id': 7,
        'name': 'Thoko Mwale',
        'first_name': 'Thoko',
        'last_name': 'Mwale',
        'email': 'student@kuphanda.test',
        'plan': 'free',
        'is_staff': false,
      };

/// Two accounts on one phone, as a shared school handset would have.
Future<AppState> _state() async {
  var signedInAs = 'teacher@kuphanda.test';

  final client = MockClient((request) async {
    if (request.url.path.endsWith('/login')) {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final expected = body['email'] == 'teacher@kuphanda.test'
          ? 'KphTeacher2026'
          : 'KphStudent2026';

      if (body['password'] != expected) {
        return http.Response(
          jsonEncode({'success': false, 'message': 'Invalid credentials'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }

      signedInAs = body['email'] as String? ?? signedInAs;

      return _json({
        'data': {
          'token': signedInAs == 'teacher@kuphanda.test' ? 'teacher-token' : 'student-token',
          'user': _user(signedInAs),
        },
      });
    }

    // Signing in calls /me straight after, and it is authoritative: an empty
    // reply here wiped the account the test had just adopted.
    if (request.url.path.endsWith('/me')) {
      return _json({'data': _user(signedInAs)});
    }

    return _json({'data': []});
  });

  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    api: ApiClient(baseUrl: 'https://example.test/api/v1', token: null, httpClient: client),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

void main() {
  test('signing in with an email works and the profile follows the account',
      () async {
    final state = await _state();

    await state.signIn(email: 'teacher@kuphanda.test', password: 'KphTeacher2026');
    expect(state.profile.name, 'Mrs T. Chirwa');
    expect(state.isStaff, isTrue);
    expect(state.accountEmail, 'teacher@kuphanda.test');

    await state.signOut();
    await state.signIn(email: 'student@kuphanda.test', password: 'KphStudent2026');

    // The second person on the same phone must not inherit the first's name.
    expect(state.profile.name, 'Thoko Mwale');
    expect(state.isStaff, isFalse);
    expect(state.accountEmail, 'student@kuphanda.test');
  });

  test('a wrong password leaves the session you already had', () async {
    final state = await _state();
    await state.signIn(email: 'teacher@kuphanda.test', password: 'KphTeacher2026');

    await expectLater(
      state.signIn(email: 'teacher@kuphanda.test', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );

    expect(state.accountEmail, 'teacher@kuphanda.test');
    expect(state.isStaff, isTrue);
  });

  test('session parses the staff flag', () {
    final session = AuthSession.fromJson(
      {'id': 6, 'name': 'Mrs T. Chirwa', 'is_staff': true},
      token: 't',
    );

    expect(session.isStaff, isTrue);
  });
}
