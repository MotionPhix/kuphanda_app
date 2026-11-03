import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/api/api_models.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/assignment_tile.dart';
import '../../core/widgets/common.dart';
import '../../data/models/classroom.dart';
import '../../data/models/document.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final group = state.classById(classId);
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This class is no longer in your list.')),
      );
    }

    final theme = Theme.of(context);
    final subject = subjectById(group.subjectId);
    final assignments = state.assignmentsForClass(classId);
    final done = assignments.where((assignment) => assignment.completed).length;
    final readingProgress = assignments.isEmpty
        ? 0.0
        : assignments
                .map((assignment) => state.documentById(assignment.documentId))
                .whereType<Document>()
                .map((document) => state.progressOrDefault(document).percent)
                .fold<double>(0, (sum, value) => sum + value) /
            assignments.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          if (group.isMine)
            IconButton(
              tooltip: 'Set reading',
              onPressed: () => _addAssignment(context, state, group),
              icon: const Icon(Icons.add_task_rounded),
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
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [subject.color, Color.lerp(subject.color, Colors.black, 0.3)!],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(subject.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${subject.name} · Form ${group.form} · ${group.qualification}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        group.teacherName,
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      Text(
                        plural(group.memberCount, 'learner'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _HeaderMetric(
                              value: '${assignments.length}',
                              label: 'assignments',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeaderMetric(
                              value: '$done',
                              label: 'completed',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeaderMetric(
                              value: '${readingProgress.round()}%',
                              label: 'average read',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.tag_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Class code', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 10),
                      Text(
                        group.code,
                        style: theme.textTheme.titleSmall?.copyWith(letterSpacing: 2),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: group.code));
                          if (context.mounted) showSnack(context, 'Class code copied.');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text('Reading set', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '$done/${assignments.length} done',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (assignments.isEmpty)
                  EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No reading yet',
                    message: group.isMine
                        ? 'Set a document for the class to read, with a due date.'
                        : 'Your teacher has not set any reading for this class.',
                    actionLabel: group.isMine ? 'Set reading' : null,
                    onAction: group.isMine ? () => _addAssignment(context, state, group) : null,
                  )
                else
                  for (final assignment in assignments) ...[
                    AssignmentTile(
                      assignment: assignment,
                      state: state,
                      showClass: false,
                      onOpen: () => openDocument(context, assignment.documentId),
                      onToggleDone: () => state.toggleAssignmentDone(assignment.id),
                    ),
                    if (group.isMine)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final confirmed = await confirmAction(
                              context,
                              title: 'Remove this assignment?',
                              message: 'The document stays in the library for everyone.',
                              confirmLabel: 'Remove',
                            );
                            if (!confirmed) return;
                            final removed = await state.deleteAssignment(assignment.id);
                            if (!removed && context.mounted) {
                              showSnack(
                                context,
                                'Could not remove it from the class. Check the connection and try again.',
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Remove assignment'),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                if (group.isMine) ...[
                  const SizedBox(height: 20),
                  _ClassReportSection(classroomId: group.id, memberCount: group.memberCount),
                ],
                const SizedBox(height: 10),
                Text(
                  group.isMine
                      ? 'A learner counts as finished once they pass 90% of a paper. '
                          'The report above is the class record, not this phone’s.'
                      : 'Progress is measured from pages actually read, not from a tick box. '
                          'A document counts towards an assignment once you pass 90%.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAssignment(BuildContext context, AppState state, ClassGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAssignmentSheet(state: state, group: group),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAssignmentSheet extends StatefulWidget {
  const _AddAssignmentSheet({required this.state, required this.group});

  final AppState state;
  final ClassGroup group;

  @override
  State<_AddAssignmentSheet> createState() => _AddAssignmentSheetState();
}

class _AddAssignmentSheetState extends State<_AddAssignmentSheet> {
  final _searchController = TextEditingController();
  Document? _selected;
  late DateTime _dueDate = DateTime.now().add(const Duration(days: 3));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.toLowerCase();
    final documents = widget.state.entries
        .where((entry) => query.isEmpty || entry.document.title.toLowerCase().contains(query))
        .take(30)
        .toList();

    return SheetBody(
        title: 'Set reading',
        subtitle: '${widget.group.name} · due ${formatDate(_dueDate)}',
        maxHeightFactor: 0.9,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _selected == null
                  ? null
                  : () async {
                      final picked = _selected!;
                      try {
                        await widget.state.assignPaper(
                          classroomId: widget.group.id,
                          documentId: picked.id,
                          dueDate: _dueDate,
                        );
                      } catch (error) {
                        if (context.mounted) {
                          showSnack(context, 'Could not set reading: $error', error: true);
                        }
                        return;
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        showSnack(context, 'Reading set: ${picked.title}');
                      }
                    },
              child: const Text('Set assignment'),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('Due ${formatDate(_dueDate)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Choose a document', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search the library',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: documents.isEmpty
                  ? const Center(child: Text('No matching documents'))
                  : ListView.builder(
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final document = documents[index].document;
                        return DocumentPickerTile(
                          document: document,
                          selected: _selected?.id == document.id,
                          onTap: () => setState(() => _selected = document),
                        );
                      },
                    ),
            ),
          ],
      ),
    );
  }
}

/// How many learners are past a paper's deadline without having read it.
///
/// A deadline is a day, not a moment: the whole of the due date still counts as
/// on time.
int lateCountFor(ClassReport report, ReportedAssignment assignment) {
  final due = assignment.dueDate;
  if (due == null) return 0;

  final endOfDueDay = DateTime(due.year, due.month, due.day, 23, 59, 59);
  if (endOfDueDay.isAfter(DateTime.now())) return 0;

  return report.learners.where((learner) => !learner.hasFinished(assignment.id)).length;
}
/// The teacher's side of a class: what was set, and who has finished it.
///
/// The list above this is the class's reading, counted from this phone. This
/// section is the room's answer, fetched from the server, so a teacher opening
/// the app on a laptop sees the same figures as on their phone.
class _ClassReportSection extends StatefulWidget {
  const _ClassReportSection({required this.classroomId, required this.memberCount});

  final String classroomId;
  final int memberCount;

  @override
  State<_ClassReportSection> createState() => _ClassReportSectionState();
}

class _ClassReportSectionState extends State<_ClassReportSection> {
  bool _loading = true;

  /// Learners whose papers are expanded beneath their row.
  final Set<int> _open = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// The detail behind a learner's count: every paper the class was set, and
  /// whether this learner has read it. Inline, so it works the same on a phone
  /// and on a desktop window and needs no second surface.
  Widget _learnerPapers(ThemeData theme, ClassReport report, ReportedLearner learner) {
    if (report.assignments.isEmpty) {
      return Text(
        'Nothing has been set for this class yet.',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final assignment in report.assignments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  learner.hasFinished(assignment.id)
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: learner.hasFinished(assignment.id)
                      ? AppColors.green
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${assignment.title ?? 'A paper in the library'}'
                    '${learner.hasFinished(assignment.id) ? ' · read' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: learner.hasFinished(assignment.id)
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  /// Reminds the learners still to read this paper, and says how many it reached
  /// rather than leaving the teacher to guess.
  Future<void> _remind(ReportedAssignment assignment) async {
    final state = AppScope.read(context);
    final sent = await state.remindUnfinished(widget.classroomId, assignment.id);
    if (!mounted) return;

    if (sent == null) {
      showSnack(context, 'Could not send the reminder. Check the connection and try again.');
      return;
    }
    if (sent == 0) {
      showSnack(context, 'Everyone has already read this one.');
      return;
    }
    showSnack(context, sent == 1 ? 'Reminded one learner.' : 'Reminded $sent learners.');
  }

  Future<void> _load() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    await state.loadClassReport(widget.classroomId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = AppScope.of(context).classReportFor(widget.classroomId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Who has read it', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (report == null)
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _loading
                        ? 'Loading the class record…'
                        : 'The class record is not available offline. It appears once a '
                            'learner finishes a paper and this phone reaches the server.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!_loading)
                  TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          )
        else ...[
          if (report.assignments.isEmpty)
            AppCard(
              child: Text(
                'Nothing set yet, so there is nothing to report.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final assignment in report.assignments) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assignment.title ?? 'A paper in the library',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${assignment.completedCount} of ${report.learnerCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lateCountFor(report, assignment) > 0) ...[
                          const SizedBox(width: 8),
                          // Past its deadline with people still to read it: the
                          // number a teacher acts on first.
                          Text(
                            '${lateCountFor(report, assignment)} late',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: report.learnerCount == 0
                            ? 0
                            : assignment.completedCount / report.learnerCount,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    if (report.learnerCount - assignment.completedCount > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          // Chases only the people still to read it.
                          onPressed: () => _remind(assignment),
                          icon: const Icon(Icons.notifications_active_outlined, size: 15),
                          label: Text(
                            'Remind ${report.learnerCount - assignment.completedCount}',
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          if (report.learners.isEmpty)
            Text(
              'No learners have joined yet. Read the code out and they appear here.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            const SizedBox(height: 6),
            Text('Learners', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final learner in report.learners) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() {
                    if (!_open.remove(learner.id)) _open.add(learner.id);
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            learner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          report.assignmentCount == 0
                              ? '—'
                              : '${learner.completedAssignmentIds.length} of ${report.assignmentCount} read',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _open.contains(learner.id)
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_open.contains(learner.id))
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                  child: _learnerPapers(theme, report, learner),
                ),
            ],
          ],
        ],
      ],
    );
  }
}




