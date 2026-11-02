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
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/profile/change_password_sheet.dart';
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

/// A signed-in phone with no library behind it.
Future<AppState> _signedIn(MockClient client) async {
  final state = AppState(
    store: MemoryStateStore(
      AppSnapshot(
        accountId: 3,
        accountEmail: 'learner@kuphanda.test',
        accountName: 'Learner',
        profile: const Profile(form: 4),
      ),
    ),
    files: _NoFiles(),
    tokenStore: MemoryTokenStore('live-token'),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: 'live-token',
      httpClient: client,
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

void main() {
  testWidgets('the sheet refuses a short or mistyped new password',
      (tester) async {
    var saves = 0;
    final client = MockClient((request) async {
      if (request.method == 'PUT' && request.url.path.endsWith('/password')) {
        saves++;
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final state = await _signedIn(client);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChangePasswordSheet(context, state),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'old-one');
    await tester.enterText(fields.at(1), 'short');
    await tester.enterText(fields.at(2), 'short');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('eight characters'), findsOneWidget);
    expect(saves, 0);

    await tester.enterText(fields.at(1), 'long-enough-1');
    await tester.enterText(fields.at(2), 'long-enough-2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('do not match'), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('a wrong current password is reported without closing the sheet',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'PUT' && request.url.path.endsWith('/password')) {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'The given data was invalid.',
            'errors': {
              'current_password': ['That is not the password this account uses now.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final state = await _signedIn(client);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChangePasswordSheet(context, state),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'wrong-one');
    await tester.enterText(fields.at(1), 'long-enough-1');
    await tester.enterText(fields.at(2), 'long-enough-1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not the password'), findsOneWidget);
    // Still open, with the form intact.
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('a changed password closes the sheet and says so', (tester) async {
    String? sent;
    final client = MockClient((request) async {
      if (request.method == 'PUT' && request.url.path.endsWith('/password')) {
        sent = request.body;
        return http.Response(
          jsonEncode({'success': true, 'message': 'Password changed.'}),
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
    final state = await _signedIn(client);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChangePasswordSheet(context, state),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'old-one');
    await tester.enterText(fields.at(1), 'brand-new-9');
    await tester.enterText(fields.at(2), 'brand-new-9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final body = jsonDecode(sent!) as Map<String, Object?>;
    expect(body['current_password'], 'old-one');
    expect(body['password'], 'brand-new-9');
    expect(body['password_confirmation'], 'brand-new-9');

    expect(find.text('Save'), findsNothing);
    expect(find.textContaining('Other devices are signed out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}



