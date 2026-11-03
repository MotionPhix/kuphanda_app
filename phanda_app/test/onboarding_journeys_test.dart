import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/onboarding/onboarding_screen.dart';
import 'package:kuphanda/features/shell/app_sidebar.dart';
import 'package:kuphanda/features/shell/app_shell.dart';
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

/// A stand-in for the API that keeps accounts the way the server does: role,
/// form, and whether onboarding was ever finished.
class _Server {
  _Server({List<Map<String, Object?>> accounts = const []}) {
    for (final account in accounts) {
      _accounts[account['email'] as String] = Map<String, Object?>.of(account);
    }
  }

  final _accounts = <String, Map<String, Object?>>{};
  String? _current;
  var _nextId = 100;

  Map<String, Object?>? account(String email) => _accounts[email];

  MockClient get client => MockClient(_handle);

  Map<String, Object?> _session(Map<String, Object?> account) => {
        'data': {
          'token': 'token-${account['email']}',
          'user': account,
        },
      };

  /// The completion rule the server applies after a profile save.
  void _settleCompletion(Map<String, Object?> account) {
    final first = (account['first_name'] as String? ?? '').trim();
    final last = (account['last_name'] as String? ?? '').trim();
    final role = account['role'] as String? ?? 'student';
    final complete = first.isNotEmpty &&
        last.isNotEmpty &&
        (role == 'teacher' || account['form'] != null);
    if (complete) account['profile_completed'] = true;
  }

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(request.body) as Map<String, Object?>;

    if (path.endsWith('/register')) {
      final email = body['email'] as String? ?? '';
      if (_accounts.containsKey(email)) {
        return _json({'message': 'The email has already been taken.'}, 422);
      }
      final name = (body['name'] as String? ?? '').trim();
      final parts = name.split(' ');
      final account = <String, Object?>{
        'id': _nextId++,
        'name': name,
        'first_name': parts.isEmpty ? '' : parts.first,
        'last_name': parts.length > 1 ? parts.sublist(1).join(' ') : '',
        'email': email,
        'school': null,
        'plan': 'free',
        'is_staff': false,
        'role': 'student',
        'form': null,
        'profile_completed': false,
        'password': body['password'],
      };
      _accounts[email] = account;
      _current = email;
      return _json(_session(account), 201);
    }

    if (path.endsWith('/login')) {
      final email = body['email'] as String? ?? '';
      final account = _accounts[email];
      if (account == null || account['password'] != body['password']) {
        return _json({'message': 'Invalid credentials'}, 401);
      }
      _current = email;
      return _json(_session(account));
    }

    if (path.endsWith('/auth/google')) {
      // The id token names the account: `google:<email>`.
      final token = body['id_token'] as String? ?? '';
      final email = token.contains(':') ? token.split(':').last : 'google@example.test';
      final existing = _accounts[email];
      if (existing != null) {
        _current = email;
        return _json(_session(existing));
      }
      final account = <String, Object?>{
        'id': _nextId++,
        'name': 'Google Person',
        'first_name': 'Google',
        'last_name': 'Person',
        'email': email,
        'school': null,
        'plan': 'free',
        'is_staff': false,
        'role': 'student',
        'form': null,
        'profile_completed': false,
        'google_linked': true,
        'password': null,
      };
      _accounts[email] = account;
      _current = email;
      return _json(_session(account));
    }

    if (path.endsWith('/me')) {
      final account = _accounts[_current];
      if (account == null) return _json({'message': 'Unauthenticated.'}, 401);

      if (request.method == 'PATCH' || request.method == 'PUT') {
        for (final field in ['first_name', 'last_name', 'school', 'role', 'form', 'name']) {
          if (body.containsKey(field)) account[field] = body[field];
        }
        final first = (account['first_name'] as String? ?? '').trim();
        final last = (account['last_name'] as String? ?? '').trim();
        if (first.isNotEmpty || last.isNotEmpty) {
          account['name'] = '$first $last'.trim();
        }
        _settleCompletion(account);
      }

      return _json({'data': account});
    }

    return _json({'data': []});
  }

  /// Signs an account in on a phone that has never seen it, so the test can see
  /// what a returning user gets.

}

Future<AppState> _stateFor(_Server server, {TokenStore? tokenStore}) async {
  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    tokenStore: tokenStore ?? MemoryTokenStore(),
    api: ApiClient(
      baseUrl: 'https://api.test/api/v1',
      token: null,
      httpClient: server.client,
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

Future<void> _pumpApp(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(KuphandaApp(state: state));
  await tester.pumpAndSettle();
}

Future<void> _onboard(
  AppState state, {
  required StudentRole role,
  required String first,
  required String last,
}) =>
    state.completeOnboarding(
      name: '$first $last',
      givenName: first,
      familyName: last,
      school: '',
      form: 3,
      examYear: 2028,
      role: role,
      subjectIds: const ['mathematics', 'biology', 'chemistry', 'physics'],
    );

void main() {
  testWidgets('a new student registers, answers onboarding once, and gets the learner shell',
      (tester) async {
    final server = _Server();
    final state = await _stateFor(server);
    await _pumpApp(tester, state);

    // Signed out: the landing page, never the library.
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await state.registerAccount(
      name: 'Tadala Phiri',
      email: 'tadala@example.test',
      password: 'secret123',
    );
    state.stopAutoSync();
    await tester.pumpAndSettle();

    // A brand-new account has no profile on the server, so it is interviewed.
    expect(state.profile.onboardingComplete, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await _onboard(state, role: StudentRole.student, first: 'Tadala', last: 'Phiri');
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('STUDY'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Papers set'), findsNothing);

    // What onboarding answered reached the server.
    final account = server.account('tadala@example.test')!;
    expect(account['role'], 'student');
    expect(account['form'], 3);
    expect(account['profile_completed'], isTrue);
  });

  testWidgets('a new teacher registers and lands on the teaching side',
      (tester) async {
    final server = _Server();
    final state = await _stateFor(server);
    await _pumpApp(tester, state);

    await state.registerAccount(
      name: 'Grace Mwale',
      email: 'grace@example.test',
      password: 'secret123',
    );
    state.stopAutoSync();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await _onboard(state, role: StudentRole.teacher, first: 'Grace', last: 'Mwale');
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.descendant(of: find.byType(AppSidebar), matching: find.text('TEACHING')), findsOneWidget);
    // A teacher runs rooms; the learner progress screen is not theirs.
    expect(find.text('Progress'), findsNothing);
    expect(find.text('Papers set'), findsOneWidget);

    final account = server.account('grace@example.test')!;
    expect(account['role'], 'teacher');
    expect(account['form'], isNull);
    expect(account['profile_completed'], isTrue);
  });

  testWidgets('a returning student signs in and is not asked onboarding again',
      (tester) async {
    final server = _Server(accounts: [
      {
        'id': 7,
        'name': 'Thoko Mwale',
        'first_name': 'Thoko',
        'last_name': 'Mwale',
        'email': 'thoko@example.test',
        'school': null, // never filled the optional field
        'plan': 'free',
        'is_staff': false,
        'role': 'student',
        'form': 3,
        'profile_completed': true,
        'password': 'secret123',
      },
    ]);

    final state = await _stateFor(server);
    await _pumpApp(tester, state);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await state.signIn(email: 'thoko@example.test', password: 'secret123');
    state.stopAutoSync();
    await tester.pumpAndSettle();

    // No school on the account, and still no interview.
    expect(state.profile.onboardingComplete, isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(state.profile.role, StudentRole.student);
    expect(state.profile.form, 3);
  });

  testWidgets('a returning teacher signs in straight to the teaching shell',
      (tester) async {
    final server = _Server(accounts: [
      {
        'id': 6,
        'name': 'Grace Mwale',
        'first_name': 'Grace',
        'last_name': 'Mwale',
        'email': 'grace@example.test',
        'school': 'Bwaila Secondary School',
        'plan': 'free',
        'is_staff': true,
        'role': 'teacher',
        'form': null,
        'profile_completed': true,
        'password': 'secret123',
      },
    ]);

    final state = await _stateFor(server);
    await _pumpApp(tester, state);

    await state.signIn(email: 'grace@example.test', password: 'secret123');
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(state.profile.role, StudentRole.teacher);
    expect(find.descendant(of: find.byType(AppSidebar), matching: find.text('TEACHING')), findsOneWidget);
    expect(find.text('Progress'), findsNothing);
  });

  testWidgets('signing up with Google asks a new person for onboarding',
      (tester) async {
    final server = _Server();
    final state = await _stateFor(server);
    await _pumpApp(tester, state);

    await state.signInWithGoogle('google:new.learner@gmail.test', sync: false);
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(state.isSignedIn, isTrue);
    expect(state.profile.onboardingComplete, isFalse,
        reason: 'a Google account the server has never interviewed needs onboarding');
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await _onboard(state, role: StudentRole.student, first: 'Google', last: 'Person');
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(server.account('new.learner@gmail.test')!['profile_completed'], isTrue);
  });

  testWidgets('logging in with Google skips onboarding for a known teacher',
      (tester) async {
    final server = _Server(accounts: [
      {
        'id': 9,
        'name': 'Grace Mwale',
        'first_name': 'Grace',
        'last_name': 'Mwale',
        'email': 'grace@gmail.test',
        'school': null,
        'plan': 'free',
        'is_staff': false,
        'role': 'teacher',
        'form': null,
        'profile_completed': true,
        'google_linked': true,
        'password': null,
      },
    ]);

    final state = await _stateFor(server);
    await _pumpApp(tester, state);

    await state.signInWithGoogle('google:grace@gmail.test', sync: false);
    state.stopAutoSync();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(state.profile.role, StudentRole.teacher);
    expect(find.text('Papers set'), findsOneWidget);
  });

  testWidgets('a session restored on a cold start is trusted, not re-interviewed',
      (tester) async {
    final server = _Server(accounts: [
      {
        'id': 12,
        'name': 'Grace Mwale',
        'first_name': 'Grace',
        'last_name': 'Mwale',
        'email': 'grace@example.test',
        'school': null,
        'plan': 'free',
        'is_staff': false,
        'role': 'teacher',
        'form': null,
        'profile_completed': true,
        'password': 'secret123',
      },
    ]);

    final store = MemoryStateStore();
    final tokens = MemoryTokenStore();

    // First run: sign in on this phone.
    final first = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: tokens,
      api: ApiClient(
        baseUrl: 'https://api.test/api/v1',
        token: null,
        httpClient: server.client,
      ),
    );
    await first.initialize();
    first.stopAutoSync();
    await first.signIn(email: 'grace@example.test', password: 'secret123');
    first.stopAutoSync();

    // Second run: the app is killed and opened again with the stored token.
    final second = AppState(
      store: store,
      files: _NoFiles(),
      tokenStore: tokens,
      api: ApiClient(
        baseUrl: 'https://api.test/api/v1',
        token: null,
        httpClient: server.client,
      ),
    );
    await second.initialize();
    second.stopAutoSync();

    await _pumpApp(tester, second);
    second.stopAutoSync();
    await tester.pumpAndSettle();

    expect(second.isSignedIn, isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.descendant(of: find.byType(AppSidebar), matching: find.text('TEACHING')), findsOneWidget);
  });
}


