import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/classroom.dart';
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                eyebrow: 'Your teachers',
                title: 'Classes',
                subtitle: 'Reading set by your teachers, and the classes you run.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _joinClass(context, state),
                    icon: const Icon(Icons.login_rounded, size: 17),
                    label: const Text('Join'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InfoBanner(
                message: 'A class code is six characters, like KPH4A2. Codes work without '
                    'email, which is what most schools need.',
                icon: Icons.tag_rounded,
                actionLabel: 'Create a class',
                onAction: () => _createClass(context, state),
              ),
              const SizedBox(height: 20),
              if (classes.isEmpty)
                EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No classes yet',
                  message: 'Join with the code your teacher gave you, or create a class if you '
                      'teach one.',
                  actionLabel: 'Join a class',
                  onAction: () => _joinClass(context, state),
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
    final controller = TextEditingController();
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: StatefulBuilder(
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
                    final result = await state.joinClass(controller.text);
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
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Class code',
                    hintText: 'KPH4A2',
                    errorText: error,
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                  onChanged: (_) {
                    if (error != null) setSheetState(() => error = null);
                  },
                ),
                Text(
                  'Demo codes you can try: KPH4A2 (Form 4 sciences), KPH4M8 '
                  '(Form 4 mathematics), KPH2B7 (Form 2 mathematics).',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _createClass(BuildContext context, AppState state) async {
    final nameController = TextEditingController();
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
        child: StatefulBuilder(
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
                    final name = nameController.text.trim();
                    if (name.length < 3) {
                      setSheetState(() => error = 'Give the class a name of at least 3 characters.');
                      return;
                    }
                    final group = await state.createClass(
                      name: name,
                      form: form,
                      subjectId: subjectId,
                      teacherName: state.profile.name,
                    );
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
                  controller: nameController,
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
    );
    nameController.dispose();
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.group, required this.state, required this.onTap});

  final ClassGroup group;
  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = subjectById(group.subjectId);
    final assignments = state.assignmentsForClass(group.id);
    final done = assignments.where((assignment) => assignment.completed).length;
    final percent = assignments.isEmpty ? 0.0 : done / assignments.length;

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
                      '${group.teacherName} · ${group.memberCount} learners',
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
