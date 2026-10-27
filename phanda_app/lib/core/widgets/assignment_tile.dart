import 'package:flutter/material.dart';

import '../../data/models/classroom.dart';
import '../../data/models/document.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import 'common.dart';

class AssignmentTile extends StatelessWidget {
  const AssignmentTile({
    super.key,
    required this.assignment,
    required this.state,
    required this.onOpen,
    this.showClass = true,
    this.onToggleDone,
  });

  final Assignment assignment;
  final AppState state;
  final VoidCallback onOpen;
  final bool showClass;
  final VoidCallback? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = state.documentById(assignment.documentId);
    final classGroup = state.classById(assignment.classId);
    final status = assignmentStatus(assignment);
    final progress = document == null ? 0.0 : state.progressOrDefault(document).percent;

    final urgentColor = status.urgent ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (assignment.completed ? AppColors.green : theme.colorScheme.primary)
                  .withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              assignment.completed ? Icons.check_rounded : Icons.menu_book_outlined,
              size: 19,
              color: assignment.completed ? AppColors.green : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document?.title ?? 'Document removed',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.25),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (showClass && classGroup != null) classGroup.name,
                    if (assignment.note.isNotEmpty) assignment.note,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      status.urgent
                          ? Icons.schedule_rounded
                          : assignment.completed
                              ? Icons.check_circle_outline_rounded
                              : Icons.event_outlined,
                      size: 13,
                      color: assignment.completed ? AppColors.green : urgentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: assignment.completed ? AppColors.green : urgentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                    if (progress > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 3,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${progress.round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onToggleDone != null)
            IconButton(
              onPressed: onToggleDone,
              tooltip: assignment.completed ? 'Mark as not done' : 'Mark as done',
              icon: Icon(
                assignment.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: assignment.completed ? AppColors.green : theme.colorScheme.outline,
              ),
            )
          else if (document != null)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 8),
              child: Icon(Icons.chevron_right_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

/// A paper's cover and metadata used by the document picker.
class DocumentPickerTile extends StatelessWidget {
  const DocumentPickerTile({
    super.key,
    required this.document,
    required this.selected,
    required this.onTap,
  });

  final Document document;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.description_outlined,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${document.qualification} · ${document.kind.label} · ${formatDate(document.addedAt)}'),
    );
  }
}
