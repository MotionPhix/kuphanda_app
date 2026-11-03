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

Future<AppState> _signedIn() async {
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
    ),
  );
  final state = AppState(
    store: store,
    files: _NoFiles(),
    tokenStore: MemoryTokenStore('sidebar-token'),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'sidebar-token',
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

Future<void> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(1280, 720),
}) async {
  tester.view.physicalSize = Size(size.width * 2, size.height * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final state = await _signedIn();
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
}

void main() {
  testWidgets('the sidebar groups its destinations and names the account', (
    tester,
  ) async {
    await _pumpShell(tester);

    final sidebar = find.byType(AppSidebar);
    expect(sidebar, findsOneWidget);

    // Section labels, the primary action, both groups.
    expect(
      find.descendant(of: sidebar, matching: find.text('STUDY')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sidebar, matching: find.text('ACCOUNT')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sidebar, matching: find.text('Find a paper')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sidebar, matching: find.text('Subscription')),
      findsOneWidget,
    );

    // The footer carries the person, not just an avatar.
    expect(
      find.descendant(of: sidebar, matching: find.text('Chisomo Banda')),
      findsOneWidget,
    );
    // The second line carries the account's own detail. When the session has no
    // email — a school sign-in code rather than a mailbox — it falls back to the
    // school instead of leaving a blank row.
    expect(
      find.descendant(
        of: sidebar,
        matching: find.text('Bwaila Secondary School'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing a destination in the sidebar opens that screen', (
    tester,
  ) async {
    await _pumpShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Classes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No classes yet'), findsOneWidget);
  });

  testWidgets('the account menu offers the account screens and a way out', (
    tester,
  ) async {
    await _pumpShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Chisomo Banda'),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Profile', 'Subscription', 'Updates', 'Log out']) {
      expect(
        find.text(label),
        findsWidgets,
        reason: '$label is missing from the account menu',
      );
    }
  });

  testWidgets(
    'a tablet-width window keeps an icon rail, not a squeezed sidebar',
    (tester) async {
      await _pumpShell(tester, size: const Size(900, 800));

      final sidebar = find.byType(AppSidebar);
      expect(sidebar, findsOneWidget);
      expect(tester.getSize(sidebar).width, AppSidebar.collapsedWidth);
      expect(
        find.descendant(of: sidebar, matching: find.text('STUDY')),
        findsNothing,
      );
      expect(
        find.descendant(of: sidebar, matching: find.text('Library')),
        findsNothing,
      );
    },
  );
}
