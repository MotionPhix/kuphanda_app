import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_card.dart';
import '../../data/api/api_models.dart';
import '../../data/models/document.dart';
import '../../data/models/reading.dart';
import '../../data/models/study_guide.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';
import '../reader/block_reader_screen.dart';
import '../reader/guide_reader_screen.dart';
import '../reader/pdf_reader_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  int _tab = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final document = state.documentById(widget.documentId);

    if (document == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This document is no longer in your library.')),
      );
    }

    final entry = state.entryFor(document.id)!;
    final subject = entry.subject;
    final theme = Theme.of(context);
    final guide = state.guideFor(document);
    final progress = state.progressOrDefault(document);
    final locked = state.isLocked(document);

    return Scaffold(
      appBar: AppBar(
        title: Text(document.kind.label),
        actions: [
          IconButton(
            tooltip: entry.saved ? 'Remove from saved' : 'Save',
            onPressed: () => state.toggleSaved(document.id),
            icon: Icon(
              entry.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, state, document, value),
            itemBuilder: (context) => [
              if (document.personal) const PopupMenuItem(value: 'edit', child: Text('Edit details')),
              if (entry.onDevice && !(entry.asset?.isBundled ?? false))
                const PopupMenuItem(value: 'remove-file', child: Text('Remove file from device')),
              if (document.personal)
                const PopupMenuItem(value: 'delete', child: Text('Delete document')),
              const PopupMenuItem(value: 'pass', child: Text('About the library pass')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 620;
                    final coverWidth = wide ? 120.0 : 92.0;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DocumentCover(
                          document: document,
                          subject: subject,
                          width: coverWidth,
                          height: coverWidth * 1.33,
                          borderRadius: 12,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                document.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: wide ? 25 : 20,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Pill(
                                    label: subject.name,
                                    icon: Icons.menu_book_outlined,
                                    color: subject.color,
                                  ),
                                  Pill(
                                    label: 'Form ${document.form} · ${document.qualification}',
                                    compact: true,
                                  ),
                                  if (state.priceFor(document.id) > 0 && locked)
                                    Pill(
                                      label: formatMwk(state.priceFor(document.id)),
                                      icon: Icons.sell_outlined,
                                      color: AppColors.red,
                                      compact: true,
                                    ),
                                  if (document.year != null)
                                    Pill(label: '${document.year}', compact: true),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (document.ratingCount > 0 || entry.rating != null)
                                Row(
                                  children: [
                                    for (var index = 1; index <= 5; index++)
                                      Icon(
                                        index <= state.averageRating(document).round()
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 16,
                                        color: AppColors.sun,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${state.averageRating(document).toStringAsFixed(1)} '
                                      '(${document.ratingCount + (entry.rating == null ? 0 : 1)})',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              Text(
                                '${document.pages} pages · ${document.author}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (locked) ...[
                  InfoBanner(
                    tone: BannerTone.locked,
                    icon: Icons.lock_outline_rounded,
                    title: 'Premium document · ${document.accessTier.label}',
                    message: state.priceFor(document.id) > 0
                        ? 'Subscribe for full access, or buy this document alone for '
                            '${formatMwk(state.priceFor(document.id))}. Payment is handled by PayChangu.'
                        : 'This document is included in a paid subscription. Free papers and '
                            'guides stay open without an account.',
                    actionLabel: 'View plans & prices',
                    onAction: () => _openPass(context),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!entry.onDevice && guide == null && !locked) ...[
                  InfoBanner(
                    tone: BannerTone.warning,
                    icon: Icons.attach_file_rounded,
                    title: 'Catalogue record — no file attached',
                    message:
                        'Kuphanda stores the details so you can find the paper. Attach the official '
                        'PDF from this device to read it offline.',
                  ),
                  const SizedBox(height: 12),
                ],
                _PrimaryActions(
                  state: state,
                  document: document,
                  entry: entry,
                  guide: guide,
                  progress: progress,
                  locked: locked,
                  busy: _busy,
                  onRead: () => _openReader(context, state, document, entry, guide),
                  onAttach: () => _attach(context, state, document),
                  onDownload: () => _download(context, state, document),
                  onPass: () => _openPass(context),
                ),
                if (state.hasRemoteFile(document.id)) ...[
                  const SizedBox(height: 10),
                  _OfflineStatusCard(
                    state: state,
                    document: document,
                    onDownload: () => _download(context, state, document),
                    onRemove: () => _removeDownload(context, state, document),
                  ),
                ],
                const SizedBox(height: 14),
                _DocumentActionBar(
                  saved: entry.saved,
                  noteCount: state.notesFor(document.id).length,
                  marksActive: _tab == 1,
                  onSave: () => state.toggleSaved(document.id),
                  onNote: () => _addNote(context, state, document),
                  onMarks: () => setState(() => _tab = 1),
                ),
                const SizedBox(height: 24),
                _Tabs(value: _tab, onChanged: (value) => setState(() => _tab = value)),
                const SizedBox(height: 18),
                switch (_tab) {
                  0 => _Overview(
                      state: state,
                      document: document,
                      subject: subject,
                      guide: guide,
                      entry: entry,
                      onOpenSection: (index) => _openGuide(context, document, index),
                      onRate: (stars) => state.rateDocument(document.id, stars),
                    ),
                  1 => _MarksTab(
                      state: state,
                      document: document,
                      onAddNote: () => _addNote(context, state, document),
                    ),
                  _ => _RelatedTab(state: state, document: document),
                },
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    AppState state,
    Document document,
    String value,
  ) async {
    switch (value) {
      case 'pass':
        _openPass(context);
      case 'remove-file':
        final confirmed = await confirmAction(
          context,
          title: 'Remove the file?',
          message: 'The document stays in your catalogue and your progress is kept. '
              'You can attach the PDF again later.',
          confirmLabel: 'Remove',
        );
        if (confirmed) {
          await state.removeFile(document.id);
          if (context.mounted) showSnack(context, 'File removed from this device.');
        }
      case 'delete':
        final confirmed = await confirmAction(
          context,
          title: 'Delete this document?',
          message: 'The imported file, its progress and your notes will be deleted from this phone.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          await state.deletePersonalDocument(document.id);
          if (context.mounted) Navigator.of(context).pop();
        }
      case 'edit':
        if (context.mounted) await _editDetails(context, state, document);
    }
  }

  Future<void> _editDetails(BuildContext context, AppState state, Document document) async {
    final titleController = TextEditingController(text: document.title);
    var subjectId = document.subjectId;
    var form = document.form;
    var kind = document.kind;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SheetBody(
          title: 'Edit document',
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  await state.updatePersonalDocument(
                    document.id,
                    title: titleController.text,
                    subjectId: subjectId,
                    form: form,
                    kind: kind,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('Save'),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
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
                      onSelected: (_) => setSheetState(() => subjectId = subject.id),
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
            ],
          ),
        ),
      ),
    );
    titleController.dispose();
  }

  Future<void> _attach(BuildContext context, AppState state, Document document) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await state.pickPdf();
      if (picked == null) return;
      await state.attachPdf(document.id, picked);
      if (context.mounted) {
        showSnack(context, '${picked.fileName} is now available offline.');
      }
    } on FormatException catch (error) {
      if (context.mounted) showSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showSnack(context, 'Could not attach the file: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(BuildContext context, AppState state, Document document) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await state.markForOffline(document.id);
      if (context.mounted) showSnack(context, 'Downloaded. You can read it without internet.');
    } on ApiException catch (error) {
      if (context.mounted) showSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showSnack(context, 'Download failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDownload(
    BuildContext context,
    AppState state,
    Document document,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove the offline copy?',
      message: 'The document stays in the catalogue. Your reading progress and notes are kept. '
          'You can download it again while your subscription is active.',
      confirmLabel: 'Remove download',
    );
    if (!confirmed) return;
    await state.removeOffline(document.id);
    if (context.mounted) showSnack(context, 'Offline copy removed.');
  }

  void _openPass(BuildContext context) {
    openSubscription(context, documentId: widget.documentId);
  }

  void _openReader(
    BuildContext context,
    AppState state,
    Document document,
    LibraryEntry entry,
    StudyGuide? guide,
  ) {
    if (entry.locked) {
      _openPass(context);
      return;
    }
    if (guide != null) {
      _openGuide(context, document, 0);
      return;
    }
    // A structured version reflows to the screen; prefer it over the PDF.
    if (document.hasBlocks) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlockReaderScreen(
            documentId: document.id,
            title: document.title,
          ),
        ),
      );
      return;
    }
    final asset = entry.asset;
    if (asset == null) {
      if (state.hasRemoteFile(document.id)) {
        _download(context, state, document);
      } else {
        _attach(context, state, document);
      }
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfReaderScreen(documentId: document.id),
      ),
    );
  }

  void _openGuide(BuildContext context, Document document, int page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideReaderScreen(documentId: document.id, initialSection: page),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, AppState state, Document document) async {
    final controller = TextEditingController();
    final progress = state.progressOrDefault(document);
    final pageController = TextEditingController(text: '${progress.currentPage}');

    // A purpose-built composer instead of the generic sheet: the sheet grows to
    // exactly its content, so the field and both buttons stay above the
    // keyboard rather than being pushed behind it.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add a note', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Notes stay on this phone and are listed with the document.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: pageController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Page'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'What do you want to remember?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final page = int.tryParse(pageController.text) ??
                              progress.currentPage;
                          await state.addNote(document.id, page, controller.text);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text('Save note'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    pageController.dispose();
  }
}

/// Save / Note / Marks as one segmented control rather than three identical
/// pills. Each segment is a single line by construction: the label never wraps,
/// so "Marks" cannot break into "Mark s" on a narrow phone.
class _DocumentActionBar extends StatelessWidget {
  const _DocumentActionBar({
    required this.saved,
    required this.noteCount,
    required this.marksActive,
    required this.onSave,
    required this.onNote,
    required this.onMarks,
  });

  final bool saved;
  final int noteCount;
  final bool marksActive;
  final VoidCallback onSave;
  final VoidCallback onNote;
  final VoidCallback onMarks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: saved ? 'Saved' : 'Save',
              active: saved,
              onTap: onSave,
            ),
          ),
          _divider(theme),
          Expanded(
            child: _Segment(
              icon: Icons.edit_note_rounded,
              label: noteCount == 0 ? 'Note' : 'Notes · $noteCount',
              active: false,
              onTap: onNote,
            ),
          ),
          _divider(theme),
          Expanded(
            child: _Segment(
              icon: Icons.bookmarks_outlined,
              label: 'Marks',
              active: marksActive,
              onTap: onMarks,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        color: theme.colorScheme.outlineVariant,
      );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = active
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;

    return Material(
      color: active ? theme.colorScheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.state,
    required this.document,
    required this.entry,
    required this.guide,
    required this.progress,
    required this.locked,
    required this.busy,
    required this.onRead,
    required this.onAttach,
    required this.onDownload,
    required this.onPass,
  });

  final AppState state;
  final Document document;
  final LibraryEntry entry;
  final StudyGuide? guide;
  final ReadingProgress progress;
  final bool locked;
  final bool busy;
  final VoidCallback onRead;
  final VoidCallback onAttach;
  final VoidCallback onDownload;
  final VoidCallback onPass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = entry.onDevice;
    final isGuide = guide != null;
    final remote = state.hasRemoteFile(document.id);
    final offline = state.offlineStateFor(document.id);
    final downloading = offline == OfflineState.downloading;

    final String label;
    final IconData icon;
    final VoidCallback? action;

    if (locked) {
      label = 'Subscribe or buy';
      icon = Icons.lock_open_rounded;
      action = onPass;
    } else if (downloading) {
      label = 'Downloading ${(state.downloadProgressFor(document.id) * 100).round()}%';
      icon = Icons.downloading_rounded;
      action = null;
    } else if (isGuide) {
      label = progress.percent > 0
          ? 'Continue guide · ${progress.percent.round()}%'
          : 'Read study guide';
      icon = Icons.auto_stories_rounded;
      action = onRead;
    } else if (hasFile) {
      label = progress.percent > 0
          ? 'Continue reading · page ${progress.currentPage}'
          : 'Read now';
      icon = Icons.menu_book_rounded;
      action = onRead;
    } else if (remote) {
      label = 'Download for offline reading';
      icon = Icons.download_rounded;
      action = onDownload;
    } else {
      label = 'Attach the PDF';
      icon = Icons.attach_file_rounded;
      action = onAttach;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : action,
          icon: busy || downloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 19),
          label: Text(label),
        ),
        if (downloading) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: state.downloadProgressFor(document.id).clamp(0, 1),
              minHeight: 4,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shows the offline lifecycle for a server-managed document: not downloaded,
/// queued, downloading, up to date, update available, or failed.
class _OfflineStatusCard extends StatelessWidget {
  const _OfflineStatusCard({
    required this.state,
    required this.document,
    required this.onDownload,
    required this.onRemove,
  });

  final AppState state;
  final Document document;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offline = state.offlineStateFor(document.id);
    final asset = state.assetFor(document.id);
    final version = state.remoteVersionFor(document.id);
    final locked = state.isLocked(document);
    final error = state.downloadErrorFor(document.id);

    final String title;
    final String subtitle;
    final Widget? action;

    switch (offline) {
      case OfflineState.downloading:
        title = 'Downloading';
        subtitle = '${(state.downloadProgressFor(document.id) * 100).round()}% · '
            'keeps the previous copy until this one is verified';
        action = null;
        break;
      case OfflineState.downloaded:
        title = 'Available offline · v${asset?.version}';
        subtitle = '${asset?.fileName ?? ''} · stored on this phone';
        action = OutlinedButton(onPressed: onRemove, child: const Text('Remove'));
        break;
      case OfflineState.updateAvailable:
        title = 'Update available · v$version';
        subtitle = 'You are reading v${asset?.version}. The updated file downloads when you refresh.';
        action = FilledButton(
          onPressed: onDownload,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
          child: const Text('Update'),
        );
        break;
      case OfflineState.queued:
        title = 'Queued for download';
        subtitle = 'Marked for offline reading. Download it now to use it without internet.';
        action = FilledButton(
          onPressed: onDownload,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
          child: const Text('Download'),
        );
        break;
      case OfflineState.failed:
        title = 'Download failed';
        subtitle = error ?? 'The file could not be saved. Your previous copy is untouched.';
        action = OutlinedButton(onPressed: onDownload, child: const Text('Retry'));
        break;
      case OfflineState.none:
        if (locked) {
          title = 'Premium · online only';
          subtitle = 'Subscribe or buy this document to download it for offline reading.';
          action = null;
        } else {
          title = 'Online only';
          subtitle = 'Download it to keep reading when the connection drops.';
          action = OutlinedButton(onPressed: onDownload, child: const Text('Download'));
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (offline) {
              OfflineState.downloaded => Icons.offline_pin_rounded,
              OfflineState.updateAvailable => Icons.system_update_alt_rounded,
              OfflineState.failed => Icons.error_outline_rounded,
              OfflineState.downloading => Icons.downloading_rounded,
              _ => Icons.cloud_download_outlined,
            },
            size: 20,
            color: offline == OfflineState.failed
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (index, label) in <String>['Overview', 'Marks', 'Related'].indexed)
            Expanded(
              child: TextButton(
                onPressed: () => onChanged(index),
                style: TextButton.styleFrom(
                  backgroundColor: value == index
                      ? Theme.of(context).colorScheme.surfaceContainerLowest
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  minimumSize: const Size(0, 38),
                ),
                child: Text(label),
              ),
            ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.state,
    required this.document,
    required this.subject,
    required this.guide,
    required this.entry,
    required this.onOpenSection,
    required this.onRate,
  });

  final AppState state;
  final Document document;
  final Subject subject;
  final StudyGuide? guide;
  final LibraryEntry entry;
  final ValueChanged<int> onOpenSection;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.progressOrDefault(document);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(document.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
        const SizedBox(height: 20),
        if (guide != null) ...[
          Row(
            children: [
              Text('Contents', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${guide!.pageCount} sections · ${formatMinutes(guide!.estimatedMinutes)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < guide!.sections.length; index++) ...[
                  ListTile(
                    onTap: () => onOpenSection(index),
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: subject.color.withValues(alpha: 0.12),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: subject.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(guide!.sections[index].title, style: theme.textTheme.bodyMedium),
                    subtitle: Text(
                      '${guide!.sections[index].minutes} min · '
                      '${guide!.sections[index].difficultyLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: index == progress.currentPage - 1
                        ? const Icon(Icons.play_circle_outline_rounded, size: 20)
                        : null,
                    dense: true,
                  ),
                  if (index < guide!.sections.length - 1)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Text('Details', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              entry.onDevice ? 'Available offline' : 'File not attached',
              style: theme.textTheme.labelSmall?.copyWith(
                color: entry.onDevice ? AppColors.green : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              KeyValueRow(label: 'Subject', value: subject.name),
              KeyValueRow(label: 'Form / level', value: 'Form ${document.form} · ${document.qualification}'),
              KeyValueRow(label: 'Type', value: document.kind.label),
              if (document.year != null) KeyValueRow(label: 'Year', value: '${document.year}'),
              if (document.paperNumber != null)
                KeyValueRow(label: 'Paper', value: 'Paper ${document.paperNumber}'),
              if (document.session != null) KeyValueRow(label: 'Session', value: document.session!),
              if (document.totalMarks != null)
                KeyValueRow(label: 'Total marks', value: '${document.totalMarks}'),
              if (document.durationMinutes != null)
                KeyValueRow(label: 'Duration', value: formatMinutes(document.durationMinutes!)),
              KeyValueRow(label: 'Pages', value: '${document.pages}'),
              KeyValueRow(label: 'Language', value: document.language),
              if (document.publisher != null) KeyValueRow(label: 'Publisher', value: document.publisher!),
              KeyValueRow(label: 'Added', value: formatDate(document.addedAt)),
              if (entry.asset != null)
                KeyValueRow(
                  label: 'File',
                  value: '${entry.asset!.fileName} · ${formatBytes(entry.asset!.sizeBytes)}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Rate this document', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: () => onRate(star),
                tooltip: '$star star${star == 1 ? '' : 's'}',
                icon: Icon(
                  star <= (entry.rating ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.sun,
                ),
              ),
            if (entry.rating != null)
              Text(
                'You rated this ${entry.rating}/5',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MarksTab extends StatelessWidget {
  const _MarksTab({
    required this.state,
    required this.document,
    required this.onAddNote,
  });

  final AppState state;
  final Document document;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarks = state.bookmarksFor(document.id);
    final notes = state.notesFor(document.id);

    if (bookmarks.isEmpty && notes.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'No marks yet',
        message: 'Bookmark a page while reading, or write a note against a question you want to revisit.',
        actionLabel: 'Add a note',
        onAction: onAddNote,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bookmarks.isNotEmpty) ...[
          Text('Bookmarks', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < bookmarks.length; index++) ...[
                  ListTile(
                    leading: const Icon(Icons.bookmark_rounded, size: 20),
                    title: Text(bookmarks[index].label ?? 'Page ${bookmarks[index].page}'),
                    subtitle: Text(
                      'Page ${bookmarks[index].page} · ${formatRelative(bookmarks[index].createdAt)}',
                      style: theme.textTheme.labelSmall,
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove bookmark',
                      onPressed: () => state.removeBookmark(bookmarks[index].id),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                    dense: true,
                  ),
                  if (index < bookmarks.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (notes.isNotEmpty) ...[
          Row(
            children: [
              Text('Notes', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton(onPressed: onAddNote, child: const Text('Add note')),
            ],
          ),
          const SizedBox(height: 4),
          for (final note in notes) ...[
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(label: 'Page ${note.page}', compact: true),
                      const Spacer(),
                      Text(
                        formatRelative(note.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        onPressed: () => state.removeNote(note.id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete note',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(note.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _RelatedTab extends StatelessWidget {
  const _RelatedTab({required this.state, required this.document});

  final AppState state;
  final Document document;

  @override
  Widget build(BuildContext context) {
    final related = state.entries
        .where((entry) =>
            entry.document.id != document.id &&
            (entry.document.subjectId == document.subjectId ||
                entry.document.form == document.form))
        .take(6)
        .toList();

    if (related.isEmpty) {
      return const EmptyState(
        icon: Icons.library_books_outlined,
        title: 'Nothing related yet',
        message: 'Documents from the same subject or form will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in related) ...[
          DocumentTile(
            entry: entry,
            dense: true,
            onTap: () => openDocument(context, entry.document.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
