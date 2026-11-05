import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'data/notifications/push_service.dart';
import 'data/store/block_cache.dart';
import 'data/store/document_files.dart';
import 'data/store/state_store.dart';
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

  final store = FileStateStore();
  final state = AppState(
    store: store,
    files: LocalDocumentFiles(store),
    // Keeps every structured paper that has been opened, so it reopens in a
    // blackout rather than at a spinner.
    blockCache: LocalBlockDocumentCache(store),
  );
  await state.initialize();

  runApp(KuphandaApp(state: state));
}
