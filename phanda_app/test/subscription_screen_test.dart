import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/billing/subscription_screen.dart';
import 'package:kuphanda/state/app_state.dart';

void main() {
  testWidgets('signed-out users are asked to sign in before subscribing', (tester) async {
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
}
