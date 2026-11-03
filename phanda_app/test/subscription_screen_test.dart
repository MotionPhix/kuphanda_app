import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/billing/subscription_screen.dart';
import 'package:kuphanda/state/app_state.dart';

void main() {
  testWidgets('signed-out users are asked to sign in before subscribing', (
    tester,
  ) async {
    final state = AppState(
      store: MemoryStateStore(),
      files: FakeDocumentFiles(),
      tokenStore: MemoryTokenStore(),
    );
    await state.initialize();

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to the library'), findsOneWidget);
    expect(find.text('Sign in or create an account'), findsOneWidget);
    // No second copy of the form: the screen opens the same sheet the
    // onboarding gate uses.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Sign in or create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
  });

  testWidgets('a failed plan fetch says so instead of spinning for ever', (
    tester,
  ) async {
    // Found on the live server: /plans came back as a server error and the page
    // sat on a spinner with nothing to press.
    final store = MemoryStateStore();
    await store.write(
      AppSnapshot(
        accountId: 7,
        accountEmail: 'learner@kuphanda.test',
        accountName: 'Live Test',
        profile: const Profile(name: 'Live Test', onboardingComplete: true),
      ),
    );

    final state = AppState(
      store: store,
      files: FakeDocumentFiles(),
      tokenStore: MemoryTokenStore('token'),
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"Server Error"}',
            500,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );
    await state.initialize();
    state.stopAutoSync();

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load the plans'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}
