import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../app.dart';
import '../../core/widgets/common.dart';
import '../../data/models/document.dart';
import '../../state/app_state.dart';
import 'reader_marks.dart';

/// PDF reader for documents that have a file on the device.
///
/// Page turns and elapsed time are recorded against the document, which is the
/// signal a teacher sees on an assignment. The reader also commits time every
/// 20 seconds so a long page does not look like no activity at all.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  AppState? _state;
  Document? _document;
  PdfController? _controller;
  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  int _committedSeconds = 0;
  int _page = 1;
  int _totalPages = 1;
  Object? _loadError;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;

    final state = AppScope.of(context);
    final document = state.documentById(widget.documentId);
    final asset = state.assetFor(widget.documentId);
    _state = state;
    _document = document;

    if (document == null || asset == null || (asset.path == null && asset.assetPath == null)) {
      _loadError = StateError('No file is attached to this document.');
      return;
    }

    final progress = state.progressOrDefault(document);
    final initial = progress.currentPage.clamp(1, document.pages <= 0 ? 1 : document.pages);
    _page = initial;
    _totalPages = asset.pageCount ?? document.pages;

    _controller = PdfController(
      document: asset.assetPath != null
          ? PdfDocument.openAsset(asset.assetPath!)
          : PdfDocument.openFile(asset.path!),
      initialPage: initial,
    );

    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => _commitTime());
  }

  @override
  void dispose() {
    _commitTime();
    _ticker?.cancel();
    _stopwatch.stop();
    _controller?.dispose();
    super.dispose();
  }

  void _commitTime() {
    final state = _state;
    if (state == null || _document == null) return;
    final elapsed = _stopwatch.elapsed.inSeconds - _committedSeconds;
    if (elapsed <= 0) return;
    _committedSeconds += elapsed;
    state.recordProgress(
      documentId: widget.documentId,
      page: _page,
      totalPages: _totalPages,
      seconds: elapsed,
    );
  }

  void _setPage(int page) {
    if (!mounted) return;
    _commitTime();
    setState(() => _page = page.clamp(1, _totalPages));
    _state?.recordProgress(
      documentId: widget.documentId,
      page: _page,
      totalPages: _totalPages,
    );
  }

  Future<void> _jump(int page) async {
    final controller = _controller;
    if (controller == null) return;
    _commitTime();
    controller.jumpToPage(page.clamp(1, _totalPages));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = _state?.assetFor(widget.documentId);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _document?.title ?? 'Document',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              'Page $_page of $_totalPages',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bookmarks and notes',
            onPressed: _state == null
                ? null
                : () => showReaderMarks(
                      context,
                      state: _state!,
                      documentId: widget.documentId,
                      page: _page,
                    ),
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
        ],
      ),
      body: _loadError != null || _controller == null
          ? _ReaderError(
              message: _loadError?.toString() ?? 'This document has no file on this phone.',
              hint: 'Download it from the document screen, then try again.',
            )
          : Column(
              children: [
                Expanded(
                  child: PdfView(
                    controller: _controller!,
                    onDocumentLoaded: (document) {
                      setState(() {
                        _totalPages = document.pagesCount;
                        _page = _page.clamp(1, _totalPages);
                      });
                      _state?.recordProgress(
                        documentId: widget.documentId,
                        page: _page,
                        totalPages: _totalPages,
                      );
                    },
                    onPageChanged: _setPage,
                    onDocumentError: (error) => setState(() => _loadError = error),
                    builders: PdfViewBuilders<DefaultBuilderOptions>(
                      options: const DefaultBuilderOptions(),
                      documentLoaderBuilder: (_) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      pageLoaderBuilder: (_) => const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorBuilder: (_, error) => _ReaderError(
                        message: 'This PDF could not be opened.',
                        hint: '$error',
                      ),
                    ),
                  ),
                ),
                _BottomBar(
                  page: _page,
                  totalPages: _totalPages,
                  onPrevious: _page > 1 ? () => _jump(_page - 1) : null,
                  onNext: _page < _totalPages ? () => _jump(_page + 1) : null,
                  onChanged: _jump,
                  fileName: asset?.fileName,
                ),
              ],
            ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    required this.onChanged,
    this.fileName,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onChanged;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous page',
                ),
                Expanded(
                  child: Slider(
                    value: page.clamp(1, totalPages).toDouble(),
                    min: 1,
                    max: totalPages <= 1 ? 2 : totalPages.toDouble(),
                    divisions: totalPages <= 1 ? 1 : totalPages - 1,
                    label: '$page',
                    onChanged: (value) => onChanged(value.round()),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next page',
                ),
              ],
            ),
            if (fileName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.picture_as_pdf_outlined,
            title: message,
            message: hint,
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}
