import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/models/classroom.dart';
import '../../data/models/profile.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final gutter = pageGutter(context);
    final classes = state.classes;
    // Staff can run a class even if their local profile says student: the
    // service is the authority on who may create one.
    final isTeacher = state.isStaff || state.profile.role == StudentRole.teacher;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                // A teacher is not looking at their teachers' classes.
                eyebrow: isTeacher ? 'Teaching' : 'Your teachers',
                title: 'Classes',
                subtitle: isTeacher
                    ? 'Reading you set, and the classes you run.'
                    : 'Reading set by your teachers.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _joinClass(context, state),
                    icon: const Icon(Icons.login_rounded, size: 17),
                    label: const Text('Join'),
                  ),
                  if (isTeacher) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _createClass(context, state),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Create'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              InfoBanner(
                message: isTeacher
                    ? 'Learners join with the six-character code under each class. '
                        'Codes work without email, which is what most schools need.'
                    : 'A class code is six characters and comes from your teacher. '
                        'Codes work without email, which is what most schools need.',
                icon: Icons.tag_rounded,
                actionLabel: isTeacher ? 'Create a class' : null,
                onAction: isTeacher ? () => _createClass(context, state) : null,
              ),
              const SizedBox(height: 20),
              if (classes.isEmpty)
                EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No classes yet',
                  message: isTeacher
                      ? 'Join with a code, or create a class and share its code with your learners.'
                      : 'Join with the six-character code your teacher gave you.',
                  actionLabel: isTeacher ? 'Create a class' : 'Join a class',
                  onAction: () => isTeacher
                      ? _createClass(context, state)
                      : _joinClass(context, state),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 2 : 1;
                    final cards = [
                      for (final group in classes)
                        _ClassCard(
                          group: group,
                          state: state,
                          isTeacher: isTeacher,
                          onTap: () => openClass(context, group.id),
                        ),
                    ];
                    if (columns == 1) {
                      return Column(
                        children: [
                          for (final card in cards) ...[
                            card,
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final card in cards)
                          SizedBox(width: (constraints.maxWidth - 14) / 2, child: card),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                'Classes are a delivery and reporting unit, not a chat room. '
                'Assignments point at a document in your library.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _joinClass(BuildContext context, AppState state) async {
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        // The controller belongs to the sheet: this method resumes while the
        // sheet is still animating out, and the field is still using it then.
        child: TextControllers(
          builder: (sheetContext, controllers) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => SheetBody(
            title: 'Join a class',
            subtitle: 'Enter the code your teacher shared.',
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
                    final result = await state.joinClass(controllers.first.text);
                    if (!result.success) {
                      setSheetState(() => error = result.message);
                      return;
                    }
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) showSnack(context, result.message);
                  },
                  child: const Text('Join class'),
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controllers.first,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Class code',
                    hintText: 'Six characters',
                    errorText: error,
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                  onChanged: (_) {
                    if (error != null) setSheetState(() => error = null);
                  },
                ),
                Text(
                  // The three demo codes this used to list no longer exist: the
                  // class and its code are created by a teacher now.
                  'Your teacher reads the code out in class. It is six characters '
                  'and works without an email address.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _createClass(BuildContext context, AppState state) async {
    if (state.profile.role != StudentRole.teacher) {
      showSnack(context, 'Only teachers can create classes.', error: true);
      return;
    }
    var form = state.profile.form;
    var subjectId = state.profile.subjectIds.isEmpty
        ? kSubjects.first.id
        : state.profile.subjectIds.first;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        // Same as the join sheet: the controller outlives this method's await.
        child: TextControllers(
          builder: (sheetContext, controllers) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => SheetBody(
            title: 'Create a class',
            subtitle: 'You will be able to set reading for everyone who joins.',
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
                    final name = controllers.first.text.trim();
                    if (name.length < 3) {
                      setSheetState(() => error = 'Give the class a name of at least 3 characters.');
                      return;
                    }
                    final ClassGroup group;
                    try {
                      group = await state.createClass(
                        name: name,
                        form: form,
                        subjectId: subjectId,
                      );
                    } on ApiException catch (failure) {
                      setSheetState(() => error = failure.message);
                      return;
                    }
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) {
                      showSnack(context, '${group.name} created · code ${group.code}');
                    }
                  },
                  child: const Text('Create class'),
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controllers.first,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Class name',
                    hintText: 'e.g. Form 3B — Physical Science',
                    errorText: error,
                    prefixIcon: const Icon(Icons.groups_outlined),
                  ),
                  onChanged: (_) {
                    if (error != null) setSheetState(() => error = null);
                  },
                ),
                const SizedBox(height: 16),
                Text('Subject', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in kSubjects)
                      ChoiceChip(
                        label: Text(subject.shortName),
                        selected: subjectId == subject.id,
                        onSelected: (_) => setSheetState(() {
                          subjectId = subject.id;
                          if (!subject.forms.contains(form)) form = subject.forms.first;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Form', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in <int>[1, 2, 3, 4])
                      ChoiceChip(
                        label: Text('Form $option'),
                        selected: form == option,
                        onSelected: (_) => setSheetState(() => form = option),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.group,
    required this.state,
    required this.onTap,
    this.isTeacher = false,
  });

  final ClassGroup group;
  final AppState state;
  final bool isTeacher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = subjectById(group.subjectId);
    final assignments = state.assignmentsForClass(group.id);
    final done = assignments.where((assignment) => assignment.completed).length;
    final percent = assignments.isEmpty ? 0.0 : done / assignments.length;
    final nextDue = assignments
        .where((assignment) => assignment.dueDate != null)
        .map((assignment) => assignment.dueDate!)
        .fold<DateTime?>(null, (soonest, due) => soonest == null || due.isBefore(soonest) ? due : soonest);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: subject.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(subject.emoji, style: const TextStyle(fontSize: 19)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      isTeacher
                          ? '${subject.name} · ${plural(group.memberCount, 'learner')}'
                          : '${group.teacherName} · ${plural(group.memberCount, 'learner')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.isMine)
                const Pill(label: 'You teach', color: AppColors.sun, compact: true)
              else
                Pill(label: group.qualification, color: subject.color, compact: true),
            ],
          ),
          const SizedBox(height: 14),
          if (isTeacher) ...[
            // A teacher has no reading progress of their own here; what they
            // need is what they set and when it is next due.
            Row(
              children: [
                Text(
                  '${plural(assignments.length, 'paper')} set',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  assignments.isEmpty
                      ? 'Nothing set yet'
                      : nextDue == null
                          ? 'No deadlines'
                          : 'Next due ${formatDate(nextDue)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Text(
                  plural(assignments.length, 'assignment'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  assignments.isEmpty ? 'No reading set' : '$done of ${assignments.length} done',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 4,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.tag_rounded, size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                group.code,
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                formatDate(group.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



