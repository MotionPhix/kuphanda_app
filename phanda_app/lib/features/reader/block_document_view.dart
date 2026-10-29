import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/block_document.dart';

/// Renders a reflowable document on any screen width.
///
/// Every block is laid out with the reader's own typography instead of a fixed
/// page image, so a Form 1 learner on a 5-inch phone and a teacher on a tablet
/// read the same content without pinching. Blocks the build does not recognise
/// degrade to a "view original page" note rather than breaking the document.
class BlockDocumentView extends StatelessWidget {
  const BlockDocumentView({
    super.key,
    required this.document,
    this.showAnswers = false,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 40),
  });

  final BlockDocument document;
  final bool showAnswers;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: padding,
      children: [
        Text(
          document.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (document.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            document.subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        for (final block in document.blocks) _BlockView(
          block: block,
          showAnswers: showAnswers,
        ),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.showAnswers});

  final DocumentBlock block;
  final bool showAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (block.type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            block.text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );

      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SelectableText(
            block.text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
        );

      case 'bullets':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in block.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case 'callout':
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  block.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'figure':
        return _FigureBlock(block: block);

      case 'table':
        return _TableBlock(block: block);

      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1),
        );

      case 'question':
        return _QuestionBlock(block: block, showAnswer: showAnswers);

      case 'answer':
        return _AnswerBlock(steps: block.items);

      default:
        // Unknown block from a newer schema: keep the reader usable.
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  block.page == null
                      ? 'This part needs a newer version of the app.'
                      : 'Open the original page ${block.page} to read this part.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _QuestionBlock extends StatelessWidget {
  const _QuestionBlock({required this.block, required this.showAnswer});

  final DocumentBlock block;
  final bool showAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marks = block.marks;
    final answer = block.items;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (block.label != null)
                Text(
                  block.label!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Spacer(),
              if (marks != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$marks mark${marks == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            block.text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          // A question and its diagram are one unit: the figure sits under the
          // stem instead of being a separate block the author must keep in
          // order.
          if (block.raw['figure'] is Map)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _EmbeddedFigure(
                data: (block.raw['figure'] as Map).cast<String, Object?>(),
              ),
            ),
          for (final part in block.parts) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    part.label ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    part.text,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ],
          if (showAnswer && answer.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AnswerBlock(steps: answer),
          ],
        ],
      ),
    );
  }
}

class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Marking guide',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                step,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
        ],
      ),
    );
  }
}

/// The diagram belonging to a question. Missing assets degrade to a labelled
/// placeholder rather than an empty space, so a half-imported paper still reads.
class _EmbeddedFigure extends StatelessWidget {
  const _EmbeddedFigure({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = data['asset'] as String?;
    final caption = (data['alt'] ?? data['caption']) as String?;

    if (asset == null || asset.isEmpty) {
      return _FigurePlaceholder(label: caption ?? 'Figure not included');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Colors.white,
            child: _FigureAsset(
              asset: asset,
              caption: caption,
            ),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _FigureBlock extends StatelessWidget {
  const _FigureBlock({required this.block});

  final DocumentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final figure = block.figure;
    final caption = block.text.isNotEmpty
        ? block.text
        : (figure['alt'] as String? ?? '');
    final asset = figure['asset'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: asset == null
                ? _FigurePlaceholder(label: caption)
                : Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _FigurePlaceholder(label: caption),
                  ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FigurePlaceholder extends StatelessWidget {
  const _FigurePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 160,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            label.isEmpty ? 'Diagram' : label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock({required this.block});

  final DocumentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = block.rows;

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Table(
        border: TableBorder.all(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(color: theme.colorScheme.surfaceContainerHigh)
                  : null,
              children: [
                for (final cell in rows[r])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      cell,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            r == 0 ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Draws a diagram from either a vector or a raster asset.
///
/// SVG is the preferred form: geometry stays sharp at any density and takes the
/// theme's colours, where a scan is pinned to the pixels it was cropped from.
class _FigureAsset extends StatelessWidget {
  const _FigureAsset({required this.asset, this.caption});

  final String asset;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final isVector = asset.toLowerCase().endsWith('.svg');

    if (isVector) {
      // SvgPicture needs a finite width: with double.infinity inside a Column
      // the height resolves to infinity and the figure paints as a blank block
      // that pushes the rest of the paper off screen.
      // Both dimensions are bounded: given an unbounded width the picture
      // resolves to an unbounded height and paints as a blank block that pushes
      // the rest of the paper off screen.
      return SizedBox(
        width: double.infinity,
        height: 220,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          placeholderBuilder: (_) =>
              _FigurePlaceholder(label: caption ?? 'Figure loading'),
        ),
      );
    }

    return Image.asset(
      asset,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (_, _, _) =>
          _FigurePlaceholder(label: caption ?? 'Figure not available'),
    );
  }
}
