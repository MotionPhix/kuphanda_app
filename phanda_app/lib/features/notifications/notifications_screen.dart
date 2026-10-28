import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';

/// In-app inbox for library and class messages.
///
/// Push is best effort: a phone may be off, a learner may deny notifications,
/// or FCM may drop a message. Everything that was addressed to this account is
/// listed here so nothing is lost.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: RefreshIndicator(
        onRefresh: state.loadNotifications,
        child: ResponsivePage(
          padding: EdgeInsets.fromLTRB(
            pageGutter(context),
            12,
            pageGutter(context),
            32,
          ),
          child: !state.isSignedIn
              ? const EmptyState(
                  title: 'Sign in for updates',
                  message:
                      'Class messages, new papers and payment receipts appear '
                      'here once you sign in.',
                  icon: Icons.notifications_none_rounded,
                )
              : state.notifications.isEmpty
                  ? const EmptyState(
                      title: 'Nothing yet',
                      message:
                          'Messages from your school and the library will show '
                          'up here.',
                      icon: Icons.notifications_none_rounded,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: state.notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _NotificationTile(
                        notification: state.notifications[index],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentAt = notification.sentAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(notification.category),
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (sentAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatRelative(sentAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
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

  IconData _iconFor(String category) => switch (category) {
        'class' => Icons.groups_rounded,
        'subscription' => Icons.receipt_long_rounded,
        'document' => Icons.description_outlined,
        'reminder' => Icons.alarm_rounded,
        _ => Icons.campaign_outlined,
      };
}
