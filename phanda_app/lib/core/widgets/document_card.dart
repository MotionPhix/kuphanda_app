import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../../data/models/subject.dart';
import '../theme.dart';
import 'common.dart';

/// A generated book cover. Documents rarely have cover art in this market, and
/// a broken image is worse than a deliberate typographic cover, so the app
/// builds one from the subject colour and document kind.
class DocumentCover extends StatelessWidget {
  const DocumentCover({
    super.key,
    required this.document,
    required this.subject,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.showKind = true,
  });

  final Document document;
  final Subject subject;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = subject.color;
    final dark = Color.lerp(base, Colors.black, 0.32)!;
    final view = document.guideId != null ? 'GUIDE' : document.kind.label.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, dark],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -18,
              top: -22,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              left: -24,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        subject.emoji,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'F${document.form}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    document.kind.icon,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  if (showKind)
                    Text(
                      view,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.showProgress = true,
    this.trailing,
    this.dense = false,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;
  final bool showProgress;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = entry.document;

    final meta = <String>[
      entry.subject.name,
      document.kind == DocumentKind.pastPaper ? document.examLabel : document.kind.label,
    ].join('  Â·  ');

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          padding: EdgeInsets.all(dense ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DocumentCover(
                document: document,
                subject: entry.subject,
                width: dense ? 46 : 54,
                height: dense ? 62 : 74,
                borderRadius: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: dense ? 13.5 : 14.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (entry.locked)
                          const Pill(
                            label: 'Library pass',
                            icon: Icons.lock_outline_rounded,
                            color: AppColors.red,
                            compact: true,
                          )
                        else if (entry.onDevice)
                          Pill(
                            label: entry.asset?.isBundled ?? false ? 'Included' : 'Offline',
                            icon: Icons.offline_pin_outlined,
                            color: AppColors.green,
                            compact: true,
                          )
                        else if (document.guideId != null)
                          const Pill(
                            label: 'Readable',
                            icon: Icons.auto_stories_outlined,
                            color: AppColors.green,
                            compact: true,
                          )
                        else
                          Pill(
                            label: 'Add PDF',
                            icon: Icons.attach_file_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            compact: true,
                          ),
                        if (document.year != null && document.kind != DocumentKind.pastPaper)
                          Pill(label: '${document.year}', compact: true),
                        if (document.paperNumber != null)
                          Pill(label: 'Paper ${document.paperNumber}', compact: true),
                      ],
                    ),
                    if (showProgress && entry.progressPercent > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.progressPercent / 100,
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${entry.progressPercent.round()}% read',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ] else if (entry.saved) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.bookmark_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentGridCard extends StatelessWidget {
  const DocumentGridCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = entry.document;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: DocumentCover(
                        document: document,
                        subject: entry.subject,
                        width: height * 0.72,
                        height: height,
                        borderRadius: 8,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                document.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                '${entry.subject.shortName} Â· ${document.examLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 13, color: AppColors.sun),
                  const SizedBox(width: 3),
                  Text(
                    document.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10.5),
                  ),
                  const SizedBox(width: 8),
                  if (entry.locked)
                    const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.red)
                  else if (entry.onDevice)
                    const Icon(Icons.offline_pin_outlined, size: 13, color: AppColors.green),
                  const Spacer(),
                  if (entry.progressPercent > 0)
                    Text(
                      '${entry.progressPercent.round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10.5,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact vertical card used in horizontal carousels on the home screen.
class DocumentStripCard extends StatelessWidget {
  const DocumentStripCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.width = 138,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = entry.document;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DocumentCover(
                      document: document,
                      subject: entry.subject,
                      borderRadius: 10,
                    ),
                    if (entry.locked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                document.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                '${entry.subject.shortName} · ${document.examLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              if (entry.progressPercent > 0) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: entry.progressPercent / 100,
                    minHeight: 3,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
