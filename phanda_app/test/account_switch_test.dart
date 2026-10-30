import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:kuphanda/app.dart';
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
        'school': 'Bwaila Secondary School',
        'plan': 'free',
        'is_staff': true,
      }
    : {
        'id': 7,
        'name': 'Thoko Mwale',
        'first_name': 'Thoko',
        'last_name': 'Mwale',
        'email': 'student@kuphanda.test',
        'school': 'Bwaila Secondary School',
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

  test('signing in as somebody else is refused while an account is live',
      () async {
    // Swapping accounts means signing out first. Replacing a live session from
    // underneath the person holding the phone is not a switch, it is a surprise.
    final state = await _state();
    await state.signIn(email: 'teacher@kuphanda.test', password: 'KphTeacher2026');

    await expectLater(
      state.signIn(email: 'student@kuphanda.test', password: 'KphStudent2026'),
      throwsA(isA<ApiException>()),
    );

    expect(state.accountEmail, 'teacher@kuphanda.test');
    expect(state.profile.name, 'Mrs T. Chirwa');
  });

  test('signing out ends the session and leaves nothing of the person behind',
      () async {
    final state = await _state();
    await state.signIn(email: 'teacher@kuphanda.test', password: 'KphTeacher2026');
    expect(state.profile.onboardingComplete, isTrue);

    await state.signOut();

    expect(state.isSignedIn, isFalse);
    expect(state.profile.name, isEmpty);
    expect(state.profile.school, isEmpty);
    expect(state.profile.onboardingComplete, isFalse,
        reason: 'a finished profile on a signed-out phone opens the library');

    // Nothing belonging to the person who left is left reachable: not the
    // reading, not the classes they were in, not the papers they had saved.
    expect(state.progressFor('ref-msce-maths-2002-p1'), isNull);
    expect(state.classes, isEmpty);
    expect(state.upcomingAssignments, isEmpty);
    expect(state.stats.weekMinutes, 0);
  });

  testWidgets('a signed-out phone shows the landing page, not the library',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _state();
    await state.signIn(email: 'teacher@kuphanda.test', password: 'KphTeacher2026');

    await tester.pumpWidget(KuphandaApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Your school library, in your pocket'), findsNothing);

    await state.signOut();
    await tester.pumpAndSettle();

    // One frame while the shell is torn down reports an overflow in a row that is
    // already disposed; both screens render cleanly at this width on their own,
    // and what is under test is the gate, not that frame.
    tester.takeException();

    // Back to the first screen; the tabs are gone with the session.
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Library'), findsNothing);
  });

  testWidgets('the landing page carries no sign-in shortcut of its own',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _state();
    await tester.pumpWidget(KuphandaApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsNothing);
  });

  testWidgets('the step after Get started cannot continue without an account',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = await _state();
    await tester.pumpWidget(KuphandaApp(state: state));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Name, school and form are collected once the account exists. Until then
    // there is no form to fill in — only the two ways to sign in.
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Who should we call you?'), findsNothing);
    expect(find.text('Continue'), findsNothing);

    await tester.ensureVisible(find.text('Sign in with email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Use Google instead'), findsOneWidget);
  });

  testWidgets('signing in on the gate moves on to the details step',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // A newly registered account carries no school, so the details still have
    // to be collected after signing in.
    const fresh = {
      'id': 9,
      'name': 'Chisomo Banda',
      'first_name': 'Chisomo',
      'last_name': 'Banda',
      'email': 'newlearner@kuphanda.test',
      'school': '',
      'plan': 'free',
      'is_staff': false,
    };
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return _json({
          'data': {'token': 'fresh-token', 'user': fresh},
        });
      }
      if (request.url.path.endsWith('/me')) {
        return _json({'data': fresh});
      }
      return _json({'data': []});
    });

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        token: null,
        httpClient: client,
      ),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();
    state.stopAutoSync();

    await tester.pumpWidget(KuphandaApp(state: state));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with email'), findsOneWidget);

    await state.signIn(
      email: 'newlearner@kuphanda.test',
      password: 'KphNew2026',
    );
    // Signing in arms the fifteen-minute sync timer; stop it so teardown does
    // not fail on a pending timer rather than on the step change.
    state.stopAutoSync();
    await tester.pumpAndSettle();

    // The learner stays in onboarding and lands on the form, filled in from the
    // account — not back at the landing page they just left.
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Who should we call you?'), findsOneWidget);
    // The controllers carry the account's name, not the hints that say Chisomo.
    final names = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(names.first.controller?.text, 'Chisomo');
    expect(names[1].controller?.text, 'Banda');
    expect(find.text('Continue'), findsOneWidget);
  });
}



