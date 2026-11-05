import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/study_guide.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';
import 'reader_marks.dart';

/// Reads a structured study guide, one subtopic per page.
///
/// This is the part of Geli's curriculum graph that survives best on a phone:
/// short pages with objectives, key ideas and the mistakes examiners see most,
/// instead of a 60-page PDF the learner never opens.
class GuideReaderScreen extends StatefulWidget {
  const GuideReaderScreen({
    super.key,
    required this.documentId,
    this.initialSection = 0,
  });

  final String documentId;
  final int initialSection;

  @override
  State<GuideReaderScreen> createState() => _GuideReaderScreenState();
}

class _GuideReaderScreenState extends State<GuideReaderScreen> {
  late AppState _state;
  late StudyGuide _guide;
  late PageController _controller;
  late int _page;
  final Stopwatch _stopwatch = Stopwatch();
  int _committedSeconds = 0;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;

    _state = AppScope.of(context);
    final guide = _state.guideFor(_state.documentById(widget.documentId)!);
    if (guide == null) return;

    _guide = guide;
    final progress = _state.progressOrDefault(
      _state.documentById(widget.documentId)!,
    );
    final resume = widget.initialSection > 0
        ? widget.initialSection
        : (progress.currentPage - 1).clamp(0, guide.pageCount - 1);
    _page = resume;
    _controller = PageController(initialPage: _page);
    _stopwatch.start();
    _initialised = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state.recordProgress(
        documentId: widget.documentId,
        page: _page + 1,
        totalPages: _guide.pageCount,
      );
    });
  }

  @override
  void dispose() {
    _commitTime();
    _controller.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _commitTime() {
    if (!_initialised) return;
    final elapsed = _stopwatch.elapsed.inSeconds - _committedSeconds;
    if (elapsed <= 0) return;
    _committedSeconds += elapsed;
    _state.recordProgress(
      documentId: widget.documentId,
      page: _page + 1,
      totalPages: _guide.pageCount,
      seconds: elapsed,
    );
  }

  void _goTo(int page) {
    _commitTime();
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!_initialised) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This study guide is not available.')),
      );
    }

    final document = state.documentById(widget.documentId);
    final subject = subjectById(document?.subjectId ?? _guide.subjectId);
    final section = _guide.sections[_page];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_guide.title, style: theme.textTheme.titleMedium),
            Text(
              'Section ${_page + 1} of ${_guide.pageCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bookmarks and notes',
            onPressed: () => showReaderMarks(
              context,
              state: state,
              documentId: widget.documentId,
              page: _page + 1,
              pageLabel: section.title,
            ),
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _guide.sections.length,
              onPageChanged: (index) {
                _commitTime();
                setState(() => _page = index);
                state.recordProgress(
                  documentId: widget.documentId,
                  page: index + 1,
                  totalPages: _guide.pageCount,
                );
              },
              itemBuilder: (context, index) {
                final item = _guide.sections[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Wrap, not Row: three pills at 1.3x text need 194px
                          // more than the line has, and the third one is the
                          // difficulty the paper is aimed at.
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Pill(
                                label:
                                    'Section ${index + 1} of ${_guide.pageCount}',
                                color: subject.color,
                                compact: true,
                              ),
                              Pill(
                                label: '${item.minutes} min',
                                icon: Icons.schedule_rounded,
                                compact: true,
                              ),
                              Pill(label: item.difficultyLabel, compact: true),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 28,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_guide.title} · ${subject.name} · Form 4 (MSCE)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _ReaderCard(
                            title: 'By the end of this section',
                            icon: Icons.flag_outlined,
                            tint: subject.color,
                            child: Column(
                              children: [
                                for (final objective in item.objectives)
                                  _Bullet(
                                    text: objective,
                                    color: subject.color,
                                    icon: Icons.check_rounded,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ReaderCard(
                            title: 'Key ideas',
                            icon: Icons.lightbulb_outline_rounded,
                            tint: AppColors.sun,
                            child: Column(
                              children: [
                                for (var i = 0; i < item.keyIdeas.length; i++)
                                  _Numbered(
                                    index: i + 1,
                                    text: item.keyIdeas[i],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ReaderCard(
                            title: 'Where marks are lost',
                            icon: Icons.warning_amber_rounded,
                            tint: AppColors.red,
                            child: Column(
                              children: [
                                for (final mistake in item.mistakes)
                                  _Bullet(
                                    text: mistake,
                                    color: AppColors.red,
                                    icon: Icons.close_rounded,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ExamTip(section: item, subject: subject.name),
                          const SizedBox(height: 24),
                          if (index == _guide.sections.length - 1)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  _commitTime();
                                  state.recordProgress(
                                    documentId: widget.documentId,
                                    page: _guide.pageCount,
                                    totalPages: _guide.pageCount,
                                  );
                                  await state.flush();
                                  if (context.mounted) {
                                    showSnack(
                                      context,
                                      'Guide finished. Your progress is saved.',
                                    );
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                ),
                                label: const Text('Finish this guide'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Swipe left for the next section',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _page == 0 ? null : () => _goTo(_page - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Previous section',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (_page + 1) / _guide.pageCount,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_page + 1} / ${_guide.pageCount} · ${_guide.sections[_page].title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _page == _guide.pageCount - 1
                        ? null
                        : () => _goTo(_page + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Next section',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({
    required this.title,
    required this.icon,
    required this.tint,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: tint),
              const SizedBox(width: 7),
              // These headings are sentences ("By the end of this section…"),
              // not labels, so at 1.3x they ran 214px past the card.
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: tint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Numbered extends StatelessWidget {
  const _Numbered({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamTip extends StatelessWidget {
  const _ExamTip({required this.section, required this.subject});

  final GuideSection section;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            size: 20,
            color: AppColors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn this into marks',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Close the page and write the three key ideas from memory. Then open '
                  'the ${section.title.toLowerCase()} questions in a $subject past paper and '
                  'answer two of them without notes. ${section.minutes} minutes of reading '
                  'should produce at least ten minutes of writing.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
