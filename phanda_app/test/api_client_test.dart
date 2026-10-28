import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';

ApiClient _client(Future<http.Response> Function(http.Request) handler) {
  return ApiClient(
    baseUrl: 'https://library.test/api/v1',
    token: 'test-token',
    httpClient: MockClient(handler),
  );
}

void main() {
  test('parses plans and sends the bearer token', () async {
    late http.Request seen;
    final client = _client((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'slug': 'week',
              'name': 'Weekly pass',
              'tier': 'weekly',
              'price_mwk': 1500,
              'duration_days': 7,
              'description': 'Seven days',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final plans = await client.fetchPlans();

    expect(seen.headers['Authorization'], 'Bearer test-token');
    expect(plans.single.name, 'Weekly pass');
    expect(plans.single.priceMwk, 1500);
  });

  test('parses entitlement flags on documents', () async {
    final client = _client((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'premium',
              'title': 'Premium paper',
              'subject_id': 'mathematics',
              'form': 4,
              'kind': 'pastPaper',
              'access_tier': 'weekly',
              'price_mwk': 2500,
              'is_entitled': false,
              'pages': 20,
              'updated_at': '2026-10-27T10:00:00+00:00',
              'current_version': {
                'number': 2,
                'file_name': 'paper.pdf',
                'size_bytes': 1024,
                'page_count': 20,
                'checksum': 'abc',
                'published_at': '2026-10-27T10:00:00+00:00',
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final documents = await client.fetchDocuments();

    expect(documents.single.isEntitled, isFalse);
    expect(documents.single.priceMwk, 2500);
    expect(documents.single.file?.version, 2);
  });

  test('maps a forbidden response to a readable error', () async {
    final client = _client((request) async {
      return http.Response(
        jsonEncode({'message': 'Your library pass does not cover this document.'}),
        403,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      client.fetchOffline(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.message, 'message', contains('does not cover')),
      ),
    );
  });

  test('parses a checkout session', () async {
    final client = _client((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'tx_ref': 'SUB-123',
            'checkout_url': 'https://checkout.paychangu.com/SUB-123',
            'amount_mwk': 1500,
            'kind': 'subscription',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final session = await client.checkoutPlan(1);

    expect(session.txRef, 'SUB-123');
    expect(session.checkoutUrl, contains('paychangu'));
  });

  test('treats an active subscription payment as complete', () async {
    final client = _client((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'tx_ref': 'SUB-123', 'status': 'active', 'kind': 'subscription'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final status = await client.paymentStatus('SUB-123');

    expect(status.isComplete, isTrue);
  });

  test('exchanges a Google ID token for a session and names', () async {
    late http.Request captured;
    final client = _client((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'token': 'google-token',
            'user': {
              'id': 12,
              'name': 'Chisomo Banda',
              'first_name': 'Chisomo',
              'last_name': 'Banda',
              'email': 'chisomo@example.com',
              'plan': 'free',
              'google_linked': true,
            },
          },
        }),
        200,
      );
    });

    final session = await client.googleAuth('google-id-token');

    expect(captured.url.path, endsWith('/auth/google'));
    expect(jsonDecode(captured.body)['id_token'], 'google-id-token');
    expect(session.token, 'google-token');
    expect(session.firstName, 'Chisomo');
    expect(session.lastName, 'Banda');
    expect(session.googleLinked, isTrue);
  });

  test('parses subscription and document receipts', () async {
    final client = _client((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'tx_ref': 'SUB-1',
              'kind': 'subscription',
              'title': 'Weekly pass',
              'amount_mwk': 1500,
              'status': 'active',
              'paid_at': '2026-10-20T10:00:00+00:00',
              'ends_at': '2026-10-27T10:00:00+00:00',
            },
            {
              'tx_ref': 'DOC-1',
              'kind': 'document',
              'title': 'Chemistry masterclass',
              'amount_mwk': 2500,
              'status': 'paid',
              'paid_at': '2026-10-21T10:00:00+00:00',
              'document_id': 'chem',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final receipts = await client.fetchPayments();

    expect(receipts, hasLength(2));
    expect(receipts.first.isSubscription, isTrue);
    expect(receipts.first.isSettled, isTrue);
    expect(receipts.last.documentId, 'chem');
  });

  test('reports a network failure without leaking internals', () async {
    final client = _client((request) async => throw Exception('socket closed'));

    await expectLater(
      client.fetchDocuments(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.isNetworkError, 'network', isTrue)
            .having((error) => error.message, 'message', contains('downloaded files still work')),
      ),
    );
  });
}
