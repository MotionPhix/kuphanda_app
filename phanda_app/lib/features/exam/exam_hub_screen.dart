import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_card.dart';
import '../../data/models/document.dart';

class ExamHubScreen extends StatelessWidget {
  const ExamHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final profile = state.profile;
    final form = profile.form <= 2 ? 2 : 4;
    final qualification = profile.examTarget;

    final papers = state.entries
        .where((entry) =>
            entry.document.form == form &&
            (entry.document.kind == DocumentKind.pastPaper ||
                entry.document.kind == DocumentKind.markingScheme))
        .toList()
      ..sort((a, b) {
        final year = (b.document.year ?? 0).compareTo(a.document.year ?? 0);
        if (year != 0) return year;
        return (a.document.paperNumber ?? 0).compareTo(b.document.paperNumber ?? 0);
      });

    final byYear = <int, List<LibraryEntry>>{};
    for (final entry in papers) {
      byYear.putIfAbsent(entry.document.year ?? 0, () => <LibraryEntry>[]).add(entry);
    }

    final guides = state.entries
        .where((entry) => entry.document.guideId != null && entry.document.form == form)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Exam hub')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.greenDeep, AppColors.green],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$qualification ${state.examDate.year}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${state.daysToExam}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 48,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 8),
                            child: Text(
                              'days to the exam window',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Window opens ${formatDate(state.examDate)} · Form $form · ${profile.subjects.length} subjects',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_outlined,
                                size: 18, color: AppColors.sun),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Work backwards: one paper a week, marked the same day, beats '
                                'reading notes you already know.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Past papers', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${papers.length} papers',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (papers.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No papers for this form',
                    message: 'Change your form in the profile, or browse the whole library.',
                    compact: true,
                  )
                else
                  for (final year in byYear.keys) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '$year',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final entry in byYear[year]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DocumentTile(
                          entry: entry,
                          dense: true,
                          showProgress: true,
                          onTap: () => openDocument(context, entry.document.id),
                        ),
                      ),
                  ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Study guides', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${guides.length} guides',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (guides.isEmpty)
                  const EmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'No guides for this form yet',
                    message: 'Structured guides currently cover MSCE Biology, Chemistry, '
                        'Mathematics and Physics.',
                    compact: true,
                  )
                else
                  for (final entry in guides.take(8)) ...[
                    DocumentTile(
                      entry: entry,
                      dense: true,
                      onTap: () => openDocument(context, entry.document.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A past paper routine that works', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final (index, step) in <String>[
                        'Sit the paper in one sitting, timed, with no notes.',
                        'Mark it with the scheme and write down every lost mark.',
                        'Group the lost marks: knowledge, method, or careless slip.',
                        'Re-read only the pages that explain those marks.',
                        'Redo the same questions after two days.',
                      ].indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(step, style: theme.textTheme.bodySmall),
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
      ),
    );
  }
}
