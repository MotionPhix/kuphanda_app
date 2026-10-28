import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';

void main() {
  test('skips a malformed catalogue row instead of failing the whole sync',
      () async {
    final payload = {
      'data': [
        {
          'id': 'good-paper',
          'title': 'Mathematics Paper I',
          'subject_id': 'mathematics',
          'kind': 'pastPaper',
          'form': 4,
          'pages': 6,
          'format': 'blocks',
          'has_blocks': true,
          'updated_at': '2026-10-28T12:00:00+00:00',
          'price_mwk': 0,
          'is_entitled': true,
        },
        // No id: this is the row that used to abort the entire catalogue.
        {'title': 'Broken row', 'subject_id': 'biology'},
      ],
      'meta': {'last_page': 1},
    };

    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      token: 'test-token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/documents');
        return http.Response(jsonEncode(payload), 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    final documents = await client.fetchDocuments();

    expect(documents, hasLength(1));
    expect(documents.single.document.id, 'good-paper');
    expect(documents.single.document.hasBlocks, isTrue);
    expect(documents.single.document.format, 'blocks');
  });

  test('still returns every row when all of them are valid', () async {
    final payload = {
      'data': [
        {'id': 'a', 'title': 'A', 'subject_id': 'mathematics', 'updated_at': '2026-10-28T12:00:00+00:00'},
        {'id': 'b', 'title': 'B', 'subject_id': 'biology', 'updated_at': '2026-10-28T12:00:00+00:00'},
      ],
      'meta': {'last_page': 1},
    };

    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      token: 'test-token',
      httpClient: MockClient((_) async => http.Response(jsonEncode(payload), 200,
          headers: {'content-type': 'application/json'})),
    );

    final documents = await client.fetchDocuments();

    expect(documents.map((d) => d.document.id), ['a', 'b']);
  });
}
