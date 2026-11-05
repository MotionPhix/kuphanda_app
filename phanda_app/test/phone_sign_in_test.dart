import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/app.dart';
import 'package:kuphanda/core/phone.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/features/profile/phone_sign_in_sheet.dart';
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

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> _user({String? phone}) => <String, Object?>{
      'id': 9,
      'name': 'Chisomo Banda',
      'first_name': 'Chisomo',
      'last_name': 'Banda',
      'email': phone == null ? 'chisomo@school.mw' : null,
      'phone': phone,
      'phone_verified': phone != null,
      'school': 'Bwaila Secondary School',
      'plan': 'free',
      'is_staff': false,
      'role': 'student',
      'form': 3,
      'profile_completed': true,
    };

/// A server that behaves like the real one for the three phone purposes.
Future<AppState> _state({
  bool numberKnown = true,
  String code = '123456',
}) async {
  var signedIn = false;

  final client = MockClient((request) async {
    final path = request.url.path;

    if (path.endsWith('/auth/otp/start')) {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final purpose = body['purpose'];

      if (purpose == 'login' && !numberKnown) {
        return _json({
          'success': true,
          'message': 'No account uses that number yet.',
          'data': {
            'exists': false,
            'phone': body['phone'],
            'channel': 'whatsapp',
          },
        });
      }

      return _json({
        'success': true,
        'message': 'A code is on its way to WhatsApp.',
        'data': {
          'exists': true,
          'challenge': 'challenge-1',
          'phone': body['phone'],
          'masked': '+265 ••• ••• 567',
          'channel': 'whatsapp',
          'expires_in': 600,
          'resend_after': 60,
        },
      });
    }

    if (path.endsWith('/auth/otp/verify')) {
      final body = jsonDecode(request.body) as Map<String, Object?>;

      if (body['code'] != code) {
        return _json({
          'success': false,
          'message': 'That code is not right. Check the six digits and try again.',
          'errors': {'code': 'OTP_INVALID'},
        }, 422);
      }

      signedIn = true;

      return _json({
        'success': true,
        'message': 'Signed in with WhatsApp',
        'data': {
          'token': 'phone-token',
          'user': _user(phone: '+265991234567'),
        },
      });
    }

    if (path.endsWith('/me')) {
      return _json({
        'success': true,
        'data': _user(phone: signedIn ? '+265991234567' : null),
      });
    }

    return _json({'success': true, 'data': <Object?>[]});
  });

  final state = AppState(
    store: MemoryStateStore(),
    files: _NoFiles(),
    api: ApiClient(
      baseUrl: 'https://example.test/api/v1',
      token: null,
      httpClient: client,
    ),
    tokenStore: MemoryTokenStore(),
  );

  await state.initialize();
  state.stopAutoSync();

  return state;
}

void main() {
  group('numbers are read the way people type them', () {
    test('local, spaced, and international all land on one E.164 form', () {
      for (final typed in <String>[
        '0991234567',
        '099 123 4567',
        '265991234567',
        '+265991234567',
        '991234567',
      ]) {
        expect(PhoneNumber.normalise(typed), '+265991234567',
            reason: 'typed "$typed"');
      }
    });

    test('a landline or nonsense is refused before anything is sent', () {
      expect(PhoneNumber.normalise('021234567'), isNull);
      expect(PhoneNumber.normalise('123'), isNull);
      expect(PhoneNumber.normalise('not a number'), isNull);
      expect(PhoneNumber.normalise(''), isNull);
    });

    test('what is shown back is recognisable but not harvestable', () {
      expect(PhoneNumber.mask('+265991234567'), '+265 ••• ••• 567');
      expect(PhoneNumber.pretty('+265991234567'), '+265 991 234 567');
      expect(PhoneNumber.mask('+265991234567'), isNot(contains('9912')));
    });
  });

  test('a correct code signs in and the account carries its number', () async {
    final state = await _state();

    final sent = await state.startPhoneCode(phone: '+265991234567');
    expect(sent.sent, isTrue);
    expect(sent.masked, '+265 ••• ••• 567');

    await state.signInWithPhoneCode(
      challenge: sent.challenge!,
      code: '123456',
    );

    expect(state.isSignedIn, isTrue);
    expect(state.accountPhone, '+265991234567');
    expect(state.accountPhoneVerified, isTrue);
  });

  test('a wrong code changes nothing', () async {
    final state = await _state();
    final sent = await state.startPhoneCode(phone: '0991234567');

    await expectLater(
      state.signInWithPhoneCode(challenge: sent.challenge!, code: '000000'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('not right'),
        ),
      ),
    );

    expect(state.isSignedIn, isFalse);
  });

  test('an unknown number is reported rather than silently ignored', () async {
    final state = await _state(numberKnown: false);

    final sent = await state.startPhoneCode(phone: '0881234567');

    expect(sent.exists, isFalse);
    expect(sent.sent, isFalse);
    expect(state.isSignedIn, isFalse);
  });

  testWidgets('the sheet asks for the code, and says so when the number is new',
      (tester) async {
    final state = await _state(numberKnown: false);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPhoneSignInSheet(context, state),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with WhatsApp'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '0881234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    // No code was sent, so the sheet must not pretend one was: it offers to
    // create the account instead.
    expect(find.text('Enter the code'), findsNothing);
    expect(find.textContaining('No account uses that number yet'), findsOneWidget);
  });

  testWidgets('the sheet moves to the code step once a code is sent',
      (tester) async {
    final state = await _state();

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPhoneSignInSheet(context, state),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '099 123 4567');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('+265 ••• ••• 567'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pumpAndSettle();

    expect(state.isSignedIn, isTrue);
    expect(find.text('Enter the code'), findsNothing);

    // A signed-in account starts the periodic sync timer, and the confirmation
    // snackbar owns a four-second one. Both are legitimate; neither belongs to
    // a finished test.
    state.stopAutoSync();
    await tester.pump(const Duration(seconds: 5));
  });
}
