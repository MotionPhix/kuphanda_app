/// API location. Override at build time:
///
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///
/// The default targets a local `php artisan serve` on desktop; Android
/// emulators need 10.0.2.2 instead of 127.0.0.1.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
