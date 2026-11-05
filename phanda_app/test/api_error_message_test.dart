import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';

ApiClient _clientReturning(int status, Map<String, Object?> body) {
  return ApiClient(
    baseUrl: 'https://library.test/api/v1',
    token: 'token',
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
}

void main() {
  test('a server fault is explained in plain language, not as "Server Error"', () async {
    final client = _clientReturning(500, {'message': 'Server Error'});

    await expectLater(
      client.fetchClassrooms(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 500)
            .having(
              (e) => e.message,
              'message',
              'The library had a problem on its side. Try again in a moment.',
            ),
      ),
    );
  });

  test('a validation sentence from the server is still shown as written', () async {
    final client = _clientReturning(422, {
      'message': 'The given data was invalid.',
      'errors': {
        'email': ['That email is already registered.'],
      },
    });

    await expectLater(
      client.fetchClassrooms(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'That email is already registered.'),
      ),
    );
  });

  test('a meaningful server sentence survives a 4xx', () async {
    final client = _clientReturning(409, {'message': 'That class is full.'});

    await expectLater(
      client.fetchClassrooms(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'That class is full.')),
    );
  });

  test('a configuration sentence on a 503 reaches the learner', () async {
    final client = _clientReturning(503, {'message': 'Google sign-in is not configured.'});

    await expectLater(
      client.fetchClassrooms(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Google sign-in is not configured.'),
      ),
    );
  });

  test('a bare 503 still reads as a problem on the server side', () async {
    final client = _clientReturning(503, {'message': 'Service Unavailable'});

    await expectLater(
      client.fetchClassrooms(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'The library had a problem on its side. Try again in a moment.',
        ),
      ),
    );
  });
}
