import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final gutter = pageGutter(context);
    final stats = state.stats;
    final entries = state.entries;
    final started = entries.where((entry) => entry.progressPercent > 0).toList();
    final finished = entries.where((entry) => entry.progressPercent >= 99.5).toList();
    final tally = state.readingTally;

    final recent = started
        .where((entry) => state.progressFor(entry.document.id)?.lastReadAt != null)
        .toList()
      ..sort((a, b) => state
          .progressFor(b.document.id)!
          .lastReadAt!
          .compareTo(state.progressFor(a.document.id)!.lastReadAt!));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                eyebrow: 'Evidence, not tick boxes',
                title: 'Progress',
                subtitle: 'What you have read, and how long you spent on it.',
                actions: [
                  IconButton(
                    onPressed: onOpenProfile,
                    tooltip: 'Profile',
                    icon: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.green.withValues(alpha: 0.12),
                      child: Text(
                        state.profile.initials,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 820 ? 4 : 2;
                  final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
                  final tileHeight = constraints.maxWidth >= 820 ? 112.0 : 118.0;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: width,
                        child: StatTile(
                          height: tileHeight,
                          label: 'Streak',
                          value: '${stats.currentStreak}',
                          caption: stats.currentStreak == 1 ? 'day in a row' : 'days in a row',
                          icon: Icons.local_fire_department_outlined,
                          tint: const Color(0xFFB45309),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatTile(
                          height: tileHeight,
                          label: 'This week',
                          value: formatMinutes(stats.weekMinutes),
                          caption: 'goal ${formatMinutes(stats.weeklyGoalMinutes)}',
                          icon: Icons.timer_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatTile(
                          height: tileHeight,
                          label: 'Finished',
                          value: '${finished.length}',
                          caption: '${plural(started.length, 'document')} started',
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatTile(
                          height: tileHeight,
                          label: tally.measuredInQuestions
                              ? 'Questions read'
                              : 'Pages read',
                          value: '${tally.measuredInQuestions ? tally.questions : tally.pages}',
                          caption: tally.measuredInQuestions
                              ? 'across ${plural(tally.papers, 'paper')}'
                              : 'across all documents',
                          icon: Icons.auto_stories_outlined,
                          tint: const Color(0xFF2F6B9A),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              ResponsiveTwoPane(
                breakpoint: 900,
                primaryFlex: 6,
                secondaryFlex: 4,
                primary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Weekly study time', style: theme.textTheme.titleSmall),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _editGoal(context, state),
                                child: const Text('Edit goal'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatMinutes(stats.weekMinutes)} of '
                            '${formatMinutes(stats.weeklyGoalMinutes)} · '
                            '${(stats.weekPercent * 100).round()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          WeeklyBars(stats: stats, height: 132),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              GoalRing(
                                percent: stats.weekPercent,
                                label: '${(stats.weekPercent * 100).round()}%',
                                caption: 'of goal',
                                size: 78,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stats.studiedToday
                                          ? 'You studied ${formatMinutes(stats.todayMinutes)} today.'
                                          : 'No study recorded today yet.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'A short block every day beats one long session. '
                                      'Your streak counts any day with at least a minute.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('By subject', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          for (final subject in _subjects(state))
                            _SubjectRow(subject: subject, state: state),
                        ],
                      ),
                    ),
                  ],
                ),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Recent activity', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (recent.isEmpty)
                      const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No reading yet',
                        message: 'Open a document and your progress will appear here.',
                        compact: true,
                      )
                    else
                      for (final entry in recent.take(5)) ...[
                        AppCard(
                          onTap: () => openDocument(context, entry.document.id),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                entry.document.kind.icon,
                                size: 18,
                                color: entry.subject.color,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.document.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${entry.subject.shortName} · page '
                                      '${state.progressFor(entry.document.id)?.currentPage ?? 1} · '
                                      '${formatRelative(state.progressFor(entry.document.id)!.lastReadAt!)}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${entry.progressPercent.round()}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 14),
                    AppCard(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_outlined,
                                  size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text('How progress is measured',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pages turned and time in the reader are recorded as you read. '
                            'Completing 90% of a document marks its class assignment done. '
                            'Nothing leaves this phone.',
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Subject> _subjects(AppState state) {
    final ids = <String>{
      ...state.profile.subjects.map((subject) => subject.id),
      for (final entry in state.entries)
        if (entry.progressPercent > 0) entry.document.subjectId,
    };
    return ids.map(subjectById).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _editGoal(BuildContext context, AppState state) async {
    var minutes = state.profile.weeklyGoalMinutes;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SheetBody(
          title: 'Weekly study goal',
          subtitle: 'Choose a target you can keep on a school week.',
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
                  await state.setWeeklyGoal(minutes);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('Save goal'),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                formatMinutes(minutes),
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              Slider(
                value: minutes.toDouble(),
                min: 60,
                max: 900,
                divisions: 28,
                label: formatMinutes(minutes),
                onChanged: (value) => setSheetState(() => minutes = value.round()),
              ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final option in <int>[120, 180, 300, 420, 600])
                    ChoiceChip(
                      label: Text(formatMinutes(option)),
                      selected: minutes == option,
                      onSelected: (_) => setSheetState(() => minutes = option),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your goal affects the weekly chart and the ring. It does not lock content.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject, required this.state});

  final Subject subject;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.entries
        .where((entry) => entry.document.subjectId == subject.id)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final progress = entries.fold<double>(0, (sum, entry) => sum + entry.progressPercent) /
        entries.length;
    final started = entries.where((entry) => entry.progressPercent > 0).length;

    return SubjectProgressBar(
      label: subject.name,
      percent: progress / 100,
      detail: '$started/${entries.length} started · ${progress.round()}%',
      color: subject.color,
    );
  }
}
