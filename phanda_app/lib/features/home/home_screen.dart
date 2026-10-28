import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/assignment_tile.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_card.dart';
import '../../state/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenProfile,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final continueReading = state.continueReading.take(6).toList();
    final dueSoon = state.upcomingAssignments.take(3).toList();
    final recommended = state.recommended(limit: 8);
    final guides = state.entries
        .where((entry) => entry.document.guideId != null)
        .take(6)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          padding: EdgeInsets.fromLTRB(pageGutter(context), 12, pageGutter(context), 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeHeader(
                state: state,
                onOpenProfile: onOpenProfile,
                onOpenExam: () => openExamHub(context),
              ),
              const SizedBox(height: 16),
              _QuickActions(
                onBrowse: () => onNavigate(1),
                onImport: () => onNavigate(2),
                onClasses: () => onNavigate(3),
              ),
              const SizedBox(height: 28),
              ResponsiveTwoPane(
                primary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (continueReading.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Continue reading',
                        subtitle: 'Pick up where you stopped',
                        actionLabel: 'My documents',
                        onAction: () => onNavigate(2),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 272,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: continueReading.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final entry = continueReading[index];
                            return DocumentStripCard(
                              entry: entry,
                              onTap: () => openDocument(context, entry.document.id),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    SectionHeader(
                      title: 'For Form ${state.profile.form}',
                      subtitle: 'Chosen for ${state.profile.examTarget} ${state.profile.examYear}',
                      actionLabel: 'Library',
                      onAction: () => onNavigate(1),
                    ),
                    const SizedBox(height: 12),
                    if (recommended.isEmpty)
                      EmptyState(
                        icon: Icons.local_library_outlined,
                        title: 'Your shelf is empty',
                        message: 'Add subjects in your profile to see recommendations.',
                        actionLabel: 'Open profile',
                        onAction: onOpenProfile,
                      )
                    else
                      SizedBox(
                        height: 272,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommended.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final entry = recommended[index];
                            return DocumentStripCard(
                              entry: entry,
                              onTap: () => openDocument(context, entry.document.id),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'Study guides',
                      subtitle: 'Objectives, key ideas and common mistakes',
                      actionLabel: 'All guides',
                      onAction: () => onNavigate(1),
                    ),
                    const SizedBox(height: 12),
                    if (guides.isEmpty)
                      const EmptyState(
                        icon: Icons.auto_stories_outlined,
                        title: 'No guides yet',
                        message: 'Guides appear here once they are added to the catalogue.',
                        compact: true,
                      )
                    else
                      SizedBox(
                        height: 272,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: guides.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final entry = guides[index];
                            return DocumentStripCard(
                              entry: entry,
                              onTap: () => openDocument(context, entry.document.id),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Due soon',
                      actionLabel: 'Classes',
                      onAction: () => onNavigate(3),
                    ),
                    const SizedBox(height: 10),
                    if (dueSoon.isEmpty)
                      EmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'Nothing due',
                        message: 'Assignments from your classes will appear here.',
                        actionLabel: 'Join a class',
                        onAction: () => onNavigate(3),
                        compact: true,
                      )
                    else
                      for (final assignment in dueSoon) ...[
                        AssignmentTile(
                          assignment: assignment,
                          state: state,
                          onOpen: () => openDocument(context, assignment.documentId),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 18),
                    _WeeklyCard(state: state, onOpenProgress: () => onNavigate(4)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Kuphanda · works offline · your notes stay on this phone',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.state,
    required this.onOpenProfile,
    required this.onOpenExam,
  });

  final AppState state;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenExam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = state.profile;
    final days = state.daysToExam;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.greenDeep, AppColors.green],
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sun.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 32,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 40, light: true),
                    const SizedBox(width: 10),
                    Text(
                      'KUPHANDA',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onOpenProfile,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          child: Text(
                            profile.initials,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '${greeting(DateTime.now())}, ${profile.firstName}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (profile.school.isNotEmpty) profile.school,
                    'Form ${profile.form} · ${profile.examTarget}',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HeaderStat(
                        value: '$days',
                        label: 'days to ${profile.examTarget}',
                        onTap: onOpenExam,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeaderStat(
                        value: '${state.stats.currentStreak}',
                        label: state.stats.currentStreak == 1 ? 'day streak' : 'day streak',
                        onTap: null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onBrowse,
    required this.onImport,
    required this.onClasses,
  });

  final VoidCallback onBrowse;
  final VoidCallback onImport;
  final VoidCallback onClasses;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.search_rounded,
            label: 'Find a paper',
            onTap: onBrowse,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.download_for_offline_outlined,
            label: 'Downloads',
            onTap: onImport,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.groups_outlined,
            label: 'My classes',
            onTap: onClasses,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.state, required this.onOpenProgress});

  final AppState state;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = state.stats;
    final readCount = state.entries.where((entry) => entry.progressPercent >= 100).length;

    return AppCard(
      onTap: onOpenProgress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('This week', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${formatMinutes(stats.weekMinutes)} / ${formatMinutes(stats.weeklyGoalMinutes)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WeeklyBars(stats: stats),
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '$readCount ${readCount == 1 ? 'document' : 'documents'} finished',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 15, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${stats.todayMinutes} min today',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

