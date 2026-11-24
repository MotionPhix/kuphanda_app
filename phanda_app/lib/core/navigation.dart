import 'package:flutter/material.dart';

import '../features/billing/subscription_screen.dart';
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

Future<void> openSubscription(BuildContext context, {String? documentId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SubscriptionScreen(documentId: documentId),
    ),
  );
}

Future<void> openClass(BuildContext context, String classId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ClassDetailScreen(classId: classId)),
  );
}

/// The shell's destinations by name.
///
/// Screens used to ask for one by index, which meant deleting a tab silently
/// pointed "Add your own paper" at a different screen. The teacher list is also
/// a different order from the learner's, so the same number already meant two
/// different things.
enum AppTab { home, library, classes, progress }
