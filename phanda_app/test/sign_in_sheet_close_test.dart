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
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/onboarding/onboarding_screen.dart';
import 'package:kuphanda/state/app_state.dart';

class _NoFiles implements DocumentFiles {
  @override
  Future<PickedPdf?> pickPdf() async => null;
  @override
  Future<DocumentAsset> store({
    required String documentId,
    required PickedPdf picked,
  }) async =>
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

void main() {
  testWidgets('closing the sign-in sheet leaves the onboarding screen usable',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();
    state.stopAutoSync();

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);

    // The phone raises the keyboard over the sheet and drops it again while the
    // sheet is still open; the inset coming and going is what the phone does
    // before Cancel is ever tapped.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // The gate is still there, and nothing threw while the sheet went away.
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgotten password sends a link and says where to look',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    var askedFor = '';

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/forgot-password')) {
        askedFor =
            (jsonDecode(request.body) as Map<String, Object?>)['email']
                as String;
        return http.Response(
          jsonEncode({'success': true, 'message': 'Password reset link sent'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        token: null,
        httpClient: client,
      ),
    );
    await state.initialize();

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();

    // Without an address there is nothing to send to, and the sheet says so
    // rather than failing silently.
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Type your email first'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'tadala@kuphanda.test');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(askedFor, 'tadala@kuphanda.test');
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('tadala@kuphanda.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a learner without an account can create one from the sheet',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    const fresh = {
      'id': 11,
      'name': 'Tadala Phiri',
      'first_name': '',
      'last_name': '',
      'email': 'tadala@kuphanda.test',
      'school': '',
      'plan': 'free',
      'is_staff': false,
    };
    var registered = false;

    final client = MockClient((request) async {
      Object body = {'data': []};
      if (request.url.path.endsWith('/register')) {
        registered = true;
        body = {
          'data': {'token': 'new-token', 'user': fresh},
        };
      } else if (request.url.path.endsWith('/me')) {
        body = {'data': fresh};
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final state = AppState(
      store: MemoryStateStore(),
      files: _NoFiles(),
      tokenStore: MemoryTokenStore(),
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        token: null,
        httpClient: client,
      ),
    );
    await state.initialize();

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();

    // A sign-in box with no way to join is a dead end for a new learner.
    expect(find.text('New here? Create an account'), findsOneWidget);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Tadala Phiri');
    await tester.enterText(fields.at(1), 'tadala@kuphanda.test');
    await tester.enterText(fields.at(2), 'Tadala2026');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(registered, isTrue);
    expect(state.isSignedIn, isTrue);
    expect(state.accountEmail, 'tadala@kuphanda.test');
    // Landed on the details step, which the new account still has to fill in.
    expect(find.text('Who should we call you?'), findsOneWidget);
    state.stopAutoSync();
  });
}
