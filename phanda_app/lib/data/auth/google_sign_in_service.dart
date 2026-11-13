import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_models.dart';

/// Obtains a Google ID token for the API to verify.
///
/// The OAuth client can be overridden at build time:
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com`.
///
/// It also has a real default, because a release build that omitted the flag
/// used to compile fine and then disable the button at runtime with a toast -
/// three shipped builds had no working Google sign-in and nothing failed until
/// a learner tapped it. This client ID is public (it travels in the APK either
/// way), so shipping it as the default is safer than depending on a build
/// command being remembered.
///
/// Android also needs a matching OAuth client for the app package and signing
/// certificate in the Google Cloud console.
class GoogleSignInService {
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '239327365893-1725f6in8f6nnmc85836eqhrets9hfes.apps.googleusercontent.com',
  );

  static bool _initialised = false;

  bool get isConfigured => _serverClientId.isNotEmpty;

  /// Whether this build can hand the sign-in to a platform that actually has
  /// the plugin.
  ///
  /// `google_sign_in` ships implementations for Android, iOS, macOS and the
  /// browser — not Windows. On Windows `GoogleSignIn.instance` throws an
  /// [UnimplementedError] before any of the handled exceptions, so the button
  /// did nothing at all with no message. The button is now only drawn where it
  /// can work.
  static bool get isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

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
    } catch (error) {
      // UnimplementedError on a platform without the plugin used to escape this
      // method, which surfaced as a button that did nothing. Anything left over
      // becomes a sentence the screen can show.
      throw ApiException('Google sign-in failed: $error');
    }
  }
}

