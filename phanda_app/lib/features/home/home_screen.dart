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
import '../../data/api/api_models.dart';
import '../../state/app_state.dart';
import '../notifications/notifications_screen.dart';

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
    // A strip card is a fixed cover plus two lines of text. At a larger text
    // size the text needs more room than 272dp leaves, and the card overflowed
    // instead of growing — so the strip grows with the reader's setting.
    final stripHeight =
        272.0 +
        (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6) - 1) * 110;
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
          padding: EdgeInsets.fromLTRB(
            pageGutter(context),
            12,
            pageGutter(context),
            40,
          ),
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
              if (state.notifications.isNotEmpty) ...[
                const SizedBox(height: 16),
                _UpdatesCard(
                  latest: state.notifications.first,
                  count: state.notifications.length,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ],
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
                        height: stripHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: continueReading.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final entry = continueReading[index];
                            return DocumentStripCard(
                              entry: entry,
                              onTap: () =>
                                  openDocument(context, entry.document.id),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    SectionHeader(
                      title: 'For Form ${state.profile.form}',
                      subtitle:
                          'Chosen for ${state.profile.examTarget} ${state.profile.examYear}',
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
                        height: stripHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommended.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final entry = recommended[index];
                            return DocumentStripCard(
                              entry: entry,
                              onTap: () =>
                                  openDocument(context, entry.document.id),
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
                        height: stripHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: guides.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final entry = guides[index];
                            return DocumentStripCard(
                              entry: entry,
                              onTap: () =>
                                  openDocument(context, entry.document.id),
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
                        message:
                            'Assignments from your classes will appear here.',
                        actionLabel: 'Join a class',
                        onAction: () => onNavigate(3),
                        compact: true,
                      )
                    else
                      for (final assignment in dueSoon) ...[
                        AssignmentTile(
                          assignment: assignment,
                          state: state,
                          onOpen: () =>
                              openDocument(context, assignment.documentId),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 18),
                    _WeeklyCard(
                      state: state,
                      onOpenProgress: () => onNavigate(4),
                    ),
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
              decoration: const BoxDecoration(
                color: AppColors.sun,
                shape: BoxShape.circle,
              ),
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
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
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
                        label: state.stats.currentStreak == 1
                            ? 'day streak'
                            : 'day streak',
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
              // The pill is 111dp wide on a 360dp phone. At a large text size
              // the number alone ate the label's room and pushed the row past
              // its edge, so it scales down rather than overflowing.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  // Three lines: at 1.3x text the label read "days to …", which
                  // removes the one piece of information the pill exists for.
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
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
    // IntrinsicHeight, not a bare Row: the row sits in a scrolling column, so
    // stretching its children without a height would hand them infinity.
    // With it, a label that wraps to two lines makes all three cards match.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
          // Two lines, not one: at 1.3x text "Downloads" and "Find a paper"
          // both ellipsised to nonsense ("Downloa…"), and these are the only
          // words naming the action.
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
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
    final readCount = state.entries
        .where((entry) => entry.progressPercent >= 100)
        .length;

    return AppCard(
      onTap: onOpenProgress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two flexible labels rather than a Spacer: at a large text size the
          // pair needs more than the card's 290dp and used to run over the edge.
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'This week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: Text(
                  '${formatMinutes(stats.weekMinutes)} / ${formatMinutes(stats.weeklyGoalMinutes)}',
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WeeklyBars(stats: stats),
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 10),
          // A wrap, not a spacer row: the card is only ~320 dp in the narrow
          // desktop column, and at a large text scale the two labels collided
          // and clipped instead of dropping to a second line.
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  // Flexible, because a Wrap child still gets the full line
                  // width: without it this label alone overflowed the card.
                  Flexible(
                    child: Text(
                      '$readCount ${readCount == 1 ? 'document' : 'documents'} finished',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${stats.todayMinutes} min today',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single line that surfaces the newest message and opens the inbox. It only
/// appears when there is something to read, so the home screen stays calm.
class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard({
    required this.latest,
    required this.count,
    required this.onOpen,
  });

  final AppNotification latest;
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1 ? '1 update' : '$count updates',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.75),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
