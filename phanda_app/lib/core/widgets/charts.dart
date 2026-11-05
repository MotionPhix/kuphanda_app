import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';

/// A small, dependency-free weekly bar chart. Seven bars, a goal line, and
/// today highlighted — enough to answer "am I keeping up?" at a glance.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.stats, this.height = 112});

  final StudyStats stats;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = math.max(
      stats.weeklyGoalMinutes == 0 ? 30 : (stats.weeklyGoalMinutes / 7).ceil(),
      stats.weekDays.fold<int>(0, (max, day) => math.max(max, day.minutes)),
    );
    final scaleMax = math.max(peak, 30);

    // The bars are a fixed height, so a 2.0x label does not make room for
    // itself — it overflows the card. Chrome inside the chart is clamped; the
    // numbers it shows are repeated in the text above it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barSpace = constraints.maxWidth / 7;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      26 +
                      (height - 40) *
                          (1 -
                              (stats.weeklyGoalMinutes / 7 / scaleMax).clamp(
                                0,
                                1,
                              )),
                  child: Container(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in stats.weekDays)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: barSpace * 0.12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                day.minutes == 0 ? '' : '${day.minutes}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height:
                                    ((height - 44) * (day.minutes / scaleMax))
                                        .clamp(3, height - 44),
                                decoration: BoxDecoration(
                                  color: day.isToday
                                      ? theme.colorScheme.primary
                                      : day.minutes > 0
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.32,
                                        )
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                day.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: day.isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: day.isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // With no minutes at all every bar collapses to a 3 dp stub, so
                // the plot area reads as a blank box. Say why instead of leaving
                // a hole in the page.
                if (stats.weekMinutes == 0)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: (height - 34) / 2 - 8,
                    child: Text(
                      'No study time recorded this week',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.percent,
    required this.label,
    required this.caption,
    this.size = 92,
  });

  final double percent;
  final String label;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 1),
              strokeWidth: 7,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text(
                caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
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

class SubjectProgressBar extends StatelessWidget {
  const SubjectProgressBar({
    super.key,
    required this.label,
    required this.percent,
    required this.detail,
    required this.color,
  });

  final String label;
  final double percent;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                detail,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.green.withValues(alpha: 0.1),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
