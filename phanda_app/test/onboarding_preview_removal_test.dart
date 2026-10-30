import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/models/reading.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
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

/// The identity "Preview with sample data" used to write into the profile.
AppSnapshot _retiredSampleSnapshot() => AppSnapshot(
      profile: const Profile(
        name: 'Chisomo Banda',
        givenName: 'Chisomo',
        familyName: 'Banda',
        school: 'Bwaila Secondary School',
        form: 4,
        onboardingComplete: true,
      ),
      progress: {
        'ref-msce-agriculture-2017-p1': ReadingProgress(
          documentId: 'ref-msce-agriculture-2017-p1',
          currentPage: 4,
          totalPages: 6,
          fraction: 0.5,
        ),
      },
    );

Future<AppState> _initialized(AppSnapshot snapshot, {String? token}) async {
  final store = MemoryStateStore();
  await store.write(snapshot);
  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(token),
    // A signed-in start fires sync, billing and notifications in the background;
    // a stub answers them so the test stays about the profile flag.
    api: token == null ? null : _quietApi(),
  );
  await state.initialize();
  return state;
}

/// Answers the background calls a signed-in start makes, so the test is about
/// the profile flag rather than about reaching a server.
ApiClient _quietApi() => ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'live-token',
      httpClient: MockClient((request) async => http.Response(
            '{"data":[]}',
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

void main() {
  testWidgets('onboarding offers no way into the app without an account',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await _initialized(AppSnapshot());
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // The name step is where the shortcut used to sit, under Continue.
    // Without an account the only way forward is signing in; there is no
    // shortcut and no preview entry beside it.
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.textContaining('Preview'), findsNothing);
    expect(state.profile.onboardingComplete, isFalse);
  });

  test('a snapshot left in the sample profile is released to onboarding',
      () async {
    final state = await _initialized(_retiredSampleSnapshot());

    expect(state.profile.onboardingComplete, isFalse);

    // Only the profile is reset — the reading stays.
    final progress = state.progressFor('ref-msce-agriculture-2017-p1');
    expect(progress, isNotNull);
    expect(progress!.fraction, 0.5);
  });

  test('a real account is never treated as the sample, even on an exact match',
      () async {
    // This is the actual developer account: Chisomo Banda, Bwaila Secondary
    // School, Form 4. Releasing it signed the learner out of their own app.
    final snapshot = _retiredSampleSnapshot();
    snapshot.accountId = 5;
    snapshot.accountEmail = 'aishootsmo@gmail.com';

    final state = await _initialized(snapshot, token: 'live-token');

    expect(state.profile.onboardingComplete, isTrue);
  });

  test('the release happens once, so a second launch does not eject again',
      () async {
    // The reset leaves the identity untouched, so a release without a marker
    // re-fires forever: every start resets onboarding.
    final snapshot = _retiredSampleSnapshot();
    final store = MemoryStateStore();
    await store.write(snapshot);

    final first = AppState(store: store, files: _NoFiles(), tokenStore: MemoryTokenStore());
    await first.initialize();
    expect(first.profile.onboardingComplete, isFalse);

    // The learner finishes onboarding, keeping the same name and school.
    await first.completeOnboarding(
      name: 'Chisomo Banda',
      givenName: 'Chisomo',
      familyName: 'Banda',
      school: 'Bwaila Secondary School',
      form: 4,
      examYear: 2027,
      role: StudentRole.student,
      subjectIds: const <String>['mathematics', 'biology'],
    );

    // Second launch of the same install.
    final second = AppState(store: store, files: _NoFiles(), tokenStore: MemoryTokenStore());
    await second.initialize();

    // With no marker the release would reset this again on every single start.
    expect(second.profile.onboardingComplete, isTrue);
  });

  test('a signed-in learner with their details is put back in the library',
      () async {
    // Repair for the state the bad release left behind: profile complete,
    // onboarding reset. Asking for the same details again is our bug, not theirs.
    final snapshot = _retiredSampleSnapshot();
    snapshot.accountId = 5;
    snapshot.accountEmail = 'aishootsmo@gmail.com';
    snapshot.profile = snapshot.profile.copyWith(onboardingComplete: false);

    final state = await _initialized(snapshot, token: 'live-token');

    expect(state.profile.onboardingComplete, isTrue);
  });

  test('a partial match is treated as someone real and left alone', () async {
    final snapshot = _retiredSampleSnapshot();
    // Same name, a different school: a plausible real learner.
    snapshot.profile = snapshot.profile.copyWith(school: 'Bwaila Day Secondary');

    final state = await _initialized(snapshot);

    expect(state.profile.onboardingComplete, isTrue);
  });
}
