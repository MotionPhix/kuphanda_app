import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/navigation.dart';
import '../../core/widgets/common.dart';
import '../notifications/notifications_screen.dart';

/// The account block at the foot of the sidebar.
///
/// Its menu is not a bare list of words: the popover repeats who is signed in,
/// then the account's own screens, then the way out. That is the shape a person
/// expects from a desktop product, and it means the sidebar can carry Billing
/// and Log out without spending permanent rows on them.
class AccountChip extends StatelessWidget {
  const AccountChip({
    super.key,
    required this.name,
    required this.email,
    required this.initials,
  });

  final String name;
  final String email;
  final String initials;

  Future<void> _signOut(BuildContext context) async {
    final state = AppScope.read(context);
    final confirmed = await confirmAction(
      context,
      title: 'Log out?',
      message:
          'Downloaded files stay on this device until their subscription ends. '
          'Sign in again to sync them.',
      confirmLabel: 'Log out',
    );
    if (confirmed) await state.signOut();
  }

  void _openUpdates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return MenuAnchor(
      alignmentOffset: const Offset(0, -58),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(240, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 4),
        _AccountMenuItem(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          onPressed: () => openProfile(context),
        ),
        _AccountMenuItem(
          icon: Icons.credit_card_outlined,
          label: 'Subscription',
          onPressed: () => openSubscription(context),
        ),
        _AccountMenuItem(
          icon: Icons.notifications_none_rounded,
          label: 'Updates',
          onPressed: () => _openUpdates(context),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 4),
        _AccountMenuItem(
          icon: Icons.logout_rounded,
          label: 'Log out',
          destructive: true,
          onPressed: () => _signOut(context),
        ),
      ],
      builder: (context, controller, _) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(10),
          hoverColor: scheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  const _AccountMenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return MenuItemButton(
      onPressed: onPressed,
      leadingIcon: Icon(
        icon,
        size: 17,
        color: destructive ? scheme.error : scheme.onSurfaceVariant,
      ),
      style: MenuItemButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13.5,
          color: destructive ? scheme.error : scheme.onSurface,
        ),
      ),
    );
  }
}

