import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<AppState> _initialized(AppSnapshot snapshot) async {
  final store = MemoryStateStore();
  await store.write(snapshot);
  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(),
  );
  await state.initialize();
  return state;
}

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
    expect(find.text('Continue'), findsOneWidget);
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

  test('a real learner with the same name is left alone', () async {
    final snapshot = _retiredSampleSnapshot();
    snapshot.accountId = 4;
    snapshot.accountEmail = 'kingscrib1@gmail.com';

    final state = await _initialized(snapshot);

    expect(state.profile.onboardingComplete, isTrue);
  });
}
