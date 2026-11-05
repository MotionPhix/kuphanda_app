import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'data/notifications/push_service.dart';
import 'data/store/block_cache.dart';
import 'data/store/document_files.dart';
import 'data/store/state_store.dart';
import 'data/store/web_document_files.dart';
import 'data/store/web_state_store.dart';
import 'state/app_state.dart';

/// Runs in a background isolate when a data message arrives while the app is
/// terminated. Notification messages are displayed by the system already, so
/// there is nothing to draw here.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The About panel and the push device registration both report this, so read
  // it before anything can ask.
  await AppInfo.load();

  if (PushService.isSupported) {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  // The browser has no application support directory, so the native file store
  // throws MissingPluginException during startup and the page stays blank. Each
  // platform gets the store it can actually use.
  final StateStore store = kIsWeb ? WebStateStore() : FileStateStore();
  final state = AppState(
    store: store,
    files: kIsWeb
        ? WebDocumentFiles()
        : LocalDocumentFiles(store as FileStateStore),
    // Keeps every structured paper that has been opened, so it reopens in a
    // blackout rather than at a spinner. Web has no local file layer yet.
    blockCache: kIsWeb
        ? null
        : LocalBlockDocumentCache(store as FileStateStore),
  );
  await state.initialize();

  runApp(KuphandaApp(state: state));
}
