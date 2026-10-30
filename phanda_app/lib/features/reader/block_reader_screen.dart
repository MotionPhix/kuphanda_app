import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/store/block_cache.dart';
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
  Future<LoadedBlockDocument>? _document;
  bool _showAnswers = false;
  final ScrollController _scroll = ScrollController();
  int _lastReported = -1;
  bool _restored = false;
  bool _resumeScheduled = false;
  DateTime? _readingSince;
  Timer? _studyTimer;
  AppState? _state;

  /// A blank spinner for the length of an HTTP timeout reads as a broken app,
  /// so a slow request says so and offers the error screen early.
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope is an inherited widget, so it is only safe to read here. Lookups
    // are not allowed from a scroll callback, so the state is cached for the
    // progress listener.
    _state = AppScope.of(context);
    _document ??= _load();
  }

  Future<LoadedBlockDocument> _load() {
    _slowTimer?.cancel();
    _slow = false;
    _slowTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _slow = true);
    });

    return AppScope.of(context).loadBlockDocument(widget.documentId).whenComplete(() {
      _slowTimer?.cancel();
    });
  }

  /// Puts the reader back where the learner stopped.
  ///
  /// The percentage was recorded but never read back, so "Continue reading ·
  /// 19%" opened at question 1: a warm screen looked fine because the scroll
  /// position was still in memory, and a cold open always started over.
  /// Called from the frame that builds the list, not from the future: the
  /// callback has to run after that frame, or the scroll controller has no
  /// client yet and the jump is dropped without a trace.
  void _scheduleResume() {
    if (_restored || _resumeScheduled) return;
    _resumeScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeScheduled = false;
      _resume();
    });
  }

  void _resume({int attemptsLeft = 3}) {
    if (_restored) return;

    final progress = _state?.progressFor(widget.documentId);
    final fraction = progress?.fraction;

    // Nothing to resume, or a finished paper: it should open at the start, since
    // there is nothing below its last line to continue into.
    if (fraction == null || fraction <= 0.01 || (progress?.isComplete ?? false)) {
      _restored = true;
      return;
    }

    if (!mounted || !_scroll.hasClients) {
      if (attemptsLeft > 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _resume(attemptsLeft: attemptsLeft - 1));
      }
      return;
    }

    _restored = true;
    _jumpToFraction(fraction);
  }

  void _jumpToFraction(double fraction, {int attemptsLeft = 3}) {
    if (!mounted || !_scroll.hasClients) return;

    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) {
      if (attemptsLeft > 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _jumpToFraction(fraction, attemptsLeft: attemptsLeft - 1));
      }
      return;
    }

    _scroll.jumpTo((max * fraction).clamp(0.0, max));

    // Blocks are measured as they build, so the extent after the first jump is a
    // better estimate of the paper's height than the one before it was.
    if (attemptsLeft > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final refined = _scroll.position.maxScrollExtent;
        if ((refined - max).abs() > 1) {
          _scroll.jumpTo((refined * fraction).clamp(0.0, refined));
        }
      });
    }
  }

  /// Progress for a reflowable document follows the scroll, not fixed pages.
  /// Reporting page 1 of 6 forever is what made every book look stuck at 17%.
  void _reportProgress() {
    // Before the list has been laid out maxScrollExtent is 0, which is not the
    // same as "the reader reached the end": reading it that way marked every
    // paper 100% read the moment it was opened.
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;

    final state = _state;
    if (state == null) return;
    final max = _scroll.position.maxScrollExtent;
    final fraction = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();

    if (percent == _lastReported) return;

    _lastReported = percent;
    state.recordProgress(
      documentId: widget.documentId,
      // A reflowable paper has one scroll, not six pages. The invented page
      // number used to decide completion — page 6 of 6 at 83% — so it goes.
      page: 1,
      totalPages: 1,
      fraction: fraction,
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_reportProgress);

    _readingSince = DateTime.now();
    // Committed as it is spent, not on exit: scroll events are not a proxy for
    // minutes, and a session lost to a kill would be time the learner did.
    _studyTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _commitStudyTime(),
    );
  }

  /// Banks the time since the last commit. The cap keeps a timer that fires
  /// after the app was frozen from inventing an hour of study.
  void _commitStudyTime() {
    final since = _readingSince;
    _readingSince = DateTime.now();
    if (since == null || !mounted) return;

    final seconds = _readingSince!.difference(since).inSeconds.clamp(0, 120);
    if (seconds > 0) _state?.addStudyTime(widget.documentId, seconds);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _studyTimer?.cancel();
    _commitStudyTime();
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
      body: FutureBuilder<LoadedBlockDocument>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_slow) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Still loading. A slow connection can take up to 25 seconds.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            );
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

          final loaded = snapshot.data;
          final document = loaded?.document;
          if (document == null || document.blocks.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'Nothing to read yet',
                message: 'This paper has not been prepared in the app format.',
                icon: Icons.menu_book_outlined,
              ),
            );
          }

          _scheduleResume();

          return Column(
            children: [
              // A copy from disk looks live otherwise, and a learner reading
              // yesterday's marks has no way to know.
              if (loaded!.fromCache)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: InfoBanner(
                    tone: BannerTone.info,
                    icon: Icons.cloud_off_rounded,
                    title: 'Saved copy',
                    message: 'You are offline, so this is the paper as it was last '
                        'downloaded. Anything changed since then appears once you reconnect.',
                  ),
                ),
              Expanded(
                child: BlockDocumentView(
                  document: document,
                  showAnswers: _showAnswers,
                  controller: _scroll,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
