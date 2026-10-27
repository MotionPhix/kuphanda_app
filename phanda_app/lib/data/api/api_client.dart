import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_models.dart';

/// Thin, typed client for the Kuphanda library API.
///
/// The catalogue and the learner's offline marks are server-owned; the client
/// never invents content. Every call carries the Sanctum bearer token and every
/// failure is translated into an [ApiException] the UI can explain.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    http.Client? httpClient,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 25);

  Map<String, String> get _headers => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<AuthSession> login({required String email, required String password}) async {
    final body = await _send(
      () => _http.post(
        _uri('/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    return _sessionFrom(_dataMap(body));
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final body = await _send(
      () => _http.post(
        _uri('/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      ),
    );
    return _sessionFrom(_dataMap(body));
  }

  Future<AuthSession> me() async {
    final body = await _send(() => _http.get(_uri('/me'), headers: _headers));
    return AuthSession.fromJson(_dataMap(body), token: token ?? '');
  }

  Future<void> logout() async {
    await _send(() => _http.post(_uri('/logout'), headers: _headers));
  }

  Future<List<RemoteDocument>> fetchDocuments({int perPage = 100}) async {
    final documents = <RemoteDocument>[];
    var page = 1;
    var lastPage = 1;

    do {
      final body = await _send(
        () => _http.get(
          _uri('/documents', {'per_page': '$perPage', 'page': '$page'}),
          headers: _headers,
        ),
      );

      final data = body['data'];
      final List<Object?> rows;
      if (data is List) {
        rows = data;
      } else if (data is Map<String, Object?>) {
        rows = data['data'] as List<Object?>? ?? const <Object?>[];
        lastPage = (data['last_page'] as num?)?.toInt() ??
            ((data['meta'] as Map<String, Object?>?)?['last_page'] as num?)?.toInt() ??
            1;
      } else {
        rows = const <Object?>[];
      }

      documents.addAll(
        rows.whereType<Map<String, Object?>>().map(RemoteDocument.fromJson),
      );
      page++;
    } while (page <= lastPage);

    return documents;
  }

  Future<List<RemoteOfflineItem>> fetchOffline() async {
    final body = await _send(() => _http.get(_uri('/library/offline'), headers: _headers));
    final rows = body['data'];
    final list = rows is List ? rows : (rows is Map<String, Object?> ? rows['data'] : null);
    return (list as List<Object?>? ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(RemoteOfflineItem.fromJson)
        .toList();
  }

  Future<RemoteOfflineItem> markOffline(String documentId) async {
    final body = await _send(
      () => _http.post(
        _uri('/library/offline'),
        headers: _headers,
        body: jsonEncode({'document_id': documentId}),
      ),
    );
    return RemoteOfflineItem.fromJson(_dataMap(body));
  }

  Future<void> removeOffline(String documentId) async {
    await _send(
      () => _http.delete(_uri('/library/offline/$documentId'), headers: _headers),
    );
  }

  Future<RemoteOfflineItem> acknowledge(String documentId, int version) async {
    final body = await _send(
      () => _http.post(
        _uri('/library/offline/$documentId/ack'),
        headers: _headers,
        body: jsonEncode({'version': version}),
      ),
    );
    return RemoteOfflineItem.fromJson(_dataMap(body));
  }

  Future<RemoteSyncResult> sync({DateTime? since}) async {
    final body = await _send(
      () => _http.get(
        _uri('/library/sync',
            since == null ? null : {'since': since.toUtc().toIso8601String()}),
        headers: _headers,
      ),
    );
    return RemoteSyncResult.fromJson(_dataMap(body));
  }

  /// Streams a file, reporting bytes received so the UI can show real progress.
  Future<Uint8List> download(String url, {void Function(double progress)? onProgress}) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(<String, String>{
        'Accept': 'application/pdf',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      final response = await _http.send(request).timeout(const Duration(minutes: 2));
      if (response.statusCode >= 400) {
        final raw = await response.stream.bytesToString();
        throw _errorFor(response.statusCode, raw);
      }

      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;

      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0, 1));
      }

      onProgress?.call(1);
      return builder.takeBytes();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The download timed out. Check your connection and try again.',
        isNetworkError: true,
      );
    } catch (error) {
      throw ApiException(
        'Could not download the file: $error',
        isNetworkError: true,
      );
    }
  }

  Future<List<RemotePlan>> fetchPlans() async {
    final body = await _send(() => _http.get(_uri('/plans'), headers: _headers));
    final rows = body['data'];
    return (rows is List ? rows : const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(RemotePlan.fromJson)
        .toList();
  }

  Future<BillingStatus> fetchBillingStatus() async {
    final body = await _send(() => _http.get(_uri('/billing/status'), headers: _headers));
    return BillingStatus.fromJson(_dataMap(body));
  }

  Future<CheckoutSession> checkoutPlan(int planId) async {
    final body = await _send(
      () => _http.post(
        _uri('/billing/checkout'),
        headers: _headers,
        body: jsonEncode({'plan_id': planId}),
      ),
    );
    return CheckoutSession.fromJson(_dataMap(body));
  }

  Future<CheckoutSession> checkoutDocument(String documentId) async {
    final body = await _send(
      () => _http.post(
        _uri('/billing/checkout'),
        headers: _headers,
        body: jsonEncode({'document_id': documentId}),
      ),
    );
    return CheckoutSession.fromJson(_dataMap(body));
  }

  Future<PaymentStatus> paymentStatus(String txRef) async {
    final body = await _send(
      () => _http.get(_uri('/billing/payments/$txRef'), headers: _headers),
    );
    return PaymentStatus.fromJson(_dataMap(body));
  }

  Future<Map<String, Object?>> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond.',
        isNetworkError: true,
      );
    } catch (error) {
      throw ApiException(
        'No connection to the library. Your downloaded files still work.',
        isNetworkError: true,
      );
    }

    Map<String, Object?> body = <String, Object?>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, Object?>) body = decoded;
      } catch (_) {
        // Non-JSON responses are handled by the status check below.
      }
    }

    if (response.statusCode >= 400) {
      throw _errorFor(response.statusCode, response.body, body);
    }

    return body;
  }

  Map<String, Object?> _dataMap(Map<String, Object?> body) {
    final data = body['data'];
    return data is Map<String, Object?> ? data : body;
  }

  ApiException _errorFor(int status, String rawBody, [Map<String, Object?>? body]) {
    Map<String, Object?> parsed = body ?? <String, Object?>{};
    if (parsed.isEmpty && rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, Object?>) parsed = decoded;
      } catch (_) {}
    }

    final message = (parsed['message'] as String?) ?? switch (status) {
      401 => 'Your session has expired. Sign in again.',
      403 => 'Your library pass does not cover this document.',
      404 => 'The document is no longer available.',
      409 => 'This document is not available offline yet.',
      422 => 'The request could not be completed.',
      429 => 'Too many requests. Wait a moment and try again.',
      _ => 'The library could not be reached (HTTP $status).',
    };

    return ApiException(message, statusCode: status);
  }

  AuthSession _sessionFrom(Map<String, Object?> data) {
    final user = data['user'] as Map<String, Object?>? ?? const <String, Object?>{};
    return AuthSession.fromJson(
      user,
      token: (data['token'] as String?) ?? '',
    );
  }
}
