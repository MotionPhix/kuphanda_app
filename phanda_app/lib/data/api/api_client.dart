import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/block_document.dart';
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
        // ngrok's free tier serves an HTML interstitial before the first
        // request from an unknown client. Without this header the app would
        // try to parse that page as JSON. It is ignored by every other host.
        'ngrok-skip-browser-warning': 'true',
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

  /// Changes the password for the signed-in account. The server signs every
  /// other device out and keeps this one.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    await _send(
      () => _http.put(
        _uri('/password'),
        headers: _headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': password,
        }),
      ),
    );
  }

  /// Asks the server to mail a reset link. The link itself is opened on the web
  /// app; the phone only needs to know the request went through.
  Future<void> forgotPassword({required String email}) async {
    await _send(
      () => _http.post(
        _uri('/forgot-password'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ),
    );
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

      // One malformed row must not take out the whole catalogue: before this,
      // a single bad document threw, the caller kept its cached list and the
      // library silently went stale with no indication why.
      for (final row in rows.whereType<Map<String, Object?>>()) {
        try {
          documents.add(RemoteDocument.fromJson(row));
        } catch (error) {
          debugPrint('Skipped document ${row['id']}: $error');
        }
      }
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

  /// Classes this account teaches or belongs to.
  Future<List<RemoteClassroom>> fetchClassrooms() async {
    final body = await _send(() => _http.get(_uri('/classrooms'), headers: _headers));
    final rows = body['data'];
    final list = rows is List ? rows : (rows is Map<String, Object?> ? rows['data'] : null);

    return (list as List<Object?>? ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(RemoteClassroom.fromJson)
        .toList();
  }

  Future<RemoteClassroom> joinClass(String code) async {
    final body = await _send(
      () => _http.post(
        _uri('/classrooms/join'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      ),
    );

    return RemoteClassroom.fromJson(_dataMap(body));
  }


  Future<RemoteClassroom> createClass({
    required String name,
    required int form,
    String? subjectId,
  }) async {
    final body = await _send(
      () => _http.post(
        _uri('/classrooms'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'form': form,
          'subject_id': ?subjectId,
        }),
      ),
    );

    return RemoteClassroom.fromJson(_dataMap(body));
  }

  Future<RemoteClassroom> assignPaper({
    required String classroomId,
    required String documentId,
    DateTime? dueDate,
  }) async {
    final body = await _send(
      () => _http.post(
        _uri('/classrooms/$classroomId/assignments'),
        headers: _headers,
        body: jsonEncode({
          'document_id': documentId,
          if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first,
        }),
      ),
    );

    return RemoteClassroom.fromJson(_dataMap(body));
  }

  Future<void> leaveClass(String classroomId) async {
    await _send(
      () => _http.delete(_uri('/classrooms/$classroomId/leave'), headers: _headers),
    );
  }

  /// Nudges the learners who have not read a paper yet; returns how many.
  Future<int> remindUnfinished({
    required String classroomId,
    required String assignmentId,
  }) async {
    final body = await _send(
      () => _http.post(
        _uri('/classrooms/$classroomId/assignments/$assignmentId/remind'),
        headers: _headers,
      ),
    );
    return (_dataMap(body)['sent'] as num?)?.toInt() ?? 0;
  }
  /// Takes a paper off the class, for everyone — not just this phone.
  Future<void> unassignPaper({
    required String classroomId,
    required String assignmentId,
  }) async {
    await _send(
      () => _http.delete(
        _uri('/classrooms/$classroomId/assignments/$assignmentId'),
        headers: _headers,
      ),
    );
  }
  /// Tells the class that this learner has finished the paper it was set.
  ///
  /// Idempotent on the server, so a device that retries after a dropped
  /// connection still records one completion.
  Future<void> completeAssignment(String assignmentId) async {
    await _send(
      () => _http.post(
        _uri('/assignments/$assignmentId/complete'),
        headers: _headers,
      ),
    );
  }

  /// The teacher's view of a class: what was set, and who has read it.
  Future<ClassReport> fetchClassReport(String classroomId) async {
    final body = await _send(
      () => _http.get(_uri('/classrooms/$classroomId/report'), headers: _headers),
    );
    return ClassReport.fromJson(_dataMap(body));
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

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? school,
    String? role,
    int? form,
  }) async {
    await _send(
      () => _http.patch(
        _uri('/me'),
        headers: _headers,
        body: jsonEncode(<String, Object?>{
          'first_name': firstName,
          'last_name': lastName,
          'school': school,
          'role': role,
          'form': form,
        }),
      ),
    );
  }

  /// Registers this device for push notifications. Idempotent: the same token
  /// is reassigned to whoever is signed in.
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
  }) async {
    await _send(
      () => _http.post(
        _uri('/me/devices'),
        headers: _headers,
        body: jsonEncode(<String, Object?>{
          'token': token,
          'platform': platform,
          'app_version': appVersion,
        }),
      ),
    );
  }

  Future<void> removeDevice(String token) async {
    await _send(
      () => _http.delete(
        _uri('/me/devices'),
        headers: _headers,
        body: jsonEncode(<String, Object?>{'token': token}),
      ),
    );
  }

  Future<AuthSession> googleAuth(String idToken) async {
    final body = await _send(
      () => _http.post(
        _uri('/auth/google'),
        headers: _headers,
        body: jsonEncode(<String, String>{'id_token': idToken}),
      ),
    );
    return _sessionFrom(_dataMap(body));
  }

  /// Asks for a WhatsApp code.
  ///
  /// [purpose] is `login`, `signup`, or `link`. The server decides what each
  /// one means; sending the intent rather than a hidden flag keeps an
  /// authenticated "add my number" call honest.
  Future<OtpStart> startOtp({
    required String phone,
    required String purpose,
  }) async {
    final body = await _send(
      () => _http.post(
        _uri('/auth/otp/start'),
        headers: _headers,
        body: jsonEncode(<String, String>{'phone': phone, 'purpose': purpose}),
      ),
    );
    return OtpStart.fromJson(_dataMap(body));
  }

  /// Hands the code back. Returns a session for login and sign-up; for a link
  /// the server answers with the user, and the token already on this client
  /// stays the one in use.
  Future<AuthSession> verifyOtp({
    required String challenge,
    required String code,
    String? name,
  }) async {
    final body = await _send(
      () => _http.post(
        _uri('/auth/otp/verify'),
        headers: _headers,
        body: jsonEncode(<String, Object?>{
          'challenge': challenge,
          'code': code,
          if (name != null && name.isNotEmpty) 'name': name,
        }),
      ),
    );

    final data = _dataMap(body);
    if (data['token'] is String) return _sessionFrom(data);

    // A link reply carries only the user. Keep the existing token so the
    // session object stays whole for the caller.
    return AuthSession.fromJson(
      (data['user'] as Map<String, Object?>?) ?? data,
      token: token ?? '',
    );
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

  Future<List<PaymentRecord>> fetchPayments() async {
    final body = await _send(
      () => _http.get(_uri('/billing/payments'), headers: _headers),
    );
    final rows = body['data'];
    return (rows is List ? rows : const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(PaymentRecord.fromJson)
        .toList();
  }

  /// The reflowable version of a document. The API enforces the same
  /// entitlement as the file, so a locked paper throws rather than returning
  /// empty blocks.
  Future<BlockDocument> fetchBlockDocument(String documentId) async {
    final body = await _send(
      () => _http.get(
        _uri('/documents/$documentId/blocks'),
        headers: _headers,
      ),
    );

    final data = body['data'];

    if (data is! Map<Object?, Object?>) {
      throw const ApiException('This document has no structured version.');
    }

    return BlockDocument.fromMap(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  /// Messages addressed to this learner's audiences, newest first.
  Future<List<AppNotification>> fetchNotifications() async {
    final body = await _send(
      () => _http.get(_uri('/me/notifications'), headers: _headers),
    );
    final rows = body['data'];
    if (rows is! List) return const <AppNotification>[];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((row) => AppNotification.fromJson(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Future<PaymentStatus> paymentStatus(String txRef) async {
    final body = await _send(
      () => _http.get(_uri('/billing/payments/$txRef'), headers: _headers),
    );
    return PaymentStatus.fromJson(_dataMap(body));
  }

  Future<List<StaffDocument>> fetchStaffDocuments() async {
    final body = await _send(
      () => _http.get(_uri('/staff/documents'), headers: _headers),
    );
    final rows = body['data'];
    return (rows is List ? rows : const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(StaffDocument.fromJson)
        .toList();
  }

  Future<StaffVersion> uploadStaffVersion({
    required String documentId,
    required String filePath,
    required String fileName,
    required int pages,
    String? notes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/staff/documents/$documentId/versions'),
    )
      ..headers.addAll(_headers)
      ..fields['pages'] = '$pages';

    if (notes != null && notes.trim().isNotEmpty) {
      request.fields['notes'] = notes.trim();
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamed = await _http.send(request).timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFor(response.statusCode, response.body);
    }

    final body = jsonDecode(response.body) as Map<String, Object?>;
    return StaffVersion.fromJson(_dataMap(body));
  }

  Future<StaffDocument> setStaffPublication(String documentId, bool published) async {
    final body = await _send(
      () => _http.patch(
        _uri('/staff/documents/$documentId/publication'),
        headers: _headers,
        body: jsonEncode(<String, bool>{'is_published': published}),
      ),
    );
    return StaffDocument.fromJson(_dataMap(body));
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

    // Laravel puts the useful sentence in `errors`, and leaves `message` as
    // "The given data was invalid." — which tells a learner nothing about the
    // field they got wrong.
    final errors = parsed['errors'];
    String? fieldError;
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          fieldError = value.first as String;
          break;
        }
      }
    }

    // A failure on the server's own side is not the learner's to read. Laravel
    // answers "Server Error" with debug off, which tells them nothing and reads
    // like a bug in the app; say what happened and what to do about it instead.
    // The exception is 502/503/504: those are the codes a deployment uses to say
    // something deliberate, such as "Google sign-in is not configured", and
    // replacing that with "the library had a problem" hides the one sentence that
    // tells an operator what to fix. A 500 stays generic: its body is a stack
    // trace waiting to become a support ticket.
    final serviceSentence = status == 502 || status == 503 || status == 504;
    final serverMessage =
        status >= 500 && !serviceSentence ? null : _meaningfulMessage(parsed['message']);

    final message = fieldError ?? serverMessage ?? switch (status) {
      401 => 'Your session has expired. Sign in again.',
      403 => 'Your library pass does not cover this document.',
      404 => 'The document is no longer available.',
      409 => 'This document is not available offline yet.',
      422 => 'The request could not be completed.',
      429 => 'Too many requests. Wait a moment and try again.',
      500 || 502 || 503 || 504 =>
        'The library had a problem on its side. Try again in a moment.',
      _ => 'The library could not be reached (HTTP $status).',
    };

    return ApiException(message, statusCode: status);
  }

  /// The server's own sentence, unless it is a framework placeholder that would
  /// leave the learner no wiser than the status code did.
  String? _meaningfulMessage(Object? message) {
    if (message is! String) return null;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;

    const bland = {
      'server error',
      'internal server error',
      'whoops, looks like something went wrong.',
      'the given data was invalid.',
      'unauthenticated.',
      'service unavailable',
      'bad gateway',
      'gateway timeout',
    };

    return bland.contains(trimmed.toLowerCase()) ? null : trimmed;
  }

  AuthSession _sessionFrom(Map<String, Object?> data) {
    final user = data['user'] as Map<String, Object?>? ?? const <String, Object?>{};
    return AuthSession.fromJson(
      user,
      token: (data['token'] as String?) ?? '',
    );
  }
}



