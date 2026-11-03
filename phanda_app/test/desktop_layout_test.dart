import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/theme.dart';
import 'package:kuphanda/core/widgets/common.dart';
import 'package:kuphanda/core/widgets/document_card.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/models/reading.dart';
import 'package:kuphanda/data/seed/library_seed.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/billing/subscription_screen.dart';
import 'package:kuphanda/features/shell/app_sidebar.dart';
import 'package:kuphanda/features/shell/app_shell.dart';
import 'package:kuphanda/state/app_state.dart';

class _NoFiles implements DocumentFiles {
  @override
  Future<PickedPdf?> pickPdf() async => null;

  @override
  Future<DocumentAsset> store({
    required String documentId,
    required PickedPdf picked,
  }) async => throw UnimplementedError();

  @override
  Future<DocumentAsset> storeBytes({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    required int version,
    required String checksum,
    required int pageCount,
  }) async => throw UnimplementedError();

  @override
  Future<void> delete(DocumentAsset asset) async {}
}

/// A signed-in learner with three documents open, which is the state that makes
/// the progress screen say something.
Future<AppState> _learner() async {
  final catalogue = buildCatalogue().take(3).toList();
  final now = DateTime.now();
  final progress = <String, ReadingProgress>{
    for (var index = 0; index < catalogue.length; index++)
      catalogue[index].id: ReadingProgress(
        documentId: catalogue[index].id,
        currentPage: 4 + index,
        totalPages: 12,
        secondsSpent: 1800,
        lastReadAt: now.subtract(Duration(days: index)),
        completed: index == 0,
        fraction: index == 0 ? 1 : null,
      ),
  };

  final store = MemoryStateStore();
  await store.write(
    AppSnapshot(
      accountId: 7,
      accountEmail: 'chisomo@kuphanda.test',
      accountName: 'Chisomo Banda',
      profile: const Profile(
        name: 'Chisomo Banda',
        givenName: 'Chisomo',
        familyName: 'Banda',
        school: 'Bwaila Secondary School',
        form: 4,
        onboardingComplete: true,
      ),
      progress: progress,
    ),
  );

  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore('desktop-token'),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'desktop-token',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"data":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

/// Pumps the app shell at a desktop window size and opens [tab] through the
/// navigation rail, the way a person on a desktop would.
Future<void> _openTab(
  WidgetTester tester,
  String tab, {
  Size size = const Size(1280, 720),
}) async {
  tester.view.physicalSize = Size(size.width * 2, size.height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final state = await _learner();
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (tab.isNotEmpty) {
    await tester.tap(
      find.descendant(of: find.byType(AppSidebar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('the four progress tiles share one row on a desktop window', (
    tester,
  ) async {
    await _openTab(tester, 'Progress');

    final tiles = find.byType(StatTile);
    expect(tiles, findsNWidgets(4));

    final rects = [
      for (var index = 0; index < 4; index++) tester.getRect(tiles.at(index)),
    ];

    // One row: every tile starts at the same y.
    for (final rect in rects.skip(1)) {
      expect(
        rect.top,
        moreOrLessEquals(rects.first.top, epsilon: 0.5),
        reason: 'a tile wrapped onto a second row at 1280 dp',
      );
    }

    // Equal widths, so the numbers line up as a row of four rather than a
    // ragged grid.
    for (final rect in rects.skip(1)) {
      expect(
        rect.width,
        moreOrLessEquals(rects.first.width, epsilon: 0.5),
        reason: 'tiles were ${rects.map((r) => r.width).toList()} wide',
      );
    }

    // And the row uses the page width rather than huddling at the left edge.
    final rowWidth = rects.last.right - rects.first.left;
    expect(
      rowWidth,
      greaterThan(900),
      reason:
          'four 112 dp tiles in a row should span the content column, '
          'not ${rowWidth.toStringAsFixed(0)} dp',
    );
  });

  testWidgets('an empty week says so instead of leaving the chart blank', (
    tester,
  ) async {
    await _openTab(tester, 'Progress');

    expect(find.text('No study time recorded this week'), findsOneWidget);
  });

  testWidgets(
    'the subscription page keeps a reading column on a desktop window',
    (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final state = await _learner();
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const SubscriptionScreen(),
          ),
        ),
      );
      // The plan list spins while billing loads, so settle the layout rather than
      // waiting for animations that never end.
      await tester.pump(const Duration(milliseconds: 300));

      final smallPrint = find.textContaining('Receipts for subscriptions');
      expect(smallPrint, findsOneWidget);
      final width = tester.getSize(smallPrint).width;
      expect(
        width,
        lessThan(720),
        reason:
            'small print ran ${width.toStringAsFixed(0)} dp wide; a 1280 dp '
            'window must not stretch a paragraph across the whole page',
      );

      // The plan list is still waiting on billing; take the tree down and let the
      // request timers run out so the test does not end with one pending.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets('the library shows four columns on a desktop window', (
    tester,
  ) async {
    await _openTab(tester, 'Library');

    final cards = find.byType(DocumentGridCard);
    expect(cards, findsWidgets);

    final rects = [
      for (var index = 0; index < 4; index++) tester.getRect(cards.at(index)),
    ];
    for (final rect in rects.skip(1)) {
      expect(
        rect.top,
        moreOrLessEquals(rects.first.top, epsilon: 0.5),
        reason: 'the fourth card wrapped: ${rects.map((r) => r.top).toList()}',
      );
    }
    expect(cards.at(3).evaluate().isNotEmpty, isTrue);
  });
}
