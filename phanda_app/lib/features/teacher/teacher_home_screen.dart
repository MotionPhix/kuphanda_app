import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/models/classroom.dart';

/// What a teacher opens the app to.
///
/// The learner home is built around the next paper to read; a teacher is not
/// reading for themselves, they are running classes. Same app, different job —
/// so this screen leads with the rooms they run and the reading they set, and
/// its destination list stops after those.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key, required this.onNavigate});

  /// Index into the teacher shell: 0 home, 1 classes, 2 library, 3 files.
  final ValueChanged<int> onNavigate;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  /// The numbers on this page are the class record, which lives on the server.
  /// They are fetched once when the page opens, then kept for the session.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      state.loadClassReports([for (final group in state.classes) group.id]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onNavigate = widget.onNavigate;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final gutter = pageGutter(context);

    final classes = state.classes;
    final learners = classes.fold<int>(0, (sum, group) => sum + group.memberCount);
    final setPapers = classes.fold<int>(
      0,
      (sum, group) => sum + state.assignmentsForClass(group.id).length,
    );

    // What the class has actually finished, when the reports are in.
    final reports = [
      for (final group in classes) state.classReportFor(group.id),
    ].whereType<ClassReport>().toList();
    final readPapers = reports.fold<int>(
      0,
      (sum, report) =>
          sum + report.assignments.fold<int>(0, (papers, item) => papers + item.completedCount),
    );
    final possiblePapers = reports.fold<int>(
      0,
      (sum, report) => sum + report.assignmentCount * report.learnerCount,
    );
    final readPercent = possiblePapers == 0 ? null : (readPapers / possiblePapers * 100).round();

    final recent = <(ClassGroup, Assignment)>[
      for (final group in classes)
        for (final assignment in state.assignmentsForClass(group.id)) (group, assignment),
    ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));

    final firstName = state.profile.givenName.trim().isNotEmpty
        ? state.profile.givenName.trim()
        : 'teacher';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                eyebrow: 'Teaching',
                title: '${greeting(DateTime.now())}, $firstName',
                subtitle: state.profile.school.trim().isNotEmpty
                    ? '${state.profile.school.trim()} · ${plural(classes.length, 'class', 'classes')}'
                    : 'Your classes, and the reading you set.',
                actions: [
                  FilledButton.icon(
                    onPressed: () => onNavigate(1),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Create a class'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Four tiles need the width; three of them are counts the phone
                  // already knows, the fourth is the class record.
                  final columns = constraints.maxWidth >= 1080 ? 4 : 2;
                  final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
                  final tiles = <Widget>[
                    StatTile(
                      label: 'Classes',
                      value: '${classes.length}',
                      caption: classes.length == 1 ? 'you run one room' : 'rooms you run',
                      icon: Icons.groups_outlined,
                    ),
                    StatTile(
                      label: 'Learners',
                      value: '$learners',
                      caption: 'in your classes',
                      icon: Icons.people_alt_outlined,
                      tint: AppColors.green,
                    ),
                    StatTile(
                      label: 'Papers set',
                      value: '$setPapers',
                      caption: 'reading assignments',
                      icon: Icons.menu_book_outlined,
                    ),
                    StatTile(
                      label: 'Read',
                      value: readPercent == null ? '—' : '$readPercent%',
                      caption: readPercent == null
                          ? 'awaiting the class record'
                          : 'of the reading set',
                      icon: Icons.fact_check_outlined,
                      tint: AppColors.green,
                    ),
                  ];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final tile in tiles)
                        SizedBox(width: width, child: tile),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Your classes',
                actionLabel: classes.isEmpty ? null : 'All classes',
                onAction: classes.isEmpty ? null : () => onNavigate(1),
              ),
              const SizedBox(height: 10),
              if (classes.isEmpty)
                EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No classes yet',
                  message:
                      'Create a class, read its six-character code out to the room, and set the '
                      'papers you want read. Codes work without email.',
                  actionLabel: 'Go to Classes',
                  onAction: () => onNavigate(1),
                )
              else
                for (final group in classes.take(3)) ...[
                  _ClassRow(
                    group: group,
                    papers: state.assignmentsForClass(group.id).length,
                    read: state
                        .classReportFor(group.id)
                        ?.assignments
                        .fold<int>(0, (sum, item) => sum + item.completedCount),
                    onTap: () => openClass(context, group.id),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 14),
              SectionHeader(
                title: 'Recently set',
                subtitle: 'The latest reading across your classes',
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                AppCard(
                  child: Text(
                    'Nothing set yet. Open a class to point it at a paper in the library.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final (group, assignment) in recent.take(4)) ...[
                  AppCard(
                    onTap: () => openClass(context, group.id),
                    child: Row(
                      children: [
                        Icon(Icons.assignment_outlined, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.documentById(assignment.documentId)?.title ??
                                    'A paper in the library',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                assignment.dueDate == null
                                    ? '${group.name} · no deadline'
                                    : '${group.name} · due ${dueRelative(assignment.dueDate!)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.group,
    required this.papers,
    required this.onTap,
    this.read,
  });

  final ClassGroup group;
  final int papers;

  /// How many papers the class has finished, once the report is in. Null while
  /// it is still loading, or when this phone cannot reach the record.
  final int? read;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.groups_rounded, size: 19, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                   [
                     '${plural(group.memberCount, 'learner')} · ${plural(papers, 'paper')} set',
                     if (read != null) '$read read',
                   ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Pill(label: group.code, compact: true),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}





