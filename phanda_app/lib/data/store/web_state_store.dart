// `dart:html` is deprecated in favour of package:web, but this file is compiled
// only for the browser and adding a package dependency for one localStorage call
// is not worth it yet. The lint is suppressed rather than left to rot in CI.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'snapshot.dart';
import 'state_store.dart';

/// State persistence for the web build.
///
/// On Android and Windows the snapshot lives in `state.json` under the
/// application support directory, which goes through `path_provider`. That
/// plugin has no web implementation, so constructing [FileStateStore] threw
/// `MissingPluginException` during startup and the browser painted nothing at
/// all — a blank page with no error, which is the worst way to fail.
///
/// The encoded snapshot is the same string, so localStorage holds it directly.
/// It is a few hundred kilobytes of JSON at worst, well inside the 5 MB budget.
class WebStateStore implements StateStore {
  static const _key = 'kuphanda.state';

  @override
  Future<AppSnapshot?> read() async {
    final raw = html.window.localStorage[_key];
    if (raw == null || raw.isEmpty) return null;

    try {
      return AppSnapshot.decode(raw);
    } catch (_) {
      // A snapshot written by an older build is not worth crashing over; the
      // app can start from its bundled catalogue instead.
      return null;
    }
  }

  @override
  Future<void> write(AppSnapshot snapshot) async {
    html.window.localStorage[_key] = snapshot.encode();
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_key);
  }
}
