/// API location. Override at build time:
///
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///
/// A developer build defaults to a local `php artisan serve` (127.0.0.1 on
/// desktop, 10.0.2.2 from an Android emulator). A release build defaults to the
/// live API instead.
///
/// That split matters: a release APK built without the define used to ship
/// pointing at 127.0.0.1, so every request on a real phone went to the phone
/// itself and sign-in, registration and the catalogue all failed while the
/// server was perfectly healthy. Release artifacts must never silently inherit
/// a developer default.
abstract final class ApiConfig {
  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _isRelease
        ? 'https://app.kuphanda.com/api/v1'
        : 'http://127.0.0.1:8000/api/v1',
  );
}
