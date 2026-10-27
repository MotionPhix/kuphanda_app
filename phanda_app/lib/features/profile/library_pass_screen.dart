import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/navigation.dart';
import '../../core/widgets/document_card.dart';
import '../../data/models/profile.dart';

/// Explains entitlement without pretending to take a payment.
///
/// Kuphanda sold day/week/month passes through PayChangu and Geli reused the
/// same tiers. On a school device the realistic entitlement is a school licence,
/// so that is the default and the individual passes are informational until a
/// payment route exists in the mobile build.
class LibraryPassScreen extends StatelessWidget {
  const LibraryPassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final plan = state.profile.plan;
    final locked = state.entries.where((entry) => entry.locked).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Library pass')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePage(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.greenDeep, AppColors.green],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.sun, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ACTIVE PASS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        plan.label,
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan == LibraryPlan.school
                            ? 'Full catalogue, provided by your school. No expiry while you are enrolled.'
                            : 'Free tier: core papers and guides. Some recent marking schemes are locked.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _Metric(
                            value: '${state.documents.length - locked.length}',
                            label: 'available',
                          ),
                          const SizedBox(width: 10),
                          _Metric(value: '${locked.length}', label: 'locked'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Change plan', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RadioGroup<LibraryPlan>(
                        groupValue: plan,
                        onChanged: (value) async {
                          if (value == null) return;
                          await state.setPlan(value);
                          if (context.mounted) {
                            showSnack(context, '${value.label} selected.');
                          }
                        },
                        child: Column(
                          children: [
                            for (final option in LibraryPlan.values) ...[
                              RadioListTile<LibraryPlan>(
                                value: option,
                                title: Text(option.label),
                                subtitle: Text(option.description),
                                secondary: Icon(
                                  option == LibraryPlan.school
                                      ? Icons.school_outlined
                                      : Icons.lock_open_rounded,
                                ),
                              ),
                              if (option != LibraryPlan.values.last)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Switching to the free tier is a preview of what a learner without a school '
                  'licence sees. Nothing is charged and no data is lost.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (locked.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('Currently locked', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final entry in locked.take(4)) ...[
                    DocumentTile(
                      entry: entry,
                      dense: true,
                      onTap: () => openDocument(context, entry.document.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 22),
                Text('Individual passes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PassRow(name: 'Day pass', price: 'MWK 500', detail: '24 hours'),
                      const Divider(height: 20),
                      const _PassRow(name: 'Weekly pass', price: 'MWK 1,500', detail: '7 days'),
                      const Divider(height: 20),
                      const _PassRow(name: 'Monthly', price: 'MWK 4,500', detail: '30 days'),
                      const SizedBox(height: 12),
                      Text(
                        'Individual mobile-money passes are not enabled in this offline build. '
                        'Schools buy a seat-based licence and every enrolled learner is covered.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                InfoBanner(
                  icon: Icons.school_outlined,
                  title: 'How a school licence works',
                  message: 'The licence belongs to the school, the account belongs to the learner. '
                      'If a learner moves school, their reading history moves with them.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassRow extends StatelessWidget {
  const _PassRow({required this.name, required this.price, required this.detail});

  final String name;
  final String price;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                detail,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(price, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
