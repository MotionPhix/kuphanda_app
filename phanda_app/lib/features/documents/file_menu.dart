import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';
import '../../data/models/document.dart';
import '../../state/app_state.dart';

/// Per-file actions for a document that is on this device.
///
/// These lived inside the Files screen, which made them unreachable from the
/// Library: a learner with fourteen downloads had to open each document to drop
/// one. The menu and the two confirmed actions are here so both screens offer
/// the same thing, and so removing Files cannot take the actions with it.
class FileMenu extends StatelessWidget {
  const FileMenu({
    super.key,
    required this.entry,
    required this.onRemove,
    this.onDelete,
  });

  final LibraryEntry entry;
  final VoidCallback onRemove;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final asset = entry.asset;
    if (!entry.onDevice) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Document options',
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      onSelected: (value) {
        if (value == 'remove') onRemove();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        if (!(asset?.isBundled ?? false))
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove file from device'),
          ),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete document')),
      ],
    );
  }
}

/// Drops the downloaded copy but keeps the record and the learner's progress.
Future<void> removeFileFromDevice(
  BuildContext context,
  AppState state,
  LibraryEntry entry,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Remove from this device?',
    message: '“${entry.document.title}” stays in your library and your progress is kept. '
        'Add the file again whenever you want it on this phone.',
    confirmLabel: 'Remove file',
  );

  if (!confirmed) return;

  await state.removeFile(entry.document.id);
  if (context.mounted) showSnack(context, 'File removed. Progress kept.');
}

/// Deletes a document the learner imported themselves, with its notes.
Future<void> deleteDocumentFromDevice(
  BuildContext context,
  AppState state,
  LibraryEntry entry,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Delete this document?',
    message: 'The file, its progress and your notes are deleted from this phone.',
    confirmLabel: 'Delete',
  );

  if (!confirmed) return;

  await state.deletePersonalDocument(entry.document.id);
  if (context.mounted) showSnack(context, 'Document deleted.');
}
