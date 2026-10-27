import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_card.dart';
import '../../data/models/document.dart';
import '../../data/models/subject.dart';
import '../../data/store/document_files.dart';
import '../../state/app_state.dart';
import 'sync_card.dart';

enum _DocumentsFilter {
  offline('On this device'),
  saved('Saved'),
  all('Everything');

  const _DocumentsFilter(this.label);

  final String label;
}

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  _DocumentsFilter _filter = _DocumentsFilter.offline;
  final _searchController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final gutter = pageGutter(context);

    final source = switch (_filter) {
      _DocumentsFilter.offline => state.offlineDocuments,
      _DocumentsFilter.saved => state.savedDocuments,
      _DocumentsFilter.all => state.entries,
    };

    final query = _searchController.text.trim().toLowerCase();
    final entries = source.where((entry) {
      if (query.isEmpty) return true;
      return '${entry.document.title} ${entry.subject.name} ${entry.document.kind.label}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                eyebrow: 'Offline first',
                title: 'My documents',
                subtitle: 'Files stored on this phone, and the records you saved.',
                actions: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _importDocument(context, state),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Import'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SyncCard(state: state, onSignIn: () => openSubscription(context)),
              const SizedBox(height: 14),
              _StorageCard(state: state),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search your documents',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in _DocumentsFilter.values)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (entries.isEmpty)
                EmptyState(
                  icon: _filter == _DocumentsFilter.saved
                      ? Icons.bookmark_border_rounded
                      : Icons.folder_open_outlined,
                  title: _filter == _DocumentsFilter.saved
                      ? 'Nothing saved yet'
                      : 'No files on this device',
                  message: _filter == _DocumentsFilter.saved
                      ? 'Tap the bookmark on any document to keep it here.'
                      : 'Import a PDF from your phone, or open a catalogue record and attach '
                          'the official paper. The two starter guides are already included.',
                  actionLabel: 'Import a PDF',
                  onAction: () => _importDocument(context, state),
                )
              else ...[
                Text(
                  plural(entries.length, 'document'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in entries) ...[
                  DocumentTile(
                    entry: entry,
                    onTap: () => openDocument(context, entry.document.id),
                    trailing: _FileMenu(
                      entry: entry,
                      onRemove: () => _removeFile(context, state, entry),
                      onDelete: entry.document.personal
                          ? () => _deleteDocument(context, state, entry)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _importDocument(BuildContext context, AppState state) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await state.pickPdf();
      if (picked == null || !context.mounted) return;

      final controller = TextEditingController(text: _titleFromFile(picked.fileName));
      var subjectId = state.profile.subjectIds.isEmpty
          ? kSubjects.first.id
          : state.profile.subjectIds.first;
      var form = state.profile.form;
      var kind = DocumentKind.notes;

      final shouldImport = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => SheetBody(
            title: 'Import a document',
            subtitle: '${picked.fileName} · ${formatBytes(picked.sizeBytes)}',
            actions: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Add to library'),
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Subject', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in kSubjects)
                      ChoiceChip(
                        label: Text(subject.shortName),
                        selected: subjectId == subject.id,
                        onSelected: (_) => setSheetState(() {
                          subjectId = subject.id;
                          if (!subject.forms.contains(form) && subject.forms.isNotEmpty) {
                            form = subject.forms.first;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Form', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in <int>[1, 2, 3, 4])
                      ChoiceChip(
                        label: Text('Form $option'),
                        selected: form == option,
                        onSelected: (_) => setSheetState(() => form = option),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in DocumentKind.values)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: kind == option,
                        onSelected: (_) => setSheetState(() => kind = option),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The file is copied into Kuphanda’s private folder. Removing it here does '
                  'not touch the original.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      );

      if (shouldImport == true) {
        final document = await state.importPdf(
          picked: picked,
          title: controller.text,
          subjectId: subjectId,
          form: form,
          kind: kind,
        );
        if (context.mounted) {
          showSnack(context, '“${document.title}” is on this device.');
        }
      }
      controller.dispose();
    } on FormatException catch (error) {
      if (context.mounted) showSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showSnack(context, 'Could not import the file: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFile(BuildContext context, AppState state, LibraryEntry entry) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove from this device?',
      message: '“${entry.document.title}” stays in the catalogue and your progress is kept. '
          'Attach the PDF again to keep reading.',
      confirmLabel: 'Remove file',
    );
    if (confirmed) {
      await state.removeFile(entry.document.id);
      if (context.mounted) showSnack(context, 'File removed. Progress kept.');
    }
  }

  Future<void> _deleteDocument(BuildContext context, AppState state, LibraryEntry entry) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this document?',
      message: 'The file, its progress and your notes are deleted from this phone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await state.deletePersonalDocument(entry.document.id);
      if (context.mounted) showSnack(context, 'Document deleted.');
    }
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = state.storageBytes;

    return AppCard(
      color: theme.colorScheme.primary.withValues(alpha: 0.05),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sd_storage_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.importedFileCount} imported ${state.importedFileCount == 1 ? 'file' : 'files'} · ${formatBytes(used)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Starter guides are built in and do not use storage. Everything works offline.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Pill(
            label: 'Offline',
            icon: Icons.wifi_off_rounded,
            color: AppColors.green,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _FileMenu extends StatelessWidget {
  const _FileMenu({required this.entry, required this.onRemove, this.onDelete});

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
          const PopupMenuItem(value: 'remove', child: Text('Remove file from device')),
        if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete document')),
      ],
    );
  }
}

String _titleFromFile(String fileName) {
  final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  final cleaned = base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (cleaned.isEmpty) return 'Imported document';
  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// Kept for the import sheet's preview when a picker returns a bare name.
String fileNameFromPick(PickedPdf picked) => picked.fileName;
