import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_models.dart';

/// Obtains a Google ID token for the API to verify.
///
/// The OAuth client is supplied at build time:
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com`.
/// Android also needs a matching OAuth client for the app package and signing
/// certificate in the Google Cloud console.
class GoogleSignInService {
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool _initialised = false;

  bool get isConfigured => _serverClientId.isNotEmpty;

  Future<String> idToken() async {
    if (_serverClientId.isEmpty) {
      throw const ApiException(
        'Google sign-in is not configured for this build. Add '
        'GOOGLE_SERVER_CLIENT_ID at build time.',
      );
    }

    try {
      final signIn = GoogleSignIn.instance;

      if (!_initialised) {
        await signIn.initialize(serverClientId: _serverClientId);
        _initialised = true;
      }

      if (!signIn.supportsAuthenticate()) {
        throw const ApiException(
          'Google sign-in is not available on this device. Use your email instead.',
        );
      }

      final account = await signIn.authenticate();
      final authentication = account.authentication;

      if (authentication.idToken == null) {
        throw const ApiException(
          'Google did not return an ID token. Check that the OAuth client is '
          'configured for this app.',
        );
      }

      return authentication.idToken!;
    } on ApiException {
      rethrow;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const ApiException('Google sign-in was cancelled.');
      }
      throw ApiException('Google sign-in failed: ${error.description ?? error.code.name}');
    } on MissingPluginException {
      throw const ApiException(
        'Google sign-in is not supported on this platform. Use your email instead.',
      );
    } on PlatformException catch (error) {
      throw ApiException(
        'Google sign-in failed: ${error.message ?? error.code}. Check the OAuth '
        'client configuration.',
      );
    }
  }
}
