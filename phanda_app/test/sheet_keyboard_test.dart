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
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/profile/change_password_sheet.dart';
import 'package:kuphanda/features/profile/profile_screen.dart';
import 'package:kuphanda/features/profile/sign_in_sheet.dart';
import 'package:kuphanda/state/app_state.dart';

import 'support/phone_sheet.dart';

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

Future<AppState> _state({bool signedIn = false}) async {
  final client = MockClient((request) async => http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      ));

  final state = AppState(
    store: MemoryStateStore(
      signedIn
          ? AppSnapshot(
              accountId: 1,
              accountEmail: 'learner@kuphanda.test',
              accountName: 'Learner',
              profile: const Profile(
                name: 'Tadala Phiri',
                givenName: 'Tadala',
                familyName: 'Phiri',
                school: 'Bwaila',
                form: 4,
              ),
            )
          : null,
    ),
    files: _NoFiles(),
    tokenStore: MemoryTokenStore(signedIn ? 'token' : null),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: signedIn ? 'token' : null,
      httpClient: client,
    ),
  );
  await state.initialize();
  state.stopAutoSync();
  return state;
}

Widget _host(AppState state, Future<void> Function(BuildContext) open) {
  return AppScope(state: state, child: sheetHost(open));
}

void main() {
  testWidgets('the sign-in sheet keeps every field above the keyboard',
      (tester) async {
    final state = await _state();
    final phone = PhoneSheet(tester);

    await phone.open(
      _host(state, (context) => showSignInSheet(context, state)),
      (context) => showSignInSheet(context, state),
    );

    expect(phone.visibleBottom, 520);
    await phone.expectReachable(find.byType(TextField).first, reason: 'email field');
    await phone.expectReachable(find.byType(TextField).last, reason: 'password field');
    await phone.expectReachable(find.widgetWithText(FilledButton, 'Sign in'),
        reason: 'sign-in button');
  });

  testWidgets('the edit-profile sheet keeps its fields above the keyboard',
      (tester) async {
    final state = await _state(signedIn: true);
    final phone = PhoneSheet(tester);

    await phone.open(
      _host(state, (context) => showEditProfile(context, state)),
      (context) => showEditProfile(context, state),
    );

    expect(find.byType(TextField), findsWidgets);
    for (var index = 0; index < find.byType(TextField).evaluate().length; index++) {
      await phone.expectReachable(find.byType(TextField).at(index),
          reason: 'field $index', scroll: true);
    }
    await phone.expectReachable(find.widgetWithText(FilledButton, 'Save'),
        reason: 'save button', scroll: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the change-password sheet keeps its fields above the keyboard',
      (tester) async {
    final state = await _state(signedIn: true);
    final phone = PhoneSheet(tester);

    await phone.open(
      _host(state, (context) => showChangePasswordSheet(context, state)),
      (context) => showChangePasswordSheet(context, state),
    );

    for (var index = 0; index < find.byType(TextField).evaluate().length; index++) {
      await phone.expectReachable(find.byType(TextField).at(index),
          reason: 'field $index', scroll: true);
    }
    await phone.expectReachable(find.widgetWithText(FilledButton, 'Save'),
        reason: 'save button', scroll: true);
  });
}



