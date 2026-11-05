import 'package:package_info_plus/package_info_plus.dart';

/// The version this phone is actually running.
///
/// It used to be typed into two places by hand — the About panel and the push
/// device registration — so both kept saying 1.0.0 after the build had moved
/// on, and the server's device table could not tell one build from another.
/// The package metadata is the only source that cannot drift.
abstract final class AppInfo {
  static String _version = '1.0.0';

  /// `1.0.1` — the versionName from pubspec, without the build number.
  static String get version => _version;

  /// Read once at start-up, before the first frame. Failures are swallowed:
  /// a missing platform channel (tests, an unsupported host) must not stop the
  /// app from opening.
  static Future<void> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String version = info.version.trim();
      if (version.isNotEmpty) {
        _version = version;
      }
    } catch (_) {
      // Keep the compiled fallback.
    }
  }
}
