import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
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
                            if (confirmed) await state.deleteAssignment(assignment.id);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Remove assignment'),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 10),
                Text(
                  'Progress is measured from pages actually read, not from a tick box. '
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
  final _noteController = TextEditingController();
  Document? _selected;
  late DateTime _dueDate = DateTime.now().add(const Duration(days: 3));

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetBody(
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
                      await widget.state.addAssignment(
                        classId: widget.group.id,
                        documentId: picked.id,
                        dueDate: _dueDate,
                        note: _noteController.text,
                      );
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
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Instructions for the class (optional)',
              ),
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
      ),
    );
  }
}
