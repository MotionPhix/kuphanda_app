import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/document.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';

/// Adds a paper the learner already has on the phone.
///
/// This is the only upload path in the app, and it creates a *new* document —
/// it never attaches a file to a catalogue record. Kuphanda's own papers are
/// published as document object blocks and carry no PDF, so there is nothing
/// for a learner to match a local file against; a paper of their own needs its
/// own name, subject, form and type before it can appear in the library.
Future<Document?> importDocumentFlow(
  BuildContext context,
  AppState state,
) async {
  try {
    final picked = await state.pickPdf();
    if (picked == null || !context.mounted) return null;

    // The field is read before the sheet closes, so the controller can live
    // inside the sheet and die with it rather than being disposed here while
    // the sheet is still animating away.
    var title = titleFromFile(picked.fileName);
    var subjectId = state.profile.subjectIds.isEmpty
        ? kSubjects.first.id
        : state.profile.subjectIds.first;
    var form = state.profile.form;
    var kind = DocumentKind.notes;
    var titleMissing = false;

    final shouldImport = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => TextControllers(
        initialTexts: [title],
        builder: (sheetContext, controllers) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SheetBody(
          title: 'Name your paper',
          subtitle: '${picked.fileName} · ${formatBytes(picked.sizeBytes)}',
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (controllers.first.text.trim().isEmpty) {
                    setSheetState(() => titleMissing = true);
                    return;
                  }
                  // Taken now, while the field still exists.
                  title = controllers.first.text.trim();
                  Navigator.pop(sheetContext, true);
                },
                child: const Text('Add to library'),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controllers.first,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (titleMissing) setSheetState(() => titleMissing = false);
                },
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Biology mock 2024 — Paper 2',
                  errorText: titleMissing ? 'Give the paper a name.' : null,
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
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
                        if (!subject.forms.contains(form) && subject.forms.isNotEmpty) {
                          form = subject.forms.first;
                        }
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
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in DocumentKind.values)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: kind == option,
                      onSelected: (_) => setSheetState(() => kind = option),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'The file is copied into Kuphanda’s private folder and stays on this phone. '
                'Removing it later does not touch your original.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        ),
      ),
    );

    if (shouldImport != true) {
      return null;
    }

    final document = await state.importPdf(
      picked: picked,
      title: title,
      subjectId: subjectId,
      form: form,
      kind: kind,
    );

    if (context.mounted) {
      showSnack(context, '“${document.title}” is on this phone.');
    }
    return document;
  } on FormatException catch (error) {
    if (context.mounted) showSnack(context, error.message, error: true);
  } catch (error) {
    if (context.mounted) showSnack(context, 'Could not add the file: $error', error: true);
  }
  return null;
}

/// A file name is a poor title but a good starting point: `bio_mock_2024.pdf`
/// becomes `Bio Mock 2024`, which the learner can correct in the form.
String titleFromFile(String fileName) {
  final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  final cleaned = base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (cleaned.isEmpty) return 'My paper';
  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}


