import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';

/// Surfaces sync state without hiding it behind a menu: signed out, syncing,
/// last successful sync, a failure, or pending removals.
class SyncCard extends StatelessWidget {
  const SyncCard({super.key, required this.state, required this.onSignIn});

  final AppState state;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = state.isSignedIn;
    final syncing = state.isSyncing;
    final error = state.syncError;
    final last = state.lastSyncAt;
    final pending = state.pendingRemovalCount;

    final String title;
    final String subtitle;
    if (!signedIn) {
      title = 'Sign in to sync your library';
      subtitle = 'Your school catalogue stays available offline, but downloads and purchases '
          'need an account.';
    } else if (syncing) {
      title = 'Syncing…';
      subtitle = 'Checking the catalogue and refreshing your offline files.';
    } else if (error != null) {
      title = 'Sync needs attention';
      subtitle = error;
    } else if (last != null) {
      title = 'Last synced ${formatRelative(last)}';
      subtitle = '${state.offlineMarkCount} offline ${state.offlineMarkCount == 1 ? 'document' : 'documents'}'
          '${pending > 0 ? ' · $pending removal${pending == 1 ? '' : 's'} pending' : ''}';
    } else {
      title = 'Not synced yet';
      subtitle = 'Pull the latest catalogue and download what you marked for offline reading.';
    }

    return AppCard(
      color: theme.colorScheme.primary.withValues(alpha: 0.045),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.14),
      child: Row(
        children: [
          Icon(
            !signedIn
                ? Icons.cloud_off_outlined
                : error != null
                    ? Icons.sync_problem_rounded
                    : syncing
                        ? Icons.sync_rounded
                        : Icons.cloud_done_outlined,
            size: 22,
            color: error != null ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!signedIn)
            OutlinedButton(onPressed: onSignIn, child: const Text('Sign in'))
          else
            IconButton(
              tooltip: 'Sync now',
              onPressed: syncing ? null : () => state.syncNow(),
              icon: syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
        ],
      ),
    );
  }
}
