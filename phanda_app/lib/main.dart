import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store/document_files.dart';
import 'data/store/state_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = FileStateStore();
  final state = AppState(
    store: store,
    files: LocalDocumentFiles(store),
  );
  await state.initialize();

  runApp(KuphandaApp(state: state));
}
