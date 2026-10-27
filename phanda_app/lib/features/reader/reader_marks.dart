import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';

/// Bookmarks and notes for the current page, in one sheet. Both readers use the
/// same surface so the interaction is identical whether the page is a PDF or a
/// structured study guide.
Future<void> showReaderMarks(
  BuildContext context, {
  required AppState state,
  required String documentId,
  required int page,
  String? pageLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final title = state.documentById(documentId)?.title ?? 'Document';

      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final bookmarks = state.bookmarksFor(documentId);
          final notes = state.notesFor(documentId);
          final isBookmarked = bookmarks.any((bookmark) => bookmark.page == page);

          return SheetBody(
            title: 'Bookmarks & notes',
            subtitle: '$title · page $page${pageLabel == null ? '' : ' · $pageLabel'}',
            actions: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (isBookmarked) {
                      final existing = bookmarks.firstWhere((bookmark) => bookmark.page == page);
                      await state.removeBookmark(existing.id);
                    } else {
                      await state.addBookmark(documentId, page, label: pageLabel);
                    }
                    setSheetState(() {});
                  },
                  icon: Icon(
                    isBookmarked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                    size: 18,
                  ),
                  label: Text(isBookmarked ? 'Remove page bookmark' : 'Bookmark this page'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final text = await _noteDialog(sheetContext, page);
                    if (text != null && text.trim().isNotEmpty) {
                      await state.addNote(documentId, page, text);
                      setSheetState(() {});
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Add note'),
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bookmarks.isEmpty && notes.isEmpty)
                  const EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Nothing marked yet',
                    message: 'Bookmarks mark a page. Notes hold a correction or a question '
                        'you want to bring to class.',
                    compact: true,
                  ),
                if (bookmarks.isNotEmpty) ...[
                  Text('Bookmarks', style: Theme.of(sheetContext).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  for (final bookmark in bookmarks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.bookmark_rounded, size: 18),
                      title: Text(bookmark.label ?? 'Page ${bookmark.page}'),
                      subtitle: Text(
                        'Page ${bookmark.page} · ${formatRelative(bookmark.createdAt)}',
                        style: Theme.of(sheetContext).textTheme.labelSmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17),
                        tooltip: 'Remove',
                        onPressed: () async {
                          await state.removeBookmark(bookmark.id);
                          setSheetState(() {});
                        },
                      ),
                    ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Notes', style: Theme.of(sheetContext).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  for (final note in notes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Pill(label: 'Page ${note.page}', compact: true),
                              const Spacer(),
                              Text(
                                formatRelative(note.createdAt),
                                style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await state.removeNote(note.id);
                                  setSheetState(() {});
                                },
                                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                                tooltip: 'Delete note',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          Text(note.text, style: Theme.of(sheetContext).textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

Future<String?> _noteDialog(BuildContext context, int page) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Note on page $page'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(hintText: 'Write your note…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
