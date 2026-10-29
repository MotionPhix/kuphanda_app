import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/models/block_document.dart';
import '../../state/app_state.dart';
import 'block_document_view.dart';

/// Reads a document in its structured form.
///
/// The blocks are fetched rather than bundled so a corrected paper reaches every
/// learner without an app update. Answers stay hidden until the reader asks for
/// them, which is what makes the same document useful for both practice and
/// revision.
class BlockReaderScreen extends StatefulWidget {
  const BlockReaderScreen({
    super.key,
    required this.documentId,
    this.title,
  });

  final String documentId;
  final String? title;

  @override
  State<BlockReaderScreen> createState() => _BlockReaderScreenState();
}

class _BlockReaderScreenState extends State<BlockReaderScreen> {
  Future<BlockDocument>? _document;
  bool _showAnswers = false;
  final ScrollController _scroll = ScrollController();
  int _lastReported = -1;
  AppState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope is an inherited widget, so it is only safe to read here. Lookups
    // are not allowed from a scroll callback, so the state is cached for the
    // progress listener.
    _state = AppScope.of(context);
    _document ??= _load();
  }

  Future<BlockDocument> _load() =>
      AppScope.of(context).loadBlockDocument(widget.documentId);

  /// Progress for a reflowable document follows the scroll, not fixed pages.
  /// Reporting page 1 of 6 forever is what made every book look stuck at 17%.
  void _reportProgress() {
    if (!_scroll.hasClients) return;

    final state = _state;
    if (state == null) return;
    final max = _scroll.position.maxScrollExtent;
    final fraction = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();

    if (percent == _lastReported) return;

    _lastReported = percent;
    state.recordProgress(
      documentId: widget.documentId,
      page: (fraction * 6).ceil().clamp(1, 6),
      totalPages: 6,
      fraction: fraction,
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_reportProgress);
  }

  @override
  void dispose() {
    _reportProgress();
    _state?.flush();
    _scroll
      ..removeListener(_reportProgress)
      ..dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _document = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Read'),
        actions: [
          IconButton(
            tooltip: _showAnswers ? 'Hide answers' : 'Show answers',
            onPressed: () => setState(() => _showAnswers = !_showAnswers),
            icon: Icon(
              _showAnswers
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ],
      ),
      body: FutureBuilder<BlockDocument>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiException
                ? error.message
                : 'This paper could not be loaded.';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      title: 'Not available',
                      message: message,
                      icon: Icons.menu_book_outlined,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final document = snapshot.data;
          if (document == null || document.blocks.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'Nothing to read yet',
                message: 'This paper has not been prepared in the app format.',
                icon: Icons.menu_book_outlined,
              ),
            );
          }

          return BlockDocumentView(
            document: document,
            showAnswers: _showAnswers,
              controller: _scroll,
          );
        },
      ),
    );
  }
}
