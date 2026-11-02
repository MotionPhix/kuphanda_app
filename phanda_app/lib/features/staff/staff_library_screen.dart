import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';

/// Library-staff publishing surface. Only accounts granted with
/// `php artisan user:staff` see it, and the API enforces the same rule.
class StaffLibraryScreen extends StatefulWidget {
  const StaffLibraryScreen({super.key});

  @override
  State<StaffLibraryScreen> createState() => _StaffLibraryScreenState();
}

class _StaffLibraryScreenState extends State<StaffLibraryScreen> {
  List<StaffDocument> _documents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final documents = await state.loadStaffDocuments();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _upload(StaffDocument document) async {
    final state = AppScope.read(context);
    final picked = await state.pickPdf();
    if (picked == null) return;
    if (!mounted) return;

    final pages = await showDialog<int>(
      context: context,
      // The controller belongs to the dialog: it is still animating away when
      // showDialog returns, and the field is still using it then.
      builder: (dialogContext) => TextControllers(
        initialTexts: ['${document.currentVersion?.pageCount ?? document.pages}'],
        builder: (dialogContext, controllers) => AlertDialog(
        title: const Text('Publish a new version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(picked.fileName, style: Theme.of(dialogContext).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: controllers.first,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Page count'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controllers.first.text.trim());
              if (value != null && value > 0) Navigator.pop(dialogContext, value);
            },
            child: const Text('Publish'),
          ),
        ],
      ),
      ),
    );

    if (pages == null) return;

    setState(() => _loading = true);
    try {
      final version = await state.uploadStaffVersion(
        documentId: document.id,
        file: picked,
        pages: pages,
      );
      if (!mounted) return;
      showSnack(context, 'Published v${version.number}. Readers will see it on next sync.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, error.message, error: true);
    }
  }

  Future<void> _togglePublication(StaffDocument document) async {
    final state = AppScope.read(context);
    setState(() => _loading = true);
    try {
      await state.setStaffPublication(document.id, !document.isPublished);
      if (!mounted) return;
      showSnack(
        context,
        document.isPublished
            ? 'Withdrawn. Offline copies are revoked on next sync.'
            : 'Published to the catalogue.',
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff library')),
      body: !state.isStaff
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Staff access required',
              message: 'Ask an administrator to grant this account staff access.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Publish a new PDF or withdraw a document. Files are stored by '
                    'Media Library and versioned automatically.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      title: 'Could not load documents',
                      message: _error!,
                      actionLabel: 'Retry',
                      onAction: _load,
                      tone: BannerTone.warning,
                    ),
                  ],
                  for (final document in _documents) ...[
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    document.title,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                Pill(
                                  label: document.isPublished ? 'Published' : 'Withdrawn',
                                  color: document.isPublished
                                      ? AppColors.green
                                      : AppColors.red,
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${document.subject ?? 'Unfiled'} · Form ${document.form ?? '-'}'
                              ' · v${document.latestVersion} · ${document.versionCount} versions',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (document.currentVersion != null)
                              Text(
                                '${document.currentVersion!.pageCount} pages · '
                                '${formatBytes(document.currentVersion!.sizeBytes)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _loading ? null : () => _upload(document),
                                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text('New version'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _loading ? null : () => _togglePublication(document),
                                  child: Text(
                                    document.isPublished ? 'Withdraw' : 'Publish',
                                    style: TextStyle(
                                      color: document.isPublished
                                          ? AppColors.red
                                          : AppColors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!_loading && _documents.isEmpty && _error == null)
                    const EmptyState(
                      icon: Icons.library_books_outlined,
                      title: 'No documents yet',
                      message: 'Add catalogue records first, then publish a PDF here.',
                    ),
                ],
              ),
            ),
    );
  }
}

