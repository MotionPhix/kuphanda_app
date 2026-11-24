import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_card.dart';
import '../../state/app_state.dart';
import 'file_menu.dart';
import 'import_document.dart';
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
                eyebrow: 'Your files',
                title: 'My documents',
                subtitle: 'Library downloads and personal PDFs on this phone.',
                actions: [
                  FilledButton.icon(
                    onPressed: () => importDocumentFlow(context, state),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add a paper'),
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
                      : 'Add a paper or notes you already have on this phone — give it a name '
                          'and it joins your library. The two starter guides are included.',
                  actionLabel: 'Import a PDF',
                  onAction: () => importDocumentFlow(context, state),
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
                    trailing: FileMenu(
                      entry: entry,
                      onRemove: () => removeFileFromDevice(context, state, entry),
                      onDelete: entry.document.personal
                          ? () => deleteDocumentFromDevice(context, state, entry)
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
                  'Bundled guides do not use storage. Downloads stay until you remove them.',
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
