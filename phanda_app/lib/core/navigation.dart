import 'package:flutter/material.dart';

import '../features/classes/class_detail_screen.dart';
import '../features/document/document_detail_screen.dart';
import '../features/exam/exam_hub_screen.dart';
import '../features/profile/profile_screen.dart';

Future<void> openDocument(BuildContext context, String documentId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentDetailScreen(documentId: documentId),
    ),
  );
}

Future<void> openProfile(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
  );
}

Future<void> openExamHub(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ExamHubScreen()),
  );
}

Future<void> openClass(BuildContext context, String classId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ClassDetailScreen(classId: classId)),
  );
}
