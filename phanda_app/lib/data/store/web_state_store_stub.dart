import 'snapshot.dart';
import 'state_store.dart';

/// The declaration the compiler sees on every platform that is not the browser.
///
/// `web_state_store.dart` imports `dart:html`, which does not exist on Android,
/// Windows or in a test VM — importing it unconditionally broke the Windows
/// build at link time. `main.dart` imports this file and swaps in the real one
/// only when `dart.library.html` is available, so the web class exists by name
/// everywhere and by implementation only where it can work.
///
/// Constructing it off the web is a programming error, and says so: `main()`
/// chooses it only under `kIsWeb`.
class WebStateStore implements StateStore {
  WebStateStore() {
    throw UnsupportedError(
      'WebStateStore is only available in the browser; '
      'use FileStateStore on this platform.',
    );
  }

  @override
  Future<AppSnapshot?> read() async => null;

  @override
  Future<void> write(AppSnapshot snapshot) async {}

  @override
  Future<void> clear() async {}
}
