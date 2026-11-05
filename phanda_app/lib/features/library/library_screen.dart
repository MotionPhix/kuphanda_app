import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_card.dart';
import '../../data/library_query.dart';
import '../../data/models/document.dart';
import '../../data/models/subject.dart';
import '../documents/import_document.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  LibraryQuery _query = const LibraryQuery();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(LibraryQuery query) {
    setState(() {
      _query = query;
      if (_searchController.text != query.search) {
        _searchController.text = query.search;
      }
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<LibraryQuery>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LibraryFilterSheet(initial: _query),
    );
    if (result != null) _update(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final entries = _query.apply(state.entries);
    final theme = Theme.of(context);
    final isWide = screenSizeOf(context) != ScreenSize.compact;
    final gutter = pageGutter(context);

    final favoriteSubjects = <Subject>[];
    for (final subject in state.profile.subjects) {
      if (!favoriteSubjects.any((s) => s.id == subject.id)) {
        favoriteSubjects.add(subject);
      }
    }
    final quickSubjects = favoriteSubjects.take(5).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ResponsivePage(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  eyebrow: 'Forms 1–4',
                  title: 'Library',
                  subtitle:
                      '${plural(state.documents.length, 'document')} · '
                      '${state.offlineDocuments.length} on this device',
                  actions: [
                    // The only upload in the app: a paper of the learner's own,
                    // named in a form. Nothing is ever attached to our records.
                    IconButton(
                      onPressed: () => importDocumentFlow(context, state),
                      tooltip: 'Add your own paper',
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      onPressed: _openFilters,
                      tooltip: 'Filters',
                      icon: Badge(
                        isLabelVisible: _query.activeFilterCount > 0,
                        label: Text('${_query.activeFilterCount}'),
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => _update(_query.copyWith(search: value)),
                  decoration: InputDecoration(
                    hintText: 'Search papers, notes, subjects or years',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                _update(_query.copyWith(search: '')),
                          ),
                  ),
                ),
                if (state.showingBundledCatalogue && state.isSignedIn)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _BundledCatalogueNotice(
                      message: state.syncError,
                      onRetry: () => state.syncNow(silent: true),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _SubjectChip(
                        label: 'All subjects',
                        selected: _query.subjectIds.isEmpty,
                        onTap: () =>
                            _update(_query.copyWith(subjectIds: <String>{})),
                      ),
                      for (final subject in quickSubjects) ...[
                        const SizedBox(width: 8),
                        _SubjectChip(
                          label: subject.name,
                          emoji: subject.emoji,
                          selected:
                              _query.subjectIds.length == 1 &&
                              _query.subjectIds.contains(subject.id),
                          onTap: () => _update(
                            _query.copyWith(
                              subjectIds:
                                  _query.subjectIds.length == 1 &&
                                      _query.subjectIds.contains(subject.id)
                                  ? <String>{}
                                  : <String>{subject.id},
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _SubjectChip(
                        label: 'On device',
                        icon: Icons.offline_pin_outlined,
                        selected:
                            _query.availability == AvailabilityFilter.offline,
                        onTap: () => _update(
                          _query.copyWith(
                            availability:
                                _query.availability ==
                                    AvailabilityFilter.offline
                                ? AvailabilityFilter.all
                                : AvailabilityFilter.offline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Flexible pair, not a Spacer: at 1.3x text the count and
                    // the sort label together ran 98px past the row edge.
                    Expanded(
                      child: Text(
                        plural(entries.length, 'result'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<LibrarySort>(
                      initialValue: _query.sort,
                      tooltip: 'Sort',
                      onSelected: (sort) =>
                          _update(_query.copyWith(sort: sort)),
                      itemBuilder: (context) => [
                        for (final sort in LibrarySort.values)
                          PopupMenuItem(value: sort, child: Text(sort.label)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _query.sort.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_query.hasFilters) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (_query.search.isNotEmpty)
                          _ActiveFilter(
                            label: '“${_query.search}”',
                            onRemove: () =>
                                _update(_query.copyWith(search: '')),
                          ),
                        for (final form in _query.forms)
                          _ActiveFilter(
                            label: 'Form $form',
                            onRemove: () {
                              final next = Set<int>.from(_query.forms)
                                ..remove(form);
                              _update(_query.copyWith(forms: next));
                            },
                          ),
                        for (final id in _query.subjectIds)
                          _ActiveFilter(
                            label: subjectById(id).name,
                            onRemove: () {
                              final next = Set<String>.from(_query.subjectIds)
                                ..remove(id);
                              _update(_query.copyWith(subjectIds: next));
                            },
                          ),
                        for (final kind in _query.kinds)
                          _ActiveFilter(
                            label: kind.pluralLabel,
                            onRemove: () {
                              final next = Set<DocumentKind>.from(_query.kinds)
                                ..remove(kind);
                              _update(_query.copyWith(kinds: next));
                            },
                          ),
                        if (_query.availability != AvailabilityFilter.all)
                          _ActiveFilter(
                            label: _query.availability.label,
                            onRemove: () => _update(
                              _query.copyWith(
                                availability: AvailabilityFilter.all,
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: () => _update(_query.cleared()),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverToBoxAdapter(
            child: ResponsivePage(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 40),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Nothing matches',
                message: 'Try a different subject, form or search term.',
                actionLabel: 'Clear filters',
                onAction: () => _update(const LibraryQuery()),
              ),
            ),
          )
        else if (isWide)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 300,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = entries[index];
                return DocumentGridCard(
                  entry: entry,
                  onTap: () => openDocument(context, entry.document.id),
                );
              }, childCount: entries.length),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return DocumentTile(
                  entry: entry,
                  onTap: () => openDocument(context, entry.document.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
              ],
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.labelSmall,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
  }
}

class LibraryFilterSheet extends StatefulWidget {
  const LibraryFilterSheet({super.key, required this.initial});

  final LibraryQuery initial;

  @override
  State<LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends State<LibraryFilterSheet> {
  late LibraryQuery _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetBody(
      title: 'Filter the library',
      subtitle: 'Narrow by form, subject and document type.',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _draft = _draft.cleared()),
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _draft),
            child: const Text('Show results'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Availability', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in AvailabilityFilter.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: _draft.availability == option,
                  onSelected: (_) => setState(
                    () => _draft = _draft.copyWith(availability: option),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Access', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final option in AccessFilter.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: _draft.access == option,
                  onSelected: (_) =>
                      setState(() => _draft = _draft.copyWith(access: option)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Form', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final form in <int>[1, 2, 3, 4])
                FilterChip(
                  label: Text('Form $form'),
                  selected: _draft.forms.contains(form),
                  onSelected: (selected) {
                    final next = Set<int>.from(_draft.forms);
                    selected ? next.add(form) : next.remove(form);
                    setState(() => _draft = _draft.copyWith(forms: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Subject', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in kSubjects)
                FilterChip(
                  avatar: Text(
                    subject.emoji,
                    style: const TextStyle(fontSize: 12),
                  ),
                  label: Text(subject.shortName),
                  selected: _draft.subjectIds.contains(subject.id),
                  onSelected: (selected) {
                    final next = Set<String>.from(_draft.subjectIds);
                    selected ? next.add(subject.id) : next.remove(subject.id);
                    setState(() => _draft = _draft.copyWith(subjectIds: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Document type', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in DocumentKind.values)
                FilterChip(
                  label: Text(kind.pluralLabel),
                  selected: _draft.kinds.contains(kind),
                  onSelected: (selected) {
                    final next = Set<DocumentKind>.from(_draft.kinds);
                    selected ? next.add(kind) : next.remove(kind);
                    setState(() => _draft = _draft.copyWith(kinds: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Sort by', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          RadioGroup<LibrarySort>(
            groupValue: _draft.sort,
            onChanged: (value) {
              if (value != null) {
                setState(() => _draft = _draft.copyWith(sort: value));
              }
            },
            child: Column(
              children: [
                for (final sort in LibrarySort.values)
                  RadioListTile<LibrarySort>(
                    value: sort,
                    title: Text(sort.label),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the library on screen is the copy that shipped with the app
/// rather than the server's catalogue, which happens when a sync fails or has
/// not run yet. Without it a learner simply sees fewer papers and no reason.
class _BundledCatalogueNotice extends StatelessWidget {
  const _BundledCatalogueNotice({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? 'You are reading the copy saved on this phone. Reconnect to load the rest of the library.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
